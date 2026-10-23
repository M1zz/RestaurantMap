import SwiftUI
import SwiftData

@Model
final class TasteProfile {
    var userId: String

    // 맛 선호도 (0-10)
    var spicy: Double          // 맵기: 순한맛 ↔ 매운맛
    var boldness: Double       // 진한맛: 담백 ↔ 진하고 자극적
    var sweetness: Double      // 단맛: 싫어함 ↔ 좋아함
    var saltiness: Double      // 짠맛: 싱거움 ↔ 짭짤함
    var richness: Double       // 기름진: 담백 ↔ 고소하고 기름진

    // 음식 스타일 (0-10)
    var naturalTaste: Double   // 본연의맛: 양념 강조 ↔ 재료 본연의 맛
    var texture: Double        // 질감다양: 부드러움 ↔ 쫄깃/바삭함
    var cooking: Double        // 조리법: 생/날것 ↔ 구이/튀김

    var updatedAt: Date

    init(
        userId: String = "default",
        spicy: Double = 5.0,
        boldness: Double = 5.0,
        sweetness: Double = 5.0,
        saltiness: Double = 5.0,
        richness: Double = 5.0,
        naturalTaste: Double = 5.0,
        texture: Double = 5.0,
        cooking: Double = 5.0
    ) {
        self.userId = userId
        self.spicy = spicy
        self.boldness = boldness
        self.sweetness = sweetness
        self.saltiness = saltiness
        self.richness = richness
        self.naturalTaste = naturalTaste
        self.texture = texture
        self.cooking = cooking
        self.updatedAt = Date()
    }

    // 레이더 차트용 데이터
    var radarData: [(String, Double, String)] {
        [
            (String(localized: "맵기"), spicy, String(localized: "순한 ↔ 매운")),
            (String(localized: "진한맛"), boldness, String(localized: "담백 ↔ 진한")),
            (String(localized: "단맛"), sweetness, String(localized: "안좋아함 ↔ 좋아함")),
            (String(localized: "짠맛"), saltiness, String(localized: "싱거움 ↔ 짭짤")),
            (String(localized: "기름진"), richness, String(localized: "담백 ↔ 고소")),
            (String(localized: "본연의맛"), naturalTaste, String(localized: "양념 ↔ 재료맛")),
            (String(localized: "질감"), texture, String(localized: "부드러움 ↔ 쫄깃")),
            (String(localized: "조리법"), cooking, String(localized: "날것 ↔ 구이"))
        ]
    }
}
