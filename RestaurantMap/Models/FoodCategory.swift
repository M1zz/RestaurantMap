import SwiftUI

// MARK: - FoodCategory (Struct)

struct FoodCategory: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let icon: String
    let isCustom: Bool
    let isBuiltIn: Bool
    let evaluationType: EvaluationType

    var displayName: String {
        "\(icon) \(name)"
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

    var evaluationAttributes: [EvaluationAttribute] {
        switch self {
        case .general:
            return [
                EvaluationAttribute(emoji: "🌶️", title: "맵기", subtitle: "순한 ↔ 매운"),
                EvaluationAttribute(emoji: "💪", title: "진한맛", subtitle: "담백 ↔ 진한"),
                EvaluationAttribute(emoji: "🍯", title: "단맛", subtitle: "안좋아함 ↔ 좋아함"),
                EvaluationAttribute(emoji: "🧂", title: "짠맛", subtitle: "싱거움 ↔ 짭짤"),
                EvaluationAttribute(emoji: "🥓", title: "기름진", subtitle: "담백 ↔ 고소"),
                EvaluationAttribute(emoji: "🌿", title: "본연의맛", subtitle: "양념 ↔ 재료맛")
            ]
        case .steak:
            return [
                EvaluationAttribute(emoji: "🔥", title: "굽기", subtitle: "레어 ↔ 웰던"),
                EvaluationAttribute(emoji: "🥩", title: "육즙", subtitle: "퍽퍽 ↔ 촉촉"),
                EvaluationAttribute(emoji: "✨", title: "부드러움", subtitle: "질김 ↔ 부드러움"),
                EvaluationAttribute(emoji: "🧂", title: "간", subtitle: "싱거움 ↔ 짭짤"),
                EvaluationAttribute(emoji: "🌿", title: "육향", subtitle: "약함 ↔ 강함"),
                EvaluationAttribute(emoji: "🍖", title: "마블링", subtitle: "적음 ↔ 많음")
            ]
        case .sushi:
            return [
                EvaluationAttribute(emoji: "🍚", title: "샤리(밥)", subtitle: "흐물 ↔ 단단"),
                EvaluationAttribute(emoji: "🐟", title: "네타(재료)", subtitle: "신선도"),
                EvaluationAttribute(emoji: "🌿", title: "와사비", subtitle: "약함 ↔ 강함"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화"),
                EvaluationAttribute(emoji: "✋", title: "쥐기", subtitle: "풀림 ↔ 결속"),
                EvaluationAttribute(emoji: "🌡️", title: "온도", subtitle: "차가움 ↔ 따뜻함")
            ]
        case .ramen:
            return [
                EvaluationAttribute(emoji: "🥣", title: "국물", subtitle: "깊이/감칠맛"),
                EvaluationAttribute(emoji: "🍜", title: "면발", subtitle: "부드러움 ↔ 쫄깃함"),
                EvaluationAttribute(emoji: "🥓", title: "차슈", subtitle: "퍽퍽 ↔ 부드러움"),
                EvaluationAttribute(emoji: "🥚", title: "토핑", subtitle: "부실 ↔ 풍부"),
                EvaluationAttribute(emoji: "🔥", title: "온도", subtitle: "미지근 ↔ 뜨거움"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화")
            ]
        case .pizza:
            return [
                EvaluationAttribute(emoji: "🫓", title: "도우", subtitle: "질김 ↔ 쫄깃함"),
                EvaluationAttribute(emoji: "🍅", title: "소스", subtitle: "적음 ↔ 많음"),
                EvaluationAttribute(emoji: "🧀", title: "치즈", subtitle: "적음 ↔ 많음"),
                EvaluationAttribute(emoji: "🔥", title: "굽기", subtitle: "덜익음 ↔ 바삭함"),
                EvaluationAttribute(emoji: "🌟", title: "토핑", subtitle: "부실 ↔ 풍부"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화")
            ]
        case .wine:
            return [
                EvaluationAttribute(emoji: "💪", title: "바디", subtitle: "가벼움 ↔ 묵직함"),
                EvaluationAttribute(emoji: "🍇", title: "타닌", subtitle: "약함 ↔ 떫음"),
                EvaluationAttribute(emoji: "🍋", title: "산도", subtitle: "낮음 ↔ 높음"),
                EvaluationAttribute(emoji: "🌸", title: "아로마", subtitle: "단순 ↔ 복잡"),
                EvaluationAttribute(emoji: "✨", title: "피니시", subtitle: "짧음 ↔ 긴 여운"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화")
            ]
        case .coffee:
            return [
                EvaluationAttribute(emoji: "🍋", title: "산미", subtitle: "낮음 ↔ 밝음"),
                EvaluationAttribute(emoji: "💪", title: "바디", subtitle: "가벼움 ↔ 묵직함"),
                EvaluationAttribute(emoji: "🌸", title: "향미", subtitle: "단순 ↔ 복잡"),
                EvaluationAttribute(emoji: "✨", title: "후미", subtitle: "짧음 ↔ 긴 여운"),
                EvaluationAttribute(emoji: "🍯", title: "단맛", subtitle: "쓴맛 ↔ 단맛"),
                EvaluationAttribute(emoji: "⚖️", title: "밸런스", subtitle: "불균형 ↔ 조화")
            ]
        }
    }
}

// MARK: - EvaluationAttribute

struct EvaluationAttribute {
    let emoji: String
    let title: String
    let subtitle: String

    var displayTitle: String {
        "\(emoji) \(title)"
    }
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
            evaluationType: .general
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            name: "스테이크",
            icon: "🥩",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .steak
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            name: "초밥",
            icon: "🍣",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .sushi
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            name: "라멘",
            icon: "🍜",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .ramen
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            name: "피자",
            icon: "🍕",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .pizza
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            name: "와인",
            icon: "🍷",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .wine
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            name: "커피",
            icon: "☕",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .coffee
        ),
        // 새로 추가되는 8개 카테고리
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            name: "중식",
            icon: "🥟",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .general
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            name: "일식",
            icon: "🍱",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .general
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000A")!,
            name: "한식",
            icon: "🍲",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .general
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000B")!,
            name: "양식",
            icon: "🍝",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .general
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000C")!,
            name: "치킨",
            icon: "🍗",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .general
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000D")!,
            name: "버거",
            icon: "🍔",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .general
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000E")!,
            name: "디저트",
            icon: "🍰",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .general
        ),
        FoodCategory(
            id: UUID(uuidString: "00000000-0000-0000-0000-00000000000F")!,
            name: "술집",
            icon: "🍺",
            isCustom: false,
            isBuiltIn: true,
            evaluationType: .general
        )
    ]

    var allCategories: [FoodCategory] {
        Self.builtInCategories + customCategories
    }

    private init() {
        loadCustomCategories()
    }

    // MARK: - Public Methods

    func addCustomCategory(name: String, icon: String) {
        let newCategory = FoodCategory(
            id: UUID(),
            name: name,
            icon: icon,
            isCustom: true,
            isBuiltIn: false,
            evaluationType: .general
        )

        customCategories.append(newCategory)
        saveCustomCategories()
    }

    func deleteCustomCategory(id: UUID) {
        customCategories.removeAll { $0.id == id }
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
        guard let data = UserDefaults.standard.data(forKey: customCategoriesKey),
              let decoded = try? JSONDecoder().decode([FoodCategory].self, from: data) else {
            return
        }
        customCategories = decoded
    }
}
