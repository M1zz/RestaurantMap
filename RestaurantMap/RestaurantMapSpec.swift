import Foundation
import LeeoKit

enum RestaurantMapSpec: LeeoAppSpec {
    static let appName = "인생맛집"
    static let developerEmail = "leeo@kakao.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.Ysoup.restaurantmap")

    /// 정책 링크 — GitHub Pages(main:/docs)의 개인정보 처리방침 · 지원 · 소개 페이지.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/RestaurantMap/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/RestaurantMap/support.html")!,
        marketingURL: URL(string: "https://m1zz.github.io/RestaurantMap/")!
    )

    /// 수익모델 — 무료 다운로드 + 무료 · Plus · Pro. 칸마다 주 · 월 · 연 구독과 평생.
    /// (1.0.2 빌드 5 까지는 유료 다운로드였다. 그때 산 사람은 Pro 평생 → RestaurantPlan.boughtTheApp)
    /// 무엇이 어느 칸에서 열리는지는 `RestaurantFeature.tier` 한 곳, 상품은 `RestaurantPlan` 에 있다.
    static let monetization = LeeoMonetization.freemiumSubscription(
        LeeoSubscriptionConfig(
            productIDs: RestaurantPlan.productIDs,
            // 자체 약관이 없으므로 애플 표준 사용권 계약(EULA)을 건다. 구독을 파는 앱의 심사 필수 항목이다.
            termsURL: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!,
            entitlementIDs: RestaurantPlan.entitlementIDs,
            gate: LeeoGatePolicy(
                // 한도는 새 식당을 저장할 때만 본다. 이미 저장한 식당은 보기 · 고치기 · 지우기 모두 그대로다.
                freeLimits: [RestaurantFeature.restaurants.rawValue: RestaurantPlan.freeRestaurants],
                proOnly: [RestaurantFeature.visitReminder.rawValue, RestaurantFeature.backup.rawValue]),
            // 개발자 응원하기(팁) — 소모성 셋. 기능을 열지 않는다.
            tipJar: LeeoTipJarConfig(productIDs: RestaurantPlan.tipProductIDs)))

    /// App Store 앱 ID — 리뷰 링크 · 친구에게 소개하기에 쓴다.
    static var appStoreID: String? { "6755934548" }

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: RestaurantMapSpec.self)
}

// MARK: - 팁 (개발자 응원하기)

/// 팁 엔진은 LeeoStore 안에 있다 (결제 리스너가 하나여야 팁 거래를 서로 다투지 않는다).
@MainActor
enum RestaurantMapTip {
    static var tipJar: LeeoTipJar { Purchases.shared.tipJar }
}

/// 팁을 부탁할 만한 순간 — 지금까지 남긴 방문 기록 수. 큰 것부터.
enum RestaurantMapTipMoments {
    static let visits = [200, 50, 20]

    static func reached(visitCount n: Int) -> [LeeoTipMoment] {
        visits.filter { n >= $0 }.map { threshold in
            LeeoTipMoment(id: "visits.\(threshold)",
                          message: String(localized: "지금까지 맛집 방문 \(n)번을 기록했어요",
                                          comment: "Tip ask card: how many restaurant visits the person has logged so far"))
        }
    }

    static func reachedNow(in restaurants: [Restaurant]) -> [LeeoTipMoment] {
        reached(visitCount: restaurants.reduce(0) { $0 + ($1.visits?.count ?? 0) })
    }
}
