//
//  Regular.swift
//  인생 맛집
//
//  단골 인정 — "좋아한다"는 말이 아니라 **다녀온 날**이 정한다.
//
//   · 다시 간 집   서로 다른 날 2번
//   · 단골         서로 다른 날 4번
//   · 인생 맛집    단골 + 첫 방문부터 반년 넘게 이어지고 + 최근 90일 안에 다녀옴
//   · 한때 단골    단골이었지만 1년 넘게 가지 않음 (순위에서 빠진다)
//
//  숫자의 근거 (docs/engineering/GOURMET.md):
//   · 2번 — 첫 방문 뒤 다시 오는 손님은 절반이 안 된다. 두 번째 방문부터가 선택이다.
//   · 4번 — 외식업 재방문 자료에서 네 번째 방문 뒤로 발길이 굳는다.
//   · 하루에 한 번만 센다 — 같은 날 여러 번 적어도 방문 한 번이다.
//
//  '나의 미슐랭' 은 이 인정으로 앱이 매기는 순위다. 사람이 고르지 않는다.
//

import Foundation
import SwiftData

enum RegularLevel: Int, Comparable, CaseIterable {
    case none = 0
    case returned = 1
    case regular = 2
    case lifetime = 3

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .none: String(localized: "가본 곳")
        case .returned: String(localized: "다시 간 집", comment: "Recognition level: visited on 2 different days")
        case .regular: String(localized: "단골", comment: "Recognition level: a regular, visited on 4 different days")
        case .lifetime: String(localized: "인생 맛집", comment: "Top recognition level: a long-time regular who still goes")
        }
    }

    var symbol: String {
        switch self {
        case .none: "fork.knife"
        case .returned: "repeat"
        case .regular: "heart.fill"
        case .lifetime: "crown.fill"
        }
    }
}

struct Regular: Equatable {
    static let returnedDays = 2
    static let regularDays = 4
    /// 인생 맛집: 첫 방문부터 마지막 방문까지 이만큼은 이어져야 한다.
    static let lifetimeSpanDays = 180
    /// 인생 맛집: 마지막 방문이 이 안에 있어야 한다.
    static let lifetimeRecentDays = 90
    /// 이보다 오래 안 가면 한때 단골.
    static let lapseDays = 365
    /// 나의 미슐랭에 오르는 자리 수.
    static let rankedSeats = 6

    /// 다녀온 서로 다른 날 수.
    let days: Int
    let first: Date?
    let last: Date?
    let level: RegularLevel
    /// 단골이었지만 오래 가지 않았다.
    let isLapsed: Bool

    init(visitDates: [Date], now: Date = Date(), calendar: Calendar = .current) {
        let unique = Set(visitDates.map { calendar.startOfDay(for: $0) }).sorted()
        days = unique.count
        first = unique.first
        last = unique.last

        func daysBetween(_ a: Date, _ b: Date) -> Int {
            calendar.dateComponents([.day], from: a, to: b).day ?? 0
        }
        guard let first, let last, days >= Self.returnedDays else {
            level = .none; isLapsed = false; return
        }
        guard days >= Self.regularDays else {
            level = .returned; isLapsed = false; return
        }
        let quiet = daysBetween(last, calendar.startOfDay(for: now))
        isLapsed = quiet > Self.lapseDays
        let lasting = daysBetween(first, last) >= Self.lifetimeSpanDays
        level = (lasting && quiet <= Self.lifetimeRecentDays) ? .lifetime : .regular
    }

    /// 화면에 보일 이름. 한때 단골은 단계 이름 대신 이것을 쓴다.
    var title: String {
        isLapsed ? String(localized: "한때 단골", comment: "Was a regular but has not visited for over a year") : level.title
    }

    /// 순위에 오를 자격.
    var isRanked: Bool { level >= .regular && !isLapsed }

    /// 다음 단계까지 남은 것을 한 줄로. 더 오를 데가 없으면 nil.
    var nextStep: String? {
        if isLapsed {
            return String(localized: "다시 가면 단골로 돌아와요", comment: "Hint for a lapsed regular")
        }
        switch level {
        case .none:
            return days == 0 ? nil : String(localized: "한 번 더 가면 다시 간 집이 돼요", comment: "Hint: one more visit to reach the first recognition level")
        case .returned:
            let left = Self.regularDays - days
            return String(localized: "\(left)번 더 가면 단골이에요", comment: "Hint: N more visits to become a regular")
        case .regular:
            return String(localized: "반년 넘게 꾸준히 가면 인생 맛집이 돼요", comment: "Hint: keep visiting for over six months to reach the top level")
        case .lifetime:
            return nil
        }
    }
}

extension Restaurant {
    /// 다녀온 날들. 방문 기록이 없는 가본 곳은 처음 적은 날 하루로 친다 (예전 기록은 방문을 따로 남기지 않았다).
    var visitDates: [Date] {
        let dates = (visits ?? []).map(\.visitDate)
        if dates.isEmpty { return isWishlist ? [] : [visitDate] }
        return dates
    }

    var regular: Regular { Regular(visitDates: visitDates) }
}

extension Sequence where Element == Restaurant {
    /// 나의 미슐랭 — 단골 이상을 앱이 줄 세운다. 단계 → 다녀온 날 수 → 평균 별점 → 최근 방문 순.
    /// 같은 자리가 둘일 수 없고, 자리는 여섯이다.
    func rankedRegulars(seats: Int = Regular.rankedSeats) -> [Restaurant] {
        let entries: [(Restaurant, Regular)] = compactMap { restaurant in
            let regular = restaurant.regular
            return regular.isRanked ? (restaurant, regular) : nil
        }
        let sorted = entries.sorted { a, b in
            if a.1.level != b.1.level { return a.1.level > b.1.level }
            if a.1.days != b.1.days { return a.1.days > b.1.days }
            let (ra, rb) = (a.0.averageRating, b.0.averageRating)
            if ra != rb { return ra > rb }
            let (la, lb) = (a.1.last ?? .distantPast, b.1.last ?? .distantPast)
            if la != lb { return la > lb }
            return a.0.name < b.0.name
        }
        return sorted.prefix(seats).map(\.0)
    }

    /// 식당 → 순위(1부터). 순위에 없는 식당은 들어 있지 않다.
    func regularRanks() -> [PersistentIdentifier: Int] {
        // 같은 식당이 두 번 들어온 목록(화면이 합쳐 넘긴 배열 등)이어도 죽지 않게 — 겹치면 앞 순위를 쓴다.
        Dictionary(rankedRegulars().enumerated().map { ($1.persistentModelID, $0 + 1) }, uniquingKeysWith: { first, _ in first })
    }
}
