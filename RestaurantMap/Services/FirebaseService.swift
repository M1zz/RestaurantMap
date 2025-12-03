import Foundation
import FirebaseFirestore
import FirebaseAuth
import OSLog

/// Firebase Firestore와 통신하는 서비스 클래스
@MainActor
class FirebaseService: ObservableObject {
    static let shared = FirebaseService()

    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    private let logger = Logger(subsystem: "com.restaurantmap", category: "Firebase")

    // 현재 사용자 ID (Firebase Auth UID)
    @Published var currentUserId: String = ""
    @Published var isAuthenticated: Bool = false

    private init() {
        // Auth 상태 리스너 설정
        auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let user = user {
                    self?.currentUserId = user.uid
                    self?.isAuthenticated = true
                    self?.logger.info("✅ User authenticated: \(user.uid)")
                } else {
                    self?.currentUserId = ""
                    self?.isAuthenticated = false
                    self?.logger.warning("❌ User not authenticated")
                }
            }
        }

        logger.info("FirebaseService initialized")
    }

    // MARK: - Authentication

    /// 익명 로그인 (자동)
    func signInAnonymously() async throws {
        logger.info("🔐 Attempting anonymous sign in...")

        // 이미 로그인되어 있으면 스킵
        if auth.currentUser != nil {
            logger.info("Already signed in with UID: \(auth.currentUser!.uid)")
            return
        }

        do {
            let result = try await auth.signInAnonymously()
            currentUserId = result.user.uid
            isAuthenticated = true
            logger.info("✅ Anonymous sign in successful: \(result.user.uid)")
        } catch {
            logger.error("❌ Anonymous sign in failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// 현재 사용자 UID 가져오기 (인증 확인)
    var authenticatedUserId: String? {
        auth.currentUser?.uid
    }

    // MARK: - Upload Methods

    /// 내 취향 프로필을 Firebase에 업로드
    func uploadTasteProfile(_ profile: TasteProfile) async throws {
        let firebaseProfile = profile.toFirebase(userId: currentUserId)
        let data = try Firestore.Encoder().encode(firebaseProfile)

        try await db.collection("users")
            .document(currentUserId)
            .collection("tasteProfile")
            .document("current")
            .setData(data)

        logger.info("✅ Taste profile uploaded")
    }

    /// 식당 정보를 Firebase에 업로드
    func uploadRestaurant(_ restaurant: Restaurant, isPublic: Bool = true) async throws {
        let firebaseRestaurant = restaurant.toFirebase(userId: currentUserId, isPublic: isPublic)
        let data = try Firestore.Encoder().encode(firebaseRestaurant)

        try await db.collection("restaurants")
            .document(firebaseRestaurant.id)
            .setData(data)

        logger.info("✅ Restaurant '\(restaurant.name)' uploaded")
    }

    /// 방문 기록을 Firebase에 업로드
    func uploadVisit(_ visit: Visit, restaurantFirebaseId: String, isPublic: Bool = true) async throws {
        let firebaseVisit = visit.toFirebase(
            restaurantId: restaurantFirebaseId,
            userId: currentUserId,
            isPublic: isPublic
        )
        let data = try Firestore.Encoder().encode(firebaseVisit)

        try await db.collection("visits")
            .document(firebaseVisit.id)
            .setData(data)

        logger.info("✅ Visit uploaded")
    }

    /// 내 모든 데이터를 Firebase에 동기화
    func syncAllData(
        tasteProfile: TasteProfile?,
        restaurants: [Restaurant]
    ) async throws {
        logger.info("🔄 Starting full sync...")

        // 1. 취향 프로필 업로드
        if let profile = tasteProfile {
            try await uploadTasteProfile(profile)
        }

        // 2. 식당 & 방문 기록 업로드
        for restaurant in restaurants {
            try await uploadRestaurant(restaurant, isPublic: true)

            if let visits = restaurant.visits {
                for visit in visits {
                    try await uploadVisit(
                        visit,
                        restaurantFirebaseId: restaurant.name, // 실제로는 Firebase ID 매핑 필요
                        isPublic: true
                    )
                }
            }
        }

        logger.info("✅ Full sync completed")
    }

    // MARK: - Fetch Methods

    /// 모든 공개된 사용자들의 취향 프로필 가져오기
    func fetchAllTasteProfiles() async throws -> [FirebaseTasteProfile] {
        logger.info("📥 Fetching all taste profiles...")

        let snapshot = try await db.collectionGroup("tasteProfile")
            .getDocuments()

        let profiles = try snapshot.documents.compactMap { document -> FirebaseTasteProfile? in
            try document.data(as: FirebaseTasteProfile.self)
        }

        logger.info("📥 Fetched \(profiles.count) taste profiles")
        return profiles
    }

    /// 모든 공개된 식당 정보 가져오기
    func fetchAllRestaurants() async throws -> [FirebaseRestaurant] {
        logger.info("📥 Fetching all restaurants...")

        let snapshot = try await db.collection("restaurants")
            .whereField("isPublic", isEqualTo: true)
            .getDocuments()

        let restaurants = try snapshot.documents.compactMap { document -> FirebaseRestaurant? in
            try document.data(as: FirebaseRestaurant.self)
        }

        logger.info("📥 Fetched \(restaurants.count) restaurants")
        return restaurants
    }

    /// 특정 카테고리의 식당들 가져오기
    func fetchRestaurants(category: FoodCategory) async throws -> [FirebaseRestaurant] {
        logger.info("📥 Fetching \(category.rawValue) restaurants...")

        let snapshot = try await db.collection("restaurants")
            .whereField("isPublic", isEqualTo: true)
            .whereField("foodCategory", isEqualTo: category.rawValue)
            .getDocuments()

        let restaurants = try snapshot.documents.compactMap { document -> FirebaseRestaurant? in
            try document.data(as: FirebaseRestaurant.self)
        }

        logger.info("📥 Fetched \(restaurants.count) \(category.rawValue) restaurants")
        return restaurants
    }

    /// 특정 식당의 모든 방문 기록 가져오기
    func fetchVisits(for restaurantId: String) async throws -> [FirebaseVisit] {
        logger.info("📥 Fetching visits for restaurant \(restaurantId)...")

        let snapshot = try await db.collection("visits")
            .whereField("restaurantId", isEqualTo: restaurantId)
            .whereField("isPublic", isEqualTo: true)
            .getDocuments()

        let visits = try snapshot.documents.compactMap { document -> FirebaseVisit? in
            try document.data(as: FirebaseVisit.self)
        }

        logger.info("📥 Fetched \(visits.count) visits")
        return visits
    }

    /// 특정 사용자의 모든 방문 기록 가져오기
    func fetchVisits(for userId: String, limit: Int = 100) async throws -> [FirebaseVisit] {
        logger.info("📥 Fetching visits for user \(userId)...")

        let snapshot = try await db.collection("visits")
            .whereField("userId", isEqualTo: userId)
            .whereField("isPublic", isEqualTo: true)
            .limit(to: limit)
            .getDocuments()

        let visits = try snapshot.documents.compactMap { document -> FirebaseVisit? in
            try document.data(as: FirebaseVisit.self)
        }

        logger.info("📥 Fetched \(visits.count) visits for user")
        return visits
    }

    /// 지역 기반 식당 검색 (현재 위치 근처)
    func fetchNearbyRestaurants(
        latitude: Double,
        longitude: Double,
        radiusKm: Double = 10.0
    ) async throws -> [FirebaseRestaurant] {
        logger.info("📥 Fetching nearby restaurants...")

        // 간단한 bounding box 계산 (1도 ≈ 111km)
        let latRange = radiusKm / 111.0
        let lonRange = radiusKm / (111.0 * cos(latitude * .pi / 180.0))

        let minLat = latitude - latRange
        let maxLat = latitude + latRange
        let minLon = longitude - lonRange
        let maxLon = longitude + lonRange

        // Firestore는 복합 range 쿼리 제한이 있으므로 latitude만 필터링 후 클라이언트에서 처리
        let snapshot = try await db.collection("restaurants")
            .whereField("isPublic", isEqualTo: true)
            .whereField("latitude", isGreaterThanOrEqualTo: minLat)
            .whereField("latitude", isLessThanOrEqualTo: maxLat)
            .getDocuments()

        let restaurants = try snapshot.documents.compactMap { document -> FirebaseRestaurant? in
            try document.data(as: FirebaseRestaurant.self)
        }.filter { restaurant in
            // longitude도 클라이언트에서 필터링
            restaurant.longitude >= minLon && restaurant.longitude <= maxLon
        }

        logger.info("📥 Fetched \(restaurants.count) nearby restaurants")
        return restaurants
    }

    /// 높은 만족도 식당들 가져오기
    func fetchTopRatedRestaurants(limit: Int = 20) async throws -> [FirebaseRestaurant] {
        logger.info("📥 Fetching top rated restaurants...")

        let snapshot = try await db.collection("restaurants")
            .whereField("isPublic", isEqualTo: true)
            .whereField("satisfactionScore", isGreaterThan: 80.0)
            .order(by: "satisfactionScore", descending: true)
            .limit(to: limit)
            .getDocuments()

        let restaurants = try snapshot.documents.compactMap { document -> FirebaseRestaurant? in
            try document.data(as: FirebaseRestaurant.self)
        }

        logger.info("📥 Fetched \(restaurants.count) top rated restaurants")
        return restaurants
    }

    // MARK: - Dummy Data Generation (테스트용)

    /// 테스트용 더미 사용자 및 데이터 생성
    func generateDummyData() async throws {
        logger.info("🧪 Generating dummy data...")

        // 더미 사용자 5명 생성 (다양한 취향)
        let dummyUsers = createDummyUsers()

        for (index, profile) in dummyUsers.enumerated() {
            let userId = "dummy_user_\(index + 1)"

            // 1. 취향 프로필 업로드
            let data = try Firestore.Encoder().encode(profile)
            try await db.collection("users")
                .document(userId)
                .collection("tasteProfile")
                .document("current")
                .setData(data)

            logger.info("✅ Created user: \(userId)")

            // 2. 각 사용자의 식당 & 방문 기록 생성
            let restaurants = createDummyRestaurants(for: userId, userIndex: index)

            for restaurant in restaurants {
                // 식당 업로드
                let restaurantData = try Firestore.Encoder().encode(restaurant)
                try await db.collection("restaurants")
                    .document(restaurant.id)
                    .setData(restaurantData)

                // 방문 기록 생성 (1-3개)
                let visitCount = Int.random(in: 1...3)
                for visitIndex in 0..<visitCount {
                    let visit = createDummyVisit(
                        for: restaurant,
                        userId: userId,
                        visitIndex: visitIndex,
                        userProfile: profile
                    )

                    let visitData = try Firestore.Encoder().encode(visit)
                    try await db.collection("visits")
                        .document(visit.id)
                        .setData(visitData)
                }

                logger.info("✅ Created restaurant: \(restaurant.name)")
            }
        }

        logger.info("✅ Dummy data generation completed!")
    }

    // MARK: - Private Helper Methods

    /// 다양한 취향을 가진 더미 사용자 5명 생성
    private func createDummyUsers() -> [FirebaseTasteProfile] {
        [
            // User 1: 맵고 진한 맛 선호
            FirebaseTasteProfile(
                userId: "dummy_user_1",
                spicy: 8.5,
                boldness: 8.0,
                sweetness: 4.0,
                saltiness: 7.0,
                richness: 7.5,
                naturalTaste: 5.0,
                texture: 6.0,
                cooking: 7.0
            ),

            // User 2: 단맛과 부드러운 맛 선호
            FirebaseTasteProfile(
                userId: "dummy_user_2",
                spicy: 3.0,
                boldness: 4.5,
                sweetness: 8.0,
                saltiness: 5.0,
                richness: 6.0,
                naturalTaste: 7.5,
                texture: 7.0,
                cooking: 6.0
            ),

            // User 3: 균형잡힌 중간 취향
            FirebaseTasteProfile(
                userId: "dummy_user_3",
                spicy: 5.5,
                boldness: 6.0,
                sweetness: 6.0,
                saltiness: 6.0,
                richness: 5.5,
                naturalTaste: 7.0,
                texture: 6.5,
                cooking: 6.5
            ),

            // User 4: 자연스러운 맛, 짠맛 선호
            FirebaseTasteProfile(
                userId: "dummy_user_4",
                spicy: 4.0,
                boldness: 5.5,
                sweetness: 4.5,
                saltiness: 8.0,
                richness: 5.0,
                naturalTaste: 9.0,
                texture: 7.5,
                cooking: 8.0
            ),

            // User 5: 강렬하고 기름진 맛 선호
            FirebaseTasteProfile(
                userId: "dummy_user_5",
                spicy: 7.0,
                boldness: 9.0,
                sweetness: 5.0,
                saltiness: 7.5,
                richness: 9.0,
                naturalTaste: 4.0,
                texture: 5.5,
                cooking: 6.0
            )
        ]
    }

    /// 각 사용자별 더미 식당 3-4개 생성
    private func createDummyRestaurants(for userId: String, userIndex: Int) -> [FirebaseRestaurant] {
        let baseLatitude = 37.5665 + Double(userIndex) * 0.01 // 서울 중심에서 약간씩 이동
        let baseLongitude = 126.9780 + Double(userIndex) * 0.01

        let categories: [(name: String, category: FoodCategory, address: String)] = [
            ("프리미엄 스테이크 하우스", .steak, "서울시 강남구 청담동"),
            ("오마카세 스시 바", .sushi, "서울시 강남구 신사동"),
            ("라멘 야타이", .ramen, "서울시 마포구 홍대"),
            ("나폴리 피자", .pizza, "서울시 용산구 이태원"),
            ("와인 셀러", .wine, "서울시 강남구 압구정"),
            ("스페셜티 커피", .coffee, "서울시 종로구 삼청동")
        ]

        var restaurants: [FirebaseRestaurant] = []

        // 각 사용자당 3-4개 식당
        let restaurantCount = Int.random(in: 3...4)
        for i in 0..<restaurantCount {
            let restaurant = categories[Int.random(in: 0..<categories.count)]

            let firebaseRestaurant = FirebaseRestaurant(
                id: "rest_\(userId)_\(i)",
                userId: userId,
                name: "\(restaurant.name) \(userIndex + 1)호점",
                address: restaurant.address,
                latitude: baseLatitude + Double.random(in: -0.01...0.01),
                longitude: baseLongitude + Double.random(in: -0.01...0.01),
                category: restaurant.category.displayName,
                foodCategory: restaurant.category.rawValue,
                phoneNumber: "02-\(String(format: "%04d", Int.random(in: 1000...9999)))-\(String(format: "%04d", Int.random(in: 1000...9999)))",
                averageRating: Double.random(in: 3.5...5.0),
                visitCount: Int.random(in: 1...5),
                satisfactionScore: Double.random(in: 70.0...95.0),
                createdAt: Date().addingTimeInterval(-Double.random(in: 0...(86400 * 30))), // 최근 30일
                isPublic: true
            )

            restaurants.append(firebaseRestaurant)
        }

        return restaurants
    }

    /// 더미 방문 기록 생성
    private func createDummyVisit(
        for restaurant: FirebaseRestaurant,
        userId: String,
        visitIndex: Int,
        userProfile: FirebaseTasteProfile
    ) -> FirebaseVisit {
        let category = FoodCategory(rawValue: restaurant.foodCategory) ?? .general
        let rating = Int.random(in: 3...5)

        var visit = FirebaseVisit(
            id: "visit_\(restaurant.id)_\(visitIndex)",
            restaurantId: restaurant.id,
            userId: userId,
            visitDate: Date().addingTimeInterval(-Double.random(in: 0...(86400 * 60))), // 최근 60일
            rating: rating,
            notes: ["정말 맛있었어요!", "또 가고 싶네요", "추천합니다", "괜찮았어요"].randomElement(),
            isPublic: true
        )

        // 카테고리별로 맛 평가 추가 (사용자 취향에 가깝게)
        switch category {
        case .general:
            visit.spicy = userProfile.spicy + Double.random(in: -1...1)
            visit.boldness = userProfile.boldness + Double.random(in: -1...1)
            visit.sweetness = userProfile.sweetness + Double.random(in: -1...1)
            visit.saltiness = userProfile.saltiness + Double.random(in: -1...1)
            visit.richness = userProfile.richness + Double.random(in: -1...1)
            visit.naturalTaste = userProfile.naturalTaste + Double.random(in: -1...1)

            visit.spicyAppropriate = rating
            visit.boldnessAppropriate = rating
            visit.sweetnessAppropriate = rating
            visit.saltinessAppropriate = rating
            visit.richnessAppropriate = rating
            visit.naturalTasteAppropriate = rating

        case .steak:
            visit.steakDoneness = Double.random(in: 6...9)
            visit.steakJuiciness = Double.random(in: 6...9)
            visit.steakTenderness = Double.random(in: 6...9)
            visit.steakSeasoning = Double.random(in: 6...9)
            visit.steakFlavor = Double.random(in: 7...9)
            visit.steakMarbling = Double.random(in: 6...9)

            visit.steakDonenessAppropriate = rating
            visit.steakJuicinessAppropriate = rating
            visit.steakTendernessAppropriate = rating
            visit.steakSeasoningAppropriate = rating
            visit.steakFlavorAppropriate = rating
            visit.steakMarblingAppropriate = rating

        case .sushi:
            visit.sushiShari = Double.random(in: 7...9)
            visit.sushiNeta = Double.random(in: 7...10)
            visit.sushiWasabi = Double.random(in: 5...8)
            visit.sushiBalance = Double.random(in: 7...9)
            visit.sushiGrip = Double.random(in: 6...9)
            visit.sushiTemperature = Double.random(in: 7...9)

            visit.sushiShariAppropriate = rating
            visit.sushiNetaAppropriate = rating
            visit.sushiWasabiAppropriate = rating
            visit.sushiBalanceAppropriate = rating
            visit.sushiGripAppropriate = rating
            visit.sushiTemperatureAppropriate = rating

        case .ramen:
            visit.ramenBroth = Double.random(in: 7...10)
            visit.ramenNoodle = Double.random(in: 7...9)
            visit.ramenChashu = Double.random(in: 6...9)
            visit.ramenTopping = Double.random(in: 6...8)
            visit.ramenTemperature = Double.random(in: 7...9)
            visit.ramenBalance = Double.random(in: 7...9)

            visit.ramenBrothAppropriate = rating
            visit.ramenNoodleAppropriate = rating
            visit.ramenChashuAppropriate = rating
            visit.ramenToppingAppropriate = rating
            visit.ramenTemperatureAppropriate = rating
            visit.ramenBalanceAppropriate = rating

        case .pizza:
            visit.pizzaDough = Double.random(in: 7...9)
            visit.pizzaSauce = Double.random(in: 7...9)
            visit.pizzaCheese = Double.random(in: 7...10)
            visit.pizzaBaking = Double.random(in: 7...9)
            visit.pizzaTopping = Double.random(in: 6...8)
            visit.pizzaBalance = Double.random(in: 7...9)

            visit.pizzaDoughAppropriate = rating
            visit.pizzaSauceAppropriate = rating
            visit.pizzaCheeseAppropriate = rating
            visit.pizzaBakingAppropriate = rating
            visit.pizzaToppingAppropriate = rating
            visit.pizzaBalanceAppropriate = rating

        case .wine:
            visit.wineBody = Double.random(in: 6...9)
            visit.wineTannin = Double.random(in: 5...8)
            visit.wineAcidity = Double.random(in: 6...9)
            visit.wineAroma = Double.random(in: 7...10)
            visit.wineFinish = Double.random(in: 7...9)
            visit.wineBalance = Double.random(in: 7...9)

            visit.wineBodyAppropriate = rating
            visit.wineTanninAppropriate = rating
            visit.wineAcidityAppropriate = rating
            visit.wineAromaAppropriate = rating
            visit.wineFinishAppropriate = rating
            visit.wineBalanceAppropriate = rating

        case .coffee:
            visit.coffeeAcidity = Double.random(in: 6...9)
            visit.coffeeBody = Double.random(in: 6...9)
            visit.coffeeFlavor = Double.random(in: 7...10)
            visit.coffeeAftertaste = Double.random(in: 7...9)
            visit.coffeeSweetness = Double.random(in: 5...8)
            visit.coffeeBalance = Double.random(in: 7...9)

            visit.coffeeAcidityAppropriate = rating
            visit.coffeeBodyAppropriate = rating
            visit.coffeeFlavorAppropriate = rating
            visit.coffeeAftertasteAppropriate = rating
            visit.coffeeSweetnessAppropriate = rating
            visit.coffeeBalanceAppropriate = rating
        }

        return visit
    }
}
