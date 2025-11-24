import SwiftUI
import SwiftData
import OSLog

@main
struct RestaurantMapApp: App {
    private let logger = Logger(subsystem: "com.restaurantmap", category: "App")

    var sharedModelContainer: ModelContainer = {
        let logger = Logger(subsystem: "com.restaurantmap", category: "App")
        logger.info("ModelContainer 초기화 시작")

        let schema = Schema([
            Restaurant.self,
            TasteProfile.self,
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            logger.info("ModelContainer 초기화 성공")
            return container
        } catch {
            logger.error("ModelContainer 생성 실패: \(error.localizedDescription)")

            // 스키마 변경으로 인한 오류 시 모든 SwiftData 파일 삭제
            logger.warning("기존 SwiftData 파일을 모두 삭제합니다")

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
                .onAppear {
                    logger.info("RestaurantMap 앱 시작됨")
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
