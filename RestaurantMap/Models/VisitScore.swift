//
//  VisitScore.swift
//  인생 맛집
//
//  100점 만점 점수 — 방문 한 번을 절대 기준으로 매긴다. 별점(1~5)과 따로 있고, 적지 않아도 된다.
//  '절대' 라는 뜻: 다른 집과 견주어 매기지 않고, 아래 구간의 뜻에 맞춰 매긴다. 그래야 종류가 달라도 평균을 줄 세울 수 있다.
//
//  이 점수로 하는 것
//   · 내 이름을 건 맛집 — 평균 점수가 가장 높은 여섯 곳 (`signaturePicks`)
//   · 이 집 점수의 흐름 — 처음과 요즘을 견준다 (`ScoreTrend`)
//   · 내가 느끼는 맛의 변화 — 맛 축이 처음과 요즘 어느 쪽으로 옮겨 갔나 (`TasteShift`)
//

import Foundation
import SwiftData

enum VisitScore {
    static let range = 0...100

    /// 별을 먼저 골랐으면 그 별에 맞는 점수에서 시작한다. 시작점일 뿐이고 바로 고칠 수 있다.
    static func suggested(fromStars stars: Int) -> Int {
        switch stars {
        case 1: 40
        case 2: 55
        case 3: 70
        case 4: 82
        case 5: 92
        default: 70
        }
    }

    /// 점수 구간의 뜻 — 매길 때 기준이 되는 말.
    static func meaning(_ score: Int) -> String {
        switch score {
        case 95...: String(localized: "인생의 맛", comment: "Visit score band 95-100")
        case 90..<95: String(localized: "일부러 찾아갈 맛", comment: "Visit score band 90-94")
        case 80..<90: String(localized: "아주 맛있어요", comment: "Visit score band 80-89")
        case 70..<80: String(localized: "또 와도 좋아요", comment: "Visit score band 70-79")
        case 60..<70: String(localized: "괜찮아요", comment: "Visit score band 60-69")
        case 50..<60: String(localized: "그저 그래요", comment: "Visit score band 50-59")
        default: String(localized: "아쉬워요", comment: "Visit score band below 50")
        }
    }
}

// MARK: - 식당

extension Restaurant {
    /// 점수를 매긴 방문, 오래된 것부터.
    var scoredVisits: [Visit] {
        (visits ?? []).filter { !$0.isDeleted && $0.score != nil }.sorted { $0.visitDate < $1.visitDate }
    }

    /// 매긴 점수의 평균. 하나도 없으면 nil.
    var averageScore: Double? {
        let scores = scoredVisits.compactMap(\.score)
        guard !scores.isEmpty else { return nil }
        return Double(scores.reduce(0, +)) / Double(scores.count)
    }

    var scoreTrend: ScoreTrend? { ScoreTrend(visits: scoredVisits) }

    /// 처음과 요즘 사이에 맛 축이 옮겨 간 것. 두 번 넘게 적은 축만 본다.
    var tasteShifts: [TasteShift] {
        let noted = (visits ?? []).filter { !$0.isDeleted }.sorted { $0.visitDate < $1.visitDate }
        return notedTasteAxes.compactMap { axis in
            let values = noted.compactMap { $0[axis] }.map(Double.init)
            return TasteShift(axis: axis, values: values)
        }
    }
}

extension Sequence where Element == Restaurant {
    /// 내 이름을 건 맛집 — 평균 점수 → 매긴 방문 수 → 최근 방문 순. 가본 곳에서만, 여섯 자리.
    func signaturePicks(seats: Int = Regular.rankedSeats) -> [Restaurant] {
        let entries: [(Restaurant, Double)] = compactMap { restaurant in
            guard !restaurant.isGone, !restaurant.isWishlist, let average = restaurant.averageScore else { return nil }
            return (restaurant, average)
        }
        return entries.sorted { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            let (ca, cb) = (a.0.scoredVisits.count, b.0.scoredVisits.count)
            if ca != cb { return ca > cb }
            let (la, lb) = (a.0.lastVisitDate ?? .distantPast, b.0.lastVisitDate ?? .distantPast)
            if la != lb { return la > lb }
            return a.0.name < b.0.name
        }
        .prefix(seats).map(\.0)
    }

    /// 식당 → 내 이름을 건 맛집 순위(1부터).
    func signatureRanks() -> [PersistentIdentifier: Int] {
        Dictionary(signaturePicks().enumerated().map { ($1.persistentModelID, $0 + 1) }, uniquingKeysWith: { first, _ in first })
    }
}

// MARK: - 점수의 흐름

/// 처음 몇 번과 요즘 몇 번의 평균을 견준다. 두 번은 매겨야 말할 수 있다.
struct ScoreTrend {
    enum Direction { case rising, steady, falling }

    struct Point: Identifiable {
        let date: Date
        let score: Int
        let id: PersistentIdentifier
    }

    /// 이만큼 넘게 움직여야 오르거나 내렸다고 말한다.
    static let threshold = 5.0

    let points: [Point]
    let early: Double
    let recent: Double
    var change: Double { recent - early }

    var direction: Direction {
        if change >= Self.threshold { return .rising }
        if change <= -Self.threshold { return .falling }
        return .steady
    }

    init?(visits: [Visit]) {
        let points = visits.compactMap { visit in
            visit.score.map { Point(date: visit.visitDate, score: $0, id: visit.persistentModelID) }
        }
        guard points.count >= 2 else { return nil }
        self.points = points
        // 처음 · 요즘 각각 최대 세 번, 서로 겹치지 않게
        let span = Swift.max(1, Swift.min(3, points.count / 2))
        func mean(_ slice: ArraySlice<Point>) -> Double { Double(slice.map(\.score).reduce(0, +)) / Double(slice.count) }
        early = mean(points.prefix(span))
        recent = mean(points.suffix(span))
    }

    var sentence: String {
        let delta = Int(abs(change).rounded())
        switch direction {
        case .rising: return String(localized: "처음보다 \(delta)점 올랐어요. 갈수록 좋아지는 집이에요.", comment: "Score trend: rising by N points")
        case .falling: return String(localized: "처음보다 \(delta)점 내렸어요. 예전만 못하다고 느끼고 있어요.", comment: "Score trend: falling by N points")
        case .steady: return String(localized: "처음과 요즘 점수가 비슷해요. 한결같은 집이에요.", comment: "Score trend: steady")
        }
    }

    var symbol: String {
        switch direction {
        case .rising: "arrow.up.right.circle.fill"
        case .steady: "equal.circle.fill"
        case .falling: "arrow.down.right.circle.fill"
        }
    }
}

// MARK: - 맛의 변화

/// 한 맛 축이 처음과 요즘 사이에 얼마나 옮겨 갔나 (1~5).
struct TasteShift: Identifiable {
    let axis: TasteAxis
    let early: Double
    let recent: Double
    var id: String { axis.rawValue }
    var change: Double { recent - early }
    /// 한 칸(1점) 가까이 옮겨 가야 바뀌었다고 말한다.
    var isNoticeable: Bool { abs(change) >= 0.75 }

    init?(axis: TasteAxis, values: [Double]) {
        guard values.count >= 2 else { return nil }
        let span = Swift.max(1, Swift.min(3, values.count / 2))
        self.axis = axis
        early = values.prefix(span).reduce(0, +) / Double(span)
        recent = values.suffix(span).reduce(0, +) / Double(span)
    }

    /// "진함 쪽으로 옮겨 갔어요".
    var sentence: String {
        let toward = change > 0 ? axis.high : axis.low
        return String(localized: "\(toward) 쪽으로 옮겨 갔어요", comment: "Taste shift: the taste moved toward one end, e.g. 'Moved toward rich'")
    }
}
