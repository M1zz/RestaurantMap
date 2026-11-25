//
//  RestaurantIntents.swift
//  RestaurantMap
//
//  내 맛집을 Siri · Spotlight · 단축어가 알아보게 한다.
//
//  - Spotlight: 식당마다 이름 · 주소 · 종류 · 별점과 위치를 싣는다(iOS 18+). 누르면 그 식당이 열린다.
//  - "인생맛집 근처 맛집": 지금 있는 곳에서 가까운 내 맛집을 알려 준다.
//  - "인생맛집 가볼 곳": 가볼 곳으로 담아 둔 식당을 보여 준다.
//
//  SwiftData 모델은 고유 문자열 id 가 없어 PersistentIdentifier 를 문자열로 바꿔 쓴다.
//

import AppIntents
import CoreLocation
import CoreSpotlight
import Foundation
import SwiftData

// MARK: - 앱 화면으로 넘기는 요청

@MainActor @Observable
final class RestaurantRouter {
    static let shared = RestaurantRouter()
    /// 열어 달라는 식당. ContentView 가 시트로 열고 비운다.
    var restaurantID: PersistentIdentifier?
    /// 다녀온 뒤 알림을 눌러 들어온 식당 이름. ContentView 가 찾아서 `restaurantID` 로 바꾼다.
    var pendingName: String?
}

extension PersistentIdentifier {
    var intentID: String {
        (try? JSONEncoder().encode(self))?.base64EncodedString() ?? ""
    }

    init?(intentID: String) {
        guard let data = Data(base64Encoded: intentID),
              let id = try? JSONDecoder().decode(PersistentIdentifier.self, from: data) else { return nil }
        self = id
    }
}

// MARK: - 저장소

/// 인텐트가 읽는 저장소. 저장소를 열지 못한 실행에서도 늘 등록해 두고(→ RestaurantMapApp.init),
/// 읽을 때 없으면 알림 문구와 함께 실패한다. 예전에는 등록이 빠져 `@Dependency` 를 읽는 순간 앱이 죽었다.
struct RestaurantStore: Sendable {
    let modelContainer: ModelContainer?

    func container() throws -> ModelContainer {
        guard let modelContainer else { throw RestaurantIntentError.storeUnavailable }
        return modelContainer
    }
}

enum RestaurantIntentError: Error, CustomLocalizedStringResourceConvertible {
    case storeUnavailable

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .storeUnavailable:
            LocalizedStringResource("기록을 열지 못했어요")
        }
    }
}

// MARK: - 식당

struct RestaurantEntity: AppEntity {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("맛집", comment: "Siri/Spotlight: one saved restaurant")
    )
    static let defaultQuery = RestaurantQuery()

    let id: String
    let name: String
    let address: String
    let category: String
    let rating: Int
    let latitude: Double
    let longitude: Double

    var displayRepresentation: DisplayRepresentation {
        let stars = rating > 0 ? String(repeating: "★", count: min(rating, 5)) + " · " : ""
        return DisplayRepresentation(title: "\(name)", subtitle: "\(stars)\(category)")
    }

    init(_ restaurant: Restaurant) {
        id = restaurant.persistentModelID.intentID
        name = restaurant.name
        address = restaurant.address
        category = restaurant.foodCategory.displayName
        rating = restaurant.rating
        latitude = restaurant.latitude
        longitude = restaurant.longitude
    }
}

@available(iOS 18.0, *)
extension RestaurantEntity: IndexedEntity {
    var attributeSet: CSSearchableItemAttributeSet {
        let set = defaultAttributeSet
        set.namedLocation = address
        set.latitude = NSNumber(value: latitude)
        set.longitude = NSNumber(value: longitude)
        set.keywords = [category]
        return set
    }
}

struct RestaurantQuery: EntityStringQuery {
    @Dependency private var store: RestaurantStore

    func entities(for identifiers: [String]) async throws -> [RestaurantEntity] {
        let wanted = Set(identifiers)
        return try RestaurantLibrary.read(in: store.container()) { $0.map(RestaurantEntity.init).filter { wanted.contains($0.id) } }
    }

    func entities(matching string: String) async throws -> [RestaurantEntity] {
        try RestaurantLibrary.read(in: store.container()) { all in
            all.filter { $0.name.localizedCaseInsensitiveContains(string) || $0.address.localizedCaseInsensitiveContains(string) }
                .map(RestaurantEntity.init)
        }
    }

    func suggestedEntities() async throws -> [RestaurantEntity] {
        try RestaurantLibrary.read(in: store.container()) { $0.sorted { $0.rating > $1.rating }.prefix(20).map(RestaurantEntity.init) }
    }
}

// MARK: - 인텐트

/// 지금 있는 곳에서 가까운 내 맛집(가볼 곳 말고 가 본 곳). 위치를 모르면 별점 높은 순.
struct NearbyRestaurantsIntent: AppIntent {
    static let title = LocalizedStringResource("근처 내 맛집", comment: "Siri: my saved restaurants near me")
    static let description = IntentDescription(
        LocalizedStringResource("지금 있는 곳에서 가까운 내 맛집을 알려 줍니다.", comment: "Siri: nearby restaurants description")
    )

    @Dependency private var store: RestaurantStore

    func perform() async throws -> some IntentResult & ReturnsValue<[RestaurantEntity]> & ProvidesDialog {
        // 모델은 읽는 동안만 쓰고, 밖으로는 값(RestaurantEntity)만 들고 나온다 (→ RestaurantLibrary.read)
        let visited = try RestaurantLibrary.read(in: store.container()) { $0.filter { !$0.isWishlist }.map(RestaurantEntity.init) }
        guard !visited.isEmpty else {
            return .result(value: [], dialog: IntentDialog(LocalizedStringResource("아직 저장한 맛집이 없어요.", comment: "Siri: no restaurants yet")))
        }
        // 이 앱은 방문 알림 때문에 위치 권한을 받아 둔다. 마지막으로 안 위치를 쓴다(새로 묻지 않는다).
        guard let here = CLLocationManager().location else {
            let best = visited.sorted { $0.rating > $1.rating }.prefix(5)
            return .result(value: Array(best), dialog: IntentDialog(LocalizedStringResource("위치를 몰라서 별점 높은 순으로 보여 드릴게요.", comment: "Siri: location unknown, showing top rated")))
        }
        let near = visited
            .map { ($0, here.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))) }
            .sorted { $0.1 < $1.1 }
            .prefix(5)
        guard let first = near.first else { return .result(value: [], dialog: "") }
        let distance = Measurement(value: first.1, unit: UnitLength.meters)
            .formatted(.measurement(width: .abbreviated, usage: .road))
        return .result(
            value: near.map(\.0),
            dialog: IntentDialog(LocalizedStringResource("가장 가까운 곳은 \(first.0.name)이에요. \(distance) 떨어져 있어요.", comment: "Siri: nearest restaurant. Arguments: name, distance"))
        )
    }
}

/// 가볼 곳으로 담아 둔 식당.
struct WishlistIntent: AppIntent {
    static let title = LocalizedStringResource("가볼 곳", comment: "Siri: restaurants saved to visit later")
    static let description = IntentDescription(
        LocalizedStringResource("가볼 곳으로 담아 둔 식당을 보여 줍니다.", comment: "Siri: wishlist description")
    )

    @Dependency private var store: RestaurantStore

    func perform() async throws -> some IntentResult & ReturnsValue<[RestaurantEntity]> & ProvidesDialog {
        let wish = try RestaurantLibrary.read(in: store.container()) { $0.filter(\.isWishlist).map(RestaurantEntity.init) }
        let dialog = wish.isEmpty
            ? IntentDialog(LocalizedStringResource("가볼 곳이 비어 있어요.", comment: "Siri: wishlist empty"))
            : IntentDialog(LocalizedStringResource("가볼 곳이 \(wish.count)곳 있어요.", comment: "Siri: wishlist count"))
        return .result(value: wish, dialog: dialog)
    }
}

/// 식당을 연다. Spotlight · Siri 결과를 누르면 여기로 온다.
struct OpenRestaurantIntent: OpenIntent {
    static let title = LocalizedStringResource("맛집 열기", comment: "Siri/Spotlight: open a saved restaurant")
    static let description = IntentDescription(
        LocalizedStringResource("저장한 맛집을 앱에서 엽니다.", comment: "Siri: open restaurant description")
    )

    @Parameter(title: LocalizedStringResource("맛집", comment: "Siri: restaurant parameter"),
               description: LocalizedStringResource("열어 볼 내 맛집", comment: "Siri: restaurant parameter description"))
    var target: RestaurantEntity

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        RestaurantRouter.shared.restaurantID = PersistentIdentifier(intentID: target.id)
        return .result()
    }
}

// MARK: - Siri 문구

struct RestaurantMapShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NearbyRestaurantsIntent(),
            phrases: [
                "Find my restaurants nearby in \(.applicationName)",
                "\(.applicationName) near me"
            ],
            shortTitle: "Nearby Favorites",
            systemImageName: "location.circle"
        )
        AppShortcut(
            intent: WishlistIntent(),
            phrases: [
                "Show my \(.applicationName) wishlist",
                "Where should I eat with \(.applicationName)"
            ],
            shortTitle: "Places to Try",
            systemImageName: "bookmark"
        )
    }
}

// MARK: - 읽기 · 색인

enum RestaurantLibrary {
    /// 저장된 식당을 읽어 값으로 바꿔 돌려준다.
    /// 모델은 자기를 읽어 온 컨텍스트가 살아 있는 동안만 믿을 수 있다 — 예전처럼 임시 컨텍스트에서 읽은 모델 배열을
    /// 그대로 돌려주면, 컨텍스트가 먼저 사라진 뒤에 속성을 읽게 된다. 그래서 읽기를 이 안에서 끝낸다.
    static func read<T>(in container: ModelContainer, _ body: ([Restaurant]) -> T) -> T {
        let context = ModelContext(container)
        let all = (try? context.fetch(FetchDescriptor<Restaurant>())) ?? []
        return withExtendedLifetime(context) { body(all) }
    }

    /// Spotlight 에 싣는 식당을 지금 것에 맞춘다. 앱을 열 때와 뒤로 보낼 때 부른다.
    static func reindex(_ container: ModelContainer) async {
        guard #available(iOS 18.0, *) else { return }
        let entities = read(in: container) { $0.filter { !$0.name.isEmpty }.map(RestaurantEntity.init) }
        let index = CSSearchableIndex.default()
        try? await index.deleteAppEntities(ofType: RestaurantEntity.self)
        try? await index.indexAppEntities(entities)
    }
}
