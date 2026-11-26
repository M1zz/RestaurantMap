import SwiftUI

// MARK: - FoodCategory (Struct)

struct FoodCategory: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let isCustom: Bool
    let isBuiltIn: Bool
    /// 옛 평가 방식. 더 쓰지 않는다 — 저장해 둔 종류 · 옛 백업을 읽으려고 남긴다.
    var evaluationType: EvaluationType = .general
    /// 맛 기록 계열 (→ Taste.swift). 옛 직접 만든 종류에는 없어서 nil 이면 기본이다.
    var family: TasteFamily?

    var tasteFamily: TasteFamily { family ?? .basic }

    /// 화면 표시용 이름. 기본 카테고리는 현지화하고, 사용자가 만든 카테고리는 입력한 그대로 보여 준다.
    /// `name` 은 식별자(딕셔너리 키 등)로도 쓰이므로 바꾸지 않는다.
    var localizedName: String {
        isBuiltIn ? String(localized: String.LocalizationValue(name)) : name
    }

    var displayName: String {
        "\(icon) \(localizedName)"
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: FoodCategory, rhs: FoodCategory) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - EvaluationType

enum EvaluationType: String, Codable {
    case general
    case steak
    case sushi
    case ramen
    case pizza
    case wine
    case coffee
}

// MARK: - FoodCategoryRepository

class FoodCategoryRepository: ObservableObject {
    static let shared = FoodCategoryRepository()

    @Published var customCategories: [FoodCategory] = []

    private let customCategoriesKey = "customFoodCategories"

    // 기본 제공 카테고리 28개 (고정 UUID 사용)
    static let builtInCategories: [FoodCategory] = [
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            name: "일반",
            icon: "🍽️",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "스테이크",
            icon: "🥩",
            isCustom: false,
            isBuiltIn: true,
            family: .meat
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "초밥",
            icon: "🍣",
            isCustom: false,
            isBuiltIn: true,
            family: .seafood
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "라멘",
            icon: "🍜",
            isCustom: false,
            isBuiltIn: true,
            family: .noodle
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "피자",
            icon: "🍕",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            name: "와인",
            icon: "🍷",
            isCustom: false,
            isBuiltIn: true,
            family: .drink
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            name: "커피",
            icon: "☕",
            isCustom: false,
            isBuiltIn: true,
            family: .sweet
        ),
        // 새로 추가되는 8개 카테고리
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            name: "중식",
            icon: "🥟",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            name: "일식",
            icon: "🍱",
            isCustom: false,
            isBuiltIn: true,
            family: .seafood
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
            name: "한식",
            icon: "🍲",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
            name: "양식",
            icon: "🍝",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!,
            name: "치킨",
            icon: "🍗",
            isCustom: false,
            isBuiltIn: true,
            family: .meat
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000D")!,
            name: "버거",
            icon: "🍔",
            isCustom: false,
            isBuiltIn: true,
            family: .meat
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000E")!,
            name: "디저트",
            icon: "🍰",
            isCustom: false,
            isBuiltIn: true,
            family: .sweet
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000F")!,
            name: "술집",
            icon: "🍺",
            isCustom: false,
            isBuiltIn: true,
            family: .drink
        ),
        // 2026-11-26 더한 13개 — "음식 종류가 모자라다" 는 피드백. 순서 · id 를 바꾸지 말고 뒤에만 더한다 (저장값 · 스크린샷 시드가 자리로 고른다)
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            name: "베이커리",
            icon: "🥐",
            isCustom: false,
            isBuiltIn: true,
            family: .sweet
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            name: "훠궈",
            icon: "🫕",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
            name: "바비큐",
            icon: "🍖",
            isCustom: false,
            isBuiltIn: true,
            family: .meat
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
            name: "해산물",
            icon: "🦐",
            isCustom: false,
            isBuiltIn: true,
            family: .seafood
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000014")!,
            name: "면 요리",
            icon: "🥢",
            isCustom: false,
            isBuiltIn: true,
            family: .noodle
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!,
            name: "분식",
            icon: "🍢",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000016")!,
            name: "동남아",
            icon: "🌶️",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000017")!,
            name: "카레",
            icon: "🍛",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000018")!,
            name: "멕시칸",
            icon: "🌮",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000019")!,
            name: "샐러드",
            icon: "🥗",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000001A")!,
            name: "브런치",
            icon: "🥞",
            isCustom: false,
            isBuiltIn: true,
            family: .sweet
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000001B")!,
            name: "차 · 음료",
            icon: "🧋",
            isCustom: false,
            isBuiltIn: true,
            family: .sweet
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000001C")!,
            name: "패스트푸드",
            icon: "🍟",
            isCustom: false,
            isBuiltIn: true,
            family: .basic
        )
    ]

    /// 지도 장소의 분류 · 이름으로 음식 종류를 어림한다. 모르면 '일반'.
    /// `hints` 는 카카오 분류("음식점 > 한식 > 육류,고기") · 애플 지도 분류 raw 값 · 식당 이름을 함께 받는다.
    static func guess(from hints: [String]) -> FoodCategory {
        let text = hints.joined(separator: " ").lowercased()
        // 위에서부터 먼저 맞는 것을 고른다 — 좁은 것(훠궈 · 초밥)을 넓은 것(중식 · 일식)보다 먼저 둔다
        let rules: [(String, [String])] = [
            ("훠궈", ["훠궈", "火锅", "火鍋", "hot pot", "hotpot", "샤브"]),
            ("초밥", ["초밥", "스시", "寿司", "壽司", "sushi"]),
            ("라멘", ["라멘", "拉面", "ラーメン", "ramen"]),
            ("스테이크", ["스테이크", "牛排", "steak"]),
            ("바비큐", ["바비큐", "고기", "육류", "烧烤", "燒烤", "烤肉", "bbq", "barbecue", "yakiniku"]),
            ("치킨", ["치킨", "炸鸡", "chicken"]),
            ("피자", ["피자", "披萨", "pizza"]),
            ("버거", ["버거", "汉堡", "burger"]),
            ("해산물", ["해산물", "해물", "횟집", "海鲜", "海鮮", "seafood", "oyster"]),
            ("카레", ["카레", "인도", "咖喱", "curry", "indian"]),
            ("멕시칸", ["멕시", "墨西哥", "taco", "mexican"]),
            ("동남아", ["동남아", "베트남", "태국", "쌀국수", "越南", "泰国", "泰國", "thai", "vietnam", "pho"]),
            ("면 요리", ["국수", "냉면", "칼국수", "우동", "面馆", "麵", "米线", "noodle", "udon"]),
            ("분식", ["분식", "떡볶이", "김밥"]),
            ("샐러드", ["샐러드", "비건", "沙拉", "素食", "salad", "vegan"]),
            ("브런치", ["브런치", "早午餐", "brunch"]),
            ("차 · 음료", ["찻집", "밀크티", "버블티", "奶茶", "茶", "bubble tea", "tea", "juice"]),
            ("베이커리", ["베이커리", "제과", "빵", "面包", "麵包", "烘焙", "bakery"]),
            ("디저트", ["디저트", "甜品", "甜点", "dessert", "ice cream"]),
            ("커피", ["카페", "커피", "咖啡", "cafe", "coffee"]),
            ("와인", ["와인", "葡萄酒", "winery", "wine"]),
            ("술집", ["술집", "호프", "주점", "이자카야", "酒吧", "居酒屋", "brewery", "nightlife", "bar", "pub"]),
            ("패스트푸드", ["패스트푸드", "快餐", "fastfood", "fast food"]),
            ("중식", ["중식", "중국", "中餐", "中国菜", "chinese"]),
            ("일식", ["일식", "일본", "日料", "日本料理", "japanese"]),
            ("한식", ["한식", "韩国", "韓國", "korean"]),
            ("양식", ["양식", "이탈리", "西餐", "意大利", "italian", "western"]),
        ]
        for (name, keywords) in rules where keywords.contains(where: { text.contains($0) }) {
            if let category = builtInCategories.first(where: { $0.name == name }) { return category }
        }
        return builtInCategories[0]
    }

    var allCategories: [FoodCategory] {
        Self.builtInCategories + customCategories
    }

    private init() {
        loadCustomCategories()
    }

    // MARK: - Public Methods

    @discardableResult
    func addCustomCategory(name: String, icon: String, family: TasteFamily) -> FoodCategory {
        let newCategory = FoodCategory(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            isCustom: true,
            isBuiltIn: false,
            family: family
        )

        customCategories.append(newCategory)
        saveCustomCategories()
        return newCategory
    }

    func deleteCustomCategory(id: UUID) {
        customCategories.removeAll { $0.id == id }
        saveCustomCategories()
    }

    /// iCloud 백업에서 되살린 종류를 더한다. 이미 있는 것(같은 id)은 그대로 둔다.
    func mergeCustomCategories(_ categories: [FoodCategory]) {
        let known = Set(customCategories.map(\.id))
        let added = categories.filter { $0.isCustom && !known.contains($0.id) }
        guard !added.isEmpty else { return }
        customCategories.append(contentsOf: added)
        saveCustomCategories()
    }

    func findCategory(by id: UUID) -> FoodCategory? {
        if let builtIn = Self.builtInCategories.first(where: { $0.id == id }) {
            return builtIn
        }
        return customCategories.first { $0.id == id }
    }

    // MARK: - Private Methods

    private func saveCustomCategories() {
        if let encoded = try? JSONEncoder().encode(customCategories) {
            UserDefaults.standard.set(encoded, forKey: customCategoriesKey)
        }
    }

    private func loadCustomCategories() {
        guard let data = UserDefaults.standard.data(forKey: customCategoriesKey) else { return }
        guard let decoded = try? JSONDecoder().decode([FoodCategory].self, from: data) else {
            // 못 읽은 원본을 옆에 남긴다 — 빈 목록으로 시작해 다음 저장이 덮어써도 되찾을 수 있게
            UserDefaults.standard.set(data, forKey: customCategoriesKey + ".unreadable")
            return
        }
        customCategories = decoded
    }
}
