import Foundation
import SwiftData
import UIKit

@Model
final class Visit {
    var restaurant: Restaurant?
    var menu: MenuItem? // 선택한 메뉴 (메뉴 등록된 경우)
    // CloudKit 동기화 규칙: 모든 속성은 옵셔널이거나 기본값이 있고, 관계는 옵셔널이다.
    var visitDate: Date = Date()
    var notes: String = ""
    var rating: Int = 0
    var menuItem: String = "" // 먹은 메뉴 이름 (텍스트, 하위 호환용)
    /// 옛 저장 방식의 사진 파일명. 첫 실행 때 `photos` 로 옮기고 비운다(→ PhotoMigration). 새로 쓰지 않는다.
    var photoFilenames: [String] = []
    var photoId: UUID = UUID() // 방문을 가리키는 고정 ID (백업 레코드 이름 · 옛 사진 폴더 이름)

    /// 방문 사진. 기록과 함께 iCloud 로 따라간다.
    @Relationship(deleteRule: .cascade, inverse: \VisitPhoto.visit)
    var photos: [VisitPhoto]?

    // 미식 기준 (1-5, 모두 선택) — 접시 위의 음식만 본다 (→ Gourmet.swift)
    var gourmetIngredient: Int?
    var gourmetTechnique: Int?
    var gourmetHarmony: Int?
    var gourmetPersonality: Int?

    /// 100점 만점 점수 (0~100, 선택). 별점과 따로, 이 방문 한 번을 절대 기준으로 매긴다 (→ VisitScore.swift).
    var score: Int?

    /// 맛 기록 — 축 이름 → 1~5 를 JSON 으로 담은 한 칸 (→ Taste.swift `tastes`).
    var tasteData: Data?

    // ── 옛 맛 평가 칸 (0~10 강도 · 1~5 적절함). 더 쓰지 않는다 ──
    // 뜻이 같은 것은 TasteMigration 이 새 축으로 옮겼다. iCloud 틀과 옛 백업을 읽으려고 칸만 남긴다.

    // 일반 맛 취향 프로필 - 강도 (0-10)
    var spicy: Double?
    var boldness: Double?
    var sweetness: Double?
    var saltiness: Double?
    var richness: Double?
    var naturalTaste: Double?
    var texture: Double?
    var cooking: Double?

    // 일반 맛 취향 프로필 - 적절함 (1-5)
    var spicyAppropriate: Int?
    var boldnessAppropriate: Int?
    var sweetnessAppropriate: Int?
    var saltinessAppropriate: Int?
    var richnessAppropriate: Int?
    var naturalTasteAppropriate: Int?
    var textureAppropriate: Int?
    var cookingAppropriate: Int?

    // 스테이크 전용 평가 - 강도 (0-10)
    var steakDoneness: Double? // 굽기
    var steakJuiciness: Double? // 육즙
    var steakTenderness: Double? // 부드러움
    var steakSeasoning: Double? // 간
    var steakFlavor: Double? // 육향
    var steakMarbling: Double? // 마블링

    // 스테이크 전용 평가 - 적절함 (1-5)
    var steakDonenessAppropriate: Int?
    var steakJuicinessAppropriate: Int?
    var steakTendernessAppropriate: Int?
    var steakSeasoningAppropriate: Int?
    var steakFlavorAppropriate: Int?
    var steakMarblingAppropriate: Int?

    // 초밥 전용 평가 - 강도 (0-10)
    var sushiShari: Double? // 샤리(밥)
    var sushiNeta: Double? // 네타(재료)
    var sushiWasabi: Double? // 와사비
    var sushiBalance: Double? // 밸런스
    var sushiGrip: Double? // 쥐기
    var sushiTemperature: Double? // 온도

    // 초밥 전용 평가 - 적절함 (1-5)
    var sushiShariAppropriate: Int?
    var sushiNetaAppropriate: Int?
    var sushiWasabiAppropriate: Int?
    var sushiBalanceAppropriate: Int?
    var sushiGripAppropriate: Int?
    var sushiTemperatureAppropriate: Int?

    // 라멘 전용 평가 - 강도 (0-10)
    var ramenBroth: Double? // 국물
    var ramenNoodle: Double? // 면발
    var ramenChashu: Double? // 차슈
    var ramenTopping: Double? // 토핑
    var ramenTemperature: Double? // 온도
    var ramenBalance: Double? // 밸런스

    // 라멘 전용 평가 - 적절함 (1-5)
    var ramenBrothAppropriate: Int?
    var ramenNoodleAppropriate: Int?
    var ramenChashuAppropriate: Int?
    var ramenToppingAppropriate: Int?
    var ramenTemperatureAppropriate: Int?
    var ramenBalanceAppropriate: Int?

    // 피자 전용 평가 - 강도 (0-10)
    var pizzaDough: Double? // 도우
    var pizzaSauce: Double? // 소스
    var pizzaCheese: Double? // 치즈
    var pizzaBaking: Double? // 굽기
    var pizzaTopping: Double? // 토핑
    var pizzaBalance: Double? // 밸런스

    // 피자 전용 평가 - 적절함 (1-5)
    var pizzaDoughAppropriate: Int?
    var pizzaSauceAppropriate: Int?
    var pizzaCheeseAppropriate: Int?
    var pizzaBakingAppropriate: Int?
    var pizzaToppingAppropriate: Int?
    var pizzaBalanceAppropriate: Int?

    // 와인 전용 평가 - 강도 (0-10)
    var wineBody: Double? // 바디
    var wineTannin: Double? // 타닌
    var wineAcidity: Double? // 산도
    var wineAroma: Double? // 아로마
    var wineFinish: Double? // 피니시
    var wineBalance: Double? // 밸런스

    // 와인 전용 평가 - 적절함 (1-5)
    var wineBodyAppropriate: Int?
    var wineTanninAppropriate: Int?
    var wineAcidityAppropriate: Int?
    var wineAromaAppropriate: Int?
    var wineFinishAppropriate: Int?
    var wineBalanceAppropriate: Int?

    // 커피 전용 평가 - 강도 (0-10)
    var coffeeAcidity: Double? // 산미
    var coffeeBody: Double? // 바디
    var coffeeFlavor: Double? // 향미
    var coffeeAftertaste: Double? // 후미
    var coffeeSweetness: Double? // 단맛
    var coffeeBalance: Double? // 밸런스

    // 커피 전용 평가 - 적절함 (1-5)
    var coffeeAcidityAppropriate: Int?
    var coffeeBodyAppropriate: Int?
    var coffeeFlavorAppropriate: Int?
    var coffeeAftertasteAppropriate: Int?
    var coffeeSweetnessAppropriate: Int?
    var coffeeBalanceAppropriate: Int?

    init(restaurant: Restaurant? = nil, visitDate: Date = Date(), notes: String = "", rating: Int = 0) {
        self.restaurant = restaurant
        self.visitDate = visitDate
        self.notes = notes
        self.rating = rating
    }

    // 표시할 메뉴 이름 (Menu 우선, 없으면 menuItem)
    var displayMenuName: String {
        if let menu = menu {
            return menu.name
        }
        return menuItem
    }

    // 사진 관련 computed properties
    /// 넣은 순서대로.
    var sortedPhotos: [VisitPhoto] {
        // 지우기로 표시된 사진은 뺀다 — 저장 전까지 관계에 남아 있을 수 있고, 저장된 뒤에 읽으면 죽는다.
        (photos ?? []).filter { !$0.isDeleted }
            .sorted { ($0.sortOrder, $0.createdAt) < ($1.sortOrder, $1.createdAt) }
    }

    var heroPhoto: VisitPhoto? {
        sortedPhotos.first
    }

    var hasPhotos: Bool {
        !(photos?.isEmpty ?? true)
    }

    /// 사진을 줄여(≤1024px · ≤800KB JPEG) 기록에 붙인다. 이 방문이 컨텍스트에 들어갈 때 사진도 같이 들어간다.
    @discardableResult
    func addPhoto(_ image: UIImage) -> VisitPhoto? {
        guard let data = PhotoStorageManager.shared.jpegData(for: image) else { return nil }
        let photo = VisitPhoto(data: data, sortOrder: (sortedPhotos.last?.sortOrder ?? -1) + 1)
        if photos == nil { photos = [] }
        photos?.append(photo)
        return photo
    }
}
