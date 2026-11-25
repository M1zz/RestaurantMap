//
//  Taste.swift
//  인생 맛집
//
//  맛 기록 — "어떤 맛이었나". 잘 만들었는지는 미식 기준(Gourmet.swift)이 따로 본다.
//
//  세 층 (docs/engineering/TASTE.md):
//   1. 미식 기준 — 재료 · 조리 · 조화 · 개성. 모든 방문. 종류가 달라도 견준다 (Gourmet.swift).
//   2. 기본 맛 — 진하기 · 자극. 모든 방문. 취향 탭의 맛 지도가 된다.
//   3. 계열별 맛 — 고기는 굽기 · 기름기 · 육향처럼, 음식 계열에 딸린 취향 축 두세 개. 접어 둔다.
//  축은 모두 양 끝이 있는 1~5 이고, 좋고 나쁨이 아니라 어느 쪽이었는지를 적는다. 적지 않아도 된다.
//

import Foundation
import SwiftData

// MARK: - 계열

/// 음식 종류를 묶는 계열. 계열마다 딸린 맛 축이 다르다. 직접 만든 종류는 만들 때 계열을 고른다.
enum TasteFamily: String, Codable, CaseIterable, Identifiable {
    case basic, meat, seafood, noodle, sweet, drink

    var id: String { rawValue }

    var title: String {
        switch self {
        case .basic: String(localized: "기본", comment: "Taste family: no extra taste notes")
        case .meat: String(localized: "고기", comment: "Taste family: meat")
        case .seafood: String(localized: "생선", comment: "Taste family: fish and seafood")
        case .noodle: String(localized: "면", comment: "Taste family: noodles")
        case .sweet: String(localized: "디저트 · 커피", comment: "Taste family: desserts and coffee")
        case .drink: String(localized: "술", comment: "Taste family: wine and drinks")
        }
    }

    var emoji: String {
        switch self {
        case .basic: "🍽️"
        case .meat: "🥩"
        case .seafood: "🐟"
        case .noodle: "🍜"
        case .sweet: "🍰"
        case .drink: "🍷"
        }
    }

    /// 이 계열에만 딸린 축. 기본 계열은 없다.
    var axes: [TasteAxis] {
        switch self {
        case .basic: []
        case .meat: [.doneness, .fat, .meatiness]
        case .seafood: [.aging, .wasabi, .riceSeasoning]
        case .noodle: [.noodleBite, .broth]
        case .sweet: [.sweetness, .heaviness, .acidity]
        case .drink: [.body, .dryness, .drinkAcidity]
        }
    }
}

// MARK: - 축

/// 맛 축 하나. rawValue 가 저장 키라 바꾸지 않는다.
enum TasteAxis: String, CaseIterable, Identifiable {
    // 기본 — 모든 방문
    case depth, kick
    // 고기
    case doneness, fat, meatiness
    // 생선
    case aging, wasabi, riceSeasoning
    // 면
    case noodleBite, broth
    // 디저트 · 커피
    case sweetness, heaviness, acidity
    // 술
    case body, dryness, drinkAcidity

    var id: String { rawValue }

    /// 모든 방문에 묻는 두 축. 맛 지도의 가로(진하기) · 세로(자극)다.
    static let basic: [TasteAxis] = [.depth, .kick]

    var title: String {
        switch self {
        case .depth: String(localized: "진하기", comment: "Taste axis title")
        case .kick: String(localized: "자극", comment: "Taste axis title: spicy, salty, punchy")
        case .doneness: String(localized: "굽기", comment: "Taste axis title: meat doneness")
        case .fat: String(localized: "기름기", comment: "Taste axis title")
        case .meatiness: String(localized: "육향", comment: "Taste axis title: meaty aroma")
        case .aging: String(localized: "숙성", comment: "Taste axis title: fish aging")
        case .wasabi: String(localized: "와사비", comment: "Taste axis title")
        case .riceSeasoning: String(localized: "샤리 간", comment: "Taste axis title: seasoning of sushi rice")
        case .noodleBite: String(localized: "면", comment: "Taste axis title: noodle texture")
        case .broth: String(localized: "국물", comment: "Taste axis title")
        case .sweetness: String(localized: "단맛", comment: "Taste axis title")
        case .heaviness: String(localized: "식감", comment: "Taste axis title: dessert texture")
        case .acidity: String(localized: "산미", comment: "Taste axis title: coffee or dessert acidity")
        case .body: String(localized: "바디", comment: "Taste axis title: body of a drink")
        case .dryness: String(localized: "당도", comment: "Taste axis title: dry or sweet drink")
        case .drinkAcidity: String(localized: "산도", comment: "Taste axis title: acidity of a drink")
        }
    }

    /// 1 쪽 끝.
    var low: String {
        switch self {
        case .depth: String(localized: "담백", comment: "Taste axis low end: light, clean")
        case .kick: String(localized: "순함", comment: "Taste axis low end: mild")
        case .doneness: String(localized: "레어", comment: "Taste axis low end")
        case .fat: String(localized: "담백", comment: "Taste axis low end: light, clean")
        case .meatiness: String(localized: "은은함", comment: "Taste axis low end: subtle")
        case .aging: String(localized: "활어", comment: "Taste axis low end: freshly killed fish")
        case .wasabi: String(localized: "약하게", comment: "Taste axis low end")
        case .riceSeasoning: String(localized: "순하게", comment: "Taste axis low end: lightly seasoned")
        case .noodleBite: String(localized: "부드러움", comment: "Taste axis low end: soft noodles")
        case .broth: String(localized: "맑음", comment: "Taste axis low end: clear broth")
        case .sweetness: String(localized: "은은함", comment: "Taste axis low end: subtle")
        case .heaviness: String(localized: "가벼움", comment: "Taste axis low end: light texture")
        case .acidity, .drinkAcidity: String(localized: "낮음", comment: "Taste axis low end")
        case .body: String(localized: "가벼움", comment: "Taste axis low end: light texture")
        case .dryness: String(localized: "드라이", comment: "Taste axis low end: dry wine")
        }
    }

    /// 5 쪽 끝.
    var high: String {
        switch self {
        case .depth: String(localized: "진함", comment: "Taste axis high end: rich, intense")
        case .kick: String(localized: "자극적", comment: "Taste axis high end: spicy, salty, punchy")
        case .doneness: String(localized: "웰던", comment: "Taste axis high end")
        case .fat: String(localized: "기름짐", comment: "Taste axis high end: fatty")
        case .meatiness: String(localized: "진함", comment: "Taste axis high end: rich, intense")
        case .aging: String(localized: "숙성", comment: "Taste axis high end: aged fish")
        case .wasabi: String(localized: "세게", comment: "Taste axis high end")
        case .riceSeasoning: String(localized: "새콤짭짤", comment: "Taste axis high end: strongly seasoned sushi rice")
        case .noodleBite: String(localized: "쫄깃함", comment: "Taste axis high end: chewy noodles")
        case .broth: String(localized: "진함", comment: "Taste axis high end: rich, intense")
        case .sweetness: String(localized: "진함", comment: "Taste axis high end: rich, intense")
        case .heaviness: String(localized: "꾸덕함", comment: "Taste axis high end: dense, rich texture")
        case .acidity, .drinkAcidity: String(localized: "높음", comment: "Taste axis high end")
        case .body: String(localized: "묵직함", comment: "Taste axis high end: full-bodied")
        case .dryness: String(localized: "스위트", comment: "Taste axis high end: sweet wine")
        }
    }

    /// 값을 한 마디로 — "레어 쪽", "가운데", "웰던 쪽".
    func describe(_ value: Double) -> String {
        if value < 2.5 { return String(localized: "\(low) 쪽", comment: "Taste axis reading, e.g. 'Rare side'") }
        if value > 3.5 { return String(localized: "\(high) 쪽", comment: "Taste axis reading, e.g. 'Well-done side'") }
        return String(localized: "가운데", comment: "Taste axis reading: middle")
    }
}

// MARK: - 방문에 적는 맛

extension Visit {
    /// 적은 맛 (축 → 1~5). 적지 않은 축은 들어 있지 않다.
    var tastes: [TasteAxis: Int] {
        get {
            guard let tasteData, let raw = try? JSONDecoder().decode([String: Int].self, from: tasteData) else { return [:] }
            return Dictionary(uniqueKeysWithValues: raw.compactMap { key, value in TasteAxis(rawValue: key).map { ($0, value) } })
        }
        set {
            let raw = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.rawValue, $0.value) })
            tasteData = try? JSONEncoder().encode(raw)
        }
    }

    subscript(axis: TasteAxis) -> Int? {
        get { tastes[axis] }
        set { var all = tastes; all[axis] = newValue; tastes = all }
    }

    var hasTasteNote: Bool { !tastes.isEmpty }

    /// 별을 많이 준 방문일수록 취향을 더 크게 끌어당긴다. 별을 안 줬으면 가운데(3)로 센다.
    var tasteWeight: Double { Double(rating > 0 ? rating : 3) }
}

// MARK: - 식당 · 여러 방문

extension Restaurant {
    var tasteFamily: TasteFamily { foodCategory.tasteFamily }

    /// 이 집에서 적은 맛의 평균. 적은 방문이 없으면 nil.
    func tasteAverage(_ axis: TasteAxis) -> Double? {
        let values = (visits ?? []).compactMap { $0[axis] }
        guard !values.isEmpty else { return nil }
        return Double(values.reduce(0, +)) / Double(values.count)
    }

    /// 이 집에서 한 번이라도 적은 축 — 기본 먼저, 그다음 계열 순서.
    var notedTasteAxes: [TasteAxis] {
        let noted = Set((visits ?? []).flatMap { $0.tastes.keys })
        return TasteAxis.allCases.filter(noted.contains)
    }
}

// MARK: - 옛 맛 평가 옮기기

extension Visit {
    /// 옛 평가 칸(0~10)에서 뜻이 같은 것만 새 축(1~5)으로 옮긴다. 한 번만 옮긴다(`tasteData` 가 생기면 끝).
    /// 옛 화면은 손대지 않은 칸도 5(가운데)로 저장했다 — 그 묶음이 모두 가운데면 고르지 않은 것으로 보고 옮기지 않는다.
    func migrateLegacyTaste() {
        guard tasteData == nil else { return }
        var moved: [TasteAxis: Int] = [:]
        func take(_ pairs: [(Double?, TasteAxis)], group: [Double?]) {
            let touched = group.contains { $0 != nil && $0 != 5 }
            guard touched else { return }
            // 유한한 값만 — NaN · 무한대를 Int 로 바꾸면 그 자리에서 죽는다 (옛 백업 · 동기화로 들어온 값).
            for case let (value?, axis) in pairs where value.isFinite {
                moved[axis] = min(max(Int((min(max(value, 0), 10) / 2.5).rounded()) + 1, 1), 5)
            }
        }
        take([(boldness, .depth), (spicy, .kick)],
             group: [spicy, boldness, sweetness, saltiness, richness, naturalTaste])
        take([(steakDoneness, .doneness), (steakMarbling, .fat), (steakFlavor, .meatiness)],
             group: [steakDoneness, steakJuiciness, steakTenderness, steakSeasoning, steakFlavor, steakMarbling])
        take([(sushiWasabi, .wasabi)],
             group: [sushiShari, sushiNeta, sushiWasabi, sushiBalance, sushiGrip, sushiTemperature])
        take([(ramenNoodle, .noodleBite), (ramenBroth, .broth)],
             group: [ramenBroth, ramenNoodle, ramenChashu, ramenTopping, ramenTemperature, ramenBalance])
        take([(wineBody, .body), (wineAcidity, .drinkAcidity)],
             group: [wineBody, wineTannin, wineAcidity, wineAroma, wineFinish, wineBalance])
        take([(coffeeAcidity, .acidity), (coffeeBody, .heaviness), (coffeeSweetness, .sweetness)],
             group: [coffeeAcidity, coffeeBody, coffeeFlavor, coffeeAftertaste, coffeeSweetness, coffeeBalance])
        tastes = moved
    }
}

enum TasteMigration {
    /// 앱을 열 때와 백업을 되살린 뒤에 한 번씩. 이미 옮긴 방문은 건너뛴다.
    @MainActor
    static func run(_ context: ModelContext) {
        let pending = FetchDescriptor<Visit>(predicate: #Predicate { $0.tasteData == nil })
        guard let visits = try? context.fetch(pending), !visits.isEmpty else { return }
        visits.forEach { $0.migrateLegacyTaste() }
        try? context.save()
    }
}

// MARK: - 기록이 말하는 취향

/// 취향 탭이 그리는 것 — 묻지 않고 방문 기록에서 센다.
struct TasteReport {
    /// 맛 지도의 점 하나 = 기본 두 축을 적은 집 하나.
    struct Spot: Identifiable {
        let restaurant: Restaurant
        let depth: Double
        let kick: Double
        var id: PersistentIdentifier { restaurant.persistentModelID }
    }

    struct Favorite: Identifiable {
        let category: FoodCategory
        let days: Int
        let regulars: Int
        var id: UUID { category.id }
    }

    struct FamilyNote: Identifiable {
        let family: TasteFamily
        let visits: Int
        let axes: [(axis: TasteAxis, value: Double)]
        var id: String { family.rawValue }
    }

    /// 계열 취향을 말하려면 그 계열에서 이만큼은 적어야 한다.
    static let familyMinimum = 3
    /// 별과 같이 움직이는 기준을 말하려면 이만큼은 적어야 한다.
    static let criterionMinimum = 5

    let spots: [Spot]
    /// 기록의 나 — 별을 많이 준 방문일수록 더 끌어당긴 기본 두 축의 평균.
    let center: (depth: Double, kick: Double)?
    let favorites: [Favorite]
    /// 별점과 가장 같이 움직이는 미식 기준. 기록이 모자라거나 뚜렷하지 않으면 nil.
    let drivingCriterion: GourmetCriterion?
    let families: [FamilyNote]

    init(restaurants: [Restaurant]) {
        let visited = restaurants.filter { !$0.isWishlist }
        let visits = visited.flatMap { $0.visits ?? [] }

        spots = visited.compactMap { restaurant in
            guard let depth = restaurant.tasteAverage(.depth), let kick = restaurant.tasteAverage(.kick) else { return nil }
            return Spot(restaurant: restaurant, depth: depth, kick: kick)
        }

        let weighted = visits.filter { $0[.depth] != nil && $0[.kick] != nil }
        let total = weighted.map(\.tasteWeight).reduce(0, +)
        center = total > 0 ? (
            weighted.map { Double($0[.depth]!) * $0.tasteWeight }.reduce(0, +) / total,
            weighted.map { Double($0[.kick]!) * $0.tasteWeight }.reduce(0, +) / total
        ) : nil

        favorites = Dictionary(grouping: visited, by: \.foodCategory)
            .map { category, places in
                Favorite(category: category,
                         days: places.map(\.regular.days).reduce(0, +),
                         regulars: places.filter { $0.regular.level >= .regular }.count)
            }
            .filter { $0.days > 0 }
            .sorted { ($0.days, $0.regulars) > ($1.days, $1.regulars) }
            .prefix(3)
            .map { $0 }

        drivingCriterion = Self.criterion(movingWithStarsIn: visits)

        families = TasteFamily.allCases.filter { !$0.axes.isEmpty }.compactMap { family in
            let noted = visits.filter { visit in family.axes.contains { visit[$0] != nil } }
            guard noted.count >= Self.familyMinimum else { return nil }
            let axes = family.axes.compactMap { axis -> (axis: TasteAxis, value: Double)? in
                let pairs = noted.compactMap { visit in visit[axis].map { (Double($0), visit.tasteWeight) } }
                let weight = pairs.map(\.1).reduce(0, +)
                guard weight > 0 else { return nil }
                return (axis, pairs.map { $0.0 * $0.1 }.reduce(0, +) / weight)
            }
            return FamilyNote(family: family, visits: noted.count, axes: axes)
        }
    }

    /// 기준 점수와 별점의 상관이 가장 큰 기준. 0.3 을 넘어야 "같이 움직인다"고 말한다.
    private static func criterion(movingWithStarsIn visits: [Visit]) -> GourmetCriterion? {
        let scored = GourmetCriterion.allCases.compactMap { criterion -> (GourmetCriterion, Double)? in
            let pairs = visits.compactMap { visit -> (Double, Double)? in
                guard visit.rating > 0, let value = visit[criterion] else { return nil }
                return (Double(value), Double(visit.rating))
            }
            guard pairs.count >= criterionMinimum, let r = correlation(pairs) else { return nil }
            return (criterion, r)
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0.3 else { return nil }
        return best.0
    }

    private static func correlation(_ pairs: [(Double, Double)]) -> Double? {
        let n = Double(pairs.count)
        let mx = pairs.map(\.0).reduce(0, +) / n, my = pairs.map(\.1).reduce(0, +) / n
        let sxy = pairs.map { ($0.0 - mx) * ($0.1 - my) }.reduce(0, +)
        let sxx = pairs.map { pow($0.0 - mx, 2) }.reduce(0, +), syy = pairs.map { pow($0.1 - my, 2) }.reduce(0, +)
        guard sxx > 0, syy > 0 else { return nil }
        return sxy / (sxx * syy).squareRoot()
    }
}

extension GourmetCriterion {
    /// "별을 많이 주는 집" 한 줄.
    var starSentence: String {
        switch self {
        case .ingredient: String(localized: "재료가 좋은 집에 별을 많이 줘요", comment: "Taste insight")
        case .technique: String(localized: "솜씨가 정확한 집에 별을 많이 줘요", comment: "Taste insight")
        case .harmony: String(localized: "맛이 잘 어울리는 집에 별을 많이 줘요", comment: "Taste insight")
        case .personality: String(localized: "그 집만의 맛이 있는 곳에 별을 많이 줘요", comment: "Taste insight")
        }
    }
}
