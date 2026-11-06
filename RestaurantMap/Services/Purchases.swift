//
//  Purchases.swift
//  인생 맛집
//
//  인생 맛집 Plus · Pro 를 파는 자리. **속은 전부 `LeeoStore` 다.**
//  상품 로드 · 구매 · 복원 · 거래 리스너(다른 기기, 가족 공유, 환불, 구독 만료) · 팁은 LeeoStore 안에 있다.
//
//  이 클래스는 두 가지만 한다 —
//   ① LeeoStore 의 값을 SwiftUI `@Observable` 로 옮겨 적고,
//   ② 그 값을 칸(`RestaurantTier`)으로 바꿔 기억한다.
//

import Foundation
import Combine
import StoreKit
import SwiftUI
import LeeoKit

@MainActor
@Observable
final class Purchases {

    static let shared = Purchases()

    @ObservationIgnored let store: LeeoStore

    /// 지금 쓰는 칸. 화면은 이 값(과 `allows`)만 본다.
    private(set) var tier: RestaurantTier = RestaurantPlan.cachedTier ?? .free

    /// App Store 에 물어 답을 받았는가. false 면 화면은 '무료'라고 단정하지 않는다.
    private(set) var isKnown = RestaurantPlan.cachedTier != nil

    /// 칸 상품을 한 번이라도 불러왔는가. 아니면 아무것도 막지 않는다 (→ RestaurantPlan.everSold).
    private(set) var gatesActive = RestaurantPlan.everSold

    private(set) var products: [Product] = []
    private(set) var ownedProductIDs: Set<String> = []

    /// 지금 살아 있는 구독. 있으면 설정에 '평생으로 바꾸기' 가 선다.
    private(set) var subscription: LeeoGraduation.Subscription?

    private(set) var isWorking = false

    /// 사다가 막혔을 때 그대로 보여 줄 말.
    private(set) var failureMessage: String?

    /// ⚠️ 이번 실행에서 영수증을 실제로 읽기 전에는 칸을 적지 않는다.
    ///    LeeoStore 는 불러오는 중에도 바뀌었다고 알려 오는데, 그때 빈 권한을 적으면 산 사람이 '무료'로 못박힌다.
    @ObservationIgnored private var entitlementsChecked = false
    @ObservationIgnored private var observation: AnyCancellable?

    private init() {
        guard let config = RestaurantMapSpec.paywall else {
            preconditionFailure("계약에 페이월이 없다. RestaurantMapSpec.monetization 을 확인할 것")
        }
        store = LeeoStore(config: config, grandfather: { await RestaurantPlan.boughtTheApp() })
        // objectWillChange 는 바뀌기 **직전**에 온다. 다음 차례로 미뤄 읽는다.
        observation = store.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in self?.pull() }
        }
    }

    /// 팁(응원). 기능을 열지 않는다.
    var tipJar: LeeoTipJar {
        guard let tipJar = store.tipJar else { preconditionFailure("계약에 팁이 없다") }
        return tipJar
    }

    /// 이 기능을 써도 되는가. 칸 상품을 아직 한 번도 못 불러온 기기는 모두 연다.
    func allows(_ feature: RestaurantFeature) -> Bool { !gatesActive || tier >= feature.tier }

    /// 식당을 하나 더 저장할 수 있는가 (`count` = 지금 저장된 식당 수).
    func canAddRestaurant(having count: Int) -> Bool {
        allows(.restaurants) || count < RestaurantPlan.freeRestaurants
    }

    func ownsLifetime(_ tier: RestaurantTier) -> Bool {
        RestaurantPlan.ownsLifetime(tier, in: ownedProductIDs)
    }

    func product(_ id: String) -> Product? { products.first { $0.id == id } }

    // MARK: - 상태 맞추기

    /// 영수증을 다시 읽어 칸을 정한다. 앱이 켜질 때와 앞으로 나올 때마다 부른다.
    func refresh() async {
        await store.refreshEntitlements()
        entitlementsChecked = true
        await store.loadProducts()
        subscription = await LeeoGraduation.currentSubscription(among: RestaurantPlan.subscriptionIDs)
        pull()
    }

    func loadProducts() async {
        await store.loadProducts()
        pull()
    }

    /// 구독 졸업을 제안할 때인가. 6개월째와 갱신 7일 전에 한 번씩.
    var graduationIsDue: Bool {
        guard let subscription, product(RestaurantPlan.graduateID) != nil,
              !ownsLifetime(.pro) else { return false }
        return LeeoGraduation.isDue(subscription, lastOffered: LeeoGraduation.lastOffered())
    }

    func markGraduationOffered() { LeeoGraduation.markOffered() }

    // MARK: - 사기 / 되찾기

    /// ⚠️ `action` 은 화면의 `@Environment(\.purchase)` 다. 아이패드에서 결제 시트가 엉뚱한 창에 뜨지 않게.
    func purchase(_ product: Product, using action: PurchaseAction) async {
        _ = await store.purchase(product) { try await action($0) }
        entitlementsChecked = true
        subscription = await LeeoGraduation.currentSubscription(among: RestaurantPlan.subscriptionIDs)
        pull()
    }

    func restore() async {
        await store.restore()
        entitlementsChecked = true
        pull()
        if tier == .free, failureMessage == nil {
            failureMessage = String(localized: "이 Apple 계정에서 산 기록을 찾지 못했어요.")
        }
    }

    // MARK: -

    private func pull() {
        if entitlementsChecked {
            let owned = store.isGrandfathered ? .pro : RestaurantPlan.tier(owning: store.purchasedProductIDs)
            RestaurantPlan.setTier(owned)
            tier = owned
            isKnown = true
        }
        products = store.products
        if !gatesActive, products.contains(where: { RestaurantPlan.planIDs.contains($0.id) }) {
            RestaurantPlan.everSold = true
            gatesActive = true
        }
        ownedProductIDs = store.purchasedProductIDs
        isWorking = store.purchasingProductID != nil || store.isRestoring
        failureMessage = store.lastError
    }
}
