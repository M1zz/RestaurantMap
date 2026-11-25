import UIKit
import Foundation
import ImageIO

/// 사진 데이터를 화면에 그릴 만큼만 풀어 낸다.
///
/// `UIImage(data:)` 는 그릴 때 원본 크기 그대로 풀린다 — 요즘 아이폰 사진 한 장(24~48MP)이 100~190MB 다.
/// 100pt 칸에 열 장을 그리면 메모리가 모자라 앱이 꺼진다. ImageIO 는 원본을 다 풀지 않고 필요한 크기로 바로 줄인다.
enum PhotoDownsampler {
    /// 긴 변이 `maxPixel` 픽셀을 넘지 않는 그림. 방향(EXIF)은 그림에 구워 넣는다. 읽지 못하면 nil.
    static func image(from data: Data, maxPixel: CGFloat) -> UIImage? {
        guard maxPixel >= 1, !data.isEmpty,
              let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    /// 작은 칸에 그릴 그림을 잠깐 쥐어 둔다 — 목록이 다시 그려질 때마다 풀지 않게. 메모리가 모자라면 시스템이 비운다.
    static let thumbnails: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 200
        cache.totalCostLimit = 48 * 1024 * 1024
        return cache
    }()
}

/// 방문 사진의 옛 저장소(Documents/VisitPhotos/{visitID}/)와 사진 압축.
/// 사진은 이제 기록 안(`VisitPhoto`)에 들어간다. 파일 저장소는 옛 사진을 옮길 때(→ PhotoMigration)만 읽는다.
final class PhotoStorageManager {
    static let shared = PhotoStorageManager()

    private let baseDirectory = "VisitPhotos"
    private let maxImageSize: CGFloat = 1024
    private let compressionQuality: CGFloat = 0.75
    private let targetFileSize = 800_000 // ~800KB

    private init() {}

    // MARK: - Public Methods

    /// 사진을 압축하여 파일로 저장하고 파일명 반환
    /// - Parameters:
    ///   - image: 저장할 UIImage
    ///   - visitID: 방문 기록 ID (디렉토리 구분용)
    /// - Returns: 저장된 파일명 (UUID.jpg), 실패 시 nil
    func savePhoto(_ image: UIImage, for visitID: UUID) -> String? {
        // 디렉토리 생성
        guard let directoryURL = createVisitDirectory(for: visitID) else {
            print("❌ 디렉토리 생성 실패: \(visitID)")
            return nil
        }

        // 이미지 압축
        guard let compressedData = compressImage(image) else {
            print("❌ 이미지 압축 실패")
            return nil
        }

        // 파일명 생성 (UUID)
        let filename = "\(UUID().uuidString).jpg"
        let fileURL = directoryURL.appendingPathComponent(filename)

        // 파일로 저장
        do {
            try compressedData.write(to: fileURL)
            print("✅ 사진 저장 성공: \(filename) (\(compressedData.count / 1000)KB)")
            return filename
        } catch {
            print("❌ 파일 저장 실패: \(error.localizedDescription)")
            return nil
        }
    }

    /// 파일명으로 사진 로드
    /// - Parameters:
    ///   - filename: 파일명 (savePhoto에서 반환된 값)
    ///   - visitID: 방문 기록 ID
    /// - Returns: UIImage, 실패 시 nil
    func loadPhoto(filename: String, visitID: UUID) -> UIImage? {
        guard let fileURL = photoURL(for: filename, visitID: visitID) else {
            return nil
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            print("❌ 파일 로드 실패: \(filename)")
            return nil
        }

        return UIImage(data: data)
    }

    /// 특정 사진 파일 삭제
    /// - Parameters:
    ///   - filename: 삭제할 파일명
    ///   - visitID: 방문 기록 ID
    func deletePhoto(filename: String, visitID: UUID) {
        guard let fileURL = photoURL(for: filename, visitID: visitID) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: fileURL)
            print("✅ 사진 삭제 성공: \(filename)")
        } catch {
            print("❌ 사진 삭제 실패: \(error.localizedDescription)")
        }
    }

    /// 방문 기록의 모든 사진 삭제 (방문 삭제 시 호출)
    /// - Parameter visitID: 방문 기록 ID
    func deleteAllPhotos(for visitID: UUID) {
        guard let directoryURL = visitDirectoryURL(for: visitID) else {
            return
        }

        do {
            try FileManager.default.removeItem(at: directoryURL)
            print("✅ 방문 \(visitID)의 모든 사진 삭제 완료")
        } catch {
            print("❌ 디렉토리 삭제 실패: \(error.localizedDescription)")
        }
    }

    /// 사진의 파일 URL 반환
    /// - Parameters:
    ///   - filename: 파일명
    ///   - visitID: 방문 기록 ID
    /// - Returns: 파일 URL, 파일이 없으면 nil
    func photoURL(for filename: String, visitID: UUID) -> URL? {
        guard let directoryURL = visitDirectoryURL(for: visitID) else {
            return nil
        }

        let fileURL = directoryURL.appendingPathComponent(filename)

        // 파일 존재 여부 확인
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            print("⚠️ 파일이 존재하지 않음: \(filename)")
            return nil
        }

        return fileURL
    }

    /// 다른 곳(iCloud 백업)에서 받은 사진 파일을 그 방문의 자리에 둔다. 같은 이름이 있으면 바꾼다.
    @discardableResult
    func importPhoto(from source: URL, filename: String, for visitID: UUID) -> Bool {
        guard let directoryURL = createVisitDirectory(for: visitID) else { return false }
        let target = directoryURL.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: target.path) {
                try FileManager.default.removeItem(at: target)
            }
            try FileManager.default.copyItem(at: source, to: target)
            return true
        } catch {
            print("❌ 사진 가져오기 실패: \(filename) - \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    /// 기록에 넣을 사진 데이터. 리사이징 + JPEG 압축(~800KB 이하). (→ Visit.addPhoto)
    func jpegData(for image: UIImage) -> Data? {
        compressImage(image)
    }

    /// 이미지 압축 (리사이징 + JPEG 압축)
    /// - Parameter image: 압축할 UIImage
    /// - Returns: 압축된 Data (~800KB 이하), 실패 시 nil
    private func compressImage(_ image: UIImage) -> Data? {
        // 1. 리사이징 (최대 1024x1024)
        let resizedImage = resizeImage(image, maxSize: maxImageSize)

        // 2. JPEG 압축 (0.75 품질부터 시작)
        var quality = compressionQuality
        var compressedData = resizedImage.jpegData(compressionQuality: quality)

        // 3. 목표 크기(800KB)보다 크면 품질 낮춰서 재시도
        while let data = compressedData, data.count > targetFileSize && quality > 0.3 {
            quality -= 0.1
            compressedData = resizedImage.jpegData(compressionQuality: quality)
        }

        if let data = compressedData {
            print("📦 이미지 압축 완료: \(data.count / 1000)KB (품질: \(String(format: "%.1f", quality)))")
        }

        return compressedData
    }

    /// 이미지 리사이징
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - maxSize: 최대 너비/높이
    /// - Returns: 리사이징된 이미지
    private func resizeImage(_ image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size

        // 이미 작으면 그대로 반환. 크기가 0 이거나 숫자가 아닌 그림은 그리려 하면 죽으므로 건드리지 않는다.
        guard size.width.isFinite, size.height.isFinite, size.width > 0, size.height > 0,
              size.width > maxSize || size.height > maxSize else {
            return image
        }

        // 비율 유지하며 리사이징
        let aspectRatio = size.width / size.height
        var newSize: CGSize

        if size.width > size.height {
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }

        // 아주 길쭉한 그림은 짧은 변이 0 에 가까워진다 — 1 아래로는 내리지 않는다
        newSize = CGSize(width: max(newSize.width.rounded(), 1), height: max(newSize.height.rounded(), 1))

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }

    /// 방문 기록의 사진 디렉토리 URL 반환
    /// - Parameter visitID: 방문 기록 ID
    /// - Returns: 디렉토리 URL, 실패 시 nil
    private func visitDirectoryURL(for visitID: UUID) -> URL? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        return documentsURL
            .appendingPathComponent(baseDirectory)
            .appendingPathComponent(visitID.uuidString)
    }

    /// 방문 기록의 사진 디렉토리 생성 (없으면 자동 생성)
    /// - Parameter visitID: 방문 기록 ID
    /// - Returns: 생성된 디렉토리 URL, 실패 시 nil
    private func createVisitDirectory(for visitID: UUID) -> URL? {
        guard let directoryURL = visitDirectoryURL(for: visitID) else {
            return nil
        }

        // 디렉토리가 이미 존재하면 그대로 반환
        if FileManager.default.fileExists(atPath: directoryURL.path) {
            return directoryURL
        }

        // 디렉토리 생성
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("✅ 디렉토리 생성: \(directoryURL.path)")
            return directoryURL
        } catch {
            print("❌ 디렉토리 생성 실패: \(error.localizedDescription)")
            return nil
        }
    }
}
