//
//  RegularReviews.swift
//  인생 맛집
//
//  단골 후기를 올리고 읽는 곳 — iCloud 공개 데이터베이스(`iCloud.com.Ysoup.restaurantmap`).
//
//   · 읽기는 누구나, 올리기는 iCloud 에 로그인한 사람만. 자기 글만 고치고 지울 수 있다(CloudKit 기본 권한).
//   · 신고(`ReviewReport`)는 레코드로 남고 개발자 피드백함에도 간다. 신고한 글은 그 자리에서 내 화면에서 사라진다.
//   · 차단은 이 기기에 적는다. 차단한 사람의 글은 다시 보이지 않고, 차단했다는 사실도 신고로 전해진다.
//   · 서로 다른 세 사람이 신고한 글은 개발자가 보기 전에 모두의 화면에서 먼저 가린다.
//   · 개발자는 마스터 모드에서 글을 모두에게서 내린다. 지울 권한은 CloudKit 의 Moderator 역할이 판정한다
//     (앱의 버튼은 숨겨 둔 것일 뿐, 역할이 없는 사람이 눌러도 서버가 거절한다).
//   · 사고가 나면 원격 스위치(`RestaurantFlag.publicReviews`)로 심사 없이 끈다.
//
//  ⚠️ 레코드 타입 · 색인은 CloudKit 콘솔에서 운영(Production)에 올려야 스토어 빌드에서 보인다
//     (→ docs/engineering/GOURMET.md). 안 올라가 있으면 이 화면은 '준비 중'으로 선다.
//

import Foundation
import CloudKit
import LeeoKit
import OSLog

/// 원격으로 끌 수 있는 기능. rawValue 가 CloudKit `RemoteFlags` 의 필드 이름이다.
enum RestaurantFlag: String, LeeoRemoteFlag, CaseIterable {
    case publicReviews
}

@MainActor
@Observable
final class RegularReviews {
    static let shared = RegularReviews()

    /// 후기 화면이 무엇을 보여 줄지. 후기가 0개인 것은 `.loaded` 다 — 못 읽은 것과 섞지 않는다.
    enum Phase: Equatable {
        case idle, loading, loaded
        /// 아직 열지 않았다: 원격 스위치가 꺼졌거나, 운영 CloudKit 에 후기 틀 · 색인이 없다.
        case preparing
        /// 인터넷이나 iCloud 서버에 닿지 못했다. 다시 하면 된다.
        case offline
        /// 그 밖의 이유로 읽지 못했다.
        case failed
    }

    enum Failure: LocalizedError {
        case needsICloud, notRegular, rejected(ReviewFilter.Problem), network

        var errorDescription: String? {
            switch self {
            case .needsICloud: String(localized: "후기를 올리려면 iCloud에 로그인해야 해요. 설정에서 iCloud를 켠 뒤 다시 해 주세요.")
            case .notRegular: String(localized: "단골이 된 집에만 후기를 올릴 수 있어요.")
            case .rejected(let problem): problem.message
            case .network: String(localized: "지금은 연결할 수 없어요. 잠시 뒤 다시 해 주세요.")
            }
        }
    }

    private(set) var reviews: [RegularReview] = []
    private(set) var phase: Phase = .idle
    private(set) var hasMore = false
    /// 내 iCloud 사용자 이름. 로그인하지 않았으면 nil.
    private(set) var me: String?

    private(set) var blocked: Set<String> { didSet { defaults.set(Array(blocked), forKey: Key.blocked) } }
    private(set) var hidden: Set<String> { didSet { defaults.set(Array(hidden), forKey: Key.hidden) } }
    /// 여러 사람이 신고해 모두에게서 가린 글.
    private(set) var flagged: Set<String> = []
    var nickname: String { didSet { defaults.set(nickname, forKey: Key.nickname) } }
    var agreedToRules: Bool { didSet { defaults.set(agreedToRules, forKey: Key.agreed) } }

    /// 차단 · 신고로 가린 것을 뺀, 화면에 보일 후기.
    var visible: [RegularReview] {
        reviews.filter { !blocked.contains($0.author) && !hidden.contains($0.id) && !flagged.contains($0.id) }
    }

    var isEnabled: Bool { LeeoRemoteFlags.isEnabled(RestaurantFlag.publicReviews) }
    /// 지금 모두에게 올릴 수 있는가. 아직 열지 않았으면(스위치 꺼짐 · 운영에 후기 틀 없음) 올리기와 남의 후기 칸을 통째로 숨긴다 —
    /// '곧 열려요' 같은 빈 칸을 보이지 않고, 앱은 나만 쓰는 단골 수첩으로 온전하다.
    var canPost: Bool { isEnabled && phase != .preparing }

    @ObservationIgnored private var cursor: CKQueryOperation.Cursor?
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let logger = Logger(subsystem: "com.restaurantmap", category: "RegularReviews")
    @ObservationIgnored private let container = CKContainer(identifier: RestaurantMapApp.cloudContainer)
    private var database: CKDatabase { container.publicCloudDatabase }

    private enum Key {
        static let blocked = "reviews.blocked"
        static let hidden = "reviews.hidden"
        static let nickname = "reviews.nickname"
        static let agreed = "reviews.agreedToRules"
    }

    private static let pageSize = 30
    /// 이만큼의 서로 다른 사람이 신고하면 모두에게서 가린다.
    static let hideAfterReports = 3

    private init() {
        blocked = Set(defaults.stringArray(forKey: Key.blocked) ?? [])
        hidden = Set(defaults.stringArray(forKey: Key.hidden) ?? [])
        nickname = defaults.string(forKey: Key.nickname) ?? ""
        agreedToRules = defaults.bool(forKey: Key.agreed)
    }

    // MARK: 읽기

    func load() async {
        #if DEBUG
        if ScreenshotScene.current != nil { reviews = Self.samples; phase = .loaded; return }
        #endif
        guard isEnabled else { phase = .preparing; return }
        if reviews.isEmpty { phase = .loading }
        await identify()
        let query = CKQuery(recordType: RegularReview.recordType,
                            predicate: NSPredicate(format: "postedAt > %@", Date.distantPast as NSDate))
        query.sortDescriptors = [NSSortDescriptor(key: "postedAt", ascending: false)]
        do {
            let (results, next) = try await database.records(matching: query, resultsLimit: Self.pageSize)
            reviews = results.compactMap { try? $0.1.get() }.compactMap(RegularReview.init(record:))
            cursor = next
            hasMore = next != nil
            await loadFlagged()
            phase = .loaded
        } catch {
            logger.error("후기 읽기 실패: \(error.localizedDescription)")
            if reviews.isEmpty { phase = Self.phase(for: error) }
        }
    }

    /// 읽기 실패를 사용자가 할 수 있는 일로 나눈다.
    private static func phase(for error: Error) -> Phase {
        switch (error as? CKError)?.code {
        case .unknownItem, .invalidArguments:
            // 운영에 RegularReview 틀이 없거나 postedAt 색인이 없다 — 사용자 탓이 아니고 다시 해도 같다
            .preparing
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            .offline
        default:
            .failed
        }
    }

    func loadMore() async {
        guard let cursor else { return }
        do {
            let (results, next) = try await database.records(continuingMatchFrom: cursor, resultsLimit: Self.pageSize)
            let known = Set(reviews.map(\.id))
            reviews += results.compactMap { try? $0.1.get() }.compactMap(RegularReview.init(record:))
                .filter { !known.contains($0.id) }
            self.cursor = next
            hasMore = next != nil
        } catch {
            logger.error("후기 더 읽기 실패: \(error.localizedDescription)")
        }
    }

    /// 내가 누구인지 (내 글 표시 · 올리기에 쓴다). 로그인하지 않았으면 조용히 nil.
    @discardableResult
    func identify() async -> String? {
        if let me { return me }
        guard (try? await container.accountStatus()) == .available else { return nil }
        me = try? await container.userRecordID().recordName
        return me
    }

    // MARK: 올리기 · 내리기

    /// 후기를 올리거나, 이미 올린 것을 고친다. 올린 후기의 ID 는 식당에 적어 둔다.
    func post(text: String, for restaurant: Restaurant) async throws {
        guard let author = await identify() else { throw Failure.needsICloud }
        if let problem = ReviewFilter.problem(in: text) ?? ReviewFilter.nicknameProblem(nickname) {
            throw Failure.rejected(problem)
        }
        let id = restaurant.sharedReviewID.flatMap { $0.isEmpty ? nil : $0 } ?? "review-" + UUID().uuidString
        guard let review = RegularReview(restaurant: restaurant, id: id,
                                         text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                         nickname: nickname.trimmingCharacters(in: .whitespaces), author: author) else {
            throw Failure.notRegular
        }
        try await save(review)
        // 올리는 동안(네트워크) 식당이 지워졌을 수 있다 — 지워진 모델에 쓰면 죽는다
        guard !restaurant.isGone else { return }
        restaurant.sharedReviewID = id
        restaurant.modelContext?.saveNow()
        reviews.removeAll { $0.id == id }
        reviews.insert(review, at: 0)
        if phase != .loaded { phase = .loaded }
    }

    /// 새 방문을 남긴 뒤, 올려 둔 후기의 숫자(다녀온 횟수 · 평균)를 지금 기록으로 맞춘다. 한마디는 그대로다.
    func refreshSnapshot(for restaurant: Restaurant) async {
        guard !restaurant.isGone, let id = restaurant.sharedReviewID, !id.isEmpty, isEnabled, let author = await identify() else { return }
        // 서버를 다녀오는 사이 식당이 지워졌으면 그만둔다 (방문을 남기고 곧바로 식당을 지운 경우)
        guard let record = try? await database.record(for: CKRecord.ID(recordName: id)),
              !restaurant.isGone,
              let old = RegularReview(record: record),
              var review = RegularReview(restaurant: restaurant, id: id, text: old.text, nickname: old.nickname, author: author) else { return }
        review.postedAt = old.postedAt
        try? await save(review)
        if let index = reviews.firstIndex(where: { $0.id == id }) { reviews[index] = review }
    }

    func remove(for restaurant: Restaurant) async throws {
        // 빈 이름으로 레코드 ID 를 만들면 예외로 죽는다 (깨진 백업에서 되살아난 값)
        guard let id = restaurant.sharedReviewID, !id.isEmpty else { return }
        do {
            try await database.deleteRecord(withID: CKRecord.ID(recordName: id))
        } catch let error as CKError where error.code == .unknownItem {
            // 이미 없다 — 지운 것과 같다
        } catch {
            throw Failure.network
        }
        guard !restaurant.isGone else { reviews.removeAll { $0.id == id }; return }
        restaurant.sharedReviewID = nil
        restaurant.modelContext?.saveNow()
        reviews.removeAll { $0.id == id }
    }

    private func save(_ review: RegularReview) async throws {
        let record = CKRecord(recordType: RegularReview.recordType, recordID: CKRecord.ID(recordName: review.id))
        review.fill(record)
        do {
            // 내 글을 통째로 다시 쓴다 — 먼저 읽어 올 필요가 없다
            _ = try await database.modifyRecords(saving: [record], deleting: [], savePolicy: .allKeys)
        } catch {
            logger.error("후기 올리기 실패: \(error.localizedDescription)")
            throw Failure.network
        }
    }

    // MARK: 신고 · 차단

    enum ReportReason: String, CaseIterable, Identifiable {
        case offensive, spam, fake, other

        var id: String { rawValue }

        var title: String {
            switch self {
            case .offensive: String(localized: "욕설 · 혐오 · 불쾌한 내용", comment: "Report reason")
            case .spam: String(localized: "광고 · 도배", comment: "Report reason")
            case .fake: String(localized: "거짓 후기 같아요", comment: "Report reason")
            case .other: String(localized: "그 밖의 문제", comment: "Report reason")
            }
        }
    }

    /// 신고한다. 신고한 글은 내 화면에서 바로 사라진다. 신고는 개발자가 24시간 안에 본다.
    func report(_ review: RegularReview, reason: ReportReason) async {
        hidden.insert(review.id)
        await file(review, kind: "report", reason: reason.rawValue)
    }

    /// 이 사람의 글을 다시 보지 않는다. 차단도 신고로 전해진다.
    func block(_ review: RegularReview) async {
        blocked.insert(review.author)
        await file(review, kind: "block", reason: "blocked")
    }

    func unblockAll() { blocked = [] }

    /// 신고를 모아 서로 다른 세 사람이 신고한 글을 찾는다. 못 읽으면 지난 결과를 그대로 둔다.
    private func loadFlagged() async {
        let query = CKQuery(recordType: "ReviewReport", predicate: NSPredicate(format: "kind == %@", "report"))
        guard let (results, _) = try? await database.records(matching: query, resultsLimit: 400) else { return }
        var reporters: [String: Set<String>] = [:]
        for case .success(let record) in results.map(\.1) {
            guard let review = record["review"] as? String, let who = record["reporter"] as? String else { continue }
            reporters[review, default: []].insert(who)
        }
        flagged = Set(reporters.filter { $0.value.count >= Self.hideAfterReports }.keys)
    }

    // MARK: 관리자

    enum TakeDown { case removed, notAllowed, failed }

    /// 신고가 들어온 후기 하나. 신고 레코드에 글이 함께 적혀 있어 원래 후기가 지워져도 무엇이 신고됐는지 보인다.
    struct Reported: Identifiable {
        let id: String
        let nickname: String
        let placeName: String
        let text: String
        var reasons: [String]
        var reporters: Set<String>
        var lastReportedAt: Date
        /// 원래 후기가 이미 모두에게서 내려갔는가.
        var isRemoved = false
    }

    /// 들어온 신고를 후기별로 모은다 — 신고한 사람이 많은 순, 같으면 최근 순.
    func loadReports() async throws -> [Reported] {
        let query = CKQuery(recordType: "ReviewReport", predicate: NSPredicate(format: "kind == %@", "report"))
        let (results, _) = try await database.records(matching: query, resultsLimit: 400)
        var byReview: [String: Reported] = [:]
        for case .success(let record) in results.map(\.1) {
            guard let id = record["review"] as? String else { continue }
            let at = record.creationDate ?? .distantPast
            var item = byReview[id] ?? Reported(id: id,
                                                nickname: record["nickname"] as? String ?? "",
                                                placeName: record["placeName"] as? String ?? "",
                                                text: record["text"] as? String ?? "",
                                                reasons: [], reporters: [], lastReportedAt: at)
            if let reason = record["reason"] as? String, !item.reasons.contains(reason) { item.reasons.append(reason) }
            item.reporters.insert(record["reporter"] as? String ?? record.recordID.recordName)
            item.lastReportedAt = max(item.lastReportedAt, at)
            byReview[id] = item
        }
        // 원래 후기가 아직 있는지 한 번에 묻는다. 없는 것은 이미 내려간 글이다.
        let ids = byReview.keys.filter { !$0.isEmpty }.map { CKRecord.ID(recordName: $0) }
        if !ids.isEmpty, let found = try? await database.records(for: ids, desiredKeys: []) {
            for (id, result) in found {
                if case .failure(let error as CKError) = result, error.code == .unknownItem {
                    byReview[id.recordName]?.isRemoved = true
                }
            }
        }
        return byReview.values.sorted {
            ($0.reporters.count, $0.lastReportedAt) > ($1.reporters.count, $1.lastReportedAt)
        }
    }

    /// 개발자가 글을 모두에게서 내린다. CloudKit 에서 Moderator 역할을 받은 계정만 남의 글을 지울 수 있다.
    func takeDown(_ review: RegularReview) async -> TakeDown {
        await takeDown(id: review.id)
    }

    func takeDown(id: String) async -> TakeDown {
        guard !id.isEmpty else { return .failed }
        do {
            try await database.deleteRecord(withID: CKRecord.ID(recordName: id))
        } catch let error as CKError where error.code == .unknownItem {
            // 이미 없다 — 내린 것과 같다
        } catch let error as CKError where error.code == .permissionFailure || error.code == .notAuthenticated {
            return .notAllowed
        } catch {
            logger.error("후기 내리기 실패: \(error.localizedDescription)")
            return .failed
        }
        reviews.removeAll { $0.id == id }
        return .removed
    }

    private func file(_ review: RegularReview, kind: String, reason: String) async {
        let record = CKRecord(recordType: "ReviewReport")
        record["review"] = review.id
        record["author"] = review.author
        record["kind"] = kind
        record["reason"] = reason
        record["reporter"] = await identify() ?? "signed-out"
        record["text"] = review.text
        record["nickname"] = review.nickname
        record["placeName"] = review.placeName
        if (try? await database.save(record)) == nil {
            logger.error("신고 레코드 저장 실패 — 피드백함으로만 보낸다")
        }
        // 개발자가 늘 보는 피드백함에도 남긴다 (24시간 안에 확인)
        let message = "[후기 신고: \(kind) / \(reason)] 후기 \(review.id) · 올린 사람 \(review.author) · \(review.nickname) · \(review.placeName)\n\(review.text)"
        _ = try? await LeeoFeedbackService(spec: RestaurantMapSpec.self)
            .submit(type: "other", message: message, deviceInfo: LeeoFeedbackService.baseDeviceInfo())
    }
}

#if DEBUG
extension RegularReviews {
    /// 공개 DB 의 개발 스키마 만들기 — `-cloudKitSchemaWarmup` 으로 띄우면 후기 · 신고 표본을 올렸다가 30초 뒤 지운다.
    /// 그 뒤 CloudKit 콘솔에서 색인을 달고 운영에 올린다 (→ docs/engineering/GOURMET.md).
    func warmupSchemaIfRequested() {
        guard CommandLine.arguments.contains("-cloudKitSchemaWarmup") else { return }
        Task {
            guard let author = await identify() else { print("☁️ 후기 스키마 워밍업: iCloud 로그인이 필요하다"); return }
            let review = CKRecord(recordType: RegularReview.recordType, recordID: CKRecord.ID(recordName: "warmup-review"))
            Self.samples[0].fill(review)
            review["author"] = author
            let report = CKRecord(recordType: "ReviewReport", recordID: CKRecord.ID(recordName: "warmup-report"))
            for key in ["review", "author", "kind", "reason", "reporter", "text", "nickname", "placeName"] { report[key] = "warmup" }
            do {
                _ = try await database.modifyRecords(saving: [review, report], deleting: [], savePolicy: .allKeys)
                print("☁️ 후기 스키마 워밍업: 표본 2개를 올렸다 — 30초 뒤 지운다")
                try? await Task.sleep(for: .seconds(30))
                _ = try await database.modifyRecords(saving: [], deleting: [review.recordID, report.recordID])
                print("☁️ 후기 스키마 워밍업: 표본을 지웠다")
            } catch {
                print("☁️ 후기 스키마 워밍업 실패: \(error)")
            }
        }
    }

    /// 스크린샷 장면에 세울 예시 후기. 네트워크를 타지 않는다.
    static var samples: [RegularReview] {
        let ko = Locale.preferredLanguages.first?.hasPrefix("ko") ?? false
        func review(_ i: Int, _ name: String, _ icon: String, _ days: Int, _ months: Int, _ level: RegularLevel,
                    _ rating: Double, _ text: String, _ nick: String) -> RegularReview {
            RegularReview(id: "sample-\(i)", placeName: name, address: ko ? "서울 성동구 성수동" : "Seongsu, Seoul",
                          categoryIcon: icon, latitude: 37.5446, longitude: 127.0557, days: days, level: level, months: months,
                          rating: rating,
                          criteria: [.ingredient: 4.8 - Double(i) * 0.2, .technique: 4.6, .harmony: 4.7 - Double(i) * 0.1, .personality: 4.3],
                          consistency: i == 2 ? .mostly : .steady, text: text, nickname: nick, author: "sample-\(i)",
                          postedAt: Date().addingTimeInterval(Double(-i - 1) * 86_400 * 2))
        }
        return ko ? [
            review(0, "스시 하루", "fish.fill", 14, 19, .lifetime, 4.9, "샤리 온도가 갈 때마다 같아요. 제철 네타가 바뀌는 재미로 계속 갑니다.", "초밥러"),
            review(1, "멘야 소라", "takeoutbag.and.cup.and.straw.fill", 9, 8, .lifetime, 4.7, "국물이 진한데 끝이 깔끔해요. 면 삶기가 늘 정확합니다.", "면식가"),
            review(2, "나폴리 화덕", "flame.fill", 5, 4, .regular, 4.4, "도우 끝이 쫄깃하고 토마토 소스 산미가 좋아요.", "화덕앞자리"),
        ] : [
            review(0, "Sushi Haru", "fish.fill", 14, 19, .lifetime, 4.9, "The rice is the same temperature every single time. I keep going back for the seasonal fish.", "nigiri"),
            review(1, "Menya Sora", "takeoutbag.and.cup.and.straw.fill", 9, 8, .lifetime, 4.7, "Rich broth with a clean finish, and the noodles are always cooked just right.", "slurp"),
            review(2, "Napoli Oven", "flame.fill", 5, 4, .regular, 4.4, "Chewy crust and a bright tomato sauce.", "front row"),
        ]
    }
}
#endif
