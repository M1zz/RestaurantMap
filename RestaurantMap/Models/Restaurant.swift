import Foundation
import SwiftData
import MapKit

// 식당 구분. 나의 미슐랭은 구분이 아니다 — 다녀온 날로 앱이 매긴다 (→ Regular.swift).
enum RestaurantListType: String, Codable, CaseIterable {
    case visited = "가본 곳"        // 실제로 방문한 식당
    case wishlist = "가볼 곳"       // 가보고 싶은 식당 (위시리스트)

    // rawValue 는 저장·비교용 식별자라 그대로 두고, 화면 표시만 현지화한다.
    var displayName: String {
        switch self {
        case .visited: return String(localized: "가본 곳")
        case .wishlist: return String(localized: "가볼 곳")
        }
    }

    var icon: String {
        switch self {
        case .visited: return "checkmark.circle.fill"
        case .wishlist: return "star.circle.fill"
        }
    }
}

@Model
final class Restaurant {
    // CloudKit 동기화 규칙: 모든 속성은 옵셔널이거나 기본값이 있고, 관계는 옵셔널이다. 저장 파일은 그대로다.
    var name: String = ""
    var address: String = ""
    var latitude: Double = 0
    var longitude: Double = 0
    var notes: String = ""
    var rating: Int = 0
    var visitDate: Date = Date()
    var category: String = ""
    var phoneNumber: String = ""
    /// 예전에 직접 고르던 탑6. 이제 쓰지 않는다 — 저장 파일 · iCloud 틀을 그대로 두려고 남긴다.
    var isTop6: Bool = false
    var top6Rank: Int?
    var categoryIcon: String = "fork.knife"
    var foodCategoryId: String = FoodCategoryRepository.builtInCategories[0].id.uuidString
    var isWishlist: Bool = false  // 가볼 곳 여부 (Boolean은 마이그레이션이 안전함)
    /// 공개한 단골 후기의 ID. 올리지 않았으면 nil (→ RegularReviews).
    var sharedReviewID: String?
    /// 이 집을 왜 계속 가는지 나만 보는 한마디. 올리지 않아도 남는다 (→ ReviewFeedView 의 내 단골집).
    var regularWord: String = ""
    /// 보고 저장한 글 · 영상의 주소 (인스타 · 블로그에서 공유로 담았을 때). 없으면 빈 글 (→ ShareInboxReceiver).
    var sourceLink: String = ""

    // 방문 기록들
    @Relationship(deleteRule: .cascade, inverse: \Visit.restaurant)
    var visits: [Visit]?

    // 메뉴들
    @Relationship(deleteRule: .cascade, inverse: \MenuItem.restaurant)
    var menus: [MenuItem]?

    // FoodCategory 편의 속성
    var foodCategory: FoodCategory {
        get {
            guard let uuid = UUID(uuidString: foodCategoryId),
                  let category = FoodCategoryRepository.shared.findCategory(by: uuid) else {
                return FoodCategoryRepository.builtInCategories[0] // 일반
            }
            return category
        }
        set {
            foodCategoryId = newValue.id.uuidString
        }
    }

    // RestaurantListType 편의 속성
    var listType: RestaurantListType {
        get { isWishlist ? .wishlist : .visited }
        set { isWishlist = (newValue == .wishlist) }
    }

    init(name: String, address: String, latitude: Double, longitude: Double, notes: String = "", rating: Int = 0, visitDate: Date = Date(), category: String = "", phoneNumber: String = "", categoryIcon: String = "fork.knife", foodCategory: FoodCategory = FoodCategoryRepository.builtInCategories[0], listType: RestaurantListType = .visited) {
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.notes = notes
        self.rating = rating
        self.visitDate = visitDate
        self.category = category
        self.phoneNumber = phoneNumber
        self.categoryIcon = categoryIcon
        self.foodCategoryId = foodCategory.id.uuidString

        // listType에 따라 isWishlist 설정
        self.isWishlist = (listType == .wishlist)

        self.visits = []
        self.menus = []
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

    // 방문 기록이 있는지 확인
    var hasVisits: Bool {
        !(visits?.isEmpty ?? true)
    }
}
