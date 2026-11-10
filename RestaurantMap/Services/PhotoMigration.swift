import Foundation
import SwiftData
import OSLog

/// 파일로 두던 옛 방문 사진을 기록 안(`VisitPhoto`)으로 옮긴다. 옮긴 파일은 지운다.
/// 첫 실행에 한 번 일하고, 그 뒤로는 옮길 것이 없어 바로 끝난다. 몇 번 돌아도 안전하다.
enum PhotoMigration {
    private static let logger = Logger(subsystem: "com.restaurantmap", category: "PhotoMigration")

    @MainActor
    static func run(_ container: ModelContainer) {
        let context = container.mainContext
        guard let visits = try? context.fetch(FetchDescriptor<Visit>()) else { return }
        var moved = 0
        for visit in visits where !visit.photoFilenames.isEmpty {
            var order = visit.sortedPhotos.count
            for filename in visit.photoFilenames {
                guard let url = PhotoStorageManager.shared.photoURL(for: filename, visitID: visit.photoId),
                      let data = try? Data(contentsOf: url) else { continue }
                let photo = VisitPhoto(data: data, sortOrder: order)
                order += 1
                context.insert(photo)
                photo.visit = visit
                moved += 1
            }
            // 읽지 못한 파일(이미 없는 사진)도 더는 가리키지 않는다.
            visit.photoFilenames = []
            PhotoStorageManager.shared.deleteAllPhotos(for: visit.photoId)
        }
        guard moved > 0 else { return }
        do {
            try context.save()
            logger.info("옛 사진 \(moved)장을 기록 안으로 옮김")
        } catch {
            logger.error("사진 옮기기 저장 실패: \(error.localizedDescription)")
        }
    }
}
