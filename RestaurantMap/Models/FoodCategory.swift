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

    // 기본 제공 카테고리 15개 (고정 UUID 사용)
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
        )
    ]

    var allCategories: [FoodCategory] {
        Self.builtInCategories + customCategories
    }

    private init() {
        loadCustomCategories()
    }

    // MARK: - Public Methods

    func addCustomCategory(name: String, icon: String, family: TasteFamily) {
        let newCategory = FoodCategory(
            id: UUID(),
            name: name,
            icon: icon,
            isCustom: true,
            isBuiltIn: false,
            family: family
        )

        customCategories.append(newCategory)
        saveCustomCategories()
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
