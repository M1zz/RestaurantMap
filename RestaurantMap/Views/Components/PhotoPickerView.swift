import SwiftUI
import PhotosUI

/// 앨범에서 선택 또는 카메라로 촬영을 통합한 사진 추가 버튼
struct PhotoPickerView: View {
    @Binding var selectedImages: [UIImage]
    @State private var showingActionSheet = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var cameraImage: UIImage?
    /// 이번에 고른 사진 중 불러오지 못한 장 수 (iCloud 사진 · 오프라인 · 깨진 파일)
    @State private var failedCount = 0

    // 카메라 사용 가능 여부 확인
    private var isCameraAvailable: Bool {
        #if os(visionOS)
        false
        #else
        UIImagePickerController.isSourceTypeAvailable(.camera)
        #endif
    }

    var body: some View {
        Button {
            showingActionSheet = true
        } label: {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                Text("사진 추가")
            }
        }
        .confirmationDialog("사진 선택", isPresented: $showingActionSheet) {
            Button("앨범에서 선택") {
                showingPhotoPicker = true
            }

            if isCameraAvailable {
                Button("카메라로 촬영") {
                    showingCamera = true
                }
            }

            Button("취소", role: .cancel) {}
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $photoPickerItems,
            maxSelectionCount: 10,
            matching: .images
        )
        .alert("사진 \(failedCount)장을 불러오지 못했어요", isPresented: Binding(get: { failedCount > 0 }, set: { if !$0 { failedCount = 0 } })) {
            Button("확인", role: .cancel) { }
        }
        #if !os(visionOS)
        .sheet(isPresented: $showingCamera) {
            CameraView(image: $cameraImage)
        }
        #endif
        .onChange(of: photoPickerItems) { oldValue, newValue in
            Task {
                await loadPhotosFromPicker(newValue)
            }
        }
        .onChange(of: cameraImage) { oldValue, newValue in
            if let image = newValue {
                // 찍은 사진도 같은 크기로 줄여 든다
                selectedImages.append(PickedPhoto.shrunk(image))
                cameraImage = nil // 리셋
            }
        }
    }

    /// PhotosPicker에서 선택한 사진들을 UIImage로 변환
    private func loadPhotosFromPicker(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        var failed = 0
        for item in items {
            // 원본(24~48MP)을 그대로 쥐고 미리보기로 그리면 한 장에 100MB 넘게 든다 — 열 장을 고르면 앱이 꺼진다.
            // 저장할 때 어차피 줄이므로(→ PhotoStorageManager) 여기서 먼저 줄여 든다.
            // 줄이지 못한 사진을 원본 크기(UIImage(data:))로 받지 않는다 — 그게 바로 메모리로 꺼지던 길이다. 못 불러온 것으로 센다.
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = PhotoDownsampler.image(from: data, maxPixel: PickedPhoto.maxPixel) {
                await MainActor.run {
                    selectedImages.append(image)
                }
            } else {
                failed += 1
            }
        }

        // 선택 완료 후 초기화. 못 불러온 사진이 있으면 말없이 빠지지 않게 알린다.
        await MainActor.run {
            photoPickerItems = []
            if failed > 0 { failedCount = failed }
        }
    }
}

/// 고른 사진을 저장 전까지 들고 있을 크기.
enum PickedPhoto {
    /// 저장되는 크기(긴 변 1024pt × 화면 배율)보다 작지 않게 — 저장되는 사진의 화질은 그대로다.
    /// 배율은 저장할 때 줄이는 렌더러(`resizeImage`)가 쓰는 것과 같은 값을 쓴다. `UITraitCollection.current` 는
    /// 그리기 밖에서 1 로 나올 수 있어, 그러면 사진을 미리 1024px 로 줄여 저장 화질이 떨어졌다.
    static var maxPixel: CGFloat { 1024 * max(UIGraphicsImageRendererFormat.default().scale, 1) }

    /// 이미 풀려 있는 큰 그림(카메라)을 줄인다. 줄일 수 없으면 그대로 돌려준다.
    static func shrunk(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height) * image.scale
        guard longest.isFinite, longest > maxPixel,
              let data = image.jpegData(compressionQuality: 0.95),
              let small = PhotoDownsampler.image(from: data, maxPixel: maxPixel) else { return image }
        return small
    }
}
