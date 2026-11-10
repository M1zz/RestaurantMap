import SwiftUI

/// 여러 사진을 그리드 레이아웃으로 표시하는 갤러리 뷰
struct PhotoGalleryView: View {
    let photos: [VisitPhoto]
    let isEditable: Bool
    let onDelete: ((Int) -> Void)?

    @State private var selectedPhotoIndex: Int?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(photos.enumerated()), id: \.element.id) { index, photo in
                photoThumbnail(for: photo, at: index)
            }
        }
        .fullScreenCover(item: $selectedPhotoIndex) { index in
            PhotoDetailView(photos: photos, initialIndex: index)
        }
    }

    @ViewBuilder
    private func photoThumbnail(for photo: VisitPhoto, at index: Int) -> some View {
        PhotoDataImage(data: photo.data) { image in
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
            selectedPhotoIndex = index
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
            let decoded = await Task.detached(priority: .userInitiated) { UIImage(data: data) }.value
            if let decoded { image = decoded } else { failed = true }
        }
    }
}

// MARK: - Int Identifiable Extension
extension Int: Identifiable {
    public var id: Int { self }
}
