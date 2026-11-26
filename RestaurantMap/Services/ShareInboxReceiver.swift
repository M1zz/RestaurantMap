//
//  ShareInboxReceiver.swift
//  인생 맛집
//
//  공유 확장이 보관함에 넣어 둔 식당을 앱이 앞으로 나올 때 '가볼 곳' 에 넣는다 (→ SharedPlace.swift).
//  이미 저장한 집(이름이 같고 100m 안)이면 새로 만들지 않고 링크만 붙인다.
//  무료 한도에 걸린 것은 보관함에 남겨 두고 이번 실행에 한 번 페이월을 띄운다 — 열고 돌아오면 마저 넣는다.
//

import SwiftUI
import SwiftData
import CoreLocation

extension View {
    /// 공유로 담은 식당을 받아 넣는다. 앱의 맨 바깥 화면에 붙인다.
    func shareInbox() -> some View { modifier(ShareInboxReceiver()) }
}

private struct ShareInboxReceiver: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var purchases = Purchases.shared
    @State private var paywallFeature: RestaurantFeature?
    /// 한도에 걸렸다고 이번 실행에 이미 알렸는가 — 닫을 때마다 다시 띄우지 않는다
    @State private var askedToUpgrade = false

    func body(content: Content) -> some View {
        content
            .task { receive() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { receive() }
            }
            .sheet(item: $paywallFeature, onDismiss: receive) { feature in
                PaywallView(highlight: feature)
            }
    }

    private func receive() {
        let inbox = ShareInbox.items
        guard !inbox.isEmpty, paywallFeature == nil else { return }
        let saved = (try? modelContext.fetch(FetchDescriptor<Restaurant>())) ?? []
        var count = saved.count
        var done: [SharedPlace] = []

        for place in inbox {
            if let existing = saved.first(where: { $0.isSame(as: place) }) {
                if existing.sourceLink.isEmpty { existing.sourceLink = place.link }
            } else if purchases.canAddRestaurant(having: count) {
                modelContext.insert(Restaurant(shared: place))
                count += 1
            } else {
                continue
            }
            done.append(place)
        }

        modelContext.saveNow()
        ShareInbox.remove(done)
        if done.count < inbox.count, !askedToUpgrade {
            askedToUpgrade = true
            paywallFeature = .restaurants
        }
    }
}

private extension Restaurant {
    convenience init(shared place: SharedPlace) {
        // 카카오는 '음식점' · '카페' 를, Apple 지도는 장소 종류(MKPOICategory…)를 넘긴다
        let category = place.category.hasPrefix("MKPOICategory") ? POICategoryMapper.toKorean(place.category) : place.category
        self.init(
            name: place.name,
            address: place.address,
            latitude: place.latitude,
            longitude: place.longitude,
            category: category,
            phoneNumber: place.phone,
            categoryIcon: POICategoryMapper.toIcon(category),
            foodCategory: FoodCategoryRepository.guess(from: place.categoryHints + [category]),
            listType: .wishlist
        )
        sourceLink = place.link
    }

    func isSame(as place: SharedPlace) -> Bool {
        guard !isGone, name == place.name, coordinate.isMappable else { return false }
        return CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: place.latitude, longitude: place.longitude)) < 100
    }
}
