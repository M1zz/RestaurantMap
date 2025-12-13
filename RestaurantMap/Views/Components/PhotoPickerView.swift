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

    // 카메라 사용 가능 여부 확인
    private var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
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
        .sheet(isPresented: $showingCamera) {
            CameraView(image: $cameraImage)
        }
        .onChange(of: photoPickerItems) { oldValue, newValue in
            Task {
                await loadPhotosFromPicker(newValue)
            }
        }
        .onChange(of: cameraImage) { oldValue, newValue in
            if let image = newValue {
                selectedImages.append(image)
                cameraImage = nil // 리셋
            }
        }
    }

    /// PhotosPicker에서 선택한 사진들을 UIImage로 변환
    private func loadPhotosFromPicker(_ items: [PhotosPickerItem]) async {
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    selectedImages.append(image)
                }
            }
        }

        // 선택 완료 후 초기화
        await MainActor.run {
            photoPickerItems = []
        }
    }
}
