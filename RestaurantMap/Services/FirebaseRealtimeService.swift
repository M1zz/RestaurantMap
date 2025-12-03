import Foundation
import FirebaseDatabase
import FirebaseAuth
import OSLog

/// Firebase Realtime Database와 통신하는 서비스 클래스
@MainActor
class FirebaseRealtimeService: ObservableObject {
    static let shared = FirebaseRealtimeService()

    private let db = Database.database().reference()
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

        logger.info("FirebaseRealtimeService initialized")
    }

    // MARK: - Authentication

    /// 익명 로그인 (자동)
    func signInAnonymously() async throws {
        logger.info("🔐 Attempting anonymous sign in...")

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

    // MARK: - Upload Methods

    /// 내 취향 프로필을 Firebase에 업로드
    func uploadTasteProfile(_ profile: TasteProfile) async throws {
        logger.info("📤 Uploading taste profile...")

        let profileData: [String: Any] = [
            "userId": currentUserId,
            "spicy": profile.spicy,
            "boldness": profile.boldness,
            "sweetness": profile.sweetness,
            "saltiness": profile.saltiness,
            "richness": profile.richness,
            "naturalTaste": profile.naturalTaste,
            "texture": profile.texture,
            "cooking": profile.cooking,
            "updatedAt": ServerValue.timestamp()
        ]

        try await db.child("users").child(currentUserId).child("tasteProfile").setValue(profileData)
        logger.info("✅ Taste profile uploaded")
    }

    /// 식당 정보를 Firebase에 업로드
    func uploadRestaurant(_ restaurant: Restaurant, isPublic: Bool = true) async throws {
        let restaurantId = restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? UUID().uuidString

        let restaurantData: [String: Any] = [
            "id": restaurantId,
            "userId": currentUserId,
            "name": restaurant.name,
            "address": restaurant.address,
            "latitude": restaurant.latitude,
            "longitude": restaurant.longitude,
            "category": restaurant.category,
            "foodCategory": restaurant.foodCategoryRaw,
            "phoneNumber": restaurant.phoneNumber,
            "averageRating": restaurant.averageRating,
            "visitCount": restaurant.visitCount,
            "satisfactionScore": restaurant.satisfactionScore,
            "isPublic": isPublic,
            "createdAt": ServerValue.timestamp()
        ]

        try await db.child("restaurants").child(restaurantId).setValue(restaurantData)
        logger.info("✅ Restaurant '\(restaurant.name)' uploaded")

        // 방문 기록도 함께 업로드
        if let visits = restaurant.visits {
            for visit in visits {
                try await uploadVisit(visit, restaurantId: restaurantId, isPublic: isPublic)
            }
        }
    }

    /// 방문 기록을 Firebase에 업로드
    func uploadVisit(_ visit: Visit, restaurantId: String, isPublic: Bool = true) async throws {
        let visitId = UUID().uuidString

        var visitData: [String: Any] = [
            "id": visitId,
            "restaurantId": restaurantId,
            "userId": currentUserId,
            "visitDate": visit.visitDate.timeIntervalSince1970,
            "rating": visit.rating,
            "notes": visit.notes,
            "isPublic": isPublic
        ]

        // 맛 평가 데이터 추가
        if let spicy = visit.spicy { visitData["spicy"] = spicy }
        if let boldness = visit.boldness { visitData["boldness"] = boldness }
        if let sweetness = visit.sweetness { visitData["sweetness"] = sweetness }
        if let saltiness = visit.saltiness { visitData["saltiness"] = saltiness }
        if let richness = visit.richness { visitData["richness"] = richness }
        if let naturalTaste = visit.naturalTaste { visitData["naturalTaste"] = naturalTaste }

        // 적절함 평가 추가
        if let spicyApp = visit.spicyAppropriate { visitData["spicyAppropriate"] = spicyApp }
        if let boldnessApp = visit.boldnessAppropriate { visitData["boldnessAppropriate"] = boldnessApp }
        if let sweetnessApp = visit.sweetnessAppropriate { visitData["sweetnessAppropriate"] = sweetnessApp }
        if let saltinessApp = visit.saltinessAppropriate { visitData["saltinessAppropriate"] = saltinessApp }
        if let richnessApp = visit.richnessAppropriate { visitData["richnessAppropriate"] = richnessApp }
        if let naturalTasteApp = visit.naturalTasteAppropriate { visitData["naturalTasteAppropriate"] = naturalTasteApp }

        // 스테이크 평가
        if let doneness = visit.steakDoneness { visitData["steakDoneness"] = doneness }
        if let juiciness = visit.steakJuiciness { visitData["steakJuiciness"] = juiciness }
        if let tenderness = visit.steakTenderness { visitData["steakTenderness"] = tenderness }
        if let seasoning = visit.steakSeasoning { visitData["steakSeasoning"] = seasoning }
        if let flavor = visit.steakFlavor { visitData["steakFlavor"] = flavor }
        if let marbling = visit.steakMarbling { visitData["steakMarbling"] = marbling }

        if let donenessApp = visit.steakDonenessAppropriate { visitData["steakDonenessAppropriate"] = donenessApp }
        if let juicinessApp = visit.steakJuicinessAppropriate { visitData["steakJuicinessAppropriate"] = juicinessApp }
        if let tendernessApp = visit.steakTendernessAppropriate { visitData["steakTendernessAppropriate"] = tendernessApp }
        if let seasoningApp = visit.steakSeasoningAppropriate { visitData["steakSeasoningAppropriate"] = seasoningApp }
        if let flavorApp = visit.steakFlavorAppropriate { visitData["steakFlavorAppropriate"] = flavorApp }
        if let marblingApp = visit.steakMarblingAppropriate { visitData["steakMarblingAppropriate"] = marblingApp }

        // 스시 평가 (생략 가능 - 필요시 추가)
        // 라멘 평가 (생략 가능 - 필요시 추가)
        // 피자 평가 (생략 가능 - 필요시 추가)
        // 와인 평가 (생략 가능 - 필요시 추가)
        // 커피 평가 (생략 가능 - 필요시 추가)

        try await db.child("visits").child(visitId).setValue(visitData)
        logger.info("✅ Visit uploaded")
    }

    /// 내 모든 데이터를 Firebase에 동기화
    func syncAllData(tasteProfile: TasteProfile?, restaurants: [Restaurant]) async throws {
        logger.info("🔄 Starting full sync...")

        // 1. 취향 프로필 업로드
        if let profile = tasteProfile {
            try await uploadTasteProfile(profile)
        }

        // 2. 식당 & 방문 기록 업로드
        for restaurant in restaurants {
            try await uploadRestaurant(restaurant, isPublic: true)
        }

        logger.info("✅ Full sync completed")
    }

    // MARK: - Fetch Methods

    /// 모든 공개된 사용자들의 취향 프로필 가져오기
    func fetchAllTasteProfiles() async throws -> [FirebaseTasteProfile] {
        logger.info("📥 Fetching all taste profiles...")

        let snapshot = try await db.child("users").getData()

        guard let usersDict = snapshot.value as? [String: Any] else {
            logger.warning("No users found")
            return []
        }

        var profiles: [FirebaseTasteProfile] = []

        for (userId, userData) in usersDict {
            guard let userDict = userData as? [String: Any],
                  let profileDict = userDict["tasteProfile"] as? [String: Any] else {
                continue
            }

            let profile = FirebaseTasteProfile(
                userId: userId,
                spicy: profileDict["spicy"] as? Double ?? 5.0,
                boldness: profileDict["boldness"] as? Double ?? 5.0,
                sweetness: profileDict["sweetness"] as? Double ?? 5.0,
                saltiness: profileDict["saltiness"] as? Double ?? 5.0,
                richness: profileDict["richness"] as? Double ?? 5.0,
                naturalTaste: profileDict["naturalTaste"] as? Double ?? 5.0,
                texture: profileDict["texture"] as? Double ?? 5.0,
                cooking: profileDict["cooking"] as? Double ?? 5.0
            )

            profiles.append(profile)
        }

        logger.info("📥 Fetched \(profiles.count) taste profiles")
        return profiles
    }

    /// 모든 공개된 식당 정보 가져오기
    func fetchAllRestaurants() async throws -> [FirebaseRestaurant] {
        logger.info("📥 Fetching all restaurants...")

        let snapshot = try await db.child("restaurants")
            .queryOrdered(byChild: "isPublic")
            .queryEqual(toValue: true)
            .getData()

        guard let restaurantsDict = snapshot.value as? [String: Any] else {
            logger.warning("No restaurants found")
            return []
        }

        var restaurants: [FirebaseRestaurant] = []

        for (_, restaurantData) in restaurantsDict {
            guard let dict = restaurantData as? [String: Any],
                  let id = dict["id"] as? String,
                  let name = dict["name"] as? String else {
                continue
            }

            let restaurant = FirebaseRestaurant(
                id: id,
                userId: dict["userId"] as? String ?? "",
                name: name,
                address: dict["address"] as? String ?? "",
                latitude: dict["latitude"] as? Double ?? 0,
                longitude: dict["longitude"] as? Double ?? 0,
                category: dict["category"] as? String ?? "",
                foodCategory: dict["foodCategory"] as? String ?? "일반",
                phoneNumber: dict["phoneNumber"] as? String,
                averageRating: dict["averageRating"] as? Double ?? 0,
                visitCount: dict["visitCount"] as? Int ?? 0,
                satisfactionScore: dict["satisfactionScore"] as? Double ?? 0,
                createdAt: Date(timeIntervalSince1970: dict["createdAt"] as? TimeInterval ?? 0),
                isPublic: dict["isPublic"] as? Bool ?? false
            )

            restaurants.append(restaurant)
        }

        logger.info("📥 Fetched \(restaurants.count) restaurants")
        return restaurants
    }

    /// 특정 카테고리의 식당들 가져오기
    func fetchRestaurants(category: FoodCategory) async throws -> [FirebaseRestaurant] {
        logger.info("📥 Fetching \(category.rawValue) restaurants...")

        let snapshot = try await db.child("restaurants")
            .queryOrdered(byChild: "foodCategory")
            .queryEqual(toValue: category.rawValue)
            .getData()

        guard let restaurantsDict = snapshot.value as? [String: Any] else {
            logger.warning("No restaurants found for category")
            return []
        }

        var restaurants: [FirebaseRestaurant] = []

        for (_, restaurantData) in restaurantsDict {
            guard let dict = restaurantData as? [String: Any],
                  let isPublic = dict["isPublic"] as? Bool,
                  isPublic,
                  let id = dict["id"] as? String,
                  let name = dict["name"] as? String else {
                continue
            }

            let restaurant = FirebaseRestaurant(
                id: id,
                userId: dict["userId"] as? String ?? "",
                name: name,
                address: dict["address"] as? String ?? "",
                latitude: dict["latitude"] as? Double ?? 0,
                longitude: dict["longitude"] as? Double ?? 0,
                category: dict["category"] as? String ?? "",
                foodCategory: dict["foodCategory"] as? String ?? "일반",
                phoneNumber: dict["phoneNumber"] as? String,
                averageRating: dict["averageRating"] as? Double ?? 0,
                visitCount: dict["visitCount"] as? Int ?? 0,
                satisfactionScore: dict["satisfactionScore"] as? Double ?? 0,
                createdAt: Date(timeIntervalSince1970: dict["createdAt"] as? TimeInterval ?? 0),
                isPublic: isPublic
            )

            restaurants.append(restaurant)
        }

        logger.info("📥 Fetched \(restaurants.count) \(category.rawValue) restaurants")
        return restaurants
    }

    /// 특정 식당의 모든 방문 기록 가져오기
    func fetchVisits(for restaurantId: String) async throws -> [FirebaseVisit] {
        logger.info("📥 Fetching visits for restaurant \(restaurantId)...")

        let snapshot = try await db.child("visits")
            .queryOrdered(byChild: "restaurantId")
            .queryEqual(toValue: restaurantId)
            .getData()

        guard let visitsDict = snapshot.value as? [String: Any] else {
            return []
        }

        return parseVisits(from: visitsDict)
    }

    /// 특정 사용자의 모든 방문 기록 가져오기
    func fetchVisits(for userId: String, limit: Int = 100) async throws -> [FirebaseVisit] {
        logger.info("📥 Fetching visits for user \(userId)...")

        let snapshot = try await db.child("visits")
            .queryOrdered(byChild: "userId")
            .queryEqual(toValue: userId)
            .queryLimited(toFirst: UInt(limit))
            .getData()

        guard let visitsDict = snapshot.value as? [String: Any] else {
            return []
        }

        return parseVisits(from: visitsDict)
    }

    // MARK: - Helper Methods

    private func parseVisits(from dict: [String: Any]) -> [FirebaseVisit] {
        var visits: [FirebaseVisit] = []

        for (_, visitData) in dict {
            guard let visitDict = visitData as? [String: Any],
                  let id = visitDict["id"] as? String,
                  let restaurantId = visitDict["restaurantId"] as? String,
                  let userId = visitDict["userId"] as? String else {
                continue
            }

            var visit = FirebaseVisit(
                id: id,
                restaurantId: restaurantId,
                userId: userId,
                visitDate: Date(timeIntervalSince1970: visitDict["visitDate"] as? TimeInterval ?? 0),
                rating: visitDict["rating"] as? Int ?? 3,
                notes: visitDict["notes"] as? String,
                isPublic: visitDict["isPublic"] as? Bool ?? false
            )

            // 맛 평가 데이터
            visit.spicy = visitDict["spicy"] as? Double
            visit.boldness = visitDict["boldness"] as? Double
            visit.sweetness = visitDict["sweetness"] as? Double
            visit.saltiness = visitDict["saltiness"] as? Double
            visit.richness = visitDict["richness"] as? Double
            visit.naturalTaste = visitDict["naturalTaste"] as? Double

            visit.spicyAppropriate = visitDict["spicyAppropriate"] as? Int
            visit.boldnessAppropriate = visitDict["boldnessAppropriate"] as? Int
            visit.sweetnessAppropriate = visitDict["sweetnessAppropriate"] as? Int
            visit.saltinessAppropriate = visitDict["saltinessAppropriate"] as? Int
            visit.richnessAppropriate = visitDict["richnessAppropriate"] as? Int
            visit.naturalTasteAppropriate = visitDict["naturalTasteAppropriate"] as? Int

            // 스테이크
            visit.steakDoneness = visitDict["steakDoneness"] as? Double
            visit.steakJuiciness = visitDict["steakJuiciness"] as? Double
            visit.steakTenderness = visitDict["steakTenderness"] as? Double

            visits.append(visit)
        }

        logger.info("📥 Parsed \(visits.count) visits")
        return visits
    }

    // MARK: - Dummy Data Generation

    /// 테스트용 더미 데이터 생성
    func generateDummyData() async throws {
        logger.info("🧪 Generating dummy data...")

        // 더미 사용자 5명
        let dummyUsers: [(userId: String, profile: [String: Any])] = [
            ("dummy_user_1", [
                "userId": "dummy_user_1",
                "spicy": 8.5, "boldness": 8.0, "sweetness": 4.0,
                "saltiness": 7.0, "richness": 7.5, "naturalTaste": 5.0,
                "texture": 6.0, "cooking": 7.0
            ]),
            ("dummy_user_2", [
                "userId": "dummy_user_2",
                "spicy": 3.0, "boldness": 4.5, "sweetness": 8.0,
                "saltiness": 5.0, "richness": 6.0, "naturalTaste": 7.5,
                "texture": 7.0, "cooking": 6.0
            ]),
            ("dummy_user_3", [
                "userId": "dummy_user_3",
                "spicy": 5.5, "boldness": 6.0, "sweetness": 6.0,
                "saltiness": 6.0, "richness": 5.5, "naturalTaste": 7.0,
                "texture": 6.5, "cooking": 6.5
            ]),
            ("dummy_user_4", [
                "userId": "dummy_user_4",
                "spicy": 4.0, "boldness": 5.5, "sweetness": 4.5,
                "saltiness": 8.0, "richness": 5.0, "naturalTaste": 9.0,
                "texture": 7.5, "cooking": 8.0
            ]),
            ("dummy_user_5", [
                "userId": "dummy_user_5",
                "spicy": 7.0, "boldness": 9.0, "sweetness": 5.0,
                "saltiness": 7.5, "richness": 9.0, "naturalTaste": 4.0,
                "texture": 5.5, "cooking": 6.0
            ])
        ]

        for (userId, profileData) in dummyUsers {
            // 취향 프로필 업로드
            try await db.child("users").child(userId).child("tasteProfile").setValue(profileData)

            // 각 사용자당 3-4개 식당 생성
            let restaurantCount = Int.random(in: 3...4)
            for i in 0..<restaurantCount {
                let restaurantId = "rest_\(userId)_\(i)"
                let restaurantData: [String: Any] = [
                    "id": restaurantId,
                    "userId": userId,
                    "name": "테스트 식당 \(userId)_\(i)",
                    "address": "서울시 강남구",
                    "latitude": 37.5665 + Double.random(in: -0.01...0.01),
                    "longitude": 126.9780 + Double.random(in: -0.01...0.01),
                    "category": ["스테이크", "스시", "라멘", "피자"].randomElement()!,
                    "foodCategory": ["스테이크", "초밥", "라멘", "피자"].randomElement()!,
                    "phoneNumber": "02-1234-5678",
                    "averageRating": Double.random(in: 3.5...5.0),
                    "visitCount": Int.random(in: 1...5),
                    "satisfactionScore": Double.random(in: 70...95),
                    "isPublic": true,
                    "createdAt": ServerValue.timestamp()
                ]

                try await db.child("restaurants").child(restaurantId).setValue(restaurantData)

                // 방문 기록 1-3개 생성
                let visitCount = Int.random(in: 1...3)
                for j in 0..<visitCount {
                    let visitId = "visit_\(restaurantId)_\(j)"
                    let visitData: [String: Any] = [
                        "id": visitId,
                        "restaurantId": restaurantId,
                        "userId": userId,
                        "visitDate": Date().addingTimeInterval(-Double.random(in: 0...86400*60)).timeIntervalSince1970,
                        "rating": Int.random(in: 3...5),
                        "notes": "맛있었어요!",
                        "spicy": Double.random(in: 5...9),
                        "boldness": Double.random(in: 5...9),
                        "sweetness": Double.random(in: 5...9),
                        "saltiness": Double.random(in: 5...9),
                        "richness": Double.random(in: 5...9),
                        "naturalTaste": Double.random(in: 5...9),
                        "isPublic": true
                    ]

                    try await db.child("visits").child(visitId).setValue(visitData)
                }
            }

            logger.info("✅ Created dummy user: \(userId)")
        }

        logger.info("✅ Dummy data generation completed!")
    }
}
