import SwiftUI

enum FoodCategory: String, Codable, CaseIterable, Identifiable {
    case general = "일반"
    case steak = "스테이크"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .general:
            return "🍽️"
        case .steak:
            return "🥩"
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
