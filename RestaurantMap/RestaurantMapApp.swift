import SwiftUI
import SwiftData
import AppIntents
import OSLog
import FirebaseCore
import UserNotifications
import LeeoKit

@main
struct RestaurantMapApp: App {
    private let logger = Logger(subsystem: "com.restaurantmap", category: "App")
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @State private var purchases = Purchases.shared

    init() {
        // LeeoKit — 백업 금고(예약된 복원 · 업데이트 직전 백업) · 사용량 기록 · 크래시 진단 · 익명 사용 통계 (FeedbackHub).
        // 금고가 저장소보다 먼저 돌아야 해서 맨 앞에 둔다.
        LeeoKit.bootstrap(RestaurantMapSpec.self)

        // Firebase 초기화
        FirebaseApp.configure()
        logger.info("🔥 Firebase configured")

        // 저장소는 금고 뒤에 연다 (프로퍼티 초기값으로 두면 init 보다 먼저 열린다)
        sharedModelContainer = Self.makeModelContainer()

        // Siri · Spotlight 인텐트가 같은 저장소를 읽게 한다 (→ RestaurantIntents.swift).
        // 인텐트는 화면 없이 앱을 깨워 돌기도 해서, 화면이 아니라 여기서 넘긴다.
        let container = sharedModelContainer
        AppDependencyManager.shared.add(dependency: container)
    }

    let sharedModelContainer: ModelContainer

    private static func makeModelContainer() -> ModelContainer {
        let logger = Logger(subsystem: "com.restaurantmap", category: "App")
        logger.info("ModelContainer 초기화 시작")

        let schema = Schema([
            Restaurant.self,
            TasteProfile.self,
            Visit.self,
            MenuItem.self,
        ])

        // CloudKit 통합 완전히 비활성화 (에러 방지)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // CloudKit 비활성화
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            logger.info("ModelContainer 초기화 성공")

            // 기존 Restaurant 데이터를 UUID 기반 카테고리로 마이그레이션
            let context = container.mainContext
            let descriptor = FetchDescriptor<Restaurant>()
            if let restaurants = try? context.fetch(descriptor) {
                var needsSave = false

                // 구 카테고리 이름 → 새 UUID 매핑
                let categoryMigration: [String: String] = [
                    "일반": FoodCategoryRepository.builtInCategories[0].id.uuidString,
                    "스테이크": FoodCategoryRepository.builtInCategories[1].id.uuidString,
                    "초밥": FoodCategoryRepository.builtInCategories[2].id.uuidString,
                    "라멘": FoodCategoryRepository.builtInCategories[3].id.uuidString,
                    "피자": FoodCategoryRepository.builtInCategories[4].id.uuidString,
                    "와인": FoodCategoryRepository.builtInCategories[5].id.uuidString,
                    "커피": FoodCategoryRepository.builtInCategories[6].id.uuidString
                ]

                for restaurant in restaurants {
                    // 이미 UUID 형식이면 스킵
                    if UUID(uuidString: restaurant.foodCategoryId) != nil {
                        continue
                    }

                    // 구 방식 데이터 변환
                    if let newId = categoryMigration[restaurant.foodCategoryId] {
                        restaurant.foodCategoryId = newId
                        logger.info("Restaurant '\(restaurant.name)' 카테고리 마이그레이션: \(restaurant.foodCategoryId) → UUID")
                        needsSave = true
                    } else {
                        // 매핑되지 않은 값이면 기본값(일반)으로
                        restaurant.foodCategoryId = FoodCategoryRepository.builtInCategories[0].id.uuidString
                        logger.warning("Restaurant '\(restaurant.name)' 알 수 없는 카테고리, 기본값으로 설정")
                        needsSave = true
                    }
                }

                if needsSave {
                    try? context.save()
                    logger.info("✅ 카테고리 마이그레이션 완료")
                }
            }

            return container
        } catch {
            logger.error("ModelContainer 생성 실패: \(error.localizedDescription)")

            // 열 수 없는 저장소는 지우지 않고 옆 폴더로 옮겨 둔다 — 사용자의 기록을 되살릴 길을 남긴다
            logger.warning("⚠️ 열 수 없는 저장소를 격리 폴더로 옮기고 새로 만듭니다")

            let fm = FileManager.default
            if let appSupportURL = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let quarantine = appSupportURL
                    .appendingPathComponent("QuarantinedStores", isDirectory: true)
                    .appendingPathComponent(String(Int(Date().timeIntervalSince1970)), isDirectory: true)
                try? fm.createDirectory(at: quarantine, withIntermediateDirectories: true)
                let files = (try? fm.contentsOfDirectory(at: appSupportURL, includingPropertiesForKeys: nil)) ?? []
                for fileURL in files {
                    let filename = fileURL.lastPathComponent
                    if filename.hasSuffix(".store") || filename.hasSuffix(".store-shm") || filename.hasSuffix(".store-wal") {
                        do {
                            try fm.moveItem(at: fileURL, to: quarantine.appendingPathComponent(filename))
                            logger.info("격리됨: \(filename)")
                        } catch {
                            logger.error("격리 실패: \(filename) - \(error.localizedDescription)")
                        }
                    }
                }
            }

            // 재시도
            do {
                let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                logger.info("✅ ModelContainer 재생성 성공")
                return container
            } catch {
                logger.error("❌ ModelContainer 재생성 실패: \(error.localizedDescription)")

                // 이번 실행만 메모리에서 열고, 저장되지 않는다는 걸 사용자에게 알린다
                logger.warning("⚠️  임시 메모리 전용 모드로 전환합니다 (데이터가 저장되지 않음)")
                return StoreFallback.memoryContainer(schema: schema, after: error)
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .storeFallbackNotice()
                // 아이폰 듀오: 접힘을 재서 아래로 흘리고, 시트 · 알림창이 접힌 선을 비키게 한다.
                .foldAware()
                .leeoSatisfactionCheck(RestaurantMapSpec.self)
                // Spotlight 에 싣는 식당을 지금 것에 맞춘다. 열 때 한 번, 뒤로 보낼 때마다.
                .task { await RestaurantLibrary.reindex(sharedModelContainer) }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .background { Task { await RestaurantLibrary.reindex(sharedModelContainer) } }
                    // 다른 기기에서 산 것 · 구독 만료 · 환불을 앞으로 나올 때마다 맞춘다.
                    if phase == .active { Task { await purchases.refresh() } }
                }
                .task {
                    logger.info("RestaurantMap 앱 시작됨")
                    VisitReminderManager.shared.configure(with: sharedModelContainer)
                    await VisitReminderManager.shared.carryOverEarlierChoice()
                    // 칸을 App Store 에 물은 뒤에 다녀온 뒤 기록 알림을 켜거나 끈다.
                    await purchases.refresh()
                    await VisitReminderManager.shared.apply(allowed: purchases.allows(.visitReminder))
                }
                // Pro 를 사거나 구독이 끝나면 알림도 따라 켜지거나 꺼진다.
                .onChange(of: purchases.allows(.visitReminder)) { _, allowed in
                    Task { await VisitReminderManager.shared.apply(allowed: allowed) }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - AppDelegate for Notification Handling

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let logger = Logger(subsystem: "com.restaurantmap", category: "AppDelegate")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 알림 센터 델리게이트 설정
        UNUserNotificationCenter.current().delegate = self

        // 알림 카테고리 설정
        setupNotificationCategories()

        return true
    }

    private func setupNotificationCategories() {
        let visitReminderCategory = UNNotificationCategory(
            identifier: "VISIT_REMINDER",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )

        UNUserNotificationCenter.current().setNotificationCategories([visitReminderCategory])
    }

    // 앱이 foreground에 있을 때도 알림 표시
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        logger.info("Foreground 알림 수신: \(notification.request.content.title)")
        completionHandler([.banner, .sound, .badge])
    }

    // 알림 탭 처리
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let restaurantName = userInfo["restaurantName"] as? String {
            logger.info("알림 탭됨: \(restaurantName)")
            // TODO: 해당 레스토랑의 방문 기록 추가 화면으로 이동하는 로직 추가 가능
        }
        completionHandler()
    }
}

// MARK: - 저장소를 못 연 날
//
// 원래 저장소를 못 열면 이번 실행만 메모리에서 연다. 디스크의 기록은 건드리지 않는다.
// 예전에는 아무 말 없이 넘어가서, 사용자는 저장되는 줄 알고 계속 적었다 — 이제는 알린다.

enum StoreFallback {
    /// 이번 실행이 임시(메모리) 저장소로 열렸는가
    private(set) static var isActive = false

    static func memoryContainer(schema: Schema, after error: Error) -> ModelContainer {
        isActive = true
        print("⚠️ 저장소를 열지 못해 이번 실행은 메모리에서 엽니다: \(error)")
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            // 메모리 저장소마저 안 되는 건 스키마 자체가 잘못된 것 — 개발 중에 바로 드러난다
            fatalError("메모리 저장소도 열지 못함: \(error)")
        }
    }
}

extension View {
    /// 임시 저장소로 열렸으면 한 번 알린다. 앱의 맨 바깥 화면에 붙인다.
    func storeFallbackNotice() -> some View {
        modifier(StoreFallbackNotice())
    }
}

private struct StoreFallbackNotice: ViewModifier {
    @State private var isPresented = StoreFallback.isActive

    func body(content: Content) -> some View {
        content.alert("기록을 열지 못했어요", isPresented: $isPresented) {
        } message: {
            Text("저장된 기록은 지워지지 않았어요. 다만 지금 적는 내용은 저장되지 않으니, 앱을 껐다 켜 보세요.")
        }
    }
}
