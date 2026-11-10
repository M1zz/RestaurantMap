import Foundation
import SwiftData
import UIKit

/// 방문 사진 한 장. 사진이 기록 안에 들어 있어 iCloud 로 기록과 함께 따라간다.
///
/// 예전에는 사진을 파일(Documents/VisitPhotos)로 두고 파일명만 기록했다. 그러면 기록은 동기화돼도
/// 사진은 그 기기에만 남는다. 이제 데이터를 모델에 두고(`.externalStorage` 라 큰 파일은 SwiftData 가
/// 옆에 따로 보관한다) 옛 파일은 첫 실행 때 옮긴다(→ PhotoMigration).
@Model
final class VisitPhoto {
    var id: UUID = UUID()
    @Attribute(.externalStorage) var data: Data?
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var visit: Visit?

    init(data: Data, sortOrder: Int = 0) {
        self.data = data
        self.sortOrder = sortOrder
    }

    var image: UIImage? {
        data.flatMap { UIImage(data: $0) }
    }

    /// 백업(CloudKit 레코드) 이름에 쓰는 파일명. 옛 파일 방식과 같은 꼴이라 옛 백업도 그대로 되살아난다.
    var filename: String { "\(id.uuidString).jpg" }
}
