import SwiftUI

/// 여러 사진을 그리드 레이아웃으로 표시하는 갤러리 뷰
struct PhotoGalleryView: View {
    let photoURLs: [URL]
    let isEditable: Bool
    let onDelete: ((Int) -> Void)?

    @State private var selectedPhotoIndex: Int?

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, url in
                photoThumbnail(for: url, at: index)
            }
        }
        .fullScreenCover(item: $selectedPhotoIndex) { index in
            PhotoDetailView(photoURLs: photoURLs, initialIndex: index)
        }
    }

    @ViewBuilder
    private func photoThumbnail(for url: URL, at index: Int) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipped()
                    .cornerRadius(8)
            case .failure:
                failurePlaceholder
            case .empty:
                loadingPlaceholder
            @unknown default:
                loadingPlaceholder
            }
        }
        .frame(width: 100, height: 100)
        .onTapGesture {
            selectedPhotoIndex = index
        }
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

// MARK: - Int Identifiable Extension
extension Int: Identifiable {
    public var id: Int { self }
}
