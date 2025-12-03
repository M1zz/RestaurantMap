import SwiftUI
import SwiftData
import OSLog
import FirebaseCore

@main
struct RestaurantMapApp: App {
    private let logger = Logger(subsystem: "com.restaurantmap", category: "App")

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

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            logger.info("ModelContainer 초기화 성공")

            // 기존 Restaurant 데이터에 foodCategoryRaw가 없으면 기본값 설정
            let context = container.mainContext
            let descriptor = FetchDescriptor<Restaurant>()
            if let restaurants = try? context.fetch(descriptor) {
                for restaurant in restaurants {
                    if restaurant.foodCategoryRaw.isEmpty {
                        restaurant.foodCategoryRaw = "일반"
                        logger.info("Restaurant '\(restaurant.name)'에 기본 카테고리 설정")
                    }
                }
                try? context.save()
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
                logger.info("ModelContainer 재생성 성공")
                return container
            } catch {
                logger.error("ModelContainer 재생성 실패: \(error.localizedDescription)")
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    logger.info("RestaurantMap 앱 시작됨")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
