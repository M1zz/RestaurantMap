import Foundation
import LeeoKit

enum RestaurantMapSpec: LeeoAppSpec {
    static let appName = "인생맛집"
    static let developerEmail = "mizzking75@gmail.com"
    static let feedback = LeeoFeedbackConfig(containerIdentifier: "iCloud.com.Ysoup.FeedbackHub", appIdentifier: "com.Ysoup.restaurantmap")

    /// 정책 링크 — GitHub Pages(main:/docs)의 개인정보 처리방침 · 지원 · 소개 페이지.
    static let legal = LeeoLegalConfig(
        privacyURL: URL(string: "https://m1zz.github.io/RestaurantMap/privacy.html")!,
        supportURL: URL(string: "https://m1zz.github.io/RestaurantMap/support.html")!,
        marketingURL: URL(string: "https://m1zz.github.io/RestaurantMap/")!
    )

    /// 인앱 결제 없음 (StoreKit 미사용).
    static let monetization = LeeoMonetization.free

    /// App Store 앱 ID — 리뷰 링크 · 친구에게 소개하기에 쓴다.
    static var appStoreID: String? { "6755934548" }

    /// 익명 사용 통계 → FeedbackHub. 없으면 bootstrap 이 스냅샷·app_open 을 건너뛴다.
    static let analytics: any LeeoAnalytics = LeeoUsageAnalytics(spec: RestaurantMapSpec.self)
}

// MARK: - 팁 (개발자 응원하기)

/// 무료 앱이라 LeeoStore 가 없다. 팁 엔진을 여기 하나 두고, 앱을 열 때 `startStandalone()` 을 부른다.
@MainActor
enum RestaurantMapTip {
    static let tipJar = LeeoTipJar(config: LeeoTipJarConfig(productIDs: [
        "com.Ysoup.restaurantmap.tip.small",
        "com.Ysoup.restaurantmap.tip.medium",
        "com.Ysoup.restaurantmap.tip.large",
    ]))
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
