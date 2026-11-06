//
//  PaywallView.swift
//  인생 맛집
//
//  인생 맛집의 세 칸(무료 · Plus · Pro)을 파는 한 장.
//  머리말 → (막힌 까닭) → 유료 칸 카드(들어온 자리의 칸이 먼저) → 무료 칸 → 비교표 → 약관.
//
//  칸마다 연 구독과 평생을 먼저 보이고, 주 · 월 구독은 펼쳐서 고른다.
//  첫 해 할인(App Store 첫 구독 할인)은 연 구독을 고르면 처음 보는 사람에게만 한 줄로 보인다.
//  스토어에서 불러오지 못한 상품의 단추는 서지 않는다.
//

import SwiftUI
import StoreKit
import LeeoKit

struct PaywallView: View {
    /// 어디서 들어왔는가. 그 칸을 맨 위에 세우고 막힌 까닭을 먼저 말한다.
    var highlight: RestaurantFeature?

    @State private var purchases = Purchases.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// 결제 시트를 이 페이월이 떠 있는 창에 띄운다 (→ Purchases.purchase).
    @Environment(\.purchase) private var purchaseAction

    @State private var plusTerm: PlanTerm = .yearly
    @State private var proTerm: PlanTerm = .yearly
    @State private var loadingProducts = true
    @State private var redeemingCode = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    if let highlight { reason(highlight) }
                    plansStatus
                    ForEach(paidOrder, id: \.self) { tierCard($0) }
                    freeCard
                    PlanComparisonTable()
                    if let message = purchases.failureMessage, !purchases.products.isEmpty {
                        Label(message, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    }
                    legal
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("나중에") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("구매 복원") {
                        Task {
                            await purchases.restore()
                            if let highlight, purchases.allows(highlight) { dismiss() }
                        }
                    }
                    .disabled(purchases.isWorking)
                }
            }
            .offerCodeRedemption(isPresented: $redeemingCode) { _ in
                Task {
                    await purchases.refresh()
                    if purchases.tier > .free { dismiss() }
                }
            }
            .task {
                LeeoAnalyticsCenter.track(.paywallShown(reason: highlight?.rawValue ?? "settings"))
                await loadPlans()
            }
        }
    }

    // MARK: 머리

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("인생 맛집 Plus · Pro")
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            Text("내 맛집 지도를 끝까지. 연 구독이나 평생 중에 고르세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// 막힌 자리에서 들어왔을 때 첫 줄. 무엇이 막혔고, 하던 것은 어떻게 되는지.
    private func reason(_ feature: RestaurantFeature) -> some View {
        let (title, note): (String, String) = switch feature {
        case .restaurants:
            (String(localized: "식당 \(RestaurantPlan.freeRestaurants)곳을 모았어요"),
             String(localized: "Plus부터 식당을 마음껏 저장할 수 있어요. 지금 적은 식당 정보는 그대로 남아 있어요."))
        case .customCategory:
            (String(localized: "음식 종류 직접 추가는 Plus에서 열려요"),
             String(localized: "자주 가는 음식 종류를 더해 내 방식대로 정리해요."))
        case .top6:
            (String(localized: "나의 탑6는 Plus에서 열려요"),
             String(localized: "인생 맛집 여섯 곳을 골라 1위부터 6위까지 순위를 매겨요."))
        case .tasteProfile:
            (String(localized: "취향 프로필 수정은 Plus에서 열려요"),
             String(localized: "맵기, 단맛, 짠맛, 기름진 맛, 본연의 맛까지 내 입맛을 차트로 맞춰요."))
        case .visitReminder:
            (String(localized: "다녀온 뒤 기록 알림은 Pro에서 열려요"),
             String(localized: "저장한 식당에서 먹고 나오면 40분 뒤에 기록을 남기라고 알려 드려요."))
        case .backup:
            (String(localized: "iCloud 백업은 Pro에서 열려요"),
             String(localized: "휴대폰을 바꿔도 방문 기록과 사진을 내 iCloud에서 되살려요."))
        }
        return VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            Text(note)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.accentColor.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// 유료 칸의 차례. 들어온 자리의 칸이 먼저다.
    private var paidOrder: [RestaurantTier] {
        highlight?.tier == .pro ? [.pro, .plus] : [.plus, .pro]
    }

    // MARK: 칸 카드

    private func tierCard(_ tier: RestaurantTier) -> some View {
        card(highlighted: highlight?.tier == tier && purchases.tier < tier) {
            cardTitle(tier.title, current: purchases.tier == tier)
            if tier == .plus {
                tagline(String(localized: "식당 수 제한 없이, 내 입맛대로 정리해요."))
                row("checkmark.circle", "무료의 모든 것")
                row("mappin.and.ellipse", "식당 무제한")
                row("plus.square.on.square", "음식 종류 직접 추가")
                row("crown", "나의 탑6 순위")
                row("chart.pie", "나의 취향 프로필")
            } else {
                tagline(String(localized: "다녀온 뒤 잊지 않게 알려 주고, 쌓인 기록은 지켜요."))
                row("square.stack.3d.up", "Plus의 모든 것")
                row("bell.badge", "다녀온 뒤 기록 알림")
                row("icloud", "iCloud 백업 · 복구")
            }
            // 이미 이 칸 이상이면 살 것이 없다. 구독을 평생으로 바꾸는 길은 설정에 있다.
            if purchases.tier < tier, hasAnyProduct(tier) {
                PlanTermPicker(term: term(for: tier), products: products(tier))
                    .padding(.top, 4)
                buyButton(tier)
            }
        }
    }

    private var freeCard: some View {
        card(highlighted: false) {
            cardTitle(RestaurantTier.free.title, current: purchases.isKnown && purchases.tier == .free)
            tagline(String(localized: "식당 \(RestaurantPlan.freeRestaurants)곳까지 지도에 모으고, 갈 때마다 맛을 기록해 보세요."))
        }
    }

    private func term(for tier: RestaurantTier) -> Binding<PlanTerm> {
        tier == .plus ? $plusTerm : $proTerm
    }

    private var upgradesToPro: Bool { purchases.ownsLifetime(.plus) }

    /// 칸의 상품들. **Plus 평생을 산 사람의 Pro 평생 자리에는 올리기 상품을 세운다.**
    private func products(_ tier: RestaurantTier) -> PlanTermPicker.Products {
        typealias E = RestaurantPlan
        if tier == .plus {
            return .init(weekly: purchases.product(E.plusWeeklyID), monthly: purchases.product(E.plusMonthlyID),
                         yearly: purchases.product(E.plusYearlyID), lifetime: purchases.product(E.plusLifetimeID))
        }
        return .init(weekly: purchases.product(E.proWeeklyID), monthly: purchases.product(E.proMonthlyID),
                     yearly: purchases.product(E.proYearlyID),
                     lifetime: purchases.product(upgradesToPro ? E.upgradeID : E.proLifetimeID))
    }

    private func hasAnyProduct(_ tier: RestaurantTier) -> Bool {
        PlanTerm.allCases.contains { products(tier)[$0] != nil }
    }

    private func buyButton(_ tier: RestaurantTier) -> some View {
        let chosen = term(for: tier).wrappedValue
        let product = products(tier)[chosen]
        let title: String = switch chosen {
        case .weekly:  String(localized: "주 구독 시작")
        case .monthly: String(localized: "월 구독 시작")
        case .yearly:  String(localized: "연 구독 시작")
        case .lifetime where tier == .pro && upgradesToPro: String(localized: "Pro 평생으로 올리기")
        case .lifetime: String(localized: "평생으로 사기")
        }
        return Button {
            guard let product else { return }
            Task {
                await purchases.purchase(product, using: purchaseAction)
                if purchases.tier >= tier { dismiss() }
            }
        } label: {
            if purchases.isWorking {
                ProgressView()
            } else {
                Text(title)
            }
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(purchases.isWorking || product == nil)
    }

    // MARK: 요금제를 못 불러왔을 때

    @ViewBuilder
    private var plansStatus: some View {
        if purchases.products.isEmpty && loadingProducts {
            HStack(spacing: 10) {
                ProgressView()
                Text("값을 불러오는 중…").foregroundStyle(.secondary)
            }
        } else if purchases.products.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("요금제를 불러오지 못했어요. 인터넷 연결을 확인하고 다시 불러와 주세요.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button {
                    Task { await loadPlans() }
                } label: {
                    Label("다시 불러오기", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    /// 첫 조회가 빈손이면 한 번 더 청한다. 샌드박스(심사 환경)는 첫 조회가 비어 오는 일이 잦다.
    private func loadPlans() async {
        loadingProducts = true
        await purchases.loadProducts()
        if purchases.products.isEmpty {
            try? await Task.sleep(for: .seconds(1.5))
            await purchases.loadProducts()
        }
        loadingProducts = false
    }

    // MARK: 약관 (구독을 파는 앱의 심사 필수 항목)

    private var legal: some View {
        VStack(alignment: .leading, spacing: 10) {
            if purchases.products.contains(where: { $0.subscription != nil }) {
                Text("구독은 기간이 끝나기 24시간 전까지 해지하지 않으면 같은 요금으로 자동 갱신되며, Apple 계정으로 결제돼요. 연 구독을 처음 시작하면 첫 해는 할인된 값일 수 있고, 그 뒤에는 정가로 갱신돼요. 해지와 관리는 App Store 계정 설정에서 해요. 평생은 구독이 아니라 한 번 결제예요.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ViewThatFits {
                HStack(spacing: 18) { legalLinks }
                VStack(alignment: .leading, spacing: 10) { legalLinks }
            }
        }
    }

    @ViewBuilder
    private var legalLinks: some View {
        if let terms = RestaurantMapSpec.monetization.subscriptionTermsURL {
            Button("이용약관") { openURL(terms) }
        }
        Button("개인정보 처리방침") { openURL(RestaurantMapSpec.legal.privacyURL) }
        Button {
            redeemingCode = true
        } label: {
            Label("코드 사용", systemImage: "ticket")
        }
        .disabled(purchases.isWorking)
    }

    // MARK: 부속

    private func card<Content: View>(highlighted: Bool, @ViewBuilder content: () -> Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(alignment: .leading, spacing: 10, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                shape.fill(Color(.secondarySystemBackground))
                shape.strokeBorder(highlighted ? Color.accentColor : .clear, lineWidth: 2)
            }
    }

    private func cardTitle(_ title: String, current: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if current {
                Text("지금 쓰는 칸")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.12), in: Capsule())
            }
            Spacer(minLength: 0)
        }
    }

    private func tagline(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func row(_ icon: String, _ title: LocalizedStringKey) -> some View {
        Label {
            Text(title).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(Color.accentColor)
        }
        .font(.body)
    }
}

// MARK: - 주 · 월 · 연 · 평생

enum PlanTerm: CaseIterable {
    case weekly, monthly, yearly, lifetime
}

/// 칸 하나의 길 고르기. 연 구독 · 평생을 먼저 보이고, 주 · 월은 펼쳐서 고른다.
struct PlanTermPicker: View {
    struct Products {
        var weekly, monthly, yearly, lifetime: Product?

        subscript(term: PlanTerm) -> Product? {
            switch term {
            case .weekly: weekly
            case .monthly: monthly
            case .yearly: yearly
            case .lifetime: lifetime
            }
        }
    }

    @Binding var term: PlanTerm
    let products: Products
    @State private var showsShortTerms = false
    @State private var introEligible = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            options(.yearly, .lifetime)
            if hasShortTerms {
                if showsShortTerms || term == .weekly || term == .monthly {
                    options(.weekly, .monthly)
                } else {
                    Button("주 · 월 구독도 보기") { showsShortTerms = true }
                        .font(.body)
                }
            }
            if let note {
                Text(note)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            // 연 구독을 못 불러왔으면 고를 수 있는 첫 길로 옮긴다.
            if products[term] == nil, let first = [.yearly, .lifetime, .monthly, .weekly].first(where: { products[$0] != nil }) {
                term = first
            }
        }
        .task(id: products.yearly?.id) {
            introEligible = await products.yearly?.subscription?.isEligibleForIntroOffer ?? false
        }
    }

    private var hasShortTerms: Bool { products.weekly != nil || products.monthly != nil }

    /// 아주 큰 글자에서는 위아래로 세운다. 나란히 두면 가격이 몇 줄로 꺾인다.
    private func options(_ a: PlanTerm, _ b: PlanTerm) -> some View {
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: 8)) : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            option(a)
            option(b)
        }
    }

    private var note: String? {
        switch term {
        case .yearly:
            guard introEligible, let offer = products.yearly?.subscription?.introductoryOffer,
                  offer.paymentMode == .payUpFront || offer.paymentMode == .payAsYouGo else { return nil }
            return String(format: LeeoLadderText.introFormat, offer.displayPrice)
        case .lifetime:
            guard let yearly = products.yearly?.price, let lifetime = products.lifetime?.price, yearly > 0 else { return nil }
            let years = Int(NSDecimalNumber(decimal: lifetime / yearly).doubleValue.rounded(.down))
            return years >= 2 ? String(format: LeeoLadderText.lifetimeWorthFormat, years) : nil
        case .weekly, .monthly:
            return nil
        }
    }

    private func title(_ term: PlanTerm) -> String {
        switch term {
        case .weekly: String(localized: "주 구독")
        case .monthly: String(localized: "월 구독")
        case .yearly: LeeoLadderText.yearly
        case .lifetime: LeeoLadderText.lifetime
        }
    }

    private func price(_ term: PlanTerm) -> String? {
        guard let price = products[term]?.displayPrice else { return nil }
        switch term {
        case .weekly: return String(localized: "\(price) / 주")
        case .monthly: return String(localized: "\(price) / 월")
        case .yearly: return String(format: LeeoLadderText.perYearFormat, price)
        case .lifetime: return price
        }
    }

    @ViewBuilder
    private func option(_ value: PlanTerm) -> some View {
        if let price = price(value) {
            let selected = term == value
            Button {
                term = value
            } label: {
                VStack(spacing: 2) {
                    Text(title(value)).font(.body.weight(.semibold))
                    Text(price).font(.body).monospacedDigit()
                }
                .multilineTextAlignment(.center)
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? Color.accentColor.opacity(0.12) : Color(.tertiarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 1.5)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }
}

// MARK: - 비교표

/// 세 칸이 무엇을 주는지 한눈에. 아주 큰 글자에서는 기능마다 세 칸을 아래로 적는다.
struct PlanComparisonTable: View {
    @Environment(\.dynamicTypeSize) private var typeSize

    private enum Cell { case yes, no, text(String) }

    private struct Line: Identifiable {
        let title: String
        let free: Cell, plus: Cell, pro: Cell
        var id: String { title }
    }

    private var lines: [Line] {
        let unlimited = Cell.text(String(localized: "무제한"))
        return [
            Line(title: String(localized: "식당 저장"),
                 free: .text(String(localized: "\(RestaurantPlan.freeRestaurants)곳")), plus: unlimited, pro: unlimited),
            Line(title: String(localized: "방문 기록 · 사진 · 별점"), free: .yes, plus: .yes, pro: .yes),
            Line(title: String(localized: "음식별 맛 평가"), free: .yes, plus: .yes, pro: .yes),
            Line(title: String(localized: "지도 · 길찾기 · 전화"), free: .yes, plus: .yes, pro: .yes),
            Line(title: String(localized: "음식 종류 직접 추가"), free: .no, plus: .yes, pro: .yes),
            Line(title: String(localized: "나의 탑6 순위"), free: .no, plus: .yes, pro: .yes),
            Line(title: String(localized: "취향 프로필"), free: .no, plus: .yes, pro: .yes),
            Line(title: String(localized: "다녀온 뒤 기록 알림"), free: .no, plus: .no, pro: .yes),
            Line(title: String(localized: "iCloud 백업 · 복구"), free: .no, plus: .no, pro: .yes),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("한눈에 비교")
                .font(.title2.bold())
                .accessibilityAddTraits(.isHeader)
            if typeSize.isAccessibilitySize {
                ForEach(lines) { line in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.title).font(.body.weight(.semibold))
                        ForEach(Array(zip(tierTitles, [line.free, line.plus, line.pro])), id: \.0) { title, cell in
                            HStack {
                                Text(title)
                                Spacer()
                                cellView(cell, in: title)
                            }
                        }
                    }
                    Divider()
                }
            } else {
                Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                    GridRow {
                        Color.clear.frame(height: 1).gridCellUnsizedAxes([.horizontal, .vertical])
                        ForEach(shortTitles, id: \.self) { title in
                            Text(title)
                                .font(.body.weight(.semibold))
                                .gridColumnAlignment(.center)
                        }
                    }
                    ForEach(lines) { line in
                        Divider()
                        GridRow {
                            Text(line.title).font(.body).fixedSize(horizontal: false, vertical: true)
                            cellView(line.free, in: tierTitles[0])
                            cellView(line.plus, in: tierTitles[1])
                            cellView(line.pro, in: tierTitles[2])
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var tierTitles: [String] { RestaurantTier.allCases.map(\.title) }

    /// 표 머리. 칸 이름에서 앱 이름을 뺀 짧은 꼴(무료 · Plus · Pro).
    private var shortTitles: [String] { [RestaurantTier.free.title, "Plus", "Pro"] }

    /// 칸 하나. VoiceOver 는 어느 칸인지 함께 읽는다 ("Plus: 포함").
    @ViewBuilder
    private func cellView(_ cell: Cell, in tier: String) -> some View {
        switch cell {
        case .yes:
            Image(systemName: "checkmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .accessibilityLabel(Text(verbatim: "\(tier): \(String(localized: "포함"))"))
        case .no:
            Image(systemName: "minus")
                .font(.body)
                .foregroundStyle(.tertiary)
                .accessibilityLabel(Text(verbatim: "\(tier): \(String(localized: "포함 안 됨"))"))
        case .text(let text):
            Text(text).font(.body).monospacedDigit()
                .accessibilityLabel(Text(verbatim: "\(tier): \(text)"))
        }
    }
}

// MARK: - 잠긴 자리에서 부르는 길

extension View {
    /// `feature` 가 들어 있으면 그 기능의 페이월을 낸다.
    func paywall(for feature: Binding<RestaurantFeature?>) -> some View {
        sheet(item: feature) { PaywallView(highlight: $0) }
    }
}

/// 잠긴 기능의 이름. 그 칸이 아니면 자물쇠를 함께 보이고, VoiceOver 는 어느 칸에서 열리는지 읽는다.
struct LockedLabel: View {
    let title: LocalizedStringKey
    var systemImage: String?
    let feature: RestaurantFeature
    @State private var purchases = Purchases.shared

    var body: some View {
        HStack(spacing: 8) {
            if let systemImage {
                Label(title, systemImage: systemImage)
            } else {
                Text(title)
            }
            if !purchases.allows(feature) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(Text(String(localized: "잠김, \(feature.tier.title) 필요")))
            }
        }
    }
}
