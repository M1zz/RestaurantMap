import Foundation
import SwiftData

@Model
final class MenuItem {
    var name: String
    var price: Int? // 가격 (원 단위, 옵셔널)
    var menuDescription: String = "" // 메뉴 설명
    var isSignature: Bool = false // 대표 메뉴 여부
    var restaurant: Restaurant?

    // 이 메뉴에 대한 방문 기록들
    @Relationship(deleteRule: .nullify, inverse: \Visit.menu)
    var visits: [Visit]?

    init(name: String, price: Int? = nil, menuDescription: String = "", isSignature: Bool = false, restaurant: Restaurant? = nil) {
        self.name = name
        self.price = price
        self.menuDescription = menuDescription
        self.isSignature = isSignature
        self.restaurant = restaurant
        self.visits = []
    }

    // 이 메뉴를 먹은 횟수
    var orderCount: Int {
        visits?.count ?? 0
    }

    // 평균 별점
    var averageRating: Double {
        guard let visits = visits, !visits.isEmpty else { return 0 }
        let sum = visits.reduce(0) { $0 + $1.rating }
        return Double(sum) / Double(visits.count)
    }

    // 최근 방문일
    var lastOrderDate: Date? {
        visits?.sorted(by: { $0.visitDate > $1.visitDate }).first?.visitDate
    }

    // 가격 포맷팅
    var formattedPrice: String {
        guard let price = price else { return "가격 미정" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: price)) ?? "0")원"
    }
}
