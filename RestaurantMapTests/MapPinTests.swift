//
//  MapPinTests.swift
//  인생 맛집
//
//  지도에 세우는 저장한 식당 핀 — 수백 개를 옮겨 와도 한도만큼만, 지금 보는 곳에서 가까운 것부터.
//

import XCTest
import SwiftData
import CoreLocation
@testable import RestaurantMap

@MainActor
final class MapPinTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext { container.mainContext }

    override func setUp() async throws {
        let schema = Schema([Restaurant.self, TasteProfile.self, Visit.self, VisitPhoto.self, MenuItem.self])
        container = try ModelContainer(
            for: schema,
            configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        )
    }

    override func tearDown() async throws { container = nil }

    private func restaurant(_ name: String, _ lat: Double, _ lon: Double) -> Restaurant {
        let r = Restaurant(name: name, address: "", latitude: lat, longitude: lon)
        context.insert(r)
        return r
    }

    func testUnderTheLimitShowsEveryMappableRestaurant() {
        let list = [restaurant("a", 37.5, 127.0), restaurant("b", 35.1, 129.0), restaurant("bad", 200, 0)]
        let pins = MapView.pins(of: list, near: nil, limit: 5)
        XCTAssertEqual(pins.map(\.name), ["a", "b"], "찍을 수 없는 좌표는 빼고 나머지는 다 세운다")
    }

    func testOverTheLimitKeepsTheNearestToTheViewedCenter() {
        let list = (0..<300).map { restaurant("r\($0)", 33 + Double($0) * 0.02, 127) }
        let center = CLLocationCoordinate2D(latitude: 37, longitude: 127)  // r200 자리
        let pins = MapView.pins(of: list, near: center, limit: 10)
        XCTAssertEqual(pins.count, 10)
        XCTAssertEqual(pins.first?.name, "r200")
        XCTAssertTrue(pins.allSatisfy { abs($0.latitude - 37) <= 0.11 }, "가운데에서 가까운 것만 남는다")
    }

    func testOverTheLimitWithoutCenterStillCaps() {
        let list = (0..<20).map { restaurant("r\($0)", 37 + Double($0) * 0.01, 127) }
        XCTAssertEqual(MapView.pins(of: list, near: nil, limit: 5).count, 5)
    }

    func testDeletedRestaurantGetsNoPin() throws {
        let kept = restaurant("kept", 37.5, 127.0)
        let gone = restaurant("gone", 37.6, 127.0)
        try context.save()
        context.delete(gone)
        try context.save()
        XCTAssertEqual(MapView.pins(of: [kept, gone], near: nil, limit: 5).map(\.name), ["kept"])
    }
}
