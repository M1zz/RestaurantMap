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
            // 방문 하나를 옮길 때마다 저장하고, **저장된 뒤에만** 옛 파일을 지운다.
            // 예전에는 파일부터 지우고 맨 끝에 한 번 저장해서, 저장이 실패하거나 사진이 많아 옮기는 도중
            // 앱이 꺼지면(첫 화면이 뜨기 전이라 시스템이 기다려 주지 않는다) 사진이 양쪽에서 다 사라졌다.
            // 이제는 중간에 꺼져도 옮긴 데까지 남고, 다음에 열 때 나머지를 잇는다.
            do {
                try context.save()
                PhotoStorageManager.shared.deleteAllPhotos(for: visit.photoId)
            } catch {
                logger.error("사진 옮기기 저장 실패: \(error.localizedDescription)")
                // 옮기다 만 것을 되돌린다 — 옛 파일과 파일명이 그대로 남아 다음에 다시 옮긴다.
                context.rollback()
                return
            }
        }
        if moved > 0 { logger.info("옛 사진 \(moved)장을 기록 안으로 옮김") }
    }
}
