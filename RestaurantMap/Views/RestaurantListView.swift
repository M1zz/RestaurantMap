import SwiftUI
import LeeoKit
import SwiftData
import OSLog

// MARK: - Fractional Star Rating View
struct FractionalStarRatingView: View {
    let rating: Double
    let maxRating: Int
    let starSize: CGFloat
    let filledColor: Color
    let emptyColor: Color

    init(rating: Double, maxRating: Int = 5, starSize: CGFloat = 12, filledColor: Color = .yellow, emptyColor: Color = .gray) {
        self.rating = rating
        self.maxRating = maxRating
        self.starSize = starSize
        self.filledColor = filledColor
        self.emptyColor = emptyColor
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<maxRating, id: \.self) { index in
                StarView(
                    fillAmount: fillAmount(for: index),
                    size: starSize,
                    filledColor: filledColor,
                    emptyColor: emptyColor
                )
            }
        }
        .starRatingLabel(rating)
    }

    private func fillAmount(for index: Int) -> Double {
        let starValue = Double(index + 1)
        if rating >= starValue {
            return 1.0 // 완전히 채워진 별
        } else if rating > Double(index) {
            return rating - Double(index) // 부분적으로 채워진 별 (0.0 ~ 1.0)
        } else {
            return 0.0 // 빈 별
        }
    }
}

struct StarView: View {
    let fillAmount: Double
    let size: CGFloat
    let filledColor: Color
    let emptyColor: Color

    var body: some View {
        ZStack {
            // 빈 별 (배경)
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(emptyColor)

            // 채워진 별 (마스크로 부분 표시)
            Image(systemName: "star.fill")
                .font(.system(size: size))
                .foregroundStyle(filledColor)
                .mask(
                    GeometryReader { geometry in
                        Rectangle()
                            .frame(width: geometry.size.width * fillAmount)
                    }
                )
        }
    }
}

/// 목록 정렬. 고른 값은 다음에 열 때도 남는다.
enum RestaurantSort: String, CaseIterable, Identifiable {
    case recent, visits, rating, name

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recent: String(localized: "최근 방문 순", comment: "List sort option")
        case .visits: String(localized: "자주 간 순", comment: "List sort option")
        case .rating: String(localized: "별점 높은 순", comment: "List sort option")
        case .name: String(localized: "이름 순", comment: "List sort option")
        }
    }

    func sorted(_ restaurants: [Restaurant]) -> [Restaurant] {
        switch self {
        case .recent:
            restaurants.sorted { ($0.lastVisitDate ?? $0.visitDate) > ($1.lastVisitDate ?? $1.visitDate) }
        case .visits:
            restaurants.sorted { $0.regular.days > $1.regular.days }
        case .rating:
            restaurants.sorted { $0.averageRating > $1.averageRating }
        case .name:
            restaurants.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}

struct RestaurantListView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]
    @State private var showingAddSheet = false
    @State private var selectedRestaurant: Restaurant?
    @Environment(\.foldLayout) private var fold
    @Environment(FoldRestaurantPick.self) private var foldPick: FoldRestaurantPick?
    @State private var showingDetail = false
    @State private var searchText = ""
    @AppStorage("list.sort") private var sort: RestaurantSort = .recent
    /// 고른 음식 종류. nil 이면 전부.
    @State private var categoryFilter: FoodCategory?
    /// 지우기 전에 한 번 묻는다 — 방문 기록과 사진까지 같이 사라진다.
    @State private var pendingDelete: Restaurant?
    @State private var saveFailed = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "RestaurantList")

    private var isFiltering: Bool { !searchText.isEmpty || categoryFilter != nil }

    /// 검색어 · 음식 종류로 거른 식당.
    private var shown: [Restaurant] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return restaurants.filter { restaurant in
            if let categoryFilter, restaurant.foodCategory.id != categoryFilter.id { return false }
            guard !query.isEmpty else { return true }
            let menus = (restaurant.visits ?? []).map(\.displayMenuName) + (restaurant.menus ?? []).map(\.name)
            return ([restaurant.name, restaurant.address, restaurant.notes, restaurant.foodCategory.localizedName] + menus)
                .contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    /// 나의 미슐랭 — 순위는 거르기 전 전체에서 매긴다. 걸러도 순위 숫자는 그대로다.
    private var ranks: [PersistentIdentifier: Int] { restaurants.regularRanks() }

    /// 지금 저장된 식당에 쓰인 음식 종류.
    private var usedCategories: [FoodCategory] {
        var seen = Set<UUID>()
        return restaurants.map(\.foodCategory).filter { seen.insert($0.id).inserted }
            .sorted { $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending }
    }

    /// 단골까지 가장 가까운 집 — 나의 미슐랭이 비어 있을 때 길을 보여 준다.
    private var closestCandidate: Restaurant? {
        restaurants.filter { !$0.isWishlist && !$0.regular.isRanked }
            .max { $0.regular.days < $1.regular.days }
    }

    /// 식당 자세히: 아이폰 듀오를 폈으면 결과 쪽 판에, 아니면 지금처럼 시트로.
    private func openDetail(_ restaurant: Restaurant) {
        if foldPick?.show(restaurant, in: fold) == true { return }
        selectedRestaurant = restaurant
        showingDetail = true
    }

    var body: some View {
        let ranks = ranks
        let shown = shown
        let michelin = shown.filter { ranks[$0.persistentModelID] != nil }
            .sorted { (ranks[$0.persistentModelID] ?? 99) < (ranks[$1.persistentModelID] ?? 99) }
        let visited = sort.sorted(shown.filter { !$0.isWishlist && ranks[$0.persistentModelID] == nil })
        let wishlist = sort.sorted(shown.filter(\.isWishlist))

        NavigationStack {
            List {
                // 나의 미슐랭 — 자주 간 집을 앱이 줄 세운다
                Section {
                    if michelin.isEmpty {
                        michelinEmptyRow
                    } else {
                        rows(michelin, ranks: ranks)
                    }
                } header: {
                    sectionHeader("나의 미슐랭", symbol: "crown.fill", tint: .yellow, count: michelin.count)
                } footer: {
                    Text("직접 고르지 않아요. 네 번 넘게 찾은 단골집이 자주 간 순서로 여기에 올라와요.")
                        .font(.caption2)
                }

                Section {
                    if visited.isEmpty {
                        emptyRow(isFiltering ? "찾는 식당이 없습니다" : "아직 방문한 식당이 없습니다")
                    } else {
                        rows(visited, ranks: ranks)
                    }
                } header: {
                    sectionHeader("가본 곳", symbol: "checkmark.circle.fill", tint: .green, count: visited.count)
                }

                Section {
                    if wishlist.isEmpty {
                        emptyRow(isFiltering ? "찾는 식당이 없습니다" : "아직 가보고 싶은 식당이 없습니다")
                    } else {
                        rows(wishlist, ranks: ranks)
                    }
                } header: {
                    sectionHeader("가볼 곳", symbol: "star.circle.fill", tint: .orange, count: wishlist.count)
                }
            }
            .navigationTitle("식당 목록")
            .searchable(text: $searchText, prompt: Text("이름 · 동네 · 메뉴로 찾기"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("식당 추가"))
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Picker("정렬", selection: $sort) {
                            ForEach(RestaurantSort.allCases) { Text($0.title).tag($0) }
                        }
                        if usedCategories.count > 1 {
                            Picker("음식 종류", selection: $categoryFilter) {
                                Text("모든 종류").tag(nil as FoodCategory?)
                                ForEach(usedCategories) { category in
                                    Label(category.localizedName, systemImage: category.icon).tag(category as FoodCategory?)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: categoryFilter == nil
                              ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    }
                    .accessibilityLabel(Text("정렬과 거르기"))
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddRestaurantView(coordinate: nil)
            }
            .sheet(isPresented: $showingDetail) {
                // 시트 안에서 식당을 지우면 내려가는 동안에도 이 자리가 다시 그려진다 — 지워진 식당은 넘기지 않는다
                if let restaurant = selectedRestaurant, !restaurant.isGone {
                    RestaurantDetailViewWrapper(restaurant: restaurant)
                } else if selectedRestaurant?.isGone == true {
                    // 이 시트에서 지운 식당 — 내려가는 동안 불러오는 중 화면이 비치지 않게 비워 둔다
                    Color.clear
                } else {
                    LoadingSheetView()
                }
            }
            .onChange(of: showingDetail) { _, isShowing in
                // Sheet가 닫힐 때 선택된 식당 초기화
                if !isShowing {
                    // 약간의 딜레이를 두고 초기화 (애니메이션 완료 대기)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedRestaurant = nil
                    }
                }
            }
            .confirmationDialog(
                Text("\(pendingDeleteName) 지우기"),
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { restaurant in
                Button("지우기", role: .destructive) { delete(restaurant) }
                Button("취소", role: .cancel) {}
            } message: { restaurant in
                // 지운 직후 창이 닫히는 동안에도 이 글이 다시 그려질 수 있다 — 지워진 식당은 읽지 않는다
                if !restaurant.isGone, restaurant.visitCount > 0 {
                    Text("방문 기록 \(restaurant.visitCount)개와 사진도 함께 지워져요. 되돌릴 수 없어요.")
                } else {
                    Text("되돌릴 수 없어요.")
                }
            }
            .saveFailureAlert($saveFailed)
            .overlay {
                if restaurants.isEmpty {
                    ContentUnavailableView {
                        Label("식당 없음", systemImage: "fork.knife.circle")
                    } description: {
                        Text("식당을 추가하여 시작하세요")
                    } actions: {
                        Button("식당 추가") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    /// 지우려는 식당의 이름. 이미 지워졌으면 읽지 않는다.
    private var pendingDeleteName: String {
        guard let pendingDelete, !pendingDelete.isGone else { return "" }
        return pendingDelete.name
    }

    private func rows(_ list: [Restaurant], ranks: [PersistentIdentifier: Int]) -> some View {
        ForEach(list) { restaurant in
            RestaurantRow(restaurant: restaurant, rank: ranks[restaurant.persistentModelID])
                .contentShape(Rectangle())
                .accessibilityInputLabels([Text(verbatim: restaurant.name)])
                .accessibleTap {
                    openDetail(restaurant)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        pendingDelete = restaurant
                    } label: {
                        Label("지우기", systemImage: "trash")
                    }
                    .tint(.red)
                }
        }
    }

    private func sectionHeader(_ title: LocalizedStringKey, symbol: String, tint: Color, count: Int) -> some View {
        HStack {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .accessibilityHidden(true)
            Text(title)
            Spacer()
            Text("\(count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.headline)
    }

    private func emptyRow(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var michelinEmptyRow: some View {
        if isFiltering {
            emptyRow("찾는 식당이 없습니다")
        } else if let candidate = closestCandidate, let hint = candidate.regular.nextStep {
            VStack(alignment: .leading, spacing: 4) {
                Text("아직 단골집이 없어요")
                    .font(.subheadline)
                Text(verbatim: "\(candidate.name) — \(hint)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 6)
        } else {
            emptyRow("아직 단골집이 없어요")
        }
    }

    private func delete(_ restaurant: Restaurant) {
        // 확인 창 · 결과 쪽 판이 지워질 식당을 쥐고 있지 않게 먼저 놓는다 (지운 뒤에 읽으면 죽는다)
        pendingDelete = nil
        if selectedRestaurant === restaurant { selectedRestaurant = nil }
        if foldPick?.restaurant === restaurant { foldPick?.restaurant = nil }
        guard !restaurant.isGone else { return }
        logger.info("식당 삭제: 방문 \(restaurant.visitCount)개")
        modelContext.delete(restaurant)
        do {
            try modelContext.save()
        } catch {
            logger.error("삭제 저장 실패: \(error.localizedDescription)")
            saveFailed = true
        }
    }
}

// MARK: - 단골 인정 표시

/// 단골 단계 딱지 — "단골 · 5번". 한 번 가 본 곳에는 붙지 않는다.
struct RegularBadge: View {
    let regular: Regular

    private var tint: Color {
        if regular.isLapsed { return .secondary }
        switch regular.level {
        case .lifetime: return .orange
        case .regular: return .pink
        default: return .teal
        }
    }

    var body: some View {
        if regular.level > .none {
            HStack(spacing: 3) {
                Image(systemName: regular.level.symbol)
                    .font(.caption2)
                    .accessibilityHidden(true)
                Text(verbatim: regular.title)
                    .font(.caption.weight(.semibold))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(tint.opacity(0.15))
            .foregroundStyle(tint)
            .clipShape(Capsule())
        }
    }
}

struct RestaurantRow: View {
    let restaurant: Restaurant
    /// 나의 미슐랭 순위. 순위에 없으면 nil.
    var rank: Int? = nil

    // 카테고리에 맞는 아이콘 반환
    private var categoryIcon: String {
        if !restaurant.category.isEmpty {
            return POICategoryMapper.toIcon(restaurant.category)
        }
        return restaurant.categoryIcon
    }

    var body: some View {
        // 지워진 식당의 줄이 한 박자 남아 다시 그려져도 모델을 읽지 않는다
        if !restaurant.isGone { row }
    }

    private var row: some View {
        let regular = restaurant.regular
        return HStack(spacing: 12) {
            // 얼마나 자주 갔는지가 한눈에 보이는 도장 (→ VisitStamp.swift)
            VisitStamp(restaurant: restaurant, rank: rank)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(rank.map { Text("\($0)위") } ?? Text(verbatim: ""))

            VStack(alignment: .leading, spacing: 6) {
                // 이름 + 별점
                HStack {
                    Text(restaurant.name)
                        .font(.headline)

                    Spacer()

                    // 평균 별점 (소수점 표현)
                    FractionalStarRatingView(rating: restaurant.averageRating)
                }

                // 단골 딱지(없으면 음식 종류) + 마지막 방문일 + 다녀온 날 수 (아주 큰 글씨에서는 위아래로)
                AdaptiveStack(spacing: 8) {
                    if regular.level > .none {
                        RegularBadge(regular: regular)
                    } else {
                        Text(POICategoryMapper.displayName(restaurant.category.isEmpty ? "MKPOICategoryRestaurant" : restaurant.category))
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    Spacer()

                    // 마지막 방문일
                    if let lastVisit = restaurant.lastVisitDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                                .accessibilityHidden(true)
                            Text(lastVisit, format: .dateTime.month().day())
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // 다녀온 날 수
                    if !restaurant.isWishlist {
                        HStack(spacing: 2) {
                            Image(systemName: "figure.walk")
                                .font(.caption2)
                                .accessibilityHidden(true)
                            Text("\(regular.days)회")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 저장 실패 알림

extension View {
    /// 저장이 실패하면 조용히 넘기지 않고 알린다.
    func saveFailureAlert(_ isPresented: Binding<Bool>) -> some View {
        alert("저장하지 못했어요", isPresented: isPresented) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("저장 공간이 부족하지 않은지 확인한 뒤 다시 해 주세요.")
        }
    }
}


// MARK: - Restaurant Detail Wrapper with Loading State
struct RestaurantDetailViewWrapper: View {
    let restaurant: Restaurant
    @State private var isLoading = true
    @State private var hasError = false

    var body: some View {
        Group {
            if hasError {
                ErrorSheetView()
            } else if isLoading {
                LoadingSheetView()
            } else if restaurant.isGone {
                // 이 화면에서 지웠거나 동기화로 지워진 식당 — 닫히는 동안 빈 화면으로 둔다
                Color.clear
            } else {
                RestaurantDetailView(restaurant: restaurant)
            }
        }
        .onAppear {
            // 데이터 검증
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    // Restaurant 객체가 유효한지 확인 (그 사이 지워졌으면 속성을 읽지 않는다)
                    if restaurant.isGone || restaurant.name.isEmpty {
                        hasError = true
                    }
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Loading Sheet View
struct LoadingSheetView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("불러오는 중...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

// MARK: - Error Sheet View
struct ErrorSheetView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.orange)

                Text("데이터를 불러올 수 없습니다")
                    .font(.headline)

                Text("다시 시도해주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("닫기") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("오류")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    RestaurantListView(restaurants: [])
        .modelContainer(for: Restaurant.self, inMemory: true)
}
