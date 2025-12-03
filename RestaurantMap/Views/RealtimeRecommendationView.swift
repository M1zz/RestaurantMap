import SwiftUI
import SwiftData
import CoreLocation
import OSLog

struct RealtimeRecommendationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @Query private var tasteProfiles: [TasteProfile]

    @StateObject private var engine = RealtimeRecommendationEngine.shared
    @StateObject private var firebaseService = FirebaseRealtimeService.shared
    @StateObject private var locationManager = LocationManager()

    @State private var selectedMode: RecommendationMode = .collaborative
    @State private var selectedCategory: FoodCategory? = nil
    @State private var showingSync = false
    @State private var errorMessage: String?

    private let logger = Logger(subsystem: "com.restaurantmap", category: "RecommendationView")

    enum RecommendationMode: String, CaseIterable, Identifiable {
        case collaborative = "비슷한 입맛"
        case hybrid = "종합 추천"

        var id: String { rawValue }

        var description: String {
            switch self {
            case .collaborative:
                return "나와 입맛이 비슷한 사람들의 선택"
            case .hybrid:
                return "평점, 만족도, 거리를 종합 고려"
            }
        }

        var icon: String {
            switch self {
            case .collaborative: return "person.3.fill"
            case .hybrid: return "sparkles"
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
                            Label("데이터 관리", systemImage: "icloud.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingSync) {
                RealtimeSyncDataView(
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
                        .frame(width: 120, height: 80)
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

                ForEach(FoodCategory.allCases) { category in
                    Button {
                        selectedCategory = category
                        Task {
                            await loadRecommendations()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(category.icon)
                            Text(category.displayName)
                        }
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
            Text("Realtime Database에서 데이터 가져오는 중...")
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
                        Text("데이터 업로드하기")
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
            ForEach(engine.recommendations) { recommendation in
                RecommendationCard(recommendation: recommendation)
            }
        }
        .listStyle(.plain)
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
            case .collaborative:
                let visitedIds = engine.getVisitedRestaurantIds(from: restaurants)
                recommendations = try await engine.recommendByCollaborativeFiltering(
                    myTasteProfile: tasteProfile,
                    myVisitedRestaurantIds: visitedIds,
                    limit: 20
                )

            case .hybrid:
                recommendations = try await engine.recommendHybrid(
                    myTasteProfile: tasteProfile,
                    currentLocation: locationManager.currentLocation,
                    category: selectedCategory,
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

// MARK: - Sync Data View (Realtime Database용)

struct RealtimeSyncDataView: View {
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
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)

                        Text("Realtime Database")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("⚡ 더 빠른 실시간 동기화\n💰 더 저렴한 비용")
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
                        .background(Color.orange.opacity(0.1))
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
                                    Image(systemName: "bolt.fill")
                                    Text("Realtime DB에 업로드")
                                }
                                .fontWeight(.semibold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
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
                                    .foregroundStyle(.blue)
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
                            .background(Color.blue.opacity(0.1))
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
                                .background(Color.blue)
                                .foregroundStyle(.white)
                                .cornerRadius(12)
                            }
                        }

                        // 안내 메시지
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Realtime Database 장점", systemImage: "bolt.circle.fill")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("⚡ 더 빠른 실시간 동기화")
                                Text("💰 비용 효율적 (Firestore 대비 1/6)")
                                Text("🚀 간단한 JSON 구조")
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
            syncMessage = "Realtime Database에 업로드 중..."
            syncProgress = 0.3

            try await FirebaseRealtimeService.shared.syncAllData(
                tasteProfile: tasteProfile,
                restaurants: restaurants
            )

            syncProgress = 1.0
            syncMessage = "✅ 업로드 완료!"

            try await Task.sleep(nanoseconds: 2_000_000_000)

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

            try await FirebaseRealtimeService.shared.generateDummyData()

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

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, TasteProfile.self, configurations: config)

    return RealtimeRecommendationView()
        .modelContainer(container)
}
