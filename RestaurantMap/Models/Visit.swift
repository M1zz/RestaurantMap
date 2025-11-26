import Foundation
import SwiftData

@Model
final class Visit {
    var restaurant: Restaurant?
    var visitDate: Date
    var notes: String
    var rating: Int

    // 맛 취향 프로필 - 강도 (0-10)
    var spicy: Double?
    var boldness: Double?
    var sweetness: Double?
    var saltiness: Double?
    var richness: Double?
    var naturalTaste: Double?
    var texture: Double?
    var cooking: Double?

    // 맛 취향 프로필 - 적절함 (1-5)
    var spicyAppropriate: Int?
    var boldnessAppropriate: Int?
    var sweetnessAppropriate: Int?
    var saltinessAppropriate: Int?
    var richnessAppropriate: Int?
    var naturalTasteAppropriate: Int?
    var textureAppropriate: Int?
    var cookingAppropriate: Int?

    init(restaurant: Restaurant? = nil, visitDate: Date = Date(), notes: String = "", rating: Int = 0) {
        self.restaurant = restaurant
        self.visitDate = visitDate
        self.notes = notes
        self.rating = rating
    }

    // 취향이 평가되었는지 확인
    var hasTasteProfile: Bool {
        spicy != nil || boldness != nil || sweetness != nil || saltiness != nil ||
        richness != nil || naturalTaste != nil || texture != nil || cooking != nil
    }

    // 레이더 차트용 데이터
    var intensityData: [(String, Double)] {
        [
            ("맵기", spicy ?? 5.0),
            ("진한맛", boldness ?? 5.0),
            ("단맛", sweetness ?? 5.0),
            ("짠맛", saltiness ?? 5.0),
            ("기름진", richness ?? 5.0),
            ("본연의맛", naturalTaste ?? 5.0)
        ]
    }

    var appropriatenessData: [(String, Double)] {
        [
            ("맵기", Double(spicyAppropriate ?? 3) * 2),
            ("진한맛", Double(boldnessAppropriate ?? 3) * 2),
            ("단맛", Double(sweetnessAppropriate ?? 3) * 2),
            ("짠맛", Double(saltinessAppropriate ?? 3) * 2),
            ("기름진", Double(richnessAppropriate ?? 3) * 2),
            ("본연의맛", Double(naturalTasteAppropriate ?? 3) * 2)
        ]
    }
}
