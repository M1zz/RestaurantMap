import SwiftUI
import SwiftData

@Model
final class TasteProfile {
    // CloudKit 동기화 규칙: 모든 속성에 기본값을 둔다.
    var userId: String = "default"

    // 맛 선호도 (0-10)
    var spicy: Double = 5.0          // 맵기: 순한맛 ↔ 매운맛
    var boldness: Double = 5.0       // 진한맛: 담백 ↔ 진하고 자극적
    var sweetness: Double = 5.0      // 단맛: 싫어함 ↔ 좋아함
    var saltiness: Double = 5.0      // 짠맛: 싱거움 ↔ 짭짤함
    var richness: Double = 5.0       // 기름진: 담백 ↔ 고소하고 기름진

    // 음식 스타일 (0-10)
    var naturalTaste: Double = 5.0   // 본연의맛: 양념 강조 ↔ 재료 본연의 맛
    var texture: Double = 5.0        // 질감다양: 부드러움 ↔ 쫄깃/바삭함
    var cooking: Double = 5.0        // 조리법: 생/날것 ↔ 구이/튀김

    var updatedAt: Date = Date()

    /// 내가 생각하는 나 — 맛 지도 위의 한 점 (진하기 · 자극, 1~5). 찍지 않았으면 nil.
    /// 위의 여덟 칸은 옛 취향 화면의 것이라 더 쓰지 않는다.
    var selfDepth: Double?
    var selfKick: Double?

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
}
