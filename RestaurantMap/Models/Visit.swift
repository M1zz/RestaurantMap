import Foundation
import SwiftData

@Model
final class Visit {
    var restaurant: Restaurant?
    var visitDate: Date
    var notes: String
    var rating: Int

    // 일반 맛 취향 프로필 - 강도 (0-10)
    var spicy: Double?
    var boldness: Double?
    var sweetness: Double?
    var saltiness: Double?
    var richness: Double?
    var naturalTaste: Double?
    var texture: Double?
    var cooking: Double?

    // 일반 맛 취향 프로필 - 적절함 (1-5)
    var spicyAppropriate: Int?
    var boldnessAppropriate: Int?
    var sweetnessAppropriate: Int?
    var saltinessAppropriate: Int?
    var richnessAppropriate: Int?
    var naturalTasteAppropriate: Int?
    var textureAppropriate: Int?
    var cookingAppropriate: Int?

    // 스테이크 전용 평가 - 강도 (0-10)
    var steakDoneness: Double? // 굽기
    var steakJuiciness: Double? // 육즙
    var steakTenderness: Double? // 부드러움
    var steakSeasoning: Double? // 간
    var steakFlavor: Double? // 육향
    var steakMarbling: Double? // 마블링

    // 스테이크 전용 평가 - 적절함 (1-5)
    var steakDonenessAppropriate: Int?
    var steakJuicinessAppropriate: Int?
    var steakTendernessAppropriate: Int?
    var steakSeasoningAppropriate: Int?
    var steakFlavorAppropriate: Int?
    var steakMarblingAppropriate: Int?

    // 초밥 전용 평가 - 강도 (0-10)
    var sushiShari: Double? // 샤리(밥)
    var sushiNeta: Double? // 네타(재료)
    var sushiWasabi: Double? // 와사비
    var sushiBalance: Double? // 밸런스
    var sushiGrip: Double? // 쥐기
    var sushiTemperature: Double? // 온도

    // 초밥 전용 평가 - 적절함 (1-5)
    var sushiShariAppropriate: Int?
    var sushiNetaAppropriate: Int?
    var sushiWasabiAppropriate: Int?
    var sushiBalanceAppropriate: Int?
    var sushiGripAppropriate: Int?
    var sushiTemperatureAppropriate: Int?

    // 라멘 전용 평가 - 강도 (0-10)
    var ramenBroth: Double? // 국물
    var ramenNoodle: Double? // 면발
    var ramenChashu: Double? // 차슈
    var ramenTopping: Double? // 토핑
    var ramenTemperature: Double? // 온도
    var ramenBalance: Double? // 밸런스

    // 라멘 전용 평가 - 적절함 (1-5)
    var ramenBrothAppropriate: Int?
    var ramenNoodleAppropriate: Int?
    var ramenChashuAppropriate: Int?
    var ramenToppingAppropriate: Int?
    var ramenTemperatureAppropriate: Int?
    var ramenBalanceAppropriate: Int?

    // 피자 전용 평가 - 강도 (0-10)
    var pizzaDough: Double? // 도우
    var pizzaSauce: Double? // 소스
    var pizzaCheese: Double? // 치즈
    var pizzaBaking: Double? // 굽기
    var pizzaTopping: Double? // 토핑
    var pizzaBalance: Double? // 밸런스

    // 피자 전용 평가 - 적절함 (1-5)
    var pizzaDoughAppropriate: Int?
    var pizzaSauceAppropriate: Int?
    var pizzaCheeseAppropriate: Int?
    var pizzaBakingAppropriate: Int?
    var pizzaToppingAppropriate: Int?
    var pizzaBalanceAppropriate: Int?

    // 와인 전용 평가 - 강도 (0-10)
    var wineBody: Double? // 바디
    var wineTannin: Double? // 타닌
    var wineAcidity: Double? // 산도
    var wineAroma: Double? // 아로마
    var wineFinish: Double? // 피니시
    var wineBalance: Double? // 밸런스

    // 와인 전용 평가 - 적절함 (1-5)
    var wineBodyAppropriate: Int?
    var wineTanninAppropriate: Int?
    var wineAcidityAppropriate: Int?
    var wineAromaAppropriate: Int?
    var wineFinishAppropriate: Int?
    var wineBalanceAppropriate: Int?

    // 커피 전용 평가 - 강도 (0-10)
    var coffeeAcidity: Double? // 산미
    var coffeeBody: Double? // 바디
    var coffeeFlavor: Double? // 향미
    var coffeeAftertaste: Double? // 후미
    var coffeeSweetness: Double? // 단맛
    var coffeeBalance: Double? // 밸런스

    // 커피 전용 평가 - 적절함 (1-5)
    var coffeeAcidityAppropriate: Int?
    var coffeeBodyAppropriate: Int?
    var coffeeFlavorAppropriate: Int?
    var coffeeAftertasteAppropriate: Int?
    var coffeeSweetnessAppropriate: Int?
    var coffeeBalanceAppropriate: Int?

    init(restaurant: Restaurant? = nil, visitDate: Date = Date(), notes: String = "", rating: Int = 0) {
        self.restaurant = restaurant
        self.visitDate = visitDate
        self.notes = notes
        self.rating = rating
    }

    // 취향이 평가되었는지 확인
    var hasTasteProfile: Bool {
        let hasGeneral = spicy != nil || boldness != nil || sweetness != nil || saltiness != nil ||
            richness != nil || naturalTaste != nil
        let hasSteakEval = steakDoneness != nil || steakJuiciness != nil || steakTenderness != nil ||
            steakSeasoning != nil || steakFlavor != nil || steakMarbling != nil
        let hasSushiEval = sushiShari != nil || sushiNeta != nil || sushiWasabi != nil ||
            sushiBalance != nil || sushiGrip != nil || sushiTemperature != nil
        let hasRamenEval = ramenBroth != nil || ramenNoodle != nil || ramenChashu != nil ||
            ramenTopping != nil || ramenTemperature != nil || ramenBalance != nil
        let hasPizzaEval = pizzaDough != nil || pizzaSauce != nil || pizzaCheese != nil ||
            pizzaBaking != nil || pizzaTopping != nil || pizzaBalance != nil
        let hasWineEval = wineBody != nil || wineTannin != nil || wineAcidity != nil ||
            wineAroma != nil || wineFinish != nil || wineBalance != nil
        let hasCoffeeEval = coffeeAcidity != nil || coffeeBody != nil || coffeeFlavor != nil ||
            coffeeAftertaste != nil || coffeeSweetness != nil || coffeeBalance != nil

        return hasGeneral || hasSteakEval || hasSushiEval || hasRamenEval || hasPizzaEval || hasWineEval || hasCoffeeEval
    }

    // 레이더 차트용 데이터 - 카테고리에 따라 다른 데이터 반환
    var intensityData: [(String, Double)] {
        guard let restaurant = restaurant else {
            return generalIntensityData
        }

        switch restaurant.foodCategory {
        case .general: return generalIntensityData
        case .steak: return steakIntensityData
        case .sushi: return sushiIntensityData
        case .ramen: return ramenIntensityData
        case .pizza: return pizzaIntensityData
        case .wine: return wineIntensityData
        case .coffee: return coffeeIntensityData
        }
    }

    var appropriatenessData: [(String, Double)] {
        guard let restaurant = restaurant else {
            return generalAppropriatenessData
        }

        switch restaurant.foodCategory {
        case .general: return generalAppropriatenessData
        case .steak: return steakAppropriatenessData
        case .sushi: return sushiAppropriatenessData
        case .ramen: return ramenAppropriatenessData
        case .pizza: return pizzaAppropriatenessData
        case .wine: return wineAppropriatenessData
        case .coffee: return coffeeAppropriatenessData
        }
    }

    // 일반 평가 데이터
    private var generalIntensityData: [(String, Double)] {
        [
            ("맵기", spicy ?? 5.0),
            ("진한맛", boldness ?? 5.0),
            ("단맛", sweetness ?? 5.0),
            ("짠맛", saltiness ?? 5.0),
            ("기름진", richness ?? 5.0),
            ("본연의맛", naturalTaste ?? 5.0)
        ]
    }

    private var generalAppropriatenessData: [(String, Double)] {
        [
            ("맵기", Double(spicyAppropriate ?? 3) * 2),
            ("진한맛", Double(boldnessAppropriate ?? 3) * 2),
            ("단맛", Double(sweetnessAppropriate ?? 3) * 2),
            ("짠맛", Double(saltinessAppropriate ?? 3) * 2),
            ("기름진", Double(richnessAppropriate ?? 3) * 2),
            ("본연의맛", Double(naturalTasteAppropriate ?? 3) * 2)
        ]
    }

    // 스테이크 평가 데이터
    private var steakIntensityData: [(String, Double)] {
        [
            ("굽기", steakDoneness ?? 5.0),
            ("육즙", steakJuiciness ?? 5.0),
            ("부드러움", steakTenderness ?? 5.0),
            ("간", steakSeasoning ?? 5.0),
            ("육향", steakFlavor ?? 5.0),
            ("마블링", steakMarbling ?? 5.0)
        ]
    }

    private var steakAppropriatenessData: [(String, Double)] {
        [
            ("굽기", Double(steakDonenessAppropriate ?? 3) * 2),
            ("육즙", Double(steakJuicinessAppropriate ?? 3) * 2),
            ("부드러움", Double(steakTendernessAppropriate ?? 3) * 2),
            ("간", Double(steakSeasoningAppropriate ?? 3) * 2),
            ("육향", Double(steakFlavorAppropriate ?? 3) * 2),
            ("마블링", Double(steakMarblingAppropriate ?? 3) * 2)
        ]
    }

    // 초밥 평가 데이터
    private var sushiIntensityData: [(String, Double)] {
        [
            ("샤리(밥)", sushiShari ?? 5.0),
            ("네타(재료)", sushiNeta ?? 5.0),
            ("와사비", sushiWasabi ?? 5.0),
            ("밸런스", sushiBalance ?? 5.0),
            ("쥐기", sushiGrip ?? 5.0),
            ("온도", sushiTemperature ?? 5.0)
        ]
    }

    private var sushiAppropriatenessData: [(String, Double)] {
        [
            ("샤리(밥)", Double(sushiShariAppropriate ?? 3) * 2),
            ("네타(재료)", Double(sushiNetaAppropriate ?? 3) * 2),
            ("와사비", Double(sushiWasabiAppropriate ?? 3) * 2),
            ("밸런스", Double(sushiBalanceAppropriate ?? 3) * 2),
            ("쥐기", Double(sushiGripAppropriate ?? 3) * 2),
            ("온도", Double(sushiTemperatureAppropriate ?? 3) * 2)
        ]
    }

    // 라멘 평가 데이터
    private var ramenIntensityData: [(String, Double)] {
        [
            ("국물", ramenBroth ?? 5.0),
            ("면발", ramenNoodle ?? 5.0),
            ("차슈", ramenChashu ?? 5.0),
            ("토핑", ramenTopping ?? 5.0),
            ("온도", ramenTemperature ?? 5.0),
            ("밸런스", ramenBalance ?? 5.0)
        ]
    }

    private var ramenAppropriatenessData: [(String, Double)] {
        [
            ("국물", Double(ramenBrothAppropriate ?? 3) * 2),
            ("면발", Double(ramenNoodleAppropriate ?? 3) * 2),
            ("차슈", Double(ramenChashuAppropriate ?? 3) * 2),
            ("토핑", Double(ramenToppingAppropriate ?? 3) * 2),
            ("온도", Double(ramenTemperatureAppropriate ?? 3) * 2),
            ("밸런스", Double(ramenBalanceAppropriate ?? 3) * 2)
        ]
    }

    // 피자 평가 데이터
    private var pizzaIntensityData: [(String, Double)] {
        [
            ("도우", pizzaDough ?? 5.0),
            ("소스", pizzaSauce ?? 5.0),
            ("치즈", pizzaCheese ?? 5.0),
            ("굽기", pizzaBaking ?? 5.0),
            ("토핑", pizzaTopping ?? 5.0),
            ("밸런스", pizzaBalance ?? 5.0)
        ]
    }

    private var pizzaAppropriatenessData: [(String, Double)] {
        [
            ("도우", Double(pizzaDoughAppropriate ?? 3) * 2),
            ("소스", Double(pizzaSauceAppropriate ?? 3) * 2),
            ("치즈", Double(pizzaCheeseAppropriate ?? 3) * 2),
            ("굽기", Double(pizzaBakingAppropriate ?? 3) * 2),
            ("토핑", Double(pizzaToppingAppropriate ?? 3) * 2),
            ("밸런스", Double(pizzaBalanceAppropriate ?? 3) * 2)
        ]
    }

    // 와인 평가 데이터
    private var wineIntensityData: [(String, Double)] {
        [
            ("바디", wineBody ?? 5.0),
            ("타닌", wineTannin ?? 5.0),
            ("산도", wineAcidity ?? 5.0),
            ("아로마", wineAroma ?? 5.0),
            ("피니시", wineFinish ?? 5.0),
            ("밸런스", wineBalance ?? 5.0)
        ]
    }

    private var wineAppropriatenessData: [(String, Double)] {
        [
            ("바디", Double(wineBodyAppropriate ?? 3) * 2),
            ("타닌", Double(wineTanninAppropriate ?? 3) * 2),
            ("산도", Double(wineAcidityAppropriate ?? 3) * 2),
            ("아로마", Double(wineAromaAppropriate ?? 3) * 2),
            ("피니시", Double(wineFinishAppropriate ?? 3) * 2),
            ("밸런스", Double(wineBalanceAppropriate ?? 3) * 2)
        ]
    }

    // 커피 평가 데이터
    private var coffeeIntensityData: [(String, Double)] {
        [
            ("산미", coffeeAcidity ?? 5.0),
            ("바디", coffeeBody ?? 5.0),
            ("향미", coffeeFlavor ?? 5.0),
            ("후미", coffeeAftertaste ?? 5.0),
            ("단맛", coffeeSweetness ?? 5.0),
            ("밸런스", coffeeBalance ?? 5.0)
        ]
    }

    private var coffeeAppropriatenessData: [(String, Double)] {
        [
            ("산미", Double(coffeeAcidityAppropriate ?? 3) * 2),
            ("바디", Double(coffeeBodyAppropriate ?? 3) * 2),
            ("향미", Double(coffeeFlavorAppropriate ?? 3) * 2),
            ("후미", Double(coffeeAftertasteAppropriate ?? 3) * 2),
            ("단맛", Double(coffeeSweetnessAppropriate ?? 3) * 2),
            ("밸런스", Double(coffeeBalanceAppropriate ?? 3) * 2)
        ]
    }
}
