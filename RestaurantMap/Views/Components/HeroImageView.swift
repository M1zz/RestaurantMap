import SwiftUI

/// 방문 상세 화면 상단의 큰 히어로 이미지
struct HeroImageView: View {
    let imageURL: URL?
    let height: CGFloat

    init(imageURL: URL?, height: CGFloat = 250) {
        self.imageURL = imageURL
        self.height = height
    }

    var body: some View {
        AsyncImage(url: imageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: height)
                    .clipped()
            case .failure:
                failurePlaceholder
            case .empty:
                loadingPlaceholder
            @unknown default:
                loadingPlaceholder
            }
        }
        .frame(height: height)
    }

    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: height)
            .overlay {
                ProgressView()
            }
    }

    private var failurePlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(height: height)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                    Text("이미지를 불러올 수 없습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
    }
}
