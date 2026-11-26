import Foundation
import SwiftData
import UIKit

@Model
final class MenuItem {
    var name: String = "" // CloudKit 동기화 규칙: 기본값을 둔다
    var price: Int? // 가격 (원 단위, 옵셔널)
    var menuDescription: String = "" // 메뉴 설명
    var isSignature: Bool = false // 대표 메뉴 여부
    var restaurant: Restaurant?

    /// 이 메뉴의 사진 한 장 (줄여서 ≤1024px JPEG). 큰 데이터라 SwiftData 가 옆에 따로 둔다.
    /// 없으면 이 메뉴를 고른 방문의 사진을 쓴다 (→ `coverPhotoData`).
    @Attribute(.externalStorage) var photoData: Data?
    /// 이 메뉴에 내가 매긴 점수 1~5. 0 은 아직 안 매김 — 그때는 방문 별점의 평균을 보여 준다.
    var myRating: Int = 0
    /// 다음에 또 시킬지. nil 은 아직 안 정함.
    var wouldOrderAgain: Bool?

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

    /// 이 메뉴를 고른 방문의 사진, 최근 방문부터.
    var visitPhotos: [VisitPhoto] {
        (visits ?? []).filter { !$0.isDeleted }
            .sorted { $0.visitDate > $1.visitDate }
            .flatMap(\.sortedPhotos)
    }

    /// 목록 · 머리에 그릴 사진: 메뉴에 붙인 사진, 없으면 가장 최근 방문 사진.
    var coverPhotoData: Data? {
        photoData ?? visitPhotos.first?.data
    }

    /// 보여 줄 점수: 내가 매긴 점수, 없으면 방문 별점 평균. 둘 다 없으면 0.
    var displayRating: Double {
        myRating > 0 ? Double(myRating) : averageRating
    }

    /// 사진을 줄여(≤1024px · ≤800KB JPEG) 붙인다. nil 을 넘기면 뗀다.
    func setPhoto(_ image: UIImage?) {
        photoData = image.flatMap { PhotoStorageManager.shared.jpegData(for: $0) }
    }

    // 가격 포맷팅
    var formattedPrice: String {
        guard let price = price else { return String(localized: "가격 미정") }
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale.current
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: price)) ?? "\(price)"
    }
}
