import Foundation

// MARK: - Firebase용 데이터 모델 (Codable)

/// Firebase에 저장되는 사용자 정보
struct FirebaseUser: Codable, Identifiable {
    var id: String // userId
    var createdAt: Date
    var tasteProfile: FirebaseTasteProfile?
}

/// 취향 프로필 (Firebase용)
struct FirebaseTasteProfile: Codable {
    var userId: String
    var spicy: Double
    var boldness: Double
    var sweetness: Double
    var saltiness: Double
    var richness: Double
    var naturalTaste: Double
    var texture: Double
    var cooking: Double

    // 벡터로 변환 (코사인 유사도 계산용)
    var asVector: [Double] {
        [spicy, boldness, sweetness, saltiness, richness, naturalTaste, texture, cooking]
    }
}

/// Firebase에 저장되는 식당 정보
struct FirebaseRestaurant: Codable, Identifiable {
    var id: String // restaurantId
    var userId: String // 등록한 사용자
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var category: String
    var foodCategory: String // FoodCategory rawValue
    var phoneNumber: String?
    var averageRating: Double
    var visitCount: Int
    var satisfactionScore: Double
    var createdAt: Date
    var isPublic: Bool // 다른 사용자에게 공개 여부
}

/// Firebase에 저장되는 방문 기록
struct FirebaseVisit: Codable, Identifiable {
    var id: String // visitId
    var restaurantId: String
    var userId: String
    var visitDate: Date
    var rating: Int
    var notes: String?

    // 일반 맛 평가 - 강도 (0-10)
    var spicy: Double?
    var boldness: Double?
    var sweetness: Double?
    var saltiness: Double?
    var richness: Double?
    var naturalTaste: Double?

    // 일반 맛 평가 - 적절함 (1-5)
    var spicyAppropriate: Int?
    var boldnessAppropriate: Int?
    var sweetnessAppropriate: Int?
    var saltinessAppropriate: Int?
    var richnessAppropriate: Int?
    var naturalTasteAppropriate: Int?

    // 스테이크 평가
    var steakDoneness: Double?
    var steakJuiciness: Double?
    var steakTenderness: Double?
    var steakSeasoning: Double?
    var steakFlavor: Double?
    var steakMarbling: Double?

    var steakDonenessAppropriate: Int?
    var steakJuicinessAppropriate: Int?
    var steakTendernessAppropriate: Int?
    var steakSeasoningAppropriate: Int?
    var steakFlavorAppropriate: Int?
    var steakMarblingAppropriate: Int?

    // 초밥 평가
    var sushiShari: Double?
    var sushiNeta: Double?
    var sushiWasabi: Double?
    var sushiBalance: Double?
    var sushiGrip: Double?
    var sushiTemperature: Double?

    var sushiShariAppropriate: Int?
    var sushiNetaAppropriate: Int?
    var sushiWasabiAppropriate: Int?
    var sushiBalanceAppropriate: Int?
    var sushiGripAppropriate: Int?
    var sushiTemperatureAppropriate: Int?

    // 라멘 평가
    var ramenBroth: Double?
    var ramenNoodle: Double?
    var ramenChashu: Double?
    var ramenTopping: Double?
    var ramenTemperature: Double?
    var ramenBalance: Double?

    var ramenBrothAppropriate: Int?
    var ramenNoodleAppropriate: Int?
    var ramenChashuAppropriate: Int?
    var ramenToppingAppropriate: Int?
    var ramenTemperatureAppropriate: Int?
    var ramenBalanceAppropriate: Int?

    // 피자 평가
    var pizzaDough: Double?
    var pizzaSauce: Double?
    var pizzaCheese: Double?
    var pizzaBaking: Double?
    var pizzaTopping: Double?
    var pizzaBalance: Double?

    var pizzaDoughAppropriate: Int?
    var pizzaSauceAppropriate: Int?
    var pizzaCheeseAppropriate: Int?
    var pizzaBakingAppropriate: Int?
    var pizzaToppingAppropriate: Int?
    var pizzaBalanceAppropriate: Int?

    // 와인 평가
    var wineBody: Double?
    var wineTannin: Double?
    var wineAcidity: Double?
    var wineAroma: Double?
    var wineFinish: Double?
    var wineBalance: Double?

    var wineBodyAppropriate: Int?
    var wineTanninAppropriate: Int?
    var wineAcidityAppropriate: Int?
    var wineAromaAppropriate: Int?
    var wineFinishAppropriate: Int?
    var wineBalanceAppropriate: Int?

    // 커피 평가
    var coffeeAcidity: Double?
    var coffeeBody: Double?
    var coffeeFlavor: Double?
    var coffeeAftertaste: Double?
    var coffeeSweetness: Double?
    var coffeeBalance: Double?

    var coffeeAcidityAppropriate: Int?
    var coffeeBodyAppropriate: Int?
    var coffeeFlavorAppropriate: Int?
    var coffeeAftertasteAppropriate: Int?
    var coffeeSweetnessAppropriate: Int?
    var coffeeBalanceAppropriate: Int?

    var isPublic: Bool // 공개 여부

    /// 카테고리별 강도 벡터 추출
    func intensityVector(for category: FoodCategory) -> [Double] {
        switch category {
        case .general:
            return [
                spicy ?? 5.0,
                boldness ?? 5.0,
                sweetness ?? 5.0,
                saltiness ?? 5.0,
                richness ?? 5.0,
                naturalTaste ?? 5.0
            ]
        case .steak:
            return [
                steakDoneness ?? 5.0,
                steakJuiciness ?? 5.0,
                steakTenderness ?? 5.0,
                steakSeasoning ?? 5.0,
                steakFlavor ?? 5.0,
                steakMarbling ?? 5.0
            ]
        case .sushi:
            return [
                sushiShari ?? 5.0,
                sushiNeta ?? 5.0,
                sushiWasabi ?? 5.0,
                sushiBalance ?? 5.0,
                sushiGrip ?? 5.0,
                sushiTemperature ?? 5.0
            ]
        case .ramen:
            return [
                ramenBroth ?? 5.0,
                ramenNoodle ?? 5.0,
                ramenChashu ?? 5.0,
                ramenTopping ?? 5.0,
                ramenTemperature ?? 5.0,
                ramenBalance ?? 5.0
            ]
        case .pizza:
            return [
                pizzaDough ?? 5.0,
                pizzaSauce ?? 5.0,
                pizzaCheese ?? 5.0,
                pizzaBaking ?? 5.0,
                pizzaTopping ?? 5.0,
                pizzaBalance ?? 5.0
            ]
        case .wine:
            return [
                wineBody ?? 5.0,
                wineTannin ?? 5.0,
                wineAcidity ?? 5.0,
                wineAroma ?? 5.0,
                wineFinish ?? 5.0,
                wineBalance ?? 5.0
            ]
        case .coffee:
            return [
                coffeeAcidity ?? 5.0,
                coffeeBody ?? 5.0,
                coffeeFlavor ?? 5.0,
                coffeeAftertaste ?? 5.0,
                coffeeSweetness ?? 5.0,
                coffeeBalance ?? 5.0
            ]
        }
    }
}

// MARK: - Mapper Extensions (SwiftData ↔ Firebase)

extension TasteProfile {
    func toFirebase(userId: String) -> FirebaseTasteProfile {
        FirebaseTasteProfile(
            userId: userId,
            spicy: spicy,
            boldness: boldness,
            sweetness: sweetness,
            saltiness: saltiness,
            richness: richness,
            naturalTaste: naturalTaste,
            texture: texture,
            cooking: cooking
        )
    }
}

extension Restaurant {
    func toFirebase(userId: String, isPublic: Bool = true) -> FirebaseRestaurant {
        FirebaseRestaurant(
            id: UUID().uuidString,
            userId: userId,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            category: category,
            foodCategory: foodCategoryRaw,
            phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
            averageRating: averageRating,
            visitCount: visitCount,
            satisfactionScore: satisfactionScore,
            createdAt: Date(),
            isPublic: isPublic
        )
    }
}

extension Visit {
    func toFirebase(restaurantId: String, userId: String, isPublic: Bool = true) -> FirebaseVisit {
        FirebaseVisit(
            id: UUID().uuidString,
            restaurantId: restaurantId,
            userId: userId,
            visitDate: visitDate,
            rating: rating,
            notes: notes.isEmpty ? nil : notes,
            spicy: spicy,
            boldness: boldness,
            sweetness: sweetness,
            saltiness: saltiness,
            richness: richness,
            naturalTaste: naturalTaste,
            spicyAppropriate: spicyAppropriate,
            boldnessAppropriate: boldnessAppropriate,
            sweetnessAppropriate: sweetnessAppropriate,
            saltinessAppropriate: saltinessAppropriate,
            richnessAppropriate: richnessAppropriate,
            naturalTasteAppropriate: naturalTasteAppropriate,
            steakDoneness: steakDoneness,
            steakJuiciness: steakJuiciness,
            steakTenderness: steakTenderness,
            steakSeasoning: steakSeasoning,
            steakFlavor: steakFlavor,
            steakMarbling: steakMarbling,
            steakDonenessAppropriate: steakDonenessAppropriate,
            steakJuicinessAppropriate: steakJuicinessAppropriate,
            steakTendernessAppropriate: steakTendernessAppropriate,
            steakSeasoningAppropriate: steakSeasoningAppropriate,
            steakFlavorAppropriate: steakFlavorAppropriate,
            steakMarblingAppropriate: steakMarblingAppropriate,
            sushiShari: sushiShari,
            sushiNeta: sushiNeta,
            sushiWasabi: sushiWasabi,
            sushiBalance: sushiBalance,
            sushiGrip: sushiGrip,
            sushiTemperature: sushiTemperature,
            sushiShariAppropriate: sushiShariAppropriate,
            sushiNetaAppropriate: sushiNetaAppropriate,
            sushiWasabiAppropriate: sushiWasabiAppropriate,
            sushiBalanceAppropriate: sushiBalanceAppropriate,
            sushiGripAppropriate: sushiGripAppropriate,
            sushiTemperatureAppropriate: sushiTemperatureAppropriate,
            ramenBroth: ramenBroth,
            ramenNoodle: ramenNoodle,
            ramenChashu: ramenChashu,
            ramenTopping: ramenTopping,
            ramenTemperature: ramenTemperature,
            ramenBalance: ramenBalance,
            ramenBrothAppropriate: ramenBrothAppropriate,
            ramenNoodleAppropriate: ramenNoodleAppropriate,
            ramenChashuAppropriate: ramenChashuAppropriate,
            ramenToppingAppropriate: ramenToppingAppropriate,
            ramenTemperatureAppropriate: ramenTemperatureAppropriate,
            ramenBalanceAppropriate: ramenBalanceAppropriate,
            pizzaDough: pizzaDough,
            pizzaSauce: pizzaSauce,
            pizzaCheese: pizzaCheese,
            pizzaBaking: pizzaBaking,
            pizzaTopping: pizzaTopping,
            pizzaBalance: pizzaBalance,
            pizzaDoughAppropriate: pizzaDoughAppropriate,
            pizzaSauceAppropriate: pizzaSauceAppropriate,
            pizzaCheeseAppropriate: pizzaCheeseAppropriate,
            pizzaBakingAppropriate: pizzaBakingAppropriate,
            pizzaToppingAppropriate: pizzaToppingAppropriate,
            pizzaBalanceAppropriate: pizzaBalanceAppropriate,
            wineBody: wineBody,
            wineTannin: wineTannin,
            wineAcidity: wineAcidity,
            wineAroma: wineAroma,
            wineFinish: wineFinish,
            wineBalance: wineBalance,
            wineBodyAppropriate: wineBodyAppropriate,
            wineTanninAppropriate: wineTanninAppropriate,
            wineAcidityAppropriate: wineAcidityAppropriate,
            wineAromaAppropriate: wineAromaAppropriate,
            wineFinishAppropriate: wineFinishAppropriate,
            wineBalanceAppropriate: wineBalanceAppropriate,
            coffeeAcidity: coffeeAcidity,
            coffeeBody: coffeeBody,
            coffeeFlavor: coffeeFlavor,
            coffeeAftertaste: coffeeAftertaste,
            coffeeSweetness: coffeeSweetness,
            coffeeBalance: coffeeBalance,
            coffeeAcidityAppropriate: coffeeAcidityAppropriate,
            coffeeBodyAppropriate: coffeeBodyAppropriate,
            coffeeFlavorAppropriate: coffeeFlavorAppropriate,
            coffeeAftertasteAppropriate: coffeeAftertasteAppropriate,
            coffeeSweetnessAppropriate: coffeeSweetnessAppropriate,
            coffeeBalanceAppropriate: coffeeBalanceAppropriate,
            isPublic: isPublic
        )
    }
}
