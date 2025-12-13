import SwiftUI
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

struct RestaurantListView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]
    @State private var showingAddSheet = false
    @State private var selectedRestaurant: Restaurant?
    @State private var showingDetail = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "RestaurantList")

    // 나의 미슐랭 (Top 6)
    private var michelinRestaurants: [Restaurant] {
        restaurants.filter { $0.listType == .michelin || $0.isTop6 }
            .sorted { ($0.top6Rank ?? 99) < ($1.top6Rank ?? 99) }
    }

    // 가본 곳 (visited)
    private var visitedRestaurants: [Restaurant] {
        restaurants.filter { $0.listType == .visited && !$0.isTop6 }
            .sorted { $0.visitDate > $1.visitDate }
    }

    // 가볼 곳 (wishlist)
    private var wishlistRestaurants: [Restaurant] {
        restaurants.filter { $0.listType == .wishlist }
            .sorted { $0.visitDate > $1.visitDate }
    }

    var body: some View {
        NavigationStack {
            List {
                // 나의 미슐랭 (Top 6)
                Section {
                    if michelinRestaurants.isEmpty {
                        Text("아직 탑6로 지정된 식당이 없습니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(michelinRestaurants) { restaurant in
                            Top6RestaurantRow(restaurant: restaurant)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRestaurant = restaurant
                                    showingDetail = true
                                }
                        }
                        .onDelete { indexSet in
                            deleteMichelinRestaurants(at: indexSet)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        Text("나의 미슐랭")
                        Spacer()
                        Text("\(michelinRestaurants.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.headline)
                } footer: {
                    if !michelinRestaurants.isEmpty {
                        Text("최고의 식당들입니다")
                            .font(.caption2)
                    }
                }

                // 가본 곳
                Section {
                    if visitedRestaurants.isEmpty {
                        Text("아직 방문한 식당이 없습니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(visitedRestaurants) { restaurant in
                            RestaurantRow(restaurant: restaurant)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRestaurant = restaurant
                                    showingDetail = true
                                }
                        }
                        .onDelete { indexSet in
                            deleteVisitedRestaurants(at: indexSet)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("가본 곳")
                        Spacer()
                        Text("\(visitedRestaurants.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.headline)
                }

                // 가볼 곳
                Section {
                    if wishlistRestaurants.isEmpty {
                        Text("아직 가보고 싶은 식당이 없습니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(wishlistRestaurants) { restaurant in
                            RestaurantRow(restaurant: restaurant)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRestaurant = restaurant
                                    showingDetail = true
                                }
                        }
                        .onDelete { indexSet in
                            deleteWishlistRestaurants(at: indexSet)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: "star.circle.fill")
                            .foregroundStyle(.orange)
                        Text("가볼 곳")
                        Spacer()
                        Text("\(wishlistRestaurants.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .font(.headline)
                }
            }
            .navigationTitle("식당 목록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddRestaurantView(coordinate: nil)
            }
            .sheet(isPresented: $showingDetail) {
                if let restaurant = selectedRestaurant {
                    RestaurantDetailViewWrapper(restaurant: restaurant)
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
    
    private func deleteMichelinRestaurants(at offsets: IndexSet) {
        for index in offsets {
            let restaurant = michelinRestaurants[index]
            logger.info("미슐랭 식당 삭제: 이름=\(restaurant.name), 랭킹=\(restaurant.top6Rank ?? 0)")
            modelContext.delete(restaurant)
        }
        logger.info("총 \(offsets.count)개의 미슐랭 식당 삭제됨")
    }

    private func deleteVisitedRestaurants(at offsets: IndexSet) {
        for index in offsets {
            let restaurant = visitedRestaurants[index]
            logger.info("가본 곳 삭제: 이름=\(restaurant.name), 주소=\(restaurant.address)")
            modelContext.delete(restaurant)
        }
        logger.info("총 \(offsets.count)개의 가본 곳 삭제됨")
    }

    private func deleteWishlistRestaurants(at offsets: IndexSet) {
        for index in offsets {
            let restaurant = wishlistRestaurants[index]
            logger.info("가볼 곳 삭제: 이름=\(restaurant.name), 주소=\(restaurant.address)")
            modelContext.delete(restaurant)
        }
        logger.info("총 \(offsets.count)개의 가볼 곳 삭제됨")
    }
}

// MARK: - Ranked Restaurant Row (리이오미슐랭)
struct RankedRestaurantRow: View {
    let restaurant: Restaurant
    let rank: Int

    // 카테고리에 맞는 아이콘 반환
    private var categoryIcon: String {
        if !restaurant.category.isEmpty {
            return POICategoryMapper.toIcon(restaurant.category)
        }
        return restaurant.categoryIcon
    }

    // 랭킹 메달 색상
    private var medalColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue.opacity(0.7)
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // 랭킹 배지
            ZStack {
                Circle()
                    .fill(medalColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                VStack(spacing: 0) {
                    Text("\(rank)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(medalColor)
                    if rank <= 3 {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(medalColor)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // 이름 + 점수
                HStack {
                    Text(restaurant.name)
                        .font(.headline)

                    Spacer()

                    // 만족도 점수
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text(String(format: "%.0f", restaurant.satisfactionScore))
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }

                // 별점 + 카테고리
                HStack(spacing: 8) {
                    // 별점
                    FractionalStarRatingView(rating: restaurant.averageRating, starSize: 10)

                    // 카테고리
                    Text(POICategoryMapper.toKorean(restaurant.category.isEmpty ? "레스토랑" : restaurant.category))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Spacer()

                    // 방문 횟수
                    Text("\(restaurant.visitCount)회 방문")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct Top6RestaurantRow: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: 12) {
            // 랭킹 배지
            ZStack {
                Image(systemName: "star.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.yellow)
                Text("\(restaurant.top6Rank ?? 0)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.black)
            }
            .frame(width: 40)

            VStack(alignment: .leading, spacing: 6) {
                // 이름 + 평균 별점
                HStack {
                    Text(restaurant.name)
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < Int(restaurant.averageRating.rounded()) ? "star.fill" : "star")
                                .foregroundStyle(index < Int(restaurant.averageRating.rounded()) ? .yellow : .gray)
                                .font(.system(size: 12))
                        }
                    }
                }

                // 카테고리 + 마지막 방문일 + 총 방문횟수
                HStack(spacing: 8) {
                    // 카테고리 텍스트
                    Text(POICategoryMapper.toKorean(restaurant.category.isEmpty ? "레스토랑" : restaurant.category))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Spacer()

                    // 마지막 방문일
                    if let lastVisit = restaurant.lastVisitDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(lastVisit, format: .dateTime.month().day())
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // 총 방문횟수
                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                        Text("\(restaurant.visitCount)회")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RestaurantRow: View {
    let restaurant: Restaurant

    // 카테고리에 맞는 아이콘 반환
    private var categoryIcon: String {
        if !restaurant.category.isEmpty {
            return POICategoryMapper.toIcon(restaurant.category)
        }
        return restaurant.categoryIcon
    }

    var body: some View {
        HStack(spacing: 12) {
            // 카테고리 아이콘
            ZStack {
                Circle()
                    .fill(.yellow.opacity(0.3))
                    .frame(width: 40, height: 40)
                Image(systemName: categoryIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 6) {
                // 이름 + 별점
                HStack {
                    Text(restaurant.name)
                        .font(.headline)

                    Spacer()

                    // 평균 별점 (소수점 표현)
                    FractionalStarRatingView(rating: restaurant.averageRating)
                }

                // 카테고리 + 마지막 방문일 + 총 방문횟수
                HStack(spacing: 8) {
                    // 카테고리 텍스트
                    Text(POICategoryMapper.toKorean(restaurant.category.isEmpty ? "레스토랑" : restaurant.category))
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1))
                        .foregroundStyle(.blue)
                        .clipShape(Capsule())

                    Spacer()

                    // 마지막 방문일
                    if let lastVisit = restaurant.lastVisitDate {
                        HStack(spacing: 2) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(lastVisit, format: .dateTime.month().day())
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }

                    // 총 방문횟수
                    HStack(spacing: 2) {
                        Image(systemName: "figure.walk")
                            .font(.caption2)
                        Text("\(restaurant.visitCount)회")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
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
            } else {
                RestaurantDetailView(restaurant: restaurant)
            }
        }
        .onAppear {
            // 데이터 검증
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    // Restaurant 객체가 유효한지 확인
                    if restaurant.name.isEmpty {
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
