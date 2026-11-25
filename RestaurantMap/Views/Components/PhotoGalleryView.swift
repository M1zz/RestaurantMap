import SwiftUI

/// 여러 사진을 그리드 레이아웃으로 표시하는 갤러리 뷰
struct PhotoGalleryView: View {
    let photos: [VisitPhoto]
    let isEditable: Bool
    let onDelete: ((Int) -> Void)?

    /// 크게 볼 사진. `fullScreenCover(item:)` 는 Identifiable 을 원해서 번호를 감싼다.
    private struct Opened: Identifiable { let id: Int }
    @State private var opened: Opened?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                photoThumbnail(for: photo, at: index)
            }
        }
        .fullScreenCover(item: $opened) { opened in
            PhotoDetailView(photos: photos, initialIndex: opened.id)
        }
    }

    @ViewBuilder
    private func photoThumbnail(for photo: VisitPhoto, at index: Int) -> some View {
        // 100pt 칸이다 — 원본 크기로 풀지 않는다 (사진이 많은 방문에서 메모리로 꺼지던 자리)
        PhotoDataImage(data: photo.data, maxPixel: 400, cacheKey: photo.id.uuidString) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipped()
                .cornerRadius(8)
        } loading: {
            loadingPlaceholder
        } failure: {
            failurePlaceholder
        }
        .frame(width: 100, height: 100)
        .accessibleTap {
            opened = Opened(id: index)
        }
        .accessibilityLabel(Text("사진"))
        .overlay(alignment: .topTrailing) {
            if isEditable {
                deleteButton(for: index)
            }
        }
    }

    private func deleteButton(for index: Int) -> some View {
        Button {
            onDelete?(index)
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(.white, .red)
                .shadow(radius: 2)
        }
        .accessibilityLabel(Text("사진 삭제"))
        .padding(4)
    }

    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 100, height: 100)
            .cornerRadius(8)
            .overlay {
                ProgressView()
            }
    }

    private var failurePlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 100, height: 100)
            .cornerRadius(8)
            .overlay {
                Image(systemName: "photo.fill")
                    .foregroundStyle(.gray)
            }
    }
}

/// 기록 안의 사진 데이터를 화면 밖에서 풀어 그린다 (AsyncImage 의 파일 URL 자리를 대신한다).
struct PhotoDataImage<Content: View, Loading: View, Failure: View>: View {
    let data: Data?
    /// 긴 변을 이 픽셀까지만 푼다. nil 이면 원본 크기 (크게 보는 화면).
    var maxPixel: CGFloat? = nil
    /// 줄인 그림을 잠깐 쥐어 둘 이름 (사진 ID). nil 이면 쥐어 두지 않는다.
    var cacheKey: String? = nil
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let loading: () -> Loading
    @ViewBuilder let failure: () -> Failure

    @State private var image: UIImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image {
                content(Image(uiImage: image))
            } else if failed {
                failure()
            } else {
                loading()
            }
        }
        .task(id: data?.count ?? 0) {
            guard let data else { failed = true; return }
            let key = cacheKey.flatMap { key in maxPixel.map { "\(key)@\(Int($0))" as NSString } }
            if let key, let cached = PhotoDownsampler.thumbnails.object(forKey: key) {
                image = cached
                return
            }
            let maxPixel = maxPixel
            let decoded = await Task.detached(priority: .userInitiated) { () -> UIImage? in
                if let maxPixel { return PhotoDownsampler.image(from: data, maxPixel: maxPixel) }
                return UIImage(data: data)
            }.value
            if let decoded {
                if let key { PhotoDownsampler.thumbnails.setObject(decoded, forKey: key, cost: decoded.cgImage.map { $0.bytesPerRow * $0.height } ?? 0) }
                image = decoded
            } else {
                failed = true
            }
        }
    }
}
