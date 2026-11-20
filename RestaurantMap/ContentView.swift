import SwiftUI
import SwiftData
import LeeoKit

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @State private var selectedTab = 0
    @Bindable private var router = RestaurantRouter.shared
    /// 아이폰 듀오를 폈을 때 결과 쪽에 띄울 식당 (→ Views/FoldPanes.swift).
    @State private var foldPick = FoldRestaurantPick()
    @Environment(\.foldLayout) private var fold
    @State private var purchases = Purchases.shared
    /// 구독 6개월째 · 갱신 7일 전의 '평생으로 바꾸기' 제안 (→ LeeoGraduation).
    @State private var showsGraduation = false

    var body: some View {
        TabView(selection: $selectedTab) {
            // 아이폰 듀오를 펴면 왼쪽(세로면 아래)에 이 탭, 오른쪽(위)에 고른 식당 또는 취향이 선다.
            // 접혀 있거나 보통 아이폰이면 `FoldTab` 은 이 탭만 그린다. 지금 화면 그대로.
            FoldTab { MapView(restaurants: restaurants, ranks: restaurants.regularRanks()) }
                .tabItem {
                    Label("지도", systemImage: "map")
                }
                .tag(0)

            FoldTab { RestaurantListView(restaurants: restaurants) }
                .tabItem {
                    Label("목록", systemImage: "list.bullet")
                }
                .tag(1)

            FoldTab { ReviewFeedView(restaurants: restaurants) }
                .tabItem {
                    Label("단골 후기", systemImage: "heart.text.square")
                }
                .tag(2)

            TasteProfileView()
                .tabItem {
                    Label("취향", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
        // Siri · Spotlight 에서 고른 식당 (→ RestaurantIntents.swift)
        .sheet(item: $router.restaurantID) { id in
            if let restaurant = modelContext.model(for: id) as? Restaurant {
                NavigationStack { RestaurantDetailView(restaurant: restaurant) }
            }
        }
        // 펴면 시스템 탭바 대신 고르는 쪽 판 바닥에 막대가 선다. 취향은 결과 쪽에 서 있다.
        .foldTabBar(items: FoldTabs.items, selected: selectedTab == 3 ? 1 : selectedTab) { selectedTab = $0 }
        .onChange(of: fold.isUnfolded, initial: true) { _, unfolded in
            // 취향 탭에 있다가 펴면 목록으로. 취향은 결과 쪽 판에 그대로 보인다.
            if unfolded, selectedTab == 3 { selectedTab = 1 }
        }
        .environment(foldPick)
        // 다녀온 뒤 알림을 누르면 그 식당을 연다
        .onChange(of: router.pendingName, initial: true) { _, name in
            guard let name else { return }
            router.pendingName = nil
            router.restaurantID = restaurants.first { $0.name == name }?.persistentModelID
        }
        #if DEBUG
        .onAppear { if let scene = ScreenshotScene.current { selectedTab = scene.tab } }
        #endif
        .sheet(isPresented: $showsGraduation) {
            LeeoGraduationOfferView(graduate: purchases.product(RestaurantPlan.graduateID)) {
                await purchases.refresh()
            }
        }
        .onChange(of: purchases.graduationIsDue, initial: true) { _, due in
            guard due, !showsGraduation, router.restaurantID == nil else { return }
            purchases.markGraduationOffered()
            showsGraduation = true
        }
    }
}

// MARK: - 손쉬운 사용

extension View {
    /// 탭 제스처로 여는 행·카드·핀을 VoiceOver·음성 명령에서도 단추처럼 —
    /// 한 덩어리로 읽고, 두 번 탭(또는 "탭")하면 같은 동작을 한다.
    func accessibleTap(_ action: @escaping () -> Void) -> some View {
        onTapGesture(perform: action)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(.default, action)
    }

    /// 별점 고르기의 별 하나 — "3점" 단추로 읽고, 고른 별까지는 '선택됨'
    func accessibleStar(_ value: Int, rating: Int, select: @escaping () -> Void) -> some View {
        onTapGesture(perform: select)
            .accessibilityLabel(Text("\(value)점"))
            .accessibilityAddTraits(value <= rating ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction(.default, select)
    }

    /// 별 여러 개로 그린 별점을 "별점 4.5점" 한 마디로
    func starRatingLabel(_ rating: Double) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("별점"))
            .accessibilityValue(Text("\(rating.formatted(.number.precision(.fractionLength(0...1))))점"))
    }
}

/// 평소엔 가로로, 손쉬운 사용 글자 크기에서는 세로로 쌓는다.
struct AdaptiveStack<Content: View>: View {
    var spacing: CGFloat? = nil
    @ViewBuilder var content: Content
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: spacing))
            : AnyLayout(HStackLayout(spacing: spacing))
        layout { content }
    }
}
