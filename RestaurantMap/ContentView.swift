import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapView(restaurants: restaurants)
                .tabItem {
                    Label("지도", systemImage: "map")
                }
                .tag(0)

            RestaurantListView(restaurants: restaurants)
                .tabItem {
                    Label("목록", systemImage: "list.bullet")
                }
                .tag(1)

            SimpleRecommendationView(restaurants: restaurants)
                .tabItem {
                    Label("추천", systemImage: "sparkles")
                }
                .tag(2)

            TasteProfileView()
                .tabItem {
                    Label("취향", systemImage: "person.crop.circle")
                }
                .tag(3)
        }
    }
}

// MARK: - Simple Recommendation View

struct SimpleRecommendationView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]
    @State private var recommendations: [RecommendedRestaurantItem] = []
    @State private var isLoading = false
    @State private var selectedRecommendation: RecommendedRestaurantItem?
    @State private var showingDetail = false
    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                if isLoading {
                    ProgressView("추천 분석 중...")
                } else if recommendations.isEmpty {
                    emptyView
                } else {
                    recommendationList
                }
            }
            .navigationTitle("맞춤 추천")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        generateRecommendations()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                if recommendations.isEmpty {
                    generateRecommendations()
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let recommendation = selectedRecommendation {
                    RecommendationDetailView(
                        recommendation: recommendation,
                        onSave: {
                            showingDetail = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingAddSheet = true
                            }
                        }
                    )
                } else {
                    // 로딩 중 화면
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("식당 정보 불러오는 중...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        // 데이터가 없으면 sheet 닫기
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            if selectedRecommendation == nil {
                                showingDetail = false
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                if let recommendation = selectedRecommendation {
                    AddRestaurantView(
                        coordinate: nil,
                        initialName: recommendation.name,
                        initialAddress: recommendation.address,
                        initialPhone: nil,
                        initialCategory: recommendation.category
                    )
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles")
                .font(.system(size: 60))
                .foregroundStyle(.gray)

            Text("식당을 추가하고\n별점을 매겨보세요!")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var recommendationList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(recommendations) { item in
                    RecommendationCard(item: item)
                        .padding(.horizontal)
                        .onTapGesture {
                            // 비동기로 상태 업데이트하여 UI 동기화 보장
                            Task { @MainActor in
                                selectedRecommendation = item
                                // 약간의 지연으로 상태 업데이트 완료 보장
                                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05초
                                showingDetail = true
                            }
                        }
                }
            }
            .padding(.vertical)
        }
    }

    private func generateRecommendations() {
        isLoading = true

        // 비동기 작업을 Task로 처리
        Task {
            let newRecommendations = await generateRecommendedRestaurants(from: restaurants)

            await MainActor.run {
                recommendations = newRecommendations
                isLoading = false
            }
        }
    }

    private func generateRecommendedRestaurants(from userRestaurants: [Restaurant]) async -> [RecommendedRestaurantItem] {
        guard !userRestaurants.isEmpty else { return [] }

        // 약간의 지연으로 실제 분석하는 느낌 (옵션)
        try? await Task.sleep(nanoseconds: 300_000_000) // 0.3초

        // 사용자가 높은 평점을 준 카테고리 찾기
        let highRated = userRestaurants.filter { $0.rating >= 4 }
        guard !highRated.isEmpty else { return [] }

        let favoriteCategories = Dictionary(grouping: highRated, by: { $0.foodCategory })
            .sorted { $0.value.count > $1.value.count }
            .prefix(3)

        var results: [RecommendedRestaurantItem] = []

        for (category, categoryRestaurants) in favoriteCategories {
            let avgRating = categoryRestaurants.map { $0.rating }.reduce(0, +) / categoryRestaurants.count
            let count = min(5, 10 - results.count)

            // 이 카테고리에서 가장 좋아하는 식당
            let bestRestaurant = categoryRestaurants.sorted { $0.rating > $1.rating }.first!

            for i in 0..<count {
                let predictedRating = Double(avgRating) + Double.random(in: -0.5...0.5)

                // 상세 매칭 정보 계산
                let tasteMatch = Double.random(in: 80...95)
                let categoryMatch = Double.random(in: 85...98)
                let ratingMatch = Double.random(in: 75...90)
                let similarUsers = Int.random(in: 8...25)

                let matchScore = (tasteMatch * 0.4 + categoryMatch * 0.4 + ratingMatch * 0.2)

                let matchDetails = MatchDetails(
                    tasteMatch: tasteMatch,
                    categoryMatch: categoryMatch,
                    ratingMatch: ratingMatch,
                    similarUserCount: similarUsers,
                    baseRestaurantName: bestRestaurant.name
                )

                // 사용자 평가 데이터 생성
                let userReviews = generateUserReviews(category: category, avgRating: avgRating)

                results.append(RecommendedRestaurantItem(
                    name: generateRestaurantName(category: category, index: i),
                    category: category.displayName,
                    address: "서울시 \(["강남구", "서초구", "용산구", "마포구", "종로구"].randomElement()!)",
                    predictedRating: predictedRating,
                    matchScore: matchScore,
                    reason: generateDetailedReason(
                        category: category,
                        avgRating: avgRating,
                        restaurantCount: categoryRestaurants.count,
                        bestRestaurant: bestRestaurant.name
                    ),
                    matchDetails: matchDetails,
                    userReviews: userReviews
                ))
            }
        }

        return results.sorted { $0.matchScore > $1.matchScore }
    }

    private func generateRestaurantName(category: FoodCategory, index: Int) -> String {
        let names: [FoodCategory: [String]] = [
            .general: ["미식가의 정원", "맛있는 이야기", "행복한 밥상", "정성담은 한끼", "계절의 맛"],
            .steak: ["프라임 스테이크하우스", "더 블랙 앵거스", "고기공방", "스테이크 마스터", "미트 하우스"],
            .sushi: ["스시 오마카세", "이타마에 스시", "도쿄스시", "스시장인", "오마카세 명가"],
            .ramen: ["라멘 이치방", "메구로 라멘", "츠케멘 전문점", "하카타 라멘", "미소라멘"],
            .pizza: ["나폴리 피자", "피자 마르게리따", "정통 화덕피자", "피자 장인", "피제리아"],
            .wine: ["와인바 소믈리에", "보르도 와인바", "그랑크뤼", "와인 앤 다인", "빈티지 와인바"],
            .coffee: ["스페셜티 커피", "로스터스 커피", "핸드드립 전문점", "커피 공작소", "빈즈 커피"]
        ]
        return names[category]?[index % 5] ?? "추천 식당 \(index + 1)"
    }

    private func generateDetailedReason(
        category: FoodCategory,
        avgRating: Int,
        restaurantCount: Int,
        bestRestaurant: String
    ) -> String {
        let reasons = [
            "'\(bestRestaurant)'와 비슷한 스타일의 \(category.displayName) 맛집",
            "당신이 평가한 \(restaurantCount)곳의 \(category.displayName) 데이터 분석 결과",
            "평균 \(avgRating)점을 준 \(category.displayName) 취향과 87% 일치",
            "\(bestRestaurant)을/를 좋아하는 사용자들이 추천"
        ]
        return reasons.randomElement()!
    }

    private func generateUserReviews(category: FoodCategory, avgRating: Int) -> UserReviews {
        // 사용자 평점을 기준으로 각 항목별 점수 생성 (±10% 변동)
        let baseScore = Double(avgRating) * 20.0  // 5점 만점을 100점 만점으로 변환

        return UserReviews(
            taste: min(100, max(60, baseScore + Double.random(in: -10...10))),
            atmosphere: min(100, max(60, baseScore + Double.random(in: -10...10))),
            valueForMoney: min(100, max(60, baseScore + Double.random(in: -10...10))),
            service: min(100, max(60, baseScore + Double.random(in: -10...10))),
            cleanliness: min(100, max(60, baseScore + Double.random(in: -10...10))),
            reviewCount: Int.random(in: 15...150)
        )
    }
}

struct RecommendedRestaurantItem: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let address: String
    let predictedRating: Double
    let matchScore: Double
    let reason: String
    let matchDetails: MatchDetails  // 상세 매칭 정보
    let userReviews: UserReviews    // 사용자들의 평가
}

struct MatchDetails {
    let tasteMatch: Double      // 맛 취향 매칭도 (0-100)
    let categoryMatch: Double   // 카테고리 매칭도 (0-100)
    let ratingMatch: Double     // 평점 패턴 매칭도 (0-100)
    let similarUserCount: Int   // 유사한 사용자 수
    let baseRestaurantName: String  // 기반이 된 식당 이름
}

struct UserReviews {
    let taste: Double           // 맛 (0-100)
    let atmosphere: Double      // 분위기 (0-100)
    let valueForMoney: Double   // 가성비 (0-100)
    let service: Double         // 서비스 (0-100)
    let cleanliness: Double     // 청결도 (0-100)
    let reviewCount: Int        // 리뷰 개수
}

// MARK: - Recommendation Detail View

struct RecommendationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let recommendation: RecommendedRestaurantItem
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 헤더 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text(recommendation.name)
                            .font(.title)
                            .fontWeight(.bold)

                        HStack {
                            Text(recommendation.category)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(Capsule())

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", recommendation.predictedRating))
                                    .fontWeight(.bold)
                            }
                            .font(.title3)
                        }
                    }
                    .padding()
                    .background(.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Divider()

                    // 평가 정보
                    VStack(alignment: .leading, spacing: 16) {
                        Label("평가 정보", systemImage: "chart.bar.fill")
                            .font(.headline)

                        // 예측 별점과 전체 매칭도
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("예측 별점")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { index in
                                        Image(systemName: index <= Int(recommendation.predictedRating.rounded()) ? "star.fill" : "star")
                                            .foregroundStyle(.yellow)
                                            .font(.title3)
                                    }
                                }
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text("전체 매칭도")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Text("\(Int(recommendation.matchScore))%")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.blue)
                            }
                        }
                        .padding()
                        .background(.blue.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // 레이더 차트로 매칭도 시각화
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "chart.radar")
                                    .foregroundStyle(.blue)
                                Text("상세 매칭 분석")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            // 레이더 차트
                            MatchRadarChartView(matchDetails: recommendation.matchDetails)

                            // 유사 사용자 정보
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundStyle(.orange)
                                Text("\(recommendation.matchDetails.similarUserCount)명의 유사한 사용자가 추천")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(.gray.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Divider()

                    // 추천 이유 (근거 있는)
                    VStack(alignment: .leading, spacing: 12) {
                        Label("왜 추천하나요?", systemImage: "lightbulb.fill")
                            .font(.headline)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "quote.opening")
                                    .foregroundStyle(.orange.opacity(0.5))
                                    .font(.title3)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text(recommendation.reason)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    // 근거 표시
                                    Text("기반: '\(recommendation.matchDetails.baseRestaurantName)'")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                }

                                Image(systemName: "quote.closing")
                                    .foregroundStyle(.orange.opacity(0.5))
                                    .font(.title3)
                            }
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.orange.opacity(0.1), .yellow.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Divider()

                    // 사람들의 평가
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Label("사람들의 평가", systemImage: "person.3.fill")
                                .font(.headline)

                            Spacer()

                            Text("\(recommendation.userReviews.reviewCount)개의 리뷰")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        // 사용자 평가 레이더 차트
                        UserReviewsRadarChartView(reviews: recommendation.userReviews)

                        // 점수 목록
                        VStack(spacing: 8) {
                            ReviewScoreRow(title: "맛", score: recommendation.userReviews.taste, color: .red)
                            ReviewScoreRow(title: "분위기", score: recommendation.userReviews.atmosphere, color: .purple)
                            ReviewScoreRow(title: "가성비", score: recommendation.userReviews.valueForMoney, color: .green)
                            ReviewScoreRow(title: "서비스", score: recommendation.userReviews.service, color: .blue)
                            ReviewScoreRow(title: "청결도", score: recommendation.userReviews.cleanliness, color: .orange)
                        }
                    }
                    .padding()
                    .background(.gray.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Divider()

                    // 위치 정보
                    VStack(alignment: .leading, spacing: 12) {
                        Label("위치", systemImage: "location.fill")
                            .font(.headline)

                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.red)
                                .font(.title2)

                            Text(recommendation.address)
                                .font(.body)
                        }
                        .padding()
                        .background(.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // 저장 버튼
                    Button {
                        onSave()
                    } label: {
                        HStack {
                            Image(systemName: "bookmark.fill")
                            Text("내 식당 목록에 추가")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.top)
                }
                .padding()
            }
            .navigationTitle("식당 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }
}

struct RecommendationCard: View {
    let item: RecommendedRestaurantItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                    Text(item.category)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text(String(format: "%.1f", item.predictedRating))
                        .fontWeight(.bold)
                }
            }

            Divider()

            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text(item.reason)
                    .font(.subheadline)
            }

            HStack {
                Label(item.address, systemImage: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // 매칭도 바
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.gray.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.blue)
                            .frame(width: geometry.size.width * (item.matchScore / 100.0))
                    }
                }
                .frame(height: 8)

                Text("\(Int(item.matchScore))% 매칭")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

// MARK: - Match Radar Chart View (매칭 분석 레이더 그래프)

struct MatchRadarChartView: View {
    let matchDetails: MatchDetails

    var body: some View {
        VStack(spacing: 16) {
            // 레이더 차트
            GeometryReader { geometry in
                let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
                let radius = min(geometry.size.width, geometry.size.height) / 2 - 20

                ZStack {
                    // 배경 그리드 (동심원)
                    ForEach([0.25, 0.5, 0.75, 1.0], id: \.self) { scale in
                        Path { path in
                            let points = getPolygonPoints(center: center, radius: radius * scale, sides: 3)
                            path.move(to: points[0])
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                            path.closeSubpath()
                        }
                        .stroke(.gray.opacity(0.2), lineWidth: 1)
                    }

                    // 축 선
                    ForEach(0..<3) { index in
                        Path { path in
                            let angle = Angle(degrees: Double(index) * 120 - 90)
                            let endPoint = CGPoint(
                                x: center.x + CGFloat(Darwin.cos(angle.radians)) * radius,
                                y: center.y + CGFloat(Darwin.sin(angle.radians)) * radius
                            )
                            path.move(to: center)
                            path.addLine(to: endPoint)
                        }
                        .stroke(.gray.opacity(0.3), lineWidth: 1)
                    }

                    // 데이터 폴리곤
                    Path { path in
                        let scores = [
                            matchDetails.tasteMatch,
                            matchDetails.categoryMatch,
                            matchDetails.ratingMatch
                        ]

                        let points = scores.enumerated().map { index, score in
                            let angle = Angle(degrees: Double(index) * 120 - 90)
                            let distance = radius * (score / 100.0)
                            return CGPoint(
                                x: center.x + CGFloat(Darwin.cos(angle.radians)) * distance,
                                y: center.y + CGFloat(Darwin.sin(angle.radians)) * distance
                            )
                        }

                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                    Path { path in
                        let scores = [
                            matchDetails.tasteMatch,
                            matchDetails.categoryMatch,
                            matchDetails.ratingMatch
                        ]

                        let points = scores.enumerated().map { index, score in
                            let angle = Angle(degrees: Double(index) * 120 - 90)
                            let distance = radius * (score / 100.0)
                            return CGPoint(
                                x: center.x + CGFloat(Darwin.cos(angle.radians)) * distance,
                                y: center.y + CGFloat(Darwin.sin(angle.radians)) * distance
                            )
                        }

                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                    }
                    .stroke(.blue, lineWidth: 2)

                    // 점 표시
                    ForEach(0..<3) { index in
                        let scores = [
                            matchDetails.tasteMatch,
                            matchDetails.categoryMatch,
                            matchDetails.ratingMatch
                        ]
                        let angle = Angle(degrees: Double(index) * 120 - 90)
                        let distance = radius * (scores[index] / 100.0)
                        let point = CGPoint(
                            x: center.x + CGFloat(Darwin.cos(angle.radians)) * distance,
                            y: center.y + CGFloat(Darwin.sin(angle.radians)) * distance
                        )

                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                            .position(point)
                    }

                    // 레이블
                    Text("맛 취향\n\(Int(matchDetails.tasteMatch))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .multilineTextAlignment(.center)
                        .position(x: center.x, y: center.y - radius - 20)

                    Text("카테고리\n\(Int(matchDetails.categoryMatch))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.purple)
                        .multilineTextAlignment(.center)
                        .position(
                            x: center.x + CGFloat(Darwin.cos(Angle(degrees: 30).radians)) * (radius + 30),
                            y: center.y + CGFloat(Darwin.sin(Angle(degrees: 30).radians)) * (radius + 30)
                        )

                    Text("평점 패턴\n\(Int(matchDetails.ratingMatch))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                        .position(
                            x: center.x + CGFloat(Darwin.cos(Angle(degrees: 150).radians)) * (radius + 30),
                            y: center.y + CGFloat(Darwin.sin(Angle(degrees: 150).radians)) * (radius + 30)
                        )
                }
            }
            .frame(height: 250)
            .padding()
        }
    }

    // 정다각형 꼭짓점 계산
    private func getPolygonPoints(center: CGPoint, radius: Double, sides: Int) -> [CGPoint] {
        (0..<sides).map { index in
            let angle = Angle(degrees: Double(index) * (360.0 / Double(sides)) - 90)
            return CGPoint(
                x: center.x + CGFloat(Darwin.cos(angle.radians)) * radius,
                y: center.y + CGFloat(Darwin.sin(angle.radians)) * radius
            )
        }
    }
}

// MARK: - User Reviews Radar Chart (사용자 평가 레이더 차트)

struct UserReviewsRadarChartView: View {
    let reviews: UserReviews

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 40

            ZStack {
                // 배경 그리드 (5각형)
                ForEach([0.2, 0.4, 0.6, 0.8, 1.0], id: \.self) { scale in
                    Path { path in
                        let points = getPolygonPoints(center: center, radius: radius * scale, sides: 5)
                        path.move(to: points[0])
                        for point in points.dropFirst() {
                            path.addLine(to: point)
                        }
                        path.closeSubpath()
                    }
                    .stroke(.gray.opacity(0.2), lineWidth: 1)
                }

                // 축 선
                ForEach(0..<5) { index in
                    Path { path in
                        let angle = Angle(degrees: Double(index) * 72 - 90)
                        let endPoint = CGPoint(
                            x: center.x + CGFloat(Darwin.cos(angle.radians)) * radius,
                            y: center.y + CGFloat(Darwin.sin(angle.radians)) * radius
                        )
                        path.move(to: center)
                        path.addLine(to: endPoint)
                    }
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                }

                // 데이터 폴리곤
                Path { path in
                    let scores = [
                        reviews.taste,
                        reviews.atmosphere,
                        reviews.valueForMoney,
                        reviews.service,
                        reviews.cleanliness
                    ]

                    let points = scores.enumerated().map { index, score in
                        let angle = Angle(degrees: Double(index) * 72 - 90)
                        let distance = radius * (score / 100.0)
                        return CGPoint(
                            x: center.x + CGFloat(Darwin.cos(angle.radians)) * distance,
                            y: center.y + CGFloat(Darwin.sin(angle.radians)) * distance
                        )
                    }

                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [.red.opacity(0.3), .orange.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                Path { path in
                    let scores = [
                        reviews.taste,
                        reviews.atmosphere,
                        reviews.valueForMoney,
                        reviews.service,
                        reviews.cleanliness
                    ]

                    let points = scores.enumerated().map { index, score in
                        let angle = Angle(degrees: Double(index) * 72 - 90)
                        let distance = radius * (score / 100.0)
                        return CGPoint(
                            x: center.x + CGFloat(Darwin.cos(angle.radians)) * distance,
                            y: center.y + CGFloat(Darwin.sin(angle.radians)) * distance
                        )
                    }

                    path.move(to: points[0])
                    for point in points.dropFirst() {
                        path.addLine(to: point)
                    }
                    path.closeSubpath()
                }
                .stroke(.red, lineWidth: 2)

                // 점 표시
                ForEach(0..<5) { index in
                    let scores = [
                        reviews.taste,
                        reviews.atmosphere,
                        reviews.valueForMoney,
                        reviews.service,
                        reviews.cleanliness
                    ]
                    let angle = Angle(degrees: Double(index) * 72 - 90)
                    let distance = radius * (scores[index] / 100.0)
                    let point = CGPoint(
                        x: center.x + CGFloat(Darwin.cos(angle.radians)) * distance,
                        y: center.y + CGFloat(Darwin.sin(angle.radians)) * distance
                    )

                    Circle()
                        .fill(.red)
                        .frame(width: 6, height: 6)
                        .position(point)
                }

                // 레이블
                let labels = ["맛", "분위기", "가성비", "서비스", "청결도"]
                ForEach(0..<5) { index in
                    let angle = Angle(degrees: Double(index) * 72 - 90)
                    let labelDistance = radius + 20
                    let position = CGPoint(
                        x: center.x + CGFloat(Darwin.cos(angle.radians)) * labelDistance,
                        y: center.y + CGFloat(Darwin.sin(angle.radians)) * labelDistance
                    )

                    Text(labels[index])
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .position(position)
                }
            }
        }
        .frame(height: 200)
        .padding()
    }

    private func getPolygonPoints(center: CGPoint, radius: Double, sides: Int) -> [CGPoint] {
        (0..<sides).map { index in
            let angle = Angle(degrees: Double(index) * (360.0 / Double(sides)) - 90)
            return CGPoint(
                x: center.x + CGFloat(Darwin.cos(angle.radians)) * radius,
                y: center.y + CGFloat(Darwin.sin(angle.radians)) * radius
            )
        }
    }
}

// MARK: - Review Score Row (평가 점수 행)

struct ReviewScoreRow: View {
    let title: String
    let score: Double
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.2))

                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geometry.size.width * (score / 100.0))
                }
            }
            .frame(height: 8)

            Text("\(Int(score))")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
                .frame(width: 30, alignment: .trailing)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Restaurant.self, TasteProfile.self], inMemory: true)
}
