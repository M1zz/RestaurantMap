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

    // 맛 취향 프로필 (0-10, nil = 평가하지 않음)
    var spicy: Double?
    var boldness: Double?
    var sweetness: Double?
    var saltiness: Double?
    var richness: Double?
    var naturalTaste: Double?
    var texture: Double?
    var cooking: Double?

    init(name: String, address: String, latitude: Double, longitude: Double, notes: String = "", rating: Int = 0, visitDate: Date = Date(), category: String = "", phoneNumber: String = "", isTop6: Bool = false, top6Rank: Int? = nil, categoryIcon: String = "fork.knife", spicy: Double? = nil, boldness: Double? = nil, sweetness: Double? = nil, saltiness: Double? = nil, richness: Double? = nil, naturalTaste: Double? = nil, texture: Double? = nil, cooking: Double? = nil) {
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
        self.spicy = spicy
        self.boldness = boldness
        self.sweetness = sweetness
        self.saltiness = saltiness
        self.richness = richness
        self.naturalTaste = naturalTaste
        self.texture = texture
        self.cooking = cooking
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    // 레이더 차트용 데이터 (평가된 값만)
    var tasteRadarData: [(String, Double, String)] {
        var data: [(String, Double, String)] = []
        if let spicy = spicy { data.append(("맵기", spicy, "순한 ↔ 매운")) }
        if let boldness = boldness { data.append(("진한맛", boldness, "담백 ↔ 진한")) }
        if let sweetness = sweetness { data.append(("단맛", sweetness, "안좋아함 ↔ 좋아함")) }
        if let saltiness = saltiness { data.append(("짠맛", saltiness, "싱거움 ↔ 짭짤")) }
        if let richness = richness { data.append(("기름진", richness, "담백 ↔ 고소")) }
        if let naturalTaste = naturalTaste { data.append(("본연의맛", naturalTaste, "양념 ↔ 재료맛")) }
        if let texture = texture { data.append(("질감", texture, "부드러움 ↔ 쫄깃")) }
        if let cooking = cooking { data.append(("조리법", cooking, "날것 ↔ 구이")) }
        return data
    }

    // 취향이 평가되었는지 확인
    var hasTasteProfile: Bool {
        spicy != nil || boldness != nil || sweetness != nil || saltiness != nil ||
        richness != nil || naturalTaste != nil || texture != nil || cooking != nil
    }
}
