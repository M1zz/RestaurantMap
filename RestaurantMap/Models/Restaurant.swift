import Foundation
import SwiftData
import MapKit

@Model
final class Restaurant {
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var notes: String
    var rating: Int
    var visitDate: Date
    var category: String
    var phoneNumber: String
    var isTop6: Bool
    var top6Rank: Int?
    var categoryIcon: String

    // 방문 기록들
    @Relationship(deleteRule: .cascade, inverse: \Visit.restaurant)
    var visits: [Visit]?

    init(name: String, address: String, latitude: Double, longitude: Double, notes: String = "", rating: Int = 0, visitDate: Date = Date(), category: String = "", phoneNumber: String = "", isTop6: Bool = false, top6Rank: Int? = nil, categoryIcon: String = "fork.knife") {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
        self.rating = rating
        self.visitDate = visitDate
        self.category = category
        self.phoneNumber = phoneNumber
        self.isTop6 = isTop6
        self.top6Rank = top6Rank
        self.categoryIcon = categoryIcon
        self.visits = []
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // 방문 횟수
    var visitCount: Int {
        visits?.count ?? 0
    }

    // 최근 방문일
    var lastVisitDate: Date? {
        visits?.sorted(by: { $0.visitDate > $1.visitDate }).first?.visitDate
    }

    // 평균 별점
    var averageRating: Double {
        guard let visits = visits, !visits.isEmpty else { return Double(rating) }
        let sum = visits.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(visits.count)
    }

    // 총평 - 평균 맛 강도
    var averageIntensity: [(String, Double)] {
        guard let visits = visits, !visits.isEmpty else { return [] }

        let validVisits = visits.filter { $0.hasTasteProfile }
        guard !validVisits.isEmpty else { return [] }

        let avgSpicy = validVisits.compactMap { $0.spicy }.average
        let avgBoldness = validVisits.compactMap { $0.boldness }.average
        let avgSweetness = validVisits.compactMap { $0.sweetness }.average
        let avgSaltiness = validVisits.compactMap { $0.saltiness }.average
        let avgRichness = validVisits.compactMap { $0.richness }.average
        let avgNaturalTaste = validVisits.compactMap { $0.naturalTaste }.average

        return [
            ("맵기", avgSpicy),
            ("진한맛", avgBoldness),
            ("단맛", avgSweetness),
            ("짠맛", avgSaltiness),
            ("기름진", avgRichness),
            ("본연의맛", avgNaturalTaste)
        ]
    }

    // 총평 - 평균 적절함
    var averageAppropriateness: [(String, Double)] {
        guard let visits = visits, !visits.isEmpty else { return [] }

        let validVisits = visits.filter { $0.hasTasteProfile }
        guard !validVisits.isEmpty else { return [] }

        let avgSpicy = validVisits.compactMap { $0.spicyAppropriate }.map { Double($0) }.average * 2
        let avgBoldness = validVisits.compactMap { $0.boldnessAppropriate }.map { Double($0) }.average * 2
        let avgSweetness = validVisits.compactMap { $0.sweetnessAppropriate }.map { Double($0) }.average * 2
        let avgSaltiness = validVisits.compactMap { $0.saltinessAppropriate }.map { Double($0) }.average * 2
        let avgRichness = validVisits.compactMap { $0.richnessAppropriate }.map { Double($0) }.average * 2
        let avgNaturalTaste = validVisits.compactMap { $0.naturalTasteAppropriate }.map { Double($0) }.average * 2

        return [
            ("맵기", avgSpicy),
            ("진한맛", avgBoldness),
            ("단맛", avgSweetness),
            ("짠맛", avgSaltiness),
            ("기름진", avgRichness),
            ("본연의맛", avgNaturalTaste)
        ]
    }

    // 방문 기록이 있는지 확인
    var hasVisits: Bool {
        !(visits?.isEmpty ?? true)
    }
}

// 배열 평균 계산 확장
extension Array where Element == Double {
    var average: Double {
        isEmpty ? 5.0 : reduce(0, +) / Double(count)
    }
}
