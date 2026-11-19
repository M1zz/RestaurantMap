//
//  RegularReviews.swift
//  인생 맛집
//
//  단골 후기를 올리고 읽는 곳 — iCloud 공개 데이터베이스(`iCloud.com.Ysoup.restaurantmap`).
//
//   · 읽기는 누구나, 올리기는 iCloud 에 로그인한 사람만. 자기 글만 고치고 지울 수 있다(CloudKit 기본 권한).
//   · 신고(`ReviewReport`)는 레코드로 남고 개발자 피드백함에도 간다. 신고한 글은 그 자리에서 내 화면에서 사라진다.
//   · 차단은 이 기기에 적는다. 차단한 사람의 글은 다시 보이지 않고, 차단했다는 사실도 신고로 전해진다.
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

    enum Phase: Equatable { case idle, loading, loaded, unavailable }

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
    var nickname: String { didSet { defaults.set(nickname, forKey: Key.nickname) } }
    var agreedToRules: Bool { didSet { defaults.set(agreedToRules, forKey: Key.agreed) } }

    /// 차단 · 신고로 가린 것을 뺀, 화면에 보일 후기.
    var visible: [RegularReview] {
        reviews.filter { !blocked.contains($0.author) && !hidden.contains($0.id) }
    }

    var isEnabled: Bool { LeeoRemoteFlags.isEnabled(RestaurantFlag.publicReviews) }

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
        guard isEnabled else { phase = .unavailable; return }
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
            phase = .loaded
        } catch {
            logger.error("후기 읽기 실패: \(error.localizedDescription)")
            if reviews.isEmpty { phase = .unavailable }
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
        let id = restaurant.sharedReviewID ?? "review-" + UUID().uuidString
        guard let review = RegularReview(restaurant: restaurant, id: id,
                                         text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                         nickname: nickname.trimmingCharacters(in: .whitespaces), author: author) else {
            throw Failure.notRegular
        }
        try await save(review)
        restaurant.sharedReviewID = id
        try? restaurant.modelContext?.save()
        reviews.removeAll { $0.id == id }
        reviews.insert(review, at: 0)
        if phase != .loaded { phase = .loaded }
    }

    /// 새 방문을 남긴 뒤, 올려 둔 후기의 숫자(다녀온 횟수 · 평균)를 지금 기록으로 맞춘다. 한마디는 그대로다.
    func refreshSnapshot(for restaurant: Restaurant) async {
        guard let id = restaurant.sharedReviewID, isEnabled, let author = await identify() else { return }
        guard let record = try? await database.record(for: CKRecord.ID(recordName: id)),
              let old = RegularReview(record: record),
              var review = RegularReview(restaurant: restaurant, id: id, text: old.text, nickname: old.nickname, author: author) else { return }
        review.postedAt = old.postedAt
        try? await save(review)
        if let index = reviews.firstIndex(where: { $0.id == id }) { reviews[index] = review }
    }

    func remove(for restaurant: Restaurant) async throws {
        guard let id = restaurant.sharedReviewID else { return }
        do {
            try await database.deleteRecord(withID: CKRecord.ID(recordName: id))
        } catch let error as CKError where error.code == .unknownItem {
            // 이미 없다 — 지운 것과 같다
        } catch {
            throw Failure.network
        }
        restaurant.sharedReviewID = nil
        try? restaurant.modelContext?.save()
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
