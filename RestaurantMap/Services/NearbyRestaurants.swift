//
//  NearbyRestaurants.swift
//  인생 맛집
//
//  한 지점 둘레의 식당 · 카페 찾기 (애플 지도 장소). 두 곳에서 쓴다:
//   · 식당 추가 — 지금 있는 자리 근처 식당을 "혹시 여기인가요?" 로 띄운다
//   · 사진으로 불러오기 — 사진이 찍힌 자리에서 가장 가까운 식당을 고른다
//

import Foundation
import MapKit

enum NearbyRestaurants {
    /// 먹고 마시는 곳만.
    static let categories: [MKPointOfInterestCategory] = [.restaurant, .cafe, .bakery, .brewery, .winery, .foodMarket, .nightlife]

    /// 가까운 순서로. 못 찾았거나 연결이 끊겼으면 빈 배열.
    static func search(around coordinate: CLLocationCoordinate2D,
                       radius: CLLocationDistance = 150, limit: Int = 8) async -> [MKMapItem] {
        guard coordinate.isMappable else { return [] }
        let request = MKLocalPointsOfInterestRequest(center: coordinate, radius: radius)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        guard let response = try? await MKLocalSearch(request: request).start() else { return [] }
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return response.mapItems
            .filter { $0.placemark.coordinate.isMappable && !($0.name ?? "").isEmpty }
            .sorted { distance($0, from: here) < distance($1, from: here) }
            .prefix(limit).map { $0 }
    }

    static func distance(_ item: MKMapItem, from location: CLLocation) -> CLLocationDistance {
        let c = item.placemark.coordinate
        return CLLocation(latitude: c.latitude, longitude: c.longitude).distance(from: location)
    }

    /// "40m", "1.2km" — 기기 언어 · 단위에 맞춰.
    static func distanceText(_ meters: CLLocationDistance) -> String {
        Measurement(value: meters.rounded(), unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }
}
