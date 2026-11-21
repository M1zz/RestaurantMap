//
//  ReviewFeedView.swift
//  인생 맛집
//
//  단골 후기 — 네 번 넘게 간 사람만 올릴 수 있는 후기를 모아 본다.
//  마음에 드는 집은 '가볼 곳'에 담아 내 지도로 가져온다.
//
//  사용자가 올린 글을 보여 주는 화면이라 신고 · 차단 · 올리기 전 규칙 동의 · 연락처가 여기 다 있다 (심사 지침 1.2).
//

import SwiftUI
import SwiftData
import MapKit
import LeeoKit

struct ReviewFeedView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]
    @State private var store = RegularReviews.shared
    @State private var purchases = Purchases.shared
    @State private var paywallFeature: RestaurantFeature?
    @State private var composing: Restaurant?
    @State private var showsRules = false
    @State private var reporting: RegularReview?
    @State private var blocking: RegularReview?
    @State private var takingDown: RegularReview?
    /// LeeoKit 마스터 모드(설정 ▸ 버전 7번 누르기). 켜져 있으면 관리자 메뉴가 보인다.
    @AppStorage("dev.masterMode") private var masterMode = false
    @State private var notice: String?

    /// 후기를 올릴 수 있는 내 단골집.
    private var myRegulars: [Restaurant] {
        restaurants.filter { $0.regular.isRanked }
            .sorted { $0.regular.days > $1.regular.days }
    }

    var body: some View {
        NavigationStack {
            list
            .navigationTitle("단골 후기")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if myRegulars.isEmpty {
                            Text("단골(네 번)이 되면 후기를 올릴 수 있어요")
                        } else {
                            Section("후기를 올릴 단골집") {
                                ForEach(myRegulars) { restaurant in
                                    Button {
                                        composing = restaurant
                                    } label: {
                                        Label(restaurant.name,
                                              systemImage: restaurant.sharedReviewID == nil ? "square.and.pencil" : "checkmark.circle")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel(Text("단골 후기 올리기"))
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showsRules = true
                        } label: {
                            Label("후기 규칙", systemImage: "doc.text")
                        }
                        if !store.blocked.isEmpty {
                            Button {
                                store.unblockAll()
                            } label: {
                                Label("차단 \(store.blocked.count)명 모두 풀기", systemImage: "person.crop.circle.badge.checkmark")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel(Text("더 보기"))
                }
            }
            .task { await store.load() }
            .sheet(item: $composing) { restaurant in
                ReviewComposeView(restaurant: restaurant)
            }
            .sheet(isPresented: $showsRules) {
                NavigationStack { ReviewRulesView() }
            }
            .confirmationDialog("이 후기를 신고할까요?", isPresented: Binding(get: { reporting != nil }, set: { if !$0 { reporting = nil } }),
                                titleVisibility: .visible, presenting: reporting) { review in
                ForEach(RegularReviews.ReportReason.allCases) { reason in
                    Button(reason.title) {
                        Task { await store.report(review, reason: reason) }
                        notice = String(localized: "신고했어요. 24시간 안에 확인하고 문제가 있으면 지울게요.")
                    }
                }
                Button("취소", role: .cancel) {}
            } message: { _ in
                Text("신고한 후기는 바로 내 화면에서 사라져요.")
            }
            .confirmationDialog("이 사람을 차단할까요?", isPresented: Binding(get: { blocking != nil }, set: { if !$0 { blocking = nil } }),
                                titleVisibility: .visible, presenting: blocking) { review in
                Button("차단", role: .destructive) {
                    Task { await store.block(review) }
                }
                Button("취소", role: .cancel) {}
            } message: { review in
                Text("\(review.nickname) 님이 올린 후기가 더는 보이지 않아요.")
            }
            // 관리자 메뉴는 개발자만 보므로 번역하지 않는다 (verbatim).
            .confirmationDialog(Text(verbatim: "관리자: 이 후기를 모두에게서 내릴까요?"),
                                isPresented: Binding(get: { takingDown != nil }, set: { if !$0 { takingDown = nil } }),
                                titleVisibility: .visible, presenting: takingDown) { review in
                Button(role: .destructive) {
                    Task {
                        switch await store.takeDown(review) {
                        case .removed: notice = "내렸어요. 모든 사용자 화면에서 사라졌어요."
                        case .notAllowed: notice = "이 iCloud 계정에는 관리자 권한이 없어요. CloudKit 콘솔에서 Moderator 역할을 주세요 (docs/engineering/GOURMET.md)."
                        case .failed: notice = "내리지 못했어요. 연결을 확인한 뒤 다시 해 주세요."
                        }
                    }
                } label: { Text(verbatim: "내리기") }
            } message: { review in
                Text(verbatim: "\(review.nickname) · \(review.placeName)\n\(review.text)")
            }
            .alert(Text(verbatim: notice ?? ""), isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("확인", role: .cancel) {}
            }
            .paywall(for: $paywallFeature)
        }
    }

    private var list: some View {
        List {
            // 혼자 써도 남는 것: 내 단골집과 나만 보는 한마디. 후기를 못 읽어도 이 칸은 늘 보인다.
            Section {
                if myRegulars.isEmpty {
                    Text("같은 집을 네 번 가면 단골이 돼요. 다녀온 날을 기록하면 여기 모여요.", comment: "My regulars: empty hint")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(myRegulars) { restaurant in
                    Button { composing = restaurant } label: { MyRegularRow(restaurant: restaurant) }
                        .buttonStyle(.plain)
                }
            } header: {
                Text("내 단골집", comment: "Section: my own regular places")
            }

            if !almostRegulars.isEmpty {
                Section {
                    ForEach(almostRegulars) { restaurant in
                        let regular = restaurant.regular
                        HStack(spacing: 12) {
                            VisitStamp(days: regular.days, level: regular.level, size: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: restaurant.name).font(.subheadline.weight(.semibold))
                                if let next = regular.nextStep {
                                    Text(verbatim: next).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("곧 단골", comment: "Section: places one or two visits away from becoming a regular")
                }
            }

            Section {
                others
            } header: {
                Text("다른 단골들의 후기", comment: "Section: reviews posted by other regulars")
            } footer: {
                if store.phase == .loaded {
                    Text("네 번 넘게 간 단골만 후기를 올릴 수 있어요. 한 번 가 보고 쓴 글은 여기 없어요.")
                }
            }
        }
        .refreshable { await store.load() }
    }

    /// 곧 단골이 될 집 — 두세 번 간 집을 많이 간 순으로 셋.
    private var almostRegulars: [Restaurant] {
        restaurants.filter { $0.regular.level == .returned && !$0.regular.isLapsed }
            .sorted { $0.regular.days > $1.regular.days }
            .prefix(3).map { $0 }
    }

    /// 다른 사람들의 후기 칸. 없음 · 준비 중 · 연결 안 됨 · 실패를 따로 말한다.
    @ViewBuilder
    private var others: some View {
        switch store.phase {
        case .idle, .loading:
            HStack { Spacer(); ProgressView(); Spacer() }
        case .preparing:
            status("단골 후기를 준비하고 있어요", "곧 열려요. 그동안 단골집을 늘려 두면 열리자마자 후기를 올릴 수 있어요.",
                   symbol: "heart.circle", retries: false)
        case .offline:
            status("연결할 수 없어요", "인터넷 연결을 확인한 뒤 다시 불러와 주세요.", symbol: "wifi.slash", retries: true)
        case .failed:
            status("후기를 불러오지 못했어요", "잠시 뒤 다시 불러와 주세요.", symbol: "exclamationmark.triangle", retries: true)
        case .loaded:
            if store.visible.isEmpty {
                status("아직 후기가 없어요",
                       myRegulars.isEmpty ? "같은 집을 네 번 가면 단골이 되고, 단골 후기를 올릴 수 있어요."
                                          : "내 단골집 후기를 처음으로 올려 보세요.",
                       symbol: "heart.circle", retries: false)
            }
            ForEach(store.visible) { review in
                RegularCardView(review: review)
                    .padding(.vertical, 6)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if review.author != store.me {
                            Button { reporting = review } label: { Label("신고", systemImage: "exclamationmark.bubble") }
                                .tint(.red)
                        }
                    }
                    .contextMenu { actions(for: review) }
                    .overlay(alignment: .bottomTrailing) {
                        Menu {
                            actions(for: review)
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 32)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text("\(review.placeName) 후기 더 보기"))
                    }
            }
            if store.hasMore {
                Button("더 보기") { Task { await store.loadMore() } }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func status(_ title: LocalizedStringKey, _ detail: LocalizedStringKey, symbol: String, retries: Bool) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.title2).foregroundStyle(.secondary).accessibilityHidden(true)
            Text(title).font(.subheadline.weight(.semibold))
            Text(detail).font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if retries {
                Button("다시 불러오기") { Task { await store.load() } }
                    .font(.subheadline)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func actions(for review: RegularReview) -> some View {
        Button {
            addToWishlist(review)
        } label: {
            Label("가볼 곳에 담기", systemImage: "star.circle")
        }
        Button {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: review.coordinate))
            item.name = review.placeName
            item.openInMaps()
        } label: {
            Label("지도에서 보기", systemImage: "map")
        }
        if review.author != store.me {
            Divider()
            Button(role: .destructive) { reporting = review } label: {
                Label("신고", systemImage: "exclamationmark.bubble")
            }
            Button(role: .destructive) { blocking = review } label: {
                Label("이 사람 차단", systemImage: "person.crop.circle.badge.xmark")
            }
        }
        if masterMode {
            Divider()
            Button(role: .destructive) { takingDown = review } label: {
                Label { Text(verbatim: "관리자: 모두에게서 내리기") } icon: { Image(systemName: "trash") }
            }
        }
    }

    /// 후기의 가게를 내 '가볼 곳'으로 가져온다. 이미 있는 가게면 알려만 준다.
    private func addToWishlist(_ review: RegularReview) {
        let already = restaurants.contains {
            $0.name == review.placeName && abs($0.latitude - review.latitude) < 0.001 && abs($0.longitude - review.longitude) < 0.001
        }
        guard !already else {
            notice = String(localized: "이미 내 목록에 있는 가게예요.")
            return
        }
        guard purchases.canAddRestaurant(having: restaurants.count) else {
            paywallFeature = .restaurants
            return
        }
        let restaurant = Restaurant(name: review.placeName, address: review.address,
                                    latitude: review.latitude, longitude: review.longitude,
                                    categoryIcon: review.categoryIcon, listType: .wishlist)
        modelContext.insert(restaurant)
        do {
            try modelContext.save()
            notice = String(localized: "가볼 곳에 담았어요.")
        } catch {
            modelContext.delete(restaurant)
            notice = String(localized: "저장하지 못했어요")
        }
    }
}

// MARK: - 내 단골집

/// 내 단골집 한 줄 — 도장, 이름, 나만 보는 한마디. 누르면 한마디를 적는다.
private struct MyRegularRow: View {
    let restaurant: Restaurant

    var body: some View {
        let regular = restaurant.regular
        HStack(alignment: .top, spacing: 12) {
            VisitStamp(days: regular.days, level: regular.level, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(verbatim: restaurant.name).font(.headline)
                    if restaurant.sharedReviewID != nil {
                        Text("올림", comment: "Badge: this regular's note is posted publicly")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.pink.opacity(0.15), in: Capsule())
                            .foregroundStyle(.pink)
                    }
                }
                Text(verbatim: "\(regular.title) · \(String(localized: "\(regular.days)번"))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if restaurant.regularWord.isEmpty {
                    Text("이 집을 왜 계속 가나요?")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                } else {
                    Text(verbatim: restaurant.regularWord)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "square.and.pencil").font(.footnote).foregroundStyle(.tertiary).accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - 올리기

/// 단골집 한마디 쓰기. 그냥 저장하면 나만 보고, '모두에게 올리기' 를 켜면 단골 후기가 된다.
/// 처음 올릴 때는 규칙에 먼저 동의한다.
struct ReviewComposeView: View {
    let restaurant: Restaurant
    @Environment(\.dismiss) private var dismiss
    @State private var store = RegularReviews.shared
    @State private var text = ""
    @State private var isPosting = false
    @State private var failure: String?
    @State private var confirmsRemoval = false
    /// 모두에게 올릴지. 이미 올린 글을 고칠 때는 늘 켜져 있다.
    @State private var sharesPublicly = false

    private var isEditing: Bool { restaurant.sharedReviewID != nil }
    private var publishes: Bool { isEditing || (sharesPublicly && store.isEnabled) }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var preview: RegularReview? {
        RegularReview(restaurant: restaurant, id: "preview", text: text,
                      nickname: store.nickname.isEmpty ? String(localized: "별명") : store.nickname, author: "")
    }

    private var problem: ReviewFilter.Problem? {
        ReviewFilter.nicknameProblem(store.nickname) ?? ReviewFilter.problem(in: text)
    }

    var body: some View {
        NavigationStack {
            Form {
                if publishes, let preview {
                    Section("이렇게 보여요") {
                        RegularCardView(review: preview)
                    }
                }

                Section {
                    TextField("이 집을 왜 계속 가나요?", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text("한마디")
                } footer: {
                    HStack {
                        if publishes, let problem, !text.isEmpty { Text(verbatim: problem.message).foregroundStyle(.red) }
                        Spacer()
                        Text(verbatim: "\(text.count)/\(RegularReview.textLimit)")
                    }
                }

                if !isEditing, store.isEnabled {
                    Section {
                        Toggle(isOn: $sharesPublicly.animation()) {
                            Text("모두에게 올리기", comment: "Toggle: post this note publicly as a regular's review")
                        }
                    } footer: {
                        Text("끄면 나만 보는 한마디로 남아요. 켜면 단골 후기로 모두에게 보여요.", comment: "Footer for the post-publicly toggle")
                    }
                }

                if publishes {
                    Section {
                        TextField("별명", text: $store.nickname)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    } header: {
                        Text("별명")
                    } footer: {
                        Text("실명 말고 별명을 적어 주세요. \(RegularReview.nicknameLength.lowerBound)~\(RegularReview.nicknameLength.upperBound)자.")
                    }

                    Section {
                        Toggle("후기 규칙을 지킬게요", isOn: $store.agreedToRules)
                        NavigationLink("후기 규칙 보기") { ReviewRulesView() }
                    } footer: {
                        Text("가게 이름과 위치, 다녀온 횟수, 별점과 미식 기준 평균, 한마디, 별명이 모두에게 보여요. 다녀온 날짜와 사진, 메모는 올라가지 않아요.")
                    }
                }

                if isEditing {
                    Section {
                        Button("후기 내리기", role: .destructive) { confirmsRemoval = true }
                    }
                }
            }
            .navigationTitle(isEditing ? Text("후기 고치기") : publishes ? Text("단골 후기 올리기") : Text(verbatim: restaurant.name))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isPosting {
                        ProgressView()
                    } else {
                        if publishes {
                            Button("올리기") { post() }
                                .disabled(problem != nil || !store.agreedToRules)
                        } else {
                            Button("저장") { saveWord(); dismiss() }
                                .disabled(text.count > RegularReview.textLimit)
                        }
                    }
                }
            }
            .task {
                // 적어 둔 한마디에서 시작한다. 없으면 올려 둔 글에서.
                guard text.isEmpty else { return }
                if !restaurant.regularWord.isEmpty {
                    text = restaurant.regularWord
                } else if let id = restaurant.sharedReviewID, let mine = store.reviews.first(where: { $0.id == id }) {
                    text = mine.text
                }
            }
            .alert(Text(verbatim: failure ?? ""), isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("확인", role: .cancel) {}
            }
            .confirmationDialog("올린 후기를 내릴까요?", isPresented: $confirmsRemoval, titleVisibility: .visible) {
                Button("후기 내리기", role: .destructive) { remove() }
                Button("취소", role: .cancel) {}
            }
        }
    }

    /// 나만 보는 한마디로 남긴다. 올리든 안 올리든 늘 남는다.
    private func saveWord() {
        restaurant.regularWord = trimmed
        try? restaurant.modelContext?.save()
    }

    private func post() {
        isPosting = true
        Task {
            do {
                try await store.post(text: text, for: restaurant)
                saveWord()
                dismiss()
            } catch {
                failure = error.localizedDescription
            }
            isPosting = false
        }
    }

    private func remove() {
        isPosting = true
        Task {
            do {
                try await store.remove(for: restaurant)
                dismiss()
            } catch {
                failure = error.localizedDescription
            }
            isPosting = false
        }
    }
}

// MARK: - 규칙

/// 후기 규칙 — 무엇을 올리면 안 되는지, 신고하면 어떻게 되는지, 어디로 연락하는지.
struct ReviewRulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("올릴 수 없는 것") {
                Label("욕설, 혐오, 누군가를 깎아내리는 말", systemImage: "hand.raised")
                Label("광고, 링크, 연락처", systemImage: "megaphone")
                Label("가 보지 않고 쓴 거짓 후기", systemImage: "xmark.seal")
                Label("남의 이름이나 개인 정보", systemImage: "person.crop.circle.badge.exclamationmark")
            }
            Section("신고와 차단") {
                Text("후기를 길게 누르거나 밀면 신고하거나 올린 사람을 차단할 수 있어요.")
                Text("신고된 후기는 24시간 안에 확인하고, 규칙을 어긴 글은 지우고 올린 사람은 더 올릴 수 없게 해요.")
            }
            Section("문의") {
                Link(destination: URL(string: "mailto:\(RestaurantMapSpec.developerEmail)")!) {
                    Label(RestaurantMapSpec.developerEmail, systemImage: "envelope")
                }
            }
        }
        .navigationTitle("후기 규칙")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("닫기") { dismiss() }
            }
        }
    }
}
