import SwiftUI
import SwiftData
import CoreLocation
import OSLog

struct RecommendationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @Query private var tasteProfiles: [TasteProfile]

    @StateObject private var engine = RecommendationEngine.shared
    @StateObject private var firebaseService = FirebaseService.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var categoryRepository = FoodCategoryRepository.shared

    @State private var selectedMode: RecommendationMode = .hybrid
    @State private var selectedCategory: FoodCategory? = nil
    @State private var showingSync = false
    @State private var errorMessage: String?
    @State private var selectedTop6Restaurant: Restaurant?
    @State private var showingTop6Detail = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "RecommendationView")

    // 탑6 식당들
    private var top6Restaurants: [Restaurant] {
        restaurants.filter { $0.isTop6 }
            .sorted { ($0.top6Rank ?? 99) < ($1.top6Rank ?? 99) }
    }

    enum RecommendationMode: String, CaseIterable, Identifiable {
        case hybrid = "종합 추천"
        case collaborative = "비슷한 입맛"
        case similar = "맛 유사도"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .hybrid:
                return "맛, 평점, 거리를 종합적으로 고려"
            case .collaborative:
                return "나와 입맛이 비슷한 사람들의 선택"
            case .similar:
                return "내가 좋아했던 맛과 비슷한 식당"
            }
        }

        var icon: String {
            switch self {
            case .hybrid: return "sparkles"
            case .collaborative: return "person.3.fill"
            case .similar: return "chart.pie.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 추천 모드 선택
                recommendationModeSelector

                // 카테고리 필터
                categoryFilter

                // 추천 결과
                if engine.isLoading {
                    loadingView
                } else if engine.recommendations.isEmpty {
                    emptyView
                } else {
                    recommendationList
                }
            }
            .navigationTitle("맛집 추천")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            Task {
                                await loadRecommendations()
                            }
                        } label: {
                            Label("새로고침", systemImage: "arrow.clockwise")
                        }

                        Button {
                            showingSync = true
                        } label: {
                            Label("데이터 동기화", systemImage: "icloud.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSync) {
                SyncDataView(
                    tasteProfile: tasteProfiles.first,
                    restaurants: restaurants
                )
            }
            .alert("오류", isPresented: .constant(errorMessage != nil)) {
                Button("확인") {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .task {
                await loadRecommendations()
            }
        }
    }

    // MARK: - Subviews

    private var recommendationModeSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(RecommendationMode.allCases) { mode in
                    Button {
                        selectedMode = mode
                        Task {
                            await loadRecommendations()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.title2)
                            Text(mode.rawValue)
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .frame(width: 100, height: 80)
                        .background(
                            selectedMode == mode ?
                                Color.blue.opacity(0.15) :
                                Color.gray.opacity(0.1)
                        )
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    selectedMode == mode ? Color.blue : Color.clear,
                                    lineWidth: 2
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(uiColor: .systemBackground))
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // 전체 버튼
                Button {
                    selectedCategory = nil
                    Task {
                        await loadRecommendations()
                    }
                } label: {
                    Text("전체")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedCategory == nil ?
                                Color.blue : Color.gray.opacity(0.2)
                        )
                        .foregroundStyle(
                            selectedCategory == nil ?
                                Color.white : Color.primary
                        )
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)

                ForEach(categoryRepository.allCategories) { category in
                    Button {
                        selectedCategory = category
                        Task {
                            await loadRecommendations()
                        }
                    } label: {
                        Text(category.displayName)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedCategory == category ?
                                Color.blue : Color.gray.opacity(0.2)
                        )
                        .foregroundStyle(
                            selectedCategory == category ?
                                Color.white : Color.primary
                        )
                        .cornerRadius(16)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("추천 분석 중...")
                .font(.headline)
            Text(selectedMode.description)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "fork.knife.circle")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("추천할 식당이 없습니다")
                .font(.headline)

            VStack(spacing: 8) {
                Text("데이터가 충분하지 않을 수 있습니다")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    showingSync = true
                } label: {
                    HStack {
                        Image(systemName: "icloud.and.arrow.up")
                        Text("데이터 동기화하기")
                    }
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var recommendationList: some View {
        List {
            // 나의 탑6 섹션
            if !top6Restaurants.isEmpty {
                Section {
                    ForEach(top6Restaurants) { restaurant in
                        Top6Card(restaurant: restaurant)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedTop6Restaurant = restaurant
                                showingTop6Detail = true
                            }
                    }
                } header: {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundStyle(.yellow)
                        Text("나의 탑6")
                            .font(.headline)
                    }
                } footer: {
                    Text("내가 가장 좋아하는 식당들입니다")
                        .font(.caption2)
                }
            }

            // 추천 식당 섹션
            if !engine.recommendations.isEmpty {
                Section {
                    ForEach(engine.recommendations) { recommendation in
                        RecommendationCard(recommendation: recommendation)
                    }
                } header: {
                    Text("추천 식당")
                        .font(.headline)
                }
            }
        }
        .listStyle(.plain)
        .sheet(item: $selectedTop6Restaurant) { restaurant in
            NavigationStack {
                RestaurantDetailView(restaurant: restaurant)
            }
        }
    }

    // MARK: - Methods

    private func loadRecommendations() async {
        guard let tasteProfile = tasteProfiles.first else {
            logger.warning("No taste profile found")
            return
        }

        engine.isLoading = true
        defer { engine.isLoading = false }

        do {
            let recommendations: [Recommendation]

            switch selectedMode {
            case .hybrid:
                // 최근 방문 기록 가져오기
                let allVisits = restaurants.flatMap { $0.visits ?? [] }
                let recentVisits = allVisits.sorted { $0.visitDate > $1.visitDate }.prefix(20)

                recommendations = try await engine.recommendHybrid(
                    myTasteProfile: tasteProfile,
                    myRecentVisits: Array(recentVisits),
                    currentLocation: locationManager.currentLocation,
                    category: selectedCategory,
                    limit: 20
                )

            case .collaborative:
                let visitedIds = engine.getVisitedRestaurantIds(from: restaurants)
                recommendations = try await engine.recommendByCollaborativeFiltering(
                    myTasteProfile: tasteProfile,
                    myVisitedRestaurantIds: visitedIds,
                    limit: 20
                )

            case .similar:
                // 내가 가장 좋아했던 방문 기록 하나 선택
                let allVisits = restaurants.flatMap { $0.visits ?? [] }
                guard let bestVisit = allVisits
                    .filter({ $0.rating >= 4 })
                    .sorted(by: { $0.rating > $1.rating })
                    .first else {
                    logger.warning("No high-rated visits found")
                    engine.recommendations = []
                    return
                }

                let category = bestVisit.restaurant?.foodCategory ?? .general
                recommendations = try await engine.recommendBySimilarShape(
                    myVisit: bestVisit,
                    category: category,
                    limit: 20
                )
            }

            await MainActor.run {
                engine.recommendations = recommendations
                logger.info("✅ Loaded \(recommendations.count) recommendations")
            }

        } catch {
            logger.error("Failed to load recommendations: \(error.localizedDescription)")
            errorMessage = "추천을 불러오는데 실패했습니다: \(error.localizedDescription)"
        }
    }
}

// MARK: - Recommendation Card

struct RecommendationCard: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상단: 식당 이름 + 점수
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.restaurant.name)
                        .font(.headline)

                    Text(recommendation.restaurant.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", recommendation.score))
                            .fontWeight(.bold)
                    }
                    .font(.subheadline)

                    Text("추천 점수")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // 중간: 이유
            Text(recommendation.reason)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)

            // 하단: 상세 정보
            HStack(spacing: 16) {
                DetailBadge(
                    icon: "star.fill",
                    text: String(format: "%.1f", recommendation.restaurant.averageRating),
                    color: .orange
                )

                DetailBadge(
                    icon: "fork.knife",
                    text: recommendation.restaurant.foodCategory,
                    color: .green
                )

                DetailBadge(
                    icon: "person.2.fill",
                    text: "\(recommendation.restaurant.visitCount)회",
                    color: .purple
                )

                Spacer()
            }
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
}

struct DetailBadge: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2)
                .fontWeight(.medium)
        }
        .foregroundStyle(color)
    }
}

// MARK: - Sync Data View

struct SyncDataView: View {
    @Environment(\.dismiss) private var dismiss
    let tasteProfile: TasteProfile?
    let restaurants: [Restaurant]

    @State private var isSyncing = false
    @State private var syncProgress = 0.0
    @State private var syncMessage = ""
    @State private var isGeneratingDummy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 헤더
                    VStack(spacing: 12) {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("데이터 관리")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Firebase에 데이터를 업로드하여\n추천 시스템을 테스트합니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    // 진행 상태
                    if isSyncing || isGeneratingDummy {
                        VStack(spacing: 12) {
                            ProgressView(value: syncProgress)
                                .progressViewStyle(.linear)

                            Text(syncMessage)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    } else {
                        // 내 데이터 섹션
                        VStack(alignment: .leading, spacing: 16) {
                            Text("내 데이터")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                InfoRow(
                                    icon: "person.fill",
                                    text: "취향 프로필: \(tasteProfile != nil ? "있음" : "없음")"
                                )
                                InfoRow(
                                    icon: "fork.knife",
                                    text: "식당: \(restaurants.count)개"
                                )
                                InfoRow(
                                    icon: "calendar",
                                    text: "방문 기록: \(restaurants.flatMap { $0.visits ?? [] }.count)개"
                                )
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)

                            Button {
                                Task {
                                    await syncMyData()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.up.fill")
                                    Text("내 데이터 업로드")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                            .disabled(restaurants.isEmpty)
                        }

                        Divider()
                            .padding(.vertical, 8)

                        // 테스트 데이터 섹션
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("테스트 데이터")
                                    .font(.headline)

                                Spacer()

                                Image(systemName: "flask.fill")
                                    .foregroundStyle(.orange)
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("더미 사용자 5명과 식당 데이터를 생성합니다")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("• 다양한 취향의 사용자 5명")
                                    Text("• 각 사용자당 식당 3-4개")
                                    Text("• 각 식당당 방문 기록 1-3개")
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)

                            Button {
                                Task {
                                    await generateDummyData()
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "wand.and.stars")
                                    Text("더미 데이터 생성")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                        }

                        // 안내 메시지
                        VStack(alignment: .leading, spacing: 8) {
                            Label("추천 테스트 순서", systemImage: "info.circle.fill")
                                .font(.caption)
                                .fontWeight(.semibold)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("1️⃣ 내 데이터 업로드")
                                Text("2️⃣ 더미 데이터 생성")
                                Text("3️⃣ 추천 탭에서 결과 확인")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                    .disabled(isSyncing || isGeneratingDummy)
                }
            }
        }
    }

    // 내 데이터 업로드
    private func syncMyData() async {
        isSyncing = true
        syncProgress = 0.0

        do {
            syncMessage = "내 데이터 업로드 중..."
            syncProgress = 0.3

            try await FirebaseService.shared.syncAllData(
                tasteProfile: tasteProfile,
                restaurants: restaurants
            )

            syncProgress = 1.0
            syncMessage = "✅ 내 데이터 업로드 완료!"

            try await Task.sleep(nanoseconds: 2_000_000_000)
            // dismiss() - 더미 데이터도 생성할 수 있도록 닫지 않음

        } catch {
            syncMessage = "❌ 업로드 실패: \(error.localizedDescription)"
        }

        isSyncing = false
    }

    // 더미 데이터 생성
    private func generateDummyData() async {
        isGeneratingDummy = true
        syncProgress = 0.0

        do {
            syncMessage = "더미 사용자 및 식당 생성 중..."
            syncProgress = 0.2

            try await FirebaseService.shared.generateDummyData()

            syncProgress = 1.0
            syncMessage = "✅ 더미 데이터 생성 완료!"

            try await Task.sleep(nanoseconds: 2_000_000_000)
            dismiss()

        } catch {
            syncMessage = "❌ 생성 실패: \(error.localizedDescription)"
        }

        isGeneratingDummy = false
    }
}

struct InfoRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .frame(width: 20)
                .foregroundStyle(.blue)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

// MARK: - Top6 Card

struct Top6Card: View {
    let restaurant: Restaurant

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상단: 랭킹 + 식당 이름
            HStack(alignment: .top) {
                // 랭킹 뱃지
                if let rank = restaurant.top6Rank {
                    ZStack {
                        Circle()
                            .fill(.yellow)
                            .frame(width: 36, height: 36)
                        Text("\(rank)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(restaurant.name)
                        .font(.headline)

                    Text(restaurant.foodCategory.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 별점
                HStack(spacing: 2) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                    Text(String(format: "%.1f", restaurant.averageRating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            // 통계
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(restaurant.visitCount)회 방문")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let lastVisit = restaurant.lastVisitDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(lastVisit, style: .relative)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // 평균 맛 평가 (간단한 바 차트)
            if !restaurant.averageIntensity.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("맛 평가")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ForEach(Array(restaurant.averageIntensity.prefix(3)), id: \.0) { item in
                        HStack(spacing: 8) {
                            Text(item.0)
                                .font(.caption2)
                                .frame(width: 50, alignment: .leading)
                                .foregroundStyle(.secondary)

                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(height: 6)

                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * (item.1 / 10.0), height: 6)
                                }
                            }
                            .frame(height: 6)

                            Text(String(format: "%.1f", item.1))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Location Manager

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.first
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, TasteProfile.self, configurations: config)

    return RecommendationView()
        .modelContainer(container)
}
