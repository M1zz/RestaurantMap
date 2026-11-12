#if DEBUG
import Foundation
import SwiftData

/// App Store 스크린샷용 (DEBUG 전용). `-screenshotScene <map|list|detail|taste>` 로 띄우면
/// 저장소를 예시 식당으로 채우고 그 장면을 연다. 식당 이름은 기기 언어를 따른다.
/// → scripts/capture_vision_screenshots.sh
enum ScreenshotScene: String {
    case map, list, detail, taste

    static var current: ScreenshotScene? {
        UserDefaults.standard.string(forKey: "screenshotScene").flatMap(Self.init(rawValue:))
    }

    var tab: Int {
        switch self {
        case .map: 0
        case .list, .detail: 1
        case .taste: 3
        }
    }
}

enum ScreenshotSeed {
    /// 장면을 띄울 때만, 저장소를 비우고 예시로 채운다.
    @MainActor
    static func runIfRequested(_ container: ModelContainer) {
        guard ScreenshotScene.current != nil else { return }
        let context = container.mainContext
        try? context.delete(model: Visit.self)
        try? context.delete(model: MenuItem.self)
        try? context.delete(model: Restaurant.self)
        try? context.delete(model: TasteProfile.self)

        let names = Self.names(for: Locale.preferredLanguages.first ?? "en")
        let cats = FoodCategoryRepository.builtInCategories
        let day: (Int) -> Date = { Calendar.current.date(byAdding: .day, value: -$0, to: .now)! }
        // (이름 순서, 분류, 서울 성수 근처 좌표, 별점, 방문 수, 탑6 순위, 가볼 곳)
        let rows: [(Int, Int, Double, Double, Int, Int, Int?, Bool)] = [
            (0, 1, 37.5446, 127.0557, 5, 3, 1, false),
            (1, 2, 37.5471, 127.0442, 5, 2, 2, false),
            (2, 3, 37.5408, 127.0569, 5, 4, 3, false),
            (3, 5, 37.5489, 127.0503, 4, 2, 4, false),
            (4, 4, 37.5431, 127.0478, 4, 2, 5, false),
            (5, 0, 37.5395, 127.0505, 5, 3, 6, false),
            (6, 6, 37.5459, 127.0591, 4, 2, nil, false),
            (7, 0, 37.5502, 127.0461, 0, 0, nil, true),
        ]
        var first: Restaurant?
        for (i, (n, c, lat, lon, rating, count, rank, wish)) in rows.enumerated() {
            let r = Restaurant(name: names[n], address: "", latitude: lat, longitude: lon,
                               rating: rating, visitDate: day(5 + i * 9),
                               category: c == 5 ? "MKPOICategoryBar" : c == 6 ? "MKPOICategoryCafe" : "MKPOICategoryRestaurant",
                               isTop6: rank != nil, top6Rank: rank, foodCategory: cats[c],
                               listType: wish ? .wishlist : .visited)
            context.insert(r)
            for v in 0..<count {
                let visit = Visit(restaurant: r, visitDate: day(5 + i * 9 + v * 21), rating: rating)
                if c == 1 { // 스테이크: 상세 화면에 맛 평가 차트가 보이게
                    visit.steakDoneness = [6.5, 7, 6][v % 3]
                    visit.steakJuiciness = [8.5, 9, 8][v % 3]
                    visit.steakTenderness = [8, 8.5, 9][v % 3]
                    visit.steakSeasoning = [7, 6.5, 7.5][v % 3]
                    visit.steakFlavor = [9, 8.5, 9][v % 3]
                    visit.steakMarbling = [7.5, 8, 7][v % 3]
                }
                context.insert(visit)
            }
            if first == nil { first = r }
        }
        context.insert(TasteProfile(spicy: 6.5, boldness: 7, sweetness: 4, saltiness: 5.5, richness: 7.5))
        try? context.save()
        if ScreenshotScene.current == .detail, let first {
            RestaurantRouter.shared.restaurantID = first.persistentModelID
        }
    }

    /// 탑6 여섯 · 가본 곳 · 가볼 곳 하나씩. 라틴 문자 언어는 영어 상호를 그대로 쓴다 (상호는 번역하지 않는다).
    private static func names(for language: String) -> [String] {
        let code = language.lowercased()
        if code.hasPrefix("ko") { return ["불과 참나무", "스시 하루", "멘야 소라", "코르크 바", "나폴리 화덕", "럭키 식당", "로스터리 모먼트", "블루밍 브런치"] }
        if code.hasPrefix("ja") { return ["炎と樫", "鮨 はる", "麺屋 そら", "コルク バル", "ナポリ窯", "ラッキー食堂", "ロースタリー モーメント", "ブルーミング ブランチ"] }
        if code.hasPrefix("zh-hant") || code.hasPrefix("zh-tw") || code.hasPrefix("zh-hk") { return ["炭火橡木", "壽司春", "麵屋空", "軟木塞酒館", "拿坡里窯烤", "幸運食堂", "烘焙時光", "花開早午餐"] }
        if code.hasPrefix("zh") { return ["炭火橡木", "寿司春", "面屋空", "软木塞酒馆", "那不勒斯窑烤", "幸运食堂", "烘焙时光", "花开早午餐"] }
        if code.hasPrefix("th") { return ["เอ็มเบอร์ แอนด์ โอ๊ค", "ซูชิ ฮารุ", "เมนยะ โซระ", "คอร์กสกรูว์ บาร์", "นาโปลี โอเวน", "ลัคกี้ ไดเนอร์", "โรสเตอรี โมเมนต์", "บลูมมิง บรันช์"] }
        if code.hasPrefix("ru") { return ["Угли и дуб", "Суши Хару", "Мэнъя Сора", "Пробка", "Неаполь", "Лаки Дайнер", "Обжарка", "Бранч в цвету"] }
        if code.hasPrefix("el") { return ["Κάρβουνο & Βελανιδιά", "Sushi Haru", "Menya Sora", "Φελλός", "Napoli Oven", "Lucky Diner", "Roastery Moment", "Blooming Brunch"] }
        return ["Ember & Oak", "Sushi Haru", "Menya Sora", "Corkscrew Bar", "Napoli Oven", "Lucky Diner", "Roastery Moment", "Blooming Brunch"]
    }
}
#endif
