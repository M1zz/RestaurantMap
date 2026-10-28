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
