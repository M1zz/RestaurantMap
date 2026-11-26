import SwiftUI
import SwiftData
import AppIntents
import OSLog
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
        // 단골 후기 공개를 심사 없이 끌 수 있는 스위치. 읽지 못하면 켠 채로 둔다.
        LeeoRemoteFlags(spec: RestaurantMapSpec.self).refreshInBackground(RestaurantFlag.self)

        // 저장소는 금고 뒤에 연다 (프로퍼티 초기값으로 두면 init 보다 먼저 열린다)
        sharedModelContainer = Self.makeModelContainer()

        // Siri · Spotlight 인텐트가 같은 저장소를 읽게 한다 (→ RestaurantIntents.swift).
        // 인텐트는 화면 없이 앱을 깨워 돌기도 해서, 화면이 아니라 여기서 넘긴다.
        // 저장소를 못 열었어도 등록한다 — 인텐트가 등록되지 않은 의존성을 읽으면 앱이 죽는다. 그때는 인텐트가 알림 문구로 실패한다.
        let store = RestaurantStore(modelContainer: sharedModelContainer)
        AppDependencyManager.shared.add(dependency: store)

        // 메모리 저장소마저 열지 못했으면 저장소 없이 뜬다 — 죽지 않고 안내 화면 한 장만 보인다 (→ StoreUnavailableView).
        // 알림 · 색인은 저장소가 있어야 하므로 걸지 않는다.
        guard let container = sharedModelContainer else { return }
        // 다녀온 뒤 알림: 시스템이 방문을 알리려고 앱을 깨웠을 때도 받을 수 있게 화면보다 먼저 건다.
        VisitReminderManager.shared.configure(with: container)
        VisitReminderManager.shared.resume(allowed: Purchases.shared.allows(.visitReminder))
        #if DEBUG
        ScreenshotSeed.runIfRequested(container)
        RegularReviews.shared.warmupSchemaIfRequested()
        CloudKitSchemaWarmup.runIfRequested(container, cloudContainer: Self.cloudContainer) {
            let restaurant = Restaurant(name: "표본", address: "", latitude: 0, longitude: 0)
            let menu = MenuItem(name: "표본 메뉴", restaurant: restaurant)
            let visit = Visit(restaurant: restaurant)
            visit.menu = menu
            // 값이 비어 있으면 필드가 생기지 않는다 — 새로 더한 필드에 값을 넣어 둔다
            restaurant.sharedReviewID = "warmup"
            restaurant.regularWord = "warmup"
            restaurant.sourceLink = "https://example.com/warmup"
            menu.myRating = 5
            menu.wouldOrderAgain = true
            menu.photoData = Data(repeating: 3, count: 1_500_000)
            // 메뉴 사진도 작은 것 하나 — 기록 안 · CKAsset 두 저장 꼴의 필드가 다 생기게
            let smallMenu = MenuItem(name: "표본 메뉴 2", restaurant: restaurant)
            smallMenu.photoData = Data(repeating: 4, count: 2_048)
            for criterion in GourmetCriterion.allCases { visit[criterion] = 5 }
            visit.score = 90
            // 작은 사진과 큰 사진(CKAsset 으로 나가는 크기)을 하나씩 — 두 저장 꼴의 필드가 다 생기게
            let small = VisitPhoto(data: Data(repeating: 1, count: 2_048), sortOrder: 0)
            let large = VisitPhoto(data: Data(repeating: 2, count: 1_500_000), sortOrder: 1)
            visit.photos = [small, large]
            visit.tastes = [.depth: 3, .kick: 3]
            let profile = TasteProfile()
            profile.selfDepth = 3
            profile.selfKick = 3
            return [restaurant, menu, smallMenu, visit, small, large, profile]
        }
        #endif
    }

    /// 저장소. 디스크도 메모리도 열지 못했을 때만 nil 이다.
    let sharedModelContainer: ModelContainer?

    /// 앱 자체 iCloud 컨테이너. entitlements 에 이 이름이 있어야 1 단계가 열린다. 백업(CloudKitBackupService)도 같은 곳을 쓴다.
    static let cloudContainer = "iCloud.com.Ysoup.restaurantmap"
    /// 이번 실행이 iCloud 와 이어져 열렸는가 (makeModelContainer 가 한 번 정한다).
    private(set) static var usesCloud = false

    /// 저장 파일 자리. ⚠️ 비워 두면 안 된다 — 앱 그룹(공유 확장과 나누는 곳 → SharedPlace.swift)이 생기면
    /// SwiftData 가 기본 자리를 앱 그룹 폴더로 바꿔, 기존 기록을 두고 빈 저장소를 새로 연다.
    /// 처음부터 써 온 앱 안의 Application Support/default.store 로 못박는다.
    static let storeURL = URL.applicationSupportDirectory.appending(path: "default.store")

    private static func makeModelContainer() -> ModelContainer? {
        let logger = Logger(subsystem: "com.restaurantmap", category: "App")
        logger.info("ModelContainer 초기화 시작")

        let schema = Schema([
            Restaurant.self,
            TasteProfile.self,
            Visit.self,
            VisitPhoto.self,
            MenuItem.self,
        ])

        // 2 단계용: 같은 파일을 기기 안에서만. 컨테이너를 비워 두면(.automatic) entitlements 의 첫
        // 컨테이너가 잡히므로 .none 을 명시한다.
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )

        do {
            let container: ModelContainer
            // 1. 사용자의 iCloud(앱 자체 컨테이너의 개인 데이터베이스). 기기에 있던 기록 · 사진은 그대로 올라가고,
            //    새 기기는 계정에 있던 것을 받아 온다. 개발자는 볼 수 없다.
            if let synced = try? ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, url: storeURL,
                                                    cloudKitDatabase: .private(cloudContainer))]
            ) {
                usesCloud = true
                container = synced
                logger.info("ModelContainer 초기화 성공 (iCloud)")
            } else {
                // 2. iCloud 와 잇지 못하는 빌드(entitlement 없음 · 시험)도 기록은 잃지 않는다.
                container = try ModelContainer(for: schema, configurations: [modelConfiguration])
                logger.info("ModelContainer 초기화 성공 (기기 안)")
            }
            // 파일로 두던 옛 방문 사진을 기록 안으로 — 그래야 iCloud 로 같이 따라간다.
            PhotoMigration.run(container)
            // 옛 맛 평가(종류마다 여섯 칸)를 새 맛 축으로 (→ Taste.swift)
            TasteMigration.run(container.mainContext)

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
            if let container = sharedModelContainer {
                root(container)
            } else {
                // 저장소를 하나도 열지 못했다. 모델을 읽는 화면은 띄우지 않는다.
                StoreUnavailableView()
            }
        }
    }

    private func root(_ container: ModelContainer) -> some View {
        ContentView()
            .storeFallbackNotice()
            // 아이폰 듀오: 접힘을 재서 아래로 흘리고, 시트 · 알림창이 접힌 선을 비키게 한다.
            .foldAware()
            // 처음 한 번, 이 앱이 무엇을 하는지 (→ WelcomeView.swift)
            .welcomeOnce()
            // 유료가 된 날 콘페티, 모든 사용자에게 한 번의 감사 (LeeoKit)
            .leeoCelebrations(appName: RestaurantMapSpec.appName)
            .leeoSatisfactionCheck(RestaurantMapSpec.self)
            // 개발자가 보낸 의견에 답장하면, 앱이 앞으로 올 때 답장을 시트로 보여 준다 (LeeoKit).
            .leeoFeedbackReplyNotice(RestaurantMapSpec.self)
            // 인스타 · 블로그 · 지도 앱에서 공유로 담은 식당을 '가볼 곳' 에 넣는다 (→ ShareInboxReceiver)
            .shareInbox()
            // Spotlight 에 싣는 식당을 지금 것에 맞춘다. 열 때 한 번, 뒤로 보낼 때마다.
            .task { await RestaurantLibrary.reindex(container) }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    // 뒤로 갈 때 아직 내려가지 않은 변경을 먼저 내린다 — 뒤에서 앱이 정리돼도 방금 적은 것이 남는다.
                    container.mainContext.saveNow()
                    Task { await RestaurantLibrary.reindex(container) }
                }
                // 다른 기기에서 산 것 · 구독 만료 · 환불을 앞으로 나올 때마다 맞춘다.
                if phase == .active { Task { await purchases.refresh() } }
            }
            .task {
                logger.info("RestaurantMap 앱 시작됨")
                VisitReminderManager.shared.configure(with: container)
                await VisitReminderManager.shared.carryOverEarlierChoice()
                // 칸을 App Store 에 물은 뒤에 다녀온 뒤 기록 알림을 켜거나 끈다.
                await purchases.refresh()
                await VisitReminderManager.shared.apply(allowed: purchases.allows(.visitReminder))
            }
            // Pro 를 사거나 구독이 끝나면 알림도 따라 켜지거나 꺼진다.
            .onChange(of: purchases.allows(.visitReminder)) { _, allowed in
                Task { await VisitReminderManager.shared.apply(allowed: allowed) }
            }
            .modelContainer(container)
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
            // 그 식당을 연다 — 거기서 바로 방문을 남긴다
            Task { @MainActor in RestaurantRouter.shared.pendingName = restaurantName }
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

    /// 메모리 저장소마저 열지 못하면 nil — 앱을 죽이지 않고 안내 화면만 띄운다 (→ StoreUnavailableView).
    static func memoryContainer(schema: Schema, after error: Error) -> ModelContainer? {
        isActive = true
        print("⚠️ 저장소를 열지 못해 이번 실행은 메모리에서 엽니다: \(error)")
        do {
            return try ModelContainer(
                for: schema,
                configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)
            )
        } catch {
            // 예전에는 여기서 fatalError 로 죽었다. 사용자 기기에서 죽으면 기록을 되살릴 길도 같이 막힌다.
            assertionFailure("메모리 저장소도 열지 못함: \(error)")
            Logger(subsystem: "com.restaurantmap", category: "App").fault("메모리 저장소도 열지 못함: \(error.localizedDescription)")
            return nil
        }
    }
}

/// 저장소를 하나도 열지 못한 날의 화면. 모델을 읽지 않는다.
private struct StoreUnavailableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 56))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)
            Text("기록을 열지 못했어요")
                .font(.title2.weight(.semibold))
            Text("저장된 기록은 지워지지 않았어요. 다만 지금 적는 내용은 저장되지 않으니, 앱을 껐다 켜 보세요.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 지워진 모델 · 바로 저장

extension PersistentModel {
    /// 이미 지워진 모델인가. 지워진 모델의 속성을 읽으면 SwiftData 가 그 자리에서 앱을 죽인다
    /// ("backing data could no longer be found") — 화면이 모델을 쥔 채 다시 그려질 때 먼저 이것을 본다.
    /// 지우고 저장하기 전에는 `isDeleted`, 저장한 뒤에는 `modelContext == nil` 로 드러난다.
    /// ⚠️ 아직 insert 하지 않은 새 모델도 `modelContext == nil` 이다. 화면에는 insert 한 모델만 넘길 것.
    var isGone: Bool { modelContext == nil || isDeleted }
}

/// 저장이 실패했다는 것을 맨 바깥 화면에 한 번 알린다 (→ StoreFallbackNotice).
@MainActor @Observable
final class SaveFailureNotice {
    static let shared = SaveFailureNotice()
    var isPresented = false
    /// 같은 말을 되풀이하지 않는다 — 이번 실행에 한 번.
    @ObservationIgnored private var told = false

    func report(_ error: Error) {
        Logger(subsystem: "com.restaurantmap", category: "App").error("저장 실패: \(error.localizedDescription)")
        guard !told else { return }
        told = true
        // 저장은 대개 시트를 닫는 순간에 한다. 시트가 내려가는 도중에는 바깥 알림창이 뜨지 못하므로
        // 내려간 뒤에 세운다.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { self.isPresented = true }
    }
}

extension ModelContext {
    /// 방금 적은 것을 자동 저장을 기다리지 않고 바로 내린다 — 적은 직후 앱이 꺼져도 남게.
    /// 실패하면 이번 실행에 한 번 알린다. 뷰 body 안에서는 부르지 않는다(버튼 · onDisappear 에서만).
    @MainActor
    func saveNow() {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            SaveFailureNotice.shared.report(error)
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
    @Bindable private var saveFailure = SaveFailureNotice.shared

    func body(content: Content) -> some View {
        content.alert("기록을 열지 못했어요", isPresented: $isPresented) {
        } message: {
            Text("저장된 기록은 지워지지 않았어요. 다만 지금 적는 내용은 저장되지 않으니, 앱을 껐다 켜 보세요.")
        }
        // 닫으면서 바로 저장하는 자리(→ ModelContext.saveNow)가 실패했을 때
        .saveFailureAlert($saveFailure.isPresented)
    }
}
