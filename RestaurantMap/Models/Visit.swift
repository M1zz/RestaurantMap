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

    init(restaurant: Restaurant? = nil, visitDate: Date = Date(), notes: String = "", rating: Int = 0) {
        self.restaurant = restaurant
        self.visitDate = visitDate
        self.notes = notes
        self.rating = rating
    }

    // 취향이 평가되었는지 확인
    var hasTasteProfile: Bool {
        // 일반 평가
        let hasGeneral = spicy != nil || boldness != nil || sweetness != nil || saltiness != nil ||
            richness != nil || naturalTaste != nil || texture != nil || cooking != nil

        // 스테이크 평가
        let hasSteakEval = steakDoneness != nil || steakJuiciness != nil || steakTenderness != nil ||
            steakSeasoning != nil || steakFlavor != nil || steakMarbling != nil

        return hasGeneral || hasSteakEval
    }

    // 레이더 차트용 데이터 - 카테고리에 따라 다른 데이터 반환
    var intensityData: [(String, Double)] {
        guard let restaurant = restaurant else {
            return generalIntensityData
        }

        switch restaurant.foodCategory {
        case .general:
            return generalIntensityData
        case .steak:
            return steakIntensityData
        }
    }

    var appropriatenessData: [(String, Double)] {
        guard let restaurant = restaurant else {
            return generalAppropriatenessData
        }

        switch restaurant.foodCategory {
        case .general:
            return generalAppropriatenessData
        case .steak:
            return steakAppropriatenessData
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
}
