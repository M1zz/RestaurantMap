import Foundation
import SwiftData
import MapKit

// 식당 목록 타입
enum RestaurantListType: String, Codable, CaseIterable {
    case visited = "가본 곳"        // 실제로 방문한 식당
    case wishlist = "가볼 곳"       // 가보고 싶은 식당 (위시리스트)
    case michelin = "미슐랭"        // 최고의 식당 (Top 6)

    // rawValue 는 저장·비교용 식별자라 그대로 두고, 화면 표시만 현지화한다.
    var displayName: String {
        switch self {
        case .visited: return String(localized: "가본 곳")
        case .wishlist: return String(localized: "가볼 곳")
        case .michelin: return String(localized: "미슐랭")
        }
    }

    var icon: String {
        switch self {
        case .visited: return "checkmark.circle.fill"
        case .wishlist: return "star.circle.fill"
        case .michelin: return "crown.fill"
        }
    }
}

@Model
final class Restaurant {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var notes: String
    var rating: Int
    var visitDate: Date
    var category: String
    var phoneNumber: String
    var isTop6: Bool
    var top6Rank: Int?
    var categoryIcon: String
    var foodCategoryId: String = FoodCategoryRepository.builtInCategories[0].id.uuidString
    var isWishlist: Bool = false  // 가볼 곳 여부 (Boolean은 마이그레이션이 안전함)

    // 방문 기록들
    @Relationship(deleteRule: .cascade, inverse: \Visit.restaurant)
    var visits: [Visit]?

    // 메뉴들
    @Relationship(deleteRule: .cascade, inverse: \MenuItem.restaurant)
    var menus: [MenuItem]?

    // FoodCategory 편의 속성
    var foodCategory: FoodCategory {
        get {
            guard let uuid = UUID(uuidString: foodCategoryId),
                  let category = FoodCategoryRepository.shared.findCategory(by: uuid) else {
                return FoodCategoryRepository.builtInCategories[0] // 일반
            }
            return category
        }
        set {
            foodCategoryId = newValue.id.uuidString
        }
    }

    // evaluationType은 foodCategory를 통해 접근
    var evaluationType: EvaluationType {
        foodCategory.evaluationType
    }

    // RestaurantListType 편의 속성
    var listType: RestaurantListType {
        get {
            // Top6이면 미슐랭
            if isTop6 {
                return .michelin
            }
            // 위시리스트면 가볼 곳
            if isWishlist {
                return .wishlist
            }
            // 기본값: 가본 곳
            return .visited
        }
        set {
            // 미슐랭으로 설정
            if newValue == .michelin {
                isTop6 = true
                isWishlist = false
            }
            // 가볼 곳으로 설정
            else if newValue == .wishlist {
                isTop6 = false
                isWishlist = true
            }
            // 가본 곳으로 설정
            else {
                isTop6 = false
                isWishlist = false
            }
        }
    }

    init(name: String, address: String, latitude: Double, longitude: Double, notes: String = "", rating: Int = 0, visitDate: Date = Date(), category: String = "", phoneNumber: String = "", isTop6: Bool = false, top6Rank: Int? = nil, categoryIcon: String = "fork.knife", foodCategory: FoodCategory = FoodCategoryRepository.builtInCategories[0], listType: RestaurantListType = .visited) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
        self.rating = rating
        self.visitDate = visitDate
        self.category = category
        self.phoneNumber = phoneNumber
        self.isTop6 = isTop6
        self.top6Rank = top6Rank
        self.categoryIcon = categoryIcon
        self.foodCategoryId = foodCategory.id.uuidString

        // listType에 따라 isWishlist 설정
        self.isWishlist = (listType == .wishlist)

        self.visits = []
        self.menus = []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // 방문 횟수
    var visitCount: Int {
        visits?.count ?? 0
    }

    // 최근 방문일
    var lastVisitDate: Date? {
        visits?.sorted(by: { $0.visitDate > $1.visitDate }).first?.visitDate
    }

    // 평균 별점
    var averageRating: Double {
        guard let visits = visits, !visits.isEmpty else { return Double(rating) }
        let sum = visits.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(visits.count)
    }

    // 총평 - 평균 맛 강도 (카테고리별로 다른 데이터 반환)
    var averageIntensity: [(String, Double)] {
        guard let visits = visits, !visits.isEmpty else { return [] }

        let validVisits = visits.filter { $0.hasTasteProfile }
        guard !validVisits.isEmpty else { return [] }

        switch evaluationType {
        case .general:
            let avgSpicy = validVisits.compactMap { $0.spicy }.average
            let avgBoldness = validVisits.compactMap { $0.boldness }.average
            let avgSweetness = validVisits.compactMap { $0.sweetness }.average
            let avgSaltiness = validVisits.compactMap { $0.saltiness }.average
            let avgRichness = validVisits.compactMap { $0.richness }.average
            let avgNaturalTaste = validVisits.compactMap { $0.naturalTaste }.average

            return [
                (String(localized: "맵기"), avgSpicy),
                (String(localized: "진한맛"), avgBoldness),
                (String(localized: "단맛"), avgSweetness),
                (String(localized: "짠맛"), avgSaltiness),
                (String(localized: "기름진"), avgRichness),
                (String(localized: "본연의맛"), avgNaturalTaste)
            ]

        case .steak:
            let avgDoneness = validVisits.compactMap { $0.steakDoneness }.average
            let avgJuiciness = validVisits.compactMap { $0.steakJuiciness }.average
            let avgTenderness = validVisits.compactMap { $0.steakTenderness }.average
            let avgSeasoning = validVisits.compactMap { $0.steakSeasoning }.average
            let avgFlavor = validVisits.compactMap { $0.steakFlavor }.average
            let avgMarbling = validVisits.compactMap { $0.steakMarbling }.average

            return [
                (String(localized: "굽기"), avgDoneness),
                (String(localized: "육즙"), avgJuiciness),
                (String(localized: "부드러움"), avgTenderness),
                (String(localized: "간"), avgSeasoning),
                (String(localized: "육향"), avgFlavor),
                (String(localized: "마블링"), avgMarbling)
            ]

        case .sushi:
            return [
                (String(localized: "샤리(밥)"), validVisits.compactMap { $0.sushiShari }.average),
                (String(localized: "네타(재료)"), validVisits.compactMap { $0.sushiNeta }.average),
                (String(localized: "와사비"), validVisits.compactMap { $0.sushiWasabi }.average),
                (String(localized: "밸런스"), validVisits.compactMap { $0.sushiBalance }.average),
                (String(localized: "쥐기"), validVisits.compactMap { $0.sushiGrip }.average),
                (String(localized: "온도"), validVisits.compactMap { $0.sushiTemperature }.average)
            ]

        case .ramen:
            return [
                (String(localized: "국물"), validVisits.compactMap { $0.ramenBroth }.average),
                (String(localized: "면발"), validVisits.compactMap { $0.ramenNoodle }.average),
                (String(localized: "차슈"), validVisits.compactMap { $0.ramenChashu }.average),
                (String(localized: "토핑"), validVisits.compactMap { $0.ramenTopping }.average),
                (String(localized: "온도"), validVisits.compactMap { $0.ramenTemperature }.average),
                (String(localized: "밸런스"), validVisits.compactMap { $0.ramenBalance }.average)
            ]

        case .pizza:
            return [
                (String(localized: "도우"), validVisits.compactMap { $0.pizzaDough }.average),
                (String(localized: "소스"), validVisits.compactMap { $0.pizzaSauce }.average),
                (String(localized: "치즈"), validVisits.compactMap { $0.pizzaCheese }.average),
                (String(localized: "굽기"), validVisits.compactMap { $0.pizzaBaking }.average),
                (String(localized: "토핑"), validVisits.compactMap { $0.pizzaTopping }.average),
                (String(localized: "밸런스"), validVisits.compactMap { $0.pizzaBalance }.average)
            ]

        case .wine:
            return [
                (String(localized: "바디"), validVisits.compactMap { $0.wineBody }.average),
                (String(localized: "타닌"), validVisits.compactMap { $0.wineTannin }.average),
                (String(localized: "산도"), validVisits.compactMap { $0.wineAcidity }.average),
                (String(localized: "아로마"), validVisits.compactMap { $0.wineAroma }.average),
                (String(localized: "피니시"), validVisits.compactMap { $0.wineFinish }.average),
                (String(localized: "밸런스"), validVisits.compactMap { $0.wineBalance }.average)
            ]

        case .coffee:
            return [
                (String(localized: "산미"), validVisits.compactMap { $0.coffeeAcidity }.average),
                (String(localized: "바디"), validVisits.compactMap { $0.coffeeBody }.average),
                (String(localized: "향미"), validVisits.compactMap { $0.coffeeFlavor }.average),
                (String(localized: "후미"), validVisits.compactMap { $0.coffeeAftertaste }.average),
                (String(localized: "단맛"), validVisits.compactMap { $0.coffeeSweetness }.average),
                (String(localized: "밸런스"), validVisits.compactMap { $0.coffeeBalance }.average)
            ]
        }
    }

    // 총평 - 평균 적절함 (카테고리별로 다른 데이터 반환)
    var averageAppropriateness: [(String, Double)] {
        guard let visits = visits, !visits.isEmpty else { return [] }

        let validVisits = visits.filter { $0.hasTasteProfile }
        guard !validVisits.isEmpty else { return [] }

        switch evaluationType {
        case .general:
            let avgSpicy = validVisits.compactMap { $0.spicyAppropriate }.map { Double($0) }.average * 2
            let avgBoldness = validVisits.compactMap { $0.boldnessAppropriate }.map { Double($0) }.average * 2
            let avgSweetness = validVisits.compactMap { $0.sweetnessAppropriate }.map { Double($0) }.average * 2
            let avgSaltiness = validVisits.compactMap { $0.saltinessAppropriate }.map { Double($0) }.average * 2
            let avgRichness = validVisits.compactMap { $0.richnessAppropriate }.map { Double($0) }.average * 2
            let avgNaturalTaste = validVisits.compactMap { $0.naturalTasteAppropriate }.map { Double($0) }.average * 2

            return [
                (String(localized: "맵기"), avgSpicy),
                (String(localized: "진한맛"), avgBoldness),
                (String(localized: "단맛"), avgSweetness),
                (String(localized: "짠맛"), avgSaltiness),
                (String(localized: "기름진"), avgRichness),
                (String(localized: "본연의맛"), avgNaturalTaste)
            ]

        case .steak:
            let avgDoneness = validVisits.compactMap { $0.steakDonenessAppropriate }.map { Double($0) }.average * 2
            let avgJuiciness = validVisits.compactMap { $0.steakJuicinessAppropriate }.map { Double($0) }.average * 2
            let avgTenderness = validVisits.compactMap { $0.steakTendernessAppropriate }.map { Double($0) }.average * 2
            let avgSeasoning = validVisits.compactMap { $0.steakSeasoningAppropriate }.map { Double($0) }.average * 2
            let avgFlavor = validVisits.compactMap { $0.steakFlavorAppropriate }.map { Double($0) }.average * 2
            let avgMarbling = validVisits.compactMap { $0.steakMarblingAppropriate }.map { Double($0) }.average * 2

            return [
                (String(localized: "굽기"), avgDoneness),
                (String(localized: "육즙"), avgJuiciness),
                (String(localized: "부드러움"), avgTenderness),
                (String(localized: "간"), avgSeasoning),
                (String(localized: "육향"), avgFlavor),
                (String(localized: "마블링"), avgMarbling)
            ]

        case .sushi:
            return [
                (String(localized: "샤리(밥)"), validVisits.compactMap { $0.sushiShariAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "네타(재료)"), validVisits.compactMap { $0.sushiNetaAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "와사비"), validVisits.compactMap { $0.sushiWasabiAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "밸런스"), validVisits.compactMap { $0.sushiBalanceAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "쥐기"), validVisits.compactMap { $0.sushiGripAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "온도"), validVisits.compactMap { $0.sushiTemperatureAppropriate }.map { Double($0) }.average * 2)
            ]

        case .ramen:
            return [
                (String(localized: "국물"), validVisits.compactMap { $0.ramenBrothAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "면발"), validVisits.compactMap { $0.ramenNoodleAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "차슈"), validVisits.compactMap { $0.ramenChashuAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "토핑"), validVisits.compactMap { $0.ramenToppingAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "온도"), validVisits.compactMap { $0.ramenTemperatureAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "밸런스"), validVisits.compactMap { $0.ramenBalanceAppropriate }.map { Double($0) }.average * 2)
            ]

        case .pizza:
            return [
                (String(localized: "도우"), validVisits.compactMap { $0.pizzaDoughAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "소스"), validVisits.compactMap { $0.pizzaSauceAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "치즈"), validVisits.compactMap { $0.pizzaCheeseAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "굽기"), validVisits.compactMap { $0.pizzaBakingAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "토핑"), validVisits.compactMap { $0.pizzaToppingAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "밸런스"), validVisits.compactMap { $0.pizzaBalanceAppropriate }.map { Double($0) }.average * 2)
            ]

        case .wine:
            return [
                (String(localized: "바디"), validVisits.compactMap { $0.wineBodyAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "타닌"), validVisits.compactMap { $0.wineTanninAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "산도"), validVisits.compactMap { $0.wineAcidityAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "아로마"), validVisits.compactMap { $0.wineAromaAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "피니시"), validVisits.compactMap { $0.wineFinishAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "밸런스"), validVisits.compactMap { $0.wineBalanceAppropriate }.map { Double($0) }.average * 2)
            ]

        case .coffee:
            return [
                (String(localized: "산미"), validVisits.compactMap { $0.coffeeAcidityAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "바디"), validVisits.compactMap { $0.coffeeBodyAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "향미"), validVisits.compactMap { $0.coffeeFlavorAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "후미"), validVisits.compactMap { $0.coffeeAftertasteAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "단맛"), validVisits.compactMap { $0.coffeeSweetnessAppropriate }.map { Double($0) }.average * 2),
                (String(localized: "밸런스"), validVisits.compactMap { $0.coffeeBalanceAppropriate }.map { Double($0) }.average * 2)
            ]
        }
    }

    // 방문 기록이 있는지 확인
    var hasVisits: Bool {
        !(visits?.isEmpty ?? true)
    }

    // 리이오미슐랭 점수 (0-100점)
    // 순수 맛 평가: 평균 별점(50%) + 평균 적절함(50%)
    var satisfactionScore: Double {
        guard let visits = visits, !visits.isEmpty else {
            // 방문 기록이 없으면 기본 별점만 사용
            return Double(rating) / 5.0 * 100.0
        }

        let validVisits = visits.filter { $0.hasTasteProfile }

        // 평균 별점 (1-5점 → 0-100점)
        let avgRating = averageRating / 5.0 * 100.0

        // 평균 적절함이 없으면 별점만 사용
        guard !validVisits.isEmpty else {
            return avgRating
        }

        // 평균 적절함 계산 (1-5점 → 0-100점)
        let appropriatenessValues = validVisits.flatMap { visit -> [Double] in
            var values: [Double] = []

            // 일반 음식
            if let v = visit.spicyAppropriate { values.append(Double(v)) }
            if let v = visit.boldnessAppropriate { values.append(Double(v)) }
            if let v = visit.sweetnessAppropriate { values.append(Double(v)) }
            if let v = visit.saltinessAppropriate { values.append(Double(v)) }
            if let v = visit.richnessAppropriate { values.append(Double(v)) }
            if let v = visit.naturalTasteAppropriate { values.append(Double(v)) }

            // 스테이크
            if let v = visit.steakDonenessAppropriate { values.append(Double(v)) }
            if let v = visit.steakJuicinessAppropriate { values.append(Double(v)) }
            if let v = visit.steakTendernessAppropriate { values.append(Double(v)) }
            if let v = visit.steakSeasoningAppropriate { values.append(Double(v)) }
            if let v = visit.steakFlavorAppropriate { values.append(Double(v)) }
            if let v = visit.steakMarblingAppropriate { values.append(Double(v)) }

            // 스시
            if let v = visit.sushiShariAppropriate { values.append(Double(v)) }
            if let v = visit.sushiNetaAppropriate { values.append(Double(v)) }
            if let v = visit.sushiWasabiAppropriate { values.append(Double(v)) }
            if let v = visit.sushiBalanceAppropriate { values.append(Double(v)) }
            if let v = visit.sushiGripAppropriate { values.append(Double(v)) }
            if let v = visit.sushiTemperatureAppropriate { values.append(Double(v)) }

            // 라멘
            if let v = visit.ramenBrothAppropriate { values.append(Double(v)) }
            if let v = visit.ramenNoodleAppropriate { values.append(Double(v)) }
            if let v = visit.ramenChashuAppropriate { values.append(Double(v)) }
            if let v = visit.ramenToppingAppropriate { values.append(Double(v)) }
            if let v = visit.ramenTemperatureAppropriate { values.append(Double(v)) }
            if let v = visit.ramenBalanceAppropriate { values.append(Double(v)) }

            // 피자
            if let v = visit.pizzaDoughAppropriate { values.append(Double(v)) }
            if let v = visit.pizzaSauceAppropriate { values.append(Double(v)) }
            if let v = visit.pizzaCheeseAppropriate { values.append(Double(v)) }
            if let v = visit.pizzaBakingAppropriate { values.append(Double(v)) }
            if let v = visit.pizzaToppingAppropriate { values.append(Double(v)) }
            if let v = visit.pizzaBalanceAppropriate { values.append(Double(v)) }

            // 와인
            if let v = visit.wineBodyAppropriate { values.append(Double(v)) }
            if let v = visit.wineTanninAppropriate { values.append(Double(v)) }
            if let v = visit.wineAcidityAppropriate { values.append(Double(v)) }
            if let v = visit.wineAromaAppropriate { values.append(Double(v)) }
            if let v = visit.wineFinishAppropriate { values.append(Double(v)) }
            if let v = visit.wineBalanceAppropriate { values.append(Double(v)) }

            // 커피
            if let v = visit.coffeeAcidityAppropriate { values.append(Double(v)) }
            if let v = visit.coffeeBodyAppropriate { values.append(Double(v)) }
            if let v = visit.coffeeFlavorAppropriate { values.append(Double(v)) }
            if let v = visit.coffeeAftertasteAppropriate { values.append(Double(v)) }
            if let v = visit.coffeeSweetnessAppropriate { values.append(Double(v)) }
            if let v = visit.coffeeBalanceAppropriate { values.append(Double(v)) }

            return values
        }

        if appropriatenessValues.isEmpty {
            return avgRating
        }

        let avgAppropriateness = appropriatenessValues.reduce(0, +) / Double(appropriatenessValues.count)
        let appropriatenessScore = avgAppropriateness / 5.0 * 100.0

        // 최종 점수: 별점 50% + 적절함 50%
        return (avgRating * 0.5) + (appropriatenessScore * 0.5)
    }
}

// 배열 평균 계산 확장
extension Array where Element == Double {
    var average: Double {
        isEmpty ? 5.0 : reduce(0, +) / Double(count)
    }
}
