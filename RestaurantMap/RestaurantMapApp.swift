import SwiftUI
import SwiftData
import OSLog
import FirebaseCore
import UserNotifications

@main
struct RestaurantMapApp: App {
    private let logger = Logger(subsystem: "com.restaurantmap", category: "App")
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        // Firebase 초기화
        FirebaseApp.configure()
        logger.info("🔥 Firebase configured")
    }

    var sharedModelContainer: ModelContainer = {
        let logger = Logger(subsystem: "com.restaurantmap", category: "App")
        logger.info("ModelContainer 초기화 시작")

        let schema = Schema([
            Restaurant.self,
            TasteProfile.self,
            Visit.self,
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

            // 기존 Restaurant 데이터에 기본값 설정 (마이그레이션)
            let context = container.mainContext
            let descriptor = FetchDescriptor<Restaurant>()
            if let restaurants = try? context.fetch(descriptor) {
                var needsSave = false
                for restaurant in restaurants {
                    // foodCategoryRaw 기본값 설정
                    if restaurant.foodCategoryRaw.isEmpty {
                        restaurant.foodCategoryRaw = "일반"
                        logger.info("Restaurant '\(restaurant.name)'에 기본 카테고리 설정")
                        needsSave = true
                    }
                }
                if needsSave {
                    try? context.save()
                    logger.info("✅ 마이그레이션 완료")
                }
            }

            return container
        } catch {
            logger.error("ModelContainer 생성 실패: \(error.localizedDescription)")

            // 스키마 변경으로 인한 오류 시 모든 SwiftData 파일 삭제
            logger.warning("⚠️ 스키마 변경으로 인해 기존 데이터를 모두 삭제합니다")
            logger.warning("⚠️ 이 작업은 되돌릴 수 없습니다!")

            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!

            // 모든 .store 관련 파일 삭제
            if let enumerator = FileManager.default.enumerator(at: appSupportURL, includingPropertiesForKeys: nil) {
                for case let fileURL as URL in enumerator {
                    let filename = fileURL.lastPathComponent
                    if filename.contains("default.store") || filename.hasSuffix(".store") ||
                       filename.hasSuffix(".store-shm") || filename.hasSuffix(".store-wal") {
                        do {
                            try FileManager.default.removeItem(at: fileURL)
                            logger.info("삭제됨: \(filename)")
                        } catch {
                            logger.error("파일 삭제 실패: \(filename) - \(error.localizedDescription)")
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

                // fatalError 대신 메모리 전용 컨테이너로 대체 (앱 크래시 방지)
                logger.warning("⚠️  임시 메모리 전용 모드로 전환합니다 (데이터가 저장되지 않음)")
                let memoryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: true,
                    cloudKitDatabase: .none  // CloudKit 비활성화
                )
                do {
                    let memoryContainer = try ModelContainer(for: schema, configurations: [memoryConfig])
                    logger.info("✅ 메모리 전용 ModelContainer 생성 성공")
                    return memoryContainer
                } catch {
                    logger.error("❌ 메모리 전용 컨테이너도 실패: \(error.localizedDescription)")
                    fatalError("Critical Error: Could not create ModelContainer: \(error)")
                }
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    logger.info("RestaurantMap 앱 시작됨")

                    // VisitReminderManager 설정 및 시작
                    await setupVisitReminder()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    /// 방문 리마인더 서비스 설정
    private func setupVisitReminder() async {
        let reminderManager = VisitReminderManager.shared

        // ModelContainer 설정
        reminderManager.configure(with: sharedModelContainer)

        // 알림 권한 요청
        let granted = await reminderManager.requestNotificationPermission()
        if granted {
            logger.info("알림 권한 허용됨, 위치 모니터링 시작")
            reminderManager.startMonitoring()
        } else {
            logger.warning("알림 권한이 거부되어 방문 리마인더가 비활성화됨")
        }
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
