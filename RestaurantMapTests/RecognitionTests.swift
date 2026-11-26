//
//  RecognitionTests.swift
//  인생 맛집
//
//  인생맛집의 값 — 다시 간 집 · 단골 · 인생 맛집 단계, 100점 점수와 그 흐름, 나의 미슐랭 순위.
//

import XCTest
import SwiftData
@testable import RestaurantMap

@MainActor
final class RecognitionTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)
    private lazy var now = cal.date(from: DateComponents(year: 2026, month: 11, day: 27, hour: 12))!
    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    private func daysAgo(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now)! }

    override func setUp() async throws {
        let schema = Schema([Restaurant.self, TasteProfile.self, Visit.self, VisitPhoto.self, MenuItem.self])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    override func tearDown() async throws { container = nil }

    // MARK: - 단골 단계

    func testOneDayIsJustVisitedEvenWithManyVisits() {
        let r = Regular(visitDates: [daysAgo(3), daysAgo(3).addingTimeInterval(3_600)], now: now, calendar: cal)
        XCTAssertEqual(r.days, 1, "같은 날 두 번은 하루다")
        XCTAssertEqual(r.level, .none)
        XCTAssertNotNil(r.nextStep)
    }

    func testLevelsClimbWithDistinctDays() {
        XCTAssertEqual(Regular(visitDates: [], now: now, calendar: cal).level, .none)
        XCTAssertNil(Regular(visitDates: [], now: now, calendar: cal).nextStep)
        XCTAssertEqual(Regular(visitDates: [daysAgo(1), daysAgo(2)], now: now, calendar: cal).level, .returned)
        let regular = Regular(visitDates: (1...4).map(daysAgo), now: now, calendar: cal)
        XCTAssertEqual(regular.level, .regular)
        XCTAssertTrue(regular.isRanked)
    }

    func testLifetimeNeedsHalfAYearAndARecentVisit() {
        let longAndRecent = Regular(visitDates: [daysAgo(200), daysAgo(120), daysAgo(60), daysAgo(10)], now: now, calendar: cal)
        XCTAssertEqual(longAndRecent.level, .lifetime)
        XCTAssertNil(longAndRecent.nextStep)

        let longButQuiet = Regular(visitDates: [daysAgo(400), daysAgo(300), daysAgo(250), daysAgo(100)], now: now, calendar: cal)
        XCTAssertEqual(longButQuiet.level, .regular, "마지막 방문이 90일을 넘으면 인생 맛집이 아니다")

        let short = Regular(visitDates: [daysAgo(40), daysAgo(30), daysAgo(20), daysAgo(10)], now: now, calendar: cal)
        XCTAssertEqual(short.level, .regular)
    }

    func testRegularWhoStoppedComingIsLapsedAndUnranked() {
        let r = Regular(visitDates: [daysAgo(700), daysAgo(600), daysAgo(500), daysAgo(400)], now: now, calendar: cal)
        XCTAssertTrue(r.isLapsed)
        XCTAssertFalse(r.isRanked)
        XCTAssertNotEqual(r.title, r.level.title)
    }

    // MARK: - 100점 점수

    func testSuggestedScoreFollowsStarsAndStaysInRange() {
        let suggested = (0...6).map(VisitScore.suggested(fromStars:))
        XCTAssertEqual(Array(suggested[1...5]), [40, 55, 70, 82, 92])
        XCTAssertEqual(suggested[1...5].sorted(), Array(suggested[1...5]), "별이 많을수록 높게 시작한다")
        XCTAssertTrue(suggested.allSatisfy { VisitScore.range.contains($0) })
    }

    func testScoreBandsChangeExactlyAtTheirEdges() {
        XCTAssertEqual(VisitScore.meaning(95), VisitScore.meaning(100))
        XCTAssertNotEqual(VisitScore.meaning(94), VisitScore.meaning(95))
        XCTAssertNotEqual(VisitScore.meaning(89), VisitScore.meaning(90))
        XCTAssertNotEqual(VisitScore.meaning(49), VisitScore.meaning(50))
        XCTAssertEqual(VisitScore.meaning(0), VisitScore.meaning(49))
    }

    // MARK: - 흐름

    private func restaurant(_ name: String, scores: [(Int, Int)], wishlist: Bool = false) -> Restaurant {
        let r = Restaurant(name: name, address: "", latitude: 37.5, longitude: 127)
        r.isWishlist = wishlist
        context.insert(r)
        for (days, score) in scores {
            let v = Visit(restaurant: r, visitDate: daysAgo(days), rating: 4)
            v.score = score
            context.insert(v)
        }
        try? context.save()
        return r
    }

    func testTrendComparesFirstAndLatestVisits() throws {
        let rising = restaurant("오르는 집", scores: [(50, 70), (40, 72), (30, 80), (20, 85)])
        let trend = try XCTUnwrap(rising.scoreTrend)
        XCTAssertEqual(trend.early, 71)
        XCTAssertEqual(trend.recent, 82.5)
        XCTAssertEqual(trend.direction, .rising)

        let steady = restaurant("한결같은 집", scores: [(30, 80), (10, 83)])
        XCTAssertEqual(steady.scoreTrend?.direction, .steady)

        let once = restaurant("한 번 간 집", scores: [(5, 90)])
        XCTAssertNil(once.scoreTrend, "한 번으로는 흐름을 말할 수 없다")
        XCTAssertEqual(once.averageScore, 90)
    }

    func testVisitsWithoutScoreAreIgnoredForAverage() {
        let r = restaurant("반만 매긴 집", scores: [(10, 80), (5, 90)])
        context.insert(Visit(restaurant: r, visitDate: daysAgo(1), rating: 3))
        try? context.save()
        XCTAssertEqual(r.averageScore, 85)
        XCTAssertEqual(r.scoredVisits.count, 2)
    }

    func testTasteShiftNeedsTwoValuesAndAFullStep() throws {
        XCTAssertNil(TasteShift(axis: .depth, values: [3]))
        let moved = try XCTUnwrap(TasteShift(axis: .depth, values: [2, 2, 4, 4]))
        XCTAssertEqual(moved.change, 2)
        XCTAssertTrue(moved.isNoticeable)
        XCTAssertFalse(try XCTUnwrap(TasteShift(axis: .kick, values: [3, 3.5])).isNoticeable)
    }

    // MARK: - 나의 미슐랭

    func testSignaturePicksRankByAverageThenCountAndSkipWishlist() {
        let a = restaurant("가", scores: [(10, 90)])
        let b = restaurant("나", scores: [(10, 90), (5, 90)])
        let c = restaurant("다", scores: [(10, 95)])
        _ = restaurant("가볼 곳", scores: [(10, 99)], wishlist: true)
        _ = restaurant("점수 없음", scores: [])
        let picks = [a, b, c].signaturePicks()
        XCTAssertEqual(picks.map(\.name), ["다", "나", "가"])
        let all = (try? context.fetch(FetchDescriptor<Restaurant>())) ?? []
        XCTAssertFalse(all.signaturePicks().contains { $0.isWishlist })
        XCTAssertEqual(all.signaturePicks(seats: 2).count, 2)
    }

    func testRanksSurviveDuplicatedInput() {
        let a = restaurant("가", scores: [(10, 90)])
        let ranks = [a, a].signatureRanks()
        XCTAssertEqual(ranks[a.persistentModelID], 1)
    }
}
