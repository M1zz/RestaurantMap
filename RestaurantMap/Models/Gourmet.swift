//
//  Gourmet.swift
//  인생 맛집
//
//  미식 기준 — 접시 위의 음식만 본다. 서비스 · 분위기 · 값은 여기 넣지 않는다.
//
//  미쉐린 가이드가 밝힌 다섯 기준에서 왔다 (docs/engineering/GOURMET.md):
//   재료의 질 · 요리 기술 · 맛의 조화 · 요리에 드러나는 개성 · 한결같음.
//  앞의 넷은 방문마다 1~5로 적고(모두 선택), **한결같음은 묻지 않는다** — 여러 번 간 기록의 흔들림으로 앱이 센다.
//  음식 종류별 맛 평가(맵기 · 샤리 · 국물 …)는 그대로 따로 있다. 그쪽은 "어떤 맛인가", 이쪽은 "얼마나 잘 만든 음식인가" 다.
//

import Foundation

enum GourmetCriterion: String, CaseIterable, Identifiable {
    case ingredient, technique, harmony, personality

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ingredient: String(localized: "재료", comment: "Gourmet criterion: quality of ingredients")
        case .technique: String(localized: "조리", comment: "Gourmet criterion: cooking technique")
        case .harmony: String(localized: "조화", comment: "Gourmet criterion: harmony of flavours")
        case .personality: String(localized: "개성", comment: "Gourmet criterion: personality of the cooking")
        }
    }

    /// 무엇을 보라는 것인지 한 줄.
    var hint: String {
        switch self {
        case .ingredient: String(localized: "재료가 신선하고 좋았나요", comment: "Gourmet criterion hint: ingredients")
        case .technique: String(localized: "익힘과 간, 솜씨가 정확했나요", comment: "Gourmet criterion hint: technique")
        case .harmony: String(localized: "맛이 서로 잘 어울렸나요", comment: "Gourmet criterion hint: harmony")
        case .personality: String(localized: "이 집만의 맛이 있었나요", comment: "Gourmet criterion hint: personality")
        }
    }

    var symbol: String {
        switch self {
        case .ingredient: "leaf.fill"
        case .technique: "flame.fill"
        case .harmony: "circle.hexagongrid.fill"
        case .personality: "signature"
        }
    }
}

extension Visit {
    subscript(criterion: GourmetCriterion) -> Int? {
        get {
            switch criterion {
            case .ingredient: gourmetIngredient
            case .technique: gourmetTechnique
            case .harmony: gourmetHarmony
            case .personality: gourmetPersonality
            }
        }
        set {
            switch criterion {
            case .ingredient: gourmetIngredient = newValue
            case .technique: gourmetTechnique = newValue
            case .harmony: gourmetHarmony = newValue
            case .personality: gourmetPersonality = newValue
            }
        }
    }

    var hasGourmetNote: Bool { GourmetCriterion.allCases.contains { self[$0] != nil } }
}

/// 한결같음 — 갈 때마다 별점이 얼마나 흔들렸나. 세 번은 가야 말할 수 있다.
enum Consistency {
    case steady, mostly, varies

    static let minimumVisits = 3

    init?(ratings: [Int]) {
        let rated = ratings.filter { $0 > 0 }.map(Double.init)
        guard rated.count >= Self.minimumVisits else { return nil }
        let mean = rated.reduce(0, +) / Double(rated.count)
        let deviation = (rated.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(rated.count)).squareRoot()
        self = deviation < 0.5 ? .steady : (deviation < 1.0 ? .mostly : .varies)
    }

    var title: String {
        switch self {
        case .steady: String(localized: "갈 때마다 한결같아요", comment: "Consistency across visits: steady")
        case .mostly: String(localized: "대체로 한결같아요", comment: "Consistency across visits: mostly steady")
        case .varies: String(localized: "갈 때마다 달라요", comment: "Consistency across visits: varies")
        }
    }

    /// 공개 후기에 싣는 값 (3 · 2 · 1).
    var score: Int {
        switch self { case .steady: 3; case .mostly: 2; case .varies: 1 }
    }

    init?(score: Int) {
        switch score { case 3: self = .steady; case 2: self = .mostly; case 1: self = .varies; default: return nil }
    }
}

extension Restaurant {
    /// 방문마다 적은 미식 기준의 평균. 한 번도 적지 않은 기준은 nil.
    func gourmetAverage(_ criterion: GourmetCriterion) -> Double? {
        let values = (visits ?? []).compactMap { $0[criterion] }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    var hasGourmetNotes: Bool { (visits ?? []).contains(where: \.hasGourmetNote) }

    var consistency: Consistency? { Consistency(ratings: (visits ?? []).map(\.rating)) }
}
