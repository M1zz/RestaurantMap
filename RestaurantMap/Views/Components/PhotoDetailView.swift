import SwiftUI

/// 전체화면 사진 뷰어 (스와이프로 이동, 핀치 줌 지원)
struct PhotoDetailView: View {
    let photoURLs: [URL]
    let initialIndex: Int

    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(photoURLs: [URL], initialIndex: Int) {
        self.photoURLs = photoURLs
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(photoURLs.enumerated()), id: \.offset) { index, url in
                    ZoomableImageView(url: url)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // 닫기 버튼
            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(.white.opacity(0.8), .black.opacity(0.5))
                    }
                    .padding()
                }
                Spacer()
            }

            // 페이지 인디케이터 (하단)
            VStack {
                Spacer()
                Text("\(currentIndex + 1) / \(photoURLs.count)")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.5))
                    .cornerRadius(12)
                    .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - Zoomable Image View
struct ZoomableImageView: View {
    let url: URL

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .gesture(magnificationGesture)
                        .gesture(dragGesture)
                        .onTapGesture(count: 2) {
                            // 더블 탭으로 줌 리셋
                            withAnimation {
                                scale = 1.0
                                offset = .zero
                                lastScale = 1.0
                                lastOffset = .zero
                            }
                        }
                case .failure:
                    failurePlaceholder
                case .empty:
                    loadingPlaceholder
                @unknown default:
                    loadingPlaceholder
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }

    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                scale = min(max(scale * delta, 1.0), 5.0) // 1x ~ 5x 줌
            }
            .onEnded { _ in
                lastScale = 1.0
                if scale < 1.0 {
                    withAnimation {
                        scale = 1.0
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
                // 줌이 1x이면 오프셋 리셋
                if scale == 1.0 {
                    withAnimation {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }

    private var loadingPlaceholder: some View {
        Color.black
            .overlay {
                ProgressView()
                    .tint(.white)
            }
    }

    private var failurePlaceholder: some View {
        Color.black
            .overlay {
                VStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.gray)
                    Text("이미지를 불러올 수 없습니다")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
            }
    }
}
