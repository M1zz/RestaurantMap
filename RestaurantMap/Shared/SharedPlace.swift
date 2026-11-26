//
//  SharedPlace.swift
//  인생 맛집 · 공유 확장과 앱이 함께 쓴다
//
//  인스타 · 블로그 · 지도 앱의 공유 버튼으로 담은 식당이 앱으로 건너오는 길.
//  공유 확장(RestaurantMapShare)은 저장소(SwiftData · iCloud)를 열지 않는다 — 고른 식당을 이 보관함에 적기만 하고,
//  앱이 앞으로 나올 때 꺼내 '가볼 곳' 에 넣는다 (→ ShareInboxReceiver).
//  저장소를 두 프로세스가 함께 열면 iCloud 동기화가 엉킬 수 있어서, 넘기는 것은 이 작은 목록뿐이다.
//

import Foundation

/// 공유로 고른 식당 하나. 식당을 만들 만큼만 담는다.
struct SharedPlace: Codable, Equatable {
    var name: String
    var address: String
    var phone: String
    /// 카카오의 큰 분류(음식점 · 카페) 또는 Apple 지도의 장소 종류
    var category: String
    /// 음식 종류를 짐작할 단서 (카카오의 '음식점 > 한식 > 냉면' 같은 것)
    var categoryHints: [String]
    var latitude: Double
    var longitude: Double
    /// 보고 저장한 글 · 영상의 주소
    var link: String
    var savedAt: Date = .now
}

/// 앱 그룹에 둔 보관함. 확장이 넣고 앱이 꺼낸다.
enum ShareInbox {
    static let appGroup = "group.com.Ysoup.restaurantmap"
    private static let key = "shareInbox"

    private static var defaults: UserDefaults? { UserDefaults(suiteName: appGroup) }

    static var items: [SharedPlace] {
        guard let data = defaults?.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SharedPlace].self, from: data)) ?? []
    }

    static func add(_ place: SharedPlace) {
        save(items + [place])
    }

    /// 앱이 넣은 것만 걷어 낸다 — 꺼내는 사이에 확장이 새로 넣은 것은 남는다.
    static func remove(_ done: [SharedPlace]) {
        save(items.filter { !done.contains($0) })
    }

    private static func save(_ items: [SharedPlace]) {
        defaults?.set(try? JSONEncoder().encode(items), forKey: key)
    }
}
