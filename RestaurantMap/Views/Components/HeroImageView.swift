import SwiftUI

/// 방문 상세 화면 상단의 큰 히어로 이미지
struct HeroImageView: View {
    let data: Data?
    let height: CGFloat

    init(data: Data?, height: CGFloat = 250) {
        self.data = data
        self.height = height
    }

    var body: some View {
        PhotoDataImage(data: data) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: height)
                .clipped()
        } loading: {
            loadingPlaceholder
        } failure: {
            failurePlaceholder
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
