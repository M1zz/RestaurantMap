import Foundation
import SwiftData
import MapKit

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
    var foodCategoryRaw: String = "일반" // FoodCategory enum을 String으로 저장, 기본값 설정

    // 방문 기록들
    @Relationship(deleteRule: .cascade, inverse: \Visit.restaurant)
    var visits: [Visit]?

    // FoodCategory 편의 속성
    var foodCategory: FoodCategory {
        get {
            // 빈 문자열이나 잘못된 값이면 기본값 반환
            if foodCategoryRaw.isEmpty {
                return .general
            }
            return FoodCategory(rawValue: foodCategoryRaw) ?? .general
        }
        set {
            foodCategoryRaw = newValue.rawValue
        }
    }

    init(name: String, address: String, latitude: Double, longitude: Double, notes: String = "", rating: Int = 0, visitDate: Date = Date(), category: String = "", phoneNumber: String = "", isTop6: Bool = false, top6Rank: Int? = nil, categoryIcon: String = "fork.knife", foodCategory: FoodCategory = .general) {
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
        self.foodCategoryRaw = foodCategory.rawValue
        self.visits = []
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

        switch foodCategory {
        case .general:
            let avgSpicy = validVisits.compactMap { $0.spicy }.average
            let avgBoldness = validVisits.compactMap { $0.boldness }.average
            let avgSweetness = validVisits.compactMap { $0.sweetness }.average
            let avgSaltiness = validVisits.compactMap { $0.saltiness }.average
            let avgRichness = validVisits.compactMap { $0.richness }.average
            let avgNaturalTaste = validVisits.compactMap { $0.naturalTaste }.average

            return [
                ("맵기", avgSpicy),
                ("진한맛", avgBoldness),
                ("단맛", avgSweetness),
                ("짠맛", avgSaltiness),
                ("기름진", avgRichness),
                ("본연의맛", avgNaturalTaste)
            ]

        case .steak:
            let avgDoneness = validVisits.compactMap { $0.steakDoneness }.average
            let avgJuiciness = validVisits.compactMap { $0.steakJuiciness }.average
            let avgTenderness = validVisits.compactMap { $0.steakTenderness }.average
            let avgSeasoning = validVisits.compactMap { $0.steakSeasoning }.average
            let avgFlavor = validVisits.compactMap { $0.steakFlavor }.average
            let avgMarbling = validVisits.compactMap { $0.steakMarbling }.average

            return [
                ("굽기", avgDoneness),
                ("육즙", avgJuiciness),
                ("부드러움", avgTenderness),
                ("간", avgSeasoning),
                ("육향", avgFlavor),
                ("마블링", avgMarbling)
            ]

        case .sushi:
            return [
                ("샤리(밥)", validVisits.compactMap { $0.sushiShari }.average),
                ("네타(재료)", validVisits.compactMap { $0.sushiNeta }.average),
                ("와사비", validVisits.compactMap { $0.sushiWasabi }.average),
                ("밸런스", validVisits.compactMap { $0.sushiBalance }.average),
                ("쥐기", validVisits.compactMap { $0.sushiGrip }.average),
                ("온도", validVisits.compactMap { $0.sushiTemperature }.average)
            ]

        case .ramen:
            return [
                ("국물", validVisits.compactMap { $0.ramenBroth }.average),
                ("면발", validVisits.compactMap { $0.ramenNoodle }.average),
                ("차슈", validVisits.compactMap { $0.ramenChashu }.average),
                ("토핑", validVisits.compactMap { $0.ramenTopping }.average),
                ("온도", validVisits.compactMap { $0.ramenTemperature }.average),
                ("밸런스", validVisits.compactMap { $0.ramenBalance }.average)
            ]

        case .pizza:
            return [
                ("도우", validVisits.compactMap { $0.pizzaDough }.average),
                ("소스", validVisits.compactMap { $0.pizzaSauce }.average),
                ("치즈", validVisits.compactMap { $0.pizzaCheese }.average),
                ("굽기", validVisits.compactMap { $0.pizzaBaking }.average),
                ("토핑", validVisits.compactMap { $0.pizzaTopping }.average),
                ("밸런스", validVisits.compactMap { $0.pizzaBalance }.average)
            ]

        case .wine:
            return [
                ("바디", validVisits.compactMap { $0.wineBody }.average),
                ("타닌", validVisits.compactMap { $0.wineTannin }.average),
                ("산도", validVisits.compactMap { $0.wineAcidity }.average),
                ("아로마", validVisits.compactMap { $0.wineAroma }.average),
                ("피니시", validVisits.compactMap { $0.wineFinish }.average),
                ("밸런스", validVisits.compactMap { $0.wineBalance }.average)
            ]

        case .coffee:
            return [
                ("산미", validVisits.compactMap { $0.coffeeAcidity }.average),
                ("바디", validVisits.compactMap { $0.coffeeBody }.average),
                ("향미", validVisits.compactMap { $0.coffeeFlavor }.average),
                ("후미", validVisits.compactMap { $0.coffeeAftertaste }.average),
                ("단맛", validVisits.compactMap { $0.coffeeSweetness }.average),
                ("밸런스", validVisits.compactMap { $0.coffeeBalance }.average)
            ]
        }
    }

    // 총평 - 평균 적절함 (카테고리별로 다른 데이터 반환)
    var averageAppropriateness: [(String, Double)] {
        guard let visits = visits, !visits.isEmpty else { return [] }

        let validVisits = visits.filter { $0.hasTasteProfile }
        guard !validVisits.isEmpty else { return [] }

        switch foodCategory {
        case .general:
            let avgSpicy = validVisits.compactMap { $0.spicyAppropriate }.map { Double($0) }.average * 2
            let avgBoldness = validVisits.compactMap { $0.boldnessAppropriate }.map { Double($0) }.average * 2
            let avgSweetness = validVisits.compactMap { $0.sweetnessAppropriate }.map { Double($0) }.average * 2
            let avgSaltiness = validVisits.compactMap { $0.saltinessAppropriate }.map { Double($0) }.average * 2
            let avgRichness = validVisits.compactMap { $0.richnessAppropriate }.map { Double($0) }.average * 2
            let avgNaturalTaste = validVisits.compactMap { $0.naturalTasteAppropriate }.map { Double($0) }.average * 2

            return [
                ("맵기", avgSpicy),
                ("진한맛", avgBoldness),
                ("단맛", avgSweetness),
                ("짠맛", avgSaltiness),
                ("기름진", avgRichness),
                ("본연의맛", avgNaturalTaste)
            ]

        case .steak:
            let avgDoneness = validVisits.compactMap { $0.steakDonenessAppropriate }.map { Double($0) }.average * 2
            let avgJuiciness = validVisits.compactMap { $0.steakJuicinessAppropriate }.map { Double($0) }.average * 2
            let avgTenderness = validVisits.compactMap { $0.steakTendernessAppropriate }.map { Double($0) }.average * 2
            let avgSeasoning = validVisits.compactMap { $0.steakSeasoningAppropriate }.map { Double($0) }.average * 2
            let avgFlavor = validVisits.compactMap { $0.steakFlavorAppropriate }.map { Double($0) }.average * 2
            let avgMarbling = validVisits.compactMap { $0.steakMarblingAppropriate }.map { Double($0) }.average * 2

            return [
                ("굽기", avgDoneness),
                ("육즙", avgJuiciness),
                ("부드러움", avgTenderness),
                ("간", avgSeasoning),
                ("육향", avgFlavor),
                ("마블링", avgMarbling)
            ]

        case .sushi:
            return [
                ("샤리(밥)", validVisits.compactMap { $0.sushiShariAppropriate }.map { Double($0) }.average * 2),
                ("네타(재료)", validVisits.compactMap { $0.sushiNetaAppropriate }.map { Double($0) }.average * 2),
                ("와사비", validVisits.compactMap { $0.sushiWasabiAppropriate }.map { Double($0) }.average * 2),
                ("밸런스", validVisits.compactMap { $0.sushiBalanceAppropriate }.map { Double($0) }.average * 2),
                ("쥐기", validVisits.compactMap { $0.sushiGripAppropriate }.map { Double($0) }.average * 2),
                ("온도", validVisits.compactMap { $0.sushiTemperatureAppropriate }.map { Double($0) }.average * 2)
            ]

        case .ramen:
            return [
                ("국물", validVisits.compactMap { $0.ramenBrothAppropriate }.map { Double($0) }.average * 2),
                ("면발", validVisits.compactMap { $0.ramenNoodleAppropriate }.map { Double($0) }.average * 2),
                ("차슈", validVisits.compactMap { $0.ramenChashuAppropriate }.map { Double($0) }.average * 2),
                ("토핑", validVisits.compactMap { $0.ramenToppingAppropriate }.map { Double($0) }.average * 2),
                ("온도", validVisits.compactMap { $0.ramenTemperatureAppropriate }.map { Double($0) }.average * 2),
                ("밸런스", validVisits.compactMap { $0.ramenBalanceAppropriate }.map { Double($0) }.average * 2)
            ]

        case .pizza:
            return [
                ("도우", validVisits.compactMap { $0.pizzaDoughAppropriate }.map { Double($0) }.average * 2),
                ("소스", validVisits.compactMap { $0.pizzaSauceAppropriate }.map { Double($0) }.average * 2),
                ("치즈", validVisits.compactMap { $0.pizzaCheeseAppropriate }.map { Double($0) }.average * 2),
                ("굽기", validVisits.compactMap { $0.pizzaBakingAppropriate }.map { Double($0) }.average * 2),
                ("토핑", validVisits.compactMap { $0.pizzaToppingAppropriate }.map { Double($0) }.average * 2),
                ("밸런스", validVisits.compactMap { $0.pizzaBalanceAppropriate }.map { Double($0) }.average * 2)
            ]

        case .wine:
            return [
                ("바디", validVisits.compactMap { $0.wineBodyAppropriate }.map { Double($0) }.average * 2),
                ("타닌", validVisits.compactMap { $0.wineTanninAppropriate }.map { Double($0) }.average * 2),
                ("산도", validVisits.compactMap { $0.wineAcidityAppropriate }.map { Double($0) }.average * 2),
                ("아로마", validVisits.compactMap { $0.wineAromaAppropriate }.map { Double($0) }.average * 2),
                ("피니시", validVisits.compactMap { $0.wineFinishAppropriate }.map { Double($0) }.average * 2),
                ("밸런스", validVisits.compactMap { $0.wineBalanceAppropriate }.map { Double($0) }.average * 2)
            ]

        case .coffee:
            return [
                ("산미", validVisits.compactMap { $0.coffeeAcidityAppropriate }.map { Double($0) }.average * 2),
                ("바디", validVisits.compactMap { $0.coffeeBodyAppropriate }.map { Double($0) }.average * 2),
                ("향미", validVisits.compactMap { $0.coffeeFlavorAppropriate }.map { Double($0) }.average * 2),
                ("후미", validVisits.compactMap { $0.coffeeAftertasteAppropriate }.map { Double($0) }.average * 2),
                ("단맛", validVisits.compactMap { $0.coffeeSweetnessAppropriate }.map { Double($0) }.average * 2),
                ("밸런스", validVisits.compactMap { $0.coffeeBalanceAppropriate }.map { Double($0) }.average * 2)
            ]
        }
    }

    // 방문 기록이 있는지 확인
    var hasVisits: Bool {
        !(visits?.isEmpty ?? true)
    }
}

// 배열 평균 계산 확장
extension Array where Element == Double {
    var average: Double {
        isEmpty ? 5.0 : reduce(0, +) / Double(count)
    }
}
