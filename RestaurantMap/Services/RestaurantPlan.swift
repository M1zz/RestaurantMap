//
//  RestaurantPlan.swift
//  인생 맛집
//
//  어느 칸(무료 · Plus · Pro)을 쓰는가, 그 칸이 무엇을 여는가.
//
//   · 무료: 식당 30곳(가본 곳 · 가볼 곳), 지도 검색 · 위치 고르기, 방문 기록(날짜 · 별점 · 메뉴 · 사진 · 메모),
//           음식별 맛 평가, 길찾기 · 전화, 식당 · 방문 기록 CSV 내보내기
//   · Plus: 식당 무제한, 음식 종류 직접 추가, 나의 탑6 순위, 취향 프로필 수정
//   · Pro:  Plus 전부 + 다녀온 뒤 기록 알림, iCloud 백업
//
//  ⚠️ 절대 잠그지 않는 것: 이미 저장한 식당 · 방문 기록 보기 · 고치기 · 지우기(30곳이 넘어도),
//     이미 정한 탑6 보기 · 빼기, 취향 프로필 보기, iCloud 에서 되살리기, CSV 내보내기, 접근성.
//     한도는 **새 식당을 저장할 때만** 본다.
//
//  StoreKit 은 여기 없다. 영수증은 `Purchases` 가 읽는다.
//

import Foundation
import StoreKit

/// 칸. 값이 클수록 더 많이 연다. Pro 는 Plus 를 전부 포함한다.
enum RestaurantTier: Int, Comparable, CaseIterable {
    case free = 0
    case plus = 1
    case pro = 2

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .free: String(localized: "무료", comment: "Plan name: free tier")
        case .plus: String(localized: "인생 맛집 Plus", comment: "Plan name: Plus tier")
        case .pro:  String(localized: "인생 맛집 Pro", comment: "Plan name: Pro tier")
        }
    }
}

/// 값을 받고 여는 것. 페이월 · 설정 · 잠금 자리가 모두 이 목록만 읽는다.
enum RestaurantFeature: String, Identifiable, CaseIterable {
    case restaurants
    case customCategory
    case top6
    case tasteProfile
    case visitReminder
    case backup

    var id: String { rawValue }

    /// 이 기능을 여는 가장 낮은 칸.
    var tier: RestaurantTier {
        switch self {
        case .restaurants, .customCategory, .top6, .tasteProfile: .plus
        case .visitReminder, .backup: .pro
        }
    }
}

enum RestaurantPlan {

    // MARK: - 무료 한도

    /// 가본 곳 · 가볼 곳을 합친 식당 수.
    static let freeRestaurants = 30

    // MARK: - 상품 ID
    //
    // ⚠️ App Store Connect · Products.storekit 과 글자 하나까지 같아야 한다.
    //    주 · 월 · 연 구독 여섯은 한 구독 그룹에 넣는다. Pro 가 위 단계라 서로 갈아탈 수 있다.

    private static let base = "com.Ysoup.restaurantmap"

    static let plusWeeklyID   = base + ".plus.weekly"
    static let plusMonthlyID  = base + ".plus.monthly"
    static let plusYearlyID   = base + ".plus.yearly"
    static let plusLifetimeID = base + ".plus.lifetime"
    static let proWeeklyID    = base + ".pro.weekly"
    static let proMonthlyID   = base + ".pro.monthly"
    static let proYearlyID    = base + ".pro.yearly"
    static let proLifetimeID  = base + ".pro.lifetime"
    /// Plus 평생을 산 사람이 Pro 평생으로 올리는 값.
    static let upgradeID      = base + ".pro.upgrade"
    /// 구독 중인 사람의 졸업가 Pro 평생 (→ LeeoGraduation).
    static let graduateID     = base + ".pro.graduate"

    /// 개발자 응원 팁. 아무것도 열지 않는다 — `productIDs` · `tierByProduct` 에 넣지 않는다.
    static let tipProductIDs = [base + ".tip.small", base + ".tip.medium", base + ".tip.large"]

    /// 상품마다 여는 칸. 구독은 같은 칸의 평생과 같은 권한, 올리기 · 졸업은 Pro 평생이다.
    static let tierByProduct: [String: RestaurantTier] = [
        plusWeeklyID: .plus, plusMonthlyID: .plus, plusYearlyID: .plus, plusLifetimeID: .plus,
        proWeeklyID: .pro, proMonthlyID: .pro, proYearlyID: .pro, proLifetimeID: .pro,
        upgradeID: .pro, graduateID: .pro,
    ]

    /// 페이월이 불러올 상품. 스토어에 아직 없는 상품은 불러와지지 않고, 그 단추는 서지 않는다.
    static let productIDs: [String] = [
        plusWeeklyID, plusMonthlyID, plusYearlyID, plusLifetimeID,
        proWeeklyID, proMonthlyID, proYearlyID, proLifetimeID,
        upgradeID, graduateID,
    ]

    static var entitlementIDs: Set<String> { Set(tierByProduct.keys) }

    /// 자동 갱신 구독 (구독 졸업을 제안할 대상).
    static let subscriptionIDs: Set<String> = [
        plusWeeklyID, plusMonthlyID, plusYearlyID, proWeeklyID, proMonthlyID, proYearlyID,
    ]

    static let lifetimeIDs: Set<String> = [plusLifetimeID, proLifetimeID, upgradeID, graduateID]

    /// 칸을 사는 상품 (올리기 · 졸업 제외). 이 중 하나라도 불러와야 '판다'고 본다.
    static let planIDs: Set<String> = subscriptionIDs.union([plusLifetimeID, proLifetimeID])

    /// 가진 상품들이 여는 칸. 가장 높은 것.
    static func tier(owning productIDs: Set<String>) -> RestaurantTier {
        productIDs.compactMap { tierByProduct[$0] }.max() ?? .free
    }

    static func ownsLifetime(_ tier: RestaurantTier, in productIDs: Set<String>) -> Bool {
        productIDs.contains { lifetimeIDs.contains($0) && tierByProduct[$0] == tier }
    }

    // MARK: - 이미 산 사람

    /// 유료 다운로드(₩4,400)였던 마지막 빌드 — 1.0.2 빌드 5. 그때까지 받은 사람은 이미 앱을 산 사람이라 Pro 평생이다.
    /// ⚠️ 페이월이 든 빌드의 번호는 이보다 커야 한다. 이 빌드를 내기 전에 페이월 없는 빌드를 또 내면 이 값을 그 번호로 올린다.
    static let lastPaidBuild = 5

    /// App Store 에서 처음 받은 빌드가 유료 다운로드 때인가.
    /// `originalAppVersion` 은 iOS 에서 빌드 번호다. 샌드박스 · Xcode 는 늘 "1.0" 을 돌려주므로 실제 App Store 만 본다.
    static func boughtTheApp() async -> Bool {
        guard case .verified(let app)? = try? await AppTransaction.shared,
              app.environment == .production,
              let build = Int(app.originalAppVersion.split(separator: ".").first ?? "") else { return false }
        return build <= lastPaidBuild
    }

    // MARK: - 기억해 두는 것

    private static let tierKey = "plan.tier"
    private static let everSoldKey = "plan.everSold"

    /// 마지막으로 확인한 칸. **nil 은 '무료'가 아니라 '아직 App Store 에 묻지 않았다'** 이다.
    static var cachedTier: RestaurantTier? {
        (UserDefaults.standard.object(forKey: tierKey) as? Int).flatMap(RestaurantTier.init(rawValue:))
    }

    static func setTier(_ tier: RestaurantTier) {
        guard cachedTier != tier else { return }
        UserDefaults.standard.set(tier.rawValue, forKey: tierKey)
    }

    /// 이 기기에서 칸 상품을 한 번이라도 불러왔는가.
    /// 상품을 App Store Connect 에 만들기 전에 이 빌드가 나가도, 살 수 없는 것으로 막히는 사람이 없게 한다.
    /// 한 번 불러온 뒤로는 네트워크가 끊겨도 영수증대로 막는다.
    static var everSold: Bool {
        get { UserDefaults.standard.bool(forKey: everSoldKey) }
        set { UserDefaults.standard.set(newValue, forKey: everSoldKey) }
    }
}
