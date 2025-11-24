import SwiftUI
import SwiftData
import OSLog

struct RestaurantListView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]
    @State private var showingAddSheet = false
    @State private var selectedRestaurant: Restaurant?
    @State private var showingDetail = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "RestaurantList")

    private var top6Restaurants: [Restaurant] {
        restaurants.filter { $0.isTop6 }
            .sorted { ($0.top6Rank ?? 99) < ($1.top6Rank ?? 99) }
    }

    private var regularRestaurants: [Restaurant] {
        restaurants.filter { !$0.isTop6 }
    }

    var body: some View {
        NavigationStack {
            List {
                // 나의 최애 탑6
                if !top6Restaurants.isEmpty {
                    Section {
                        ForEach(top6Restaurants) { restaurant in
                            Top6RestaurantRow(restaurant: restaurant)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRestaurant = restaurant
                                    showingDetail = true
                                }
                        }
                        .onDelete { indexSet in
                            deleteTop6Restaurants(at: indexSet)
                        }
                    } header: {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundStyle(.yellow)
                            Text("나의 최애 탑6")
                        }
                        .font(.headline)
                    }
                }

                // 내가 저장한 식당
                if !regularRestaurants.isEmpty {
                    Section {
                        ForEach(regularRestaurants) { restaurant in
                            RestaurantRow(restaurant: restaurant)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRestaurant = restaurant
                                    showingDetail = true
                                }
                        }
                        .onDelete { indexSet in
                            deleteRegularRestaurants(at: indexSet)
                        }
                    } header: {
                        Text("내가 저장한 식당")
                            .font(.headline)
                    }
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
    
    private func deleteTop6Restaurants(at offsets: IndexSet) {
        for index in offsets {
            let restaurant = top6Restaurants[index]
            logger.info("탑6 식당 삭제: 이름=\(restaurant.name), 랭킹=\(restaurant.top6Rank ?? 0)")
            modelContext.delete(restaurant)
        }
        logger.info("총 \(offsets.count)개의 탑6 식당 삭제됨")
    }

    private func deleteRegularRestaurants(at offsets: IndexSet) {
        for index in offsets {
            let restaurant = regularRestaurants[index]
            logger.info("식당 삭제: 이름=\(restaurant.name), 주소=\(restaurant.address)")
            modelContext.delete(restaurant)
        }
        logger.info("총 \(offsets.count)개의 식당 삭제됨")
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

            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name)
                    .font(.headline)

                Text(restaurant.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < restaurant.rating ? "star.fill" : "star")
                            .foregroundStyle(index < restaurant.rating ? .yellow : .gray)
                            .font(.system(size: 12))
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct RestaurantRow: View {
    let restaurant: Restaurant

    var body: some View {
        HStack(spacing: 12) {
            // 카테고리 아이콘
            ZStack {
                Circle()
                    .fill(.yellow.opacity(0.3))
                    .frame(width: 40, height: 40)
                Image(systemName: restaurant.categoryIcon)
                    .font(.system(size: 20))
                    .foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(restaurant.name)
                        .font(.headline)

                    Spacer()

                    HStack(spacing: 2) {
                        ForEach(0..<5) { index in
                            Image(systemName: index < restaurant.rating ? "star.fill" : "star")
                                .foregroundStyle(index < restaurant.rating ? .yellow : .gray)
                                .font(.system(size: 12))
                        }
                    }
                }

                Text(restaurant.address)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    if !restaurant.category.isEmpty {
                        Text(restaurant.category)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }

                    Text(restaurant.visitDate, format: .dateTime.year().month().day())
                        .font(.caption)
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
