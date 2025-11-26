import SwiftUI

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case general = "일반"
    case steak = "스테이크"
    case sushi = "초밥"
    case ramen = "라멘"
    case pizza = "피자"
    case wine = "와인"
    case coffee = "커피"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:
            return "🍽️"
        case .steak:
            return "🥩"
        case .sushi:
            return "🍣"
        case .ramen:
            return "🍜"
        case .pizza:
            return "🍕"
        case .wine:
            return "🍷"
        case .coffee:
            return "☕"
        }
    }

    var displayName: String {
        return "\(icon) \(rawValue)"
    }

    // 카테고리별 평가 항목
    var evaluationAttributes: [EvaluationAttribute] {
        switch self {
        case .general:
            return [
                EvaluationAttribute(emoji: "🌶️", title: "맵기", subtitle: "순한 ↔ 매운"),
                EvaluationAttribute(emoji: "💪", title: "진한맛", subtitle: "담백 ↔ 진한"),
                EvaluationAttribute(emoji: "🍯", title: "단맛", subtitle: "안좋아함 ↔ 좋아함"),
                EvaluationAttribute(emoji: "🧂", title: "짠맛", subtitle: "싱거움 ↔ 짭짤"),
                EvaluationAttribute(emoji: "🥓", title: "기름진", subtitle: "담백 ↔ 고소"),
                EvaluationAttribute(emoji: "🌿", title: "본연의맛", subtitle: "양념 ↔ 재료맛")
            ]
        case .steak:
            return [
                EvaluationAttribute(emoji: "🔥", title: "굽기", subtitle: "레어 ↔ 웰던"),
                EvaluationAttribute(emoji: "🥩", title: "육즙", subtitle: "퍽퍽 ↔ 촉촉"),
                EvaluationAttribute(emoji: "✨", title: "부드러움", subtitle: "질김 ↔ 부드러움"),
                EvaluationAttribute(emoji: "🧂", title: "간", subtitle: "싱거움 ↔ 짭짤"),
                EvaluationAttribute(emoji: "🌿", title: "육향", subtitle: "약함 ↔ 강함"),
                EvaluationAttribute(emoji: "🍖", title: "마블링", subtitle: "적음 ↔ 많음")
            ]
        case .sushi:
            return [
                EvaluationAttribute(emoji: "🍚", title: "샤리(밥)", subtitle: "흐물 ↔ 단단"),
                EvaluationAttribute(emoji: "🐟", title: "네타(재료)", subtitle: "신선도"),
                EvaluationAttribute(emoji: "🌿", title: "와사비", subtitle: "약함 ↔ 강함"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화"),
                EvaluationAttribute(emoji: "✋", title: "쥐기", subtitle: "풀림 ↔ 결속"),
                EvaluationAttribute(emoji: "🌡️", title: "온도", subtitle: "차가움 ↔ 따뜻함")
            ]
        case .ramen:
            return [
                EvaluationAttribute(emoji: "🥣", title: "국물", subtitle: "깊이/감칠맛"),
                EvaluationAttribute(emoji: "🍜", title: "면발", subtitle: "부드러움 ↔ 쫄깃함"),
                EvaluationAttribute(emoji: "🥓", title: "차슈", subtitle: "퍽퍽 ↔ 부드러움"),
                EvaluationAttribute(emoji: "🥚", title: "토핑", subtitle: "부실 ↔ 풍부"),
                EvaluationAttribute(emoji: "🔥", title: "온도", subtitle: "미지근 ↔ 뜨거움"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화")
            ]
        case .pizza:
            return [
                EvaluationAttribute(emoji: "🫓", title: "도우", subtitle: "질김 ↔ 쫄깃함"),
                EvaluationAttribute(emoji: "🍅", title: "소스", subtitle: "적음 ↔ 많음"),
                EvaluationAttribute(emoji: "🧀", title: "치즈", subtitle: "적음 ↔ 많음"),
                EvaluationAttribute(emoji: "🔥", title: "굽기", subtitle: "덜익음 ↔ 바삭함"),
                EvaluationAttribute(emoji: "🌟", title: "토핑", subtitle: "부실 ↔ 풍부"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화")
            ]
        case .wine:
            return [
                EvaluationAttribute(emoji: "💪", title: "바디", subtitle: "가벼움 ↔ 묵직함"),
                EvaluationAttribute(emoji: "🍇", title: "타닌", subtitle: "약함 ↔ 떫음"),
                EvaluationAttribute(emoji: "🍋", title: "산도", subtitle: "낮음 ↔ 높음"),
                EvaluationAttribute(emoji: "🌸", title: "아로마", subtitle: "단순 ↔ 복잡"),
                EvaluationAttribute(emoji: "✨", title: "피니시", subtitle: "짧음 ↔ 긴 여운"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화")
            ]
        case .coffee:
            return [
                EvaluationAttribute(emoji: "🍋", title: "산미", subtitle: "낮음 ↔ 밝음"),
                EvaluationAttribute(emoji: "💪", title: "바디", subtitle: "가벼움 ↔ 묵직함"),
                EvaluationAttribute(emoji: "🌸", title: "향미", subtitle: "단순 ↔ 복잡"),
                EvaluationAttribute(emoji: "✨", title: "후미", subtitle: "짧음 ↔ 긴 여운"),
                EvaluationAttribute(emoji: "🍯", title: "단맛", subtitle: "쓴맛 ↔ 단맛"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화")
            ]
        }
    }
}

struct EvaluationAttribute {
    let emoji: String
    let title: String
    let subtitle: String

    var displayTitle: String {
        return "\(emoji) \(title)"
    }
}
