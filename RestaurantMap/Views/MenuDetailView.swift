import SwiftUI
import SwiftData

struct MenuDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var menuItem: MenuItem

    @State private var isEditing = false
    @State private var editName = ""
    @State private var editPrice = ""
    @State private var editDescription = ""
    @State private var editIsSignature = false
    @State private var editPhoto: UIImage?
    /// 편집을 시작할 때의 사진 — 손대지 않았으면 다시 줄여 저장하지 않는다
    @State private var originalEditPhoto: UIImage?

    var sortedVisits: [Visit] {
        (menuItem.visits ?? []).filter { !$0.isDeleted }.sorted(by: { $0.visitDate > $1.visitDate })
    }

    var body: some View {
        // 열려 있는 사이 지워진 메뉴의 속성을 읽으면 죽는다 — 빈 화면으로 둔다
        if menuItem.isGone {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        NavigationStack {
            List {
                // 메뉴 사진 (붙인 사진, 없으면 최근 방문 사진)
                if !isEditing, let cover = menuItem.coverPhotoData {
                    Section {
                        HeroImageView(data: cover, height: 220)
                            .listRowInsets(EdgeInsets())
                    }
                }

                // 내 평가 — 바로 고치고 바로 저장한다
                if !isEditing {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("내 점수")
                                .font(.body)
                            MenuRatingPicker(rating: $menuItem.myRating)
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text("다음에 또 시킬까요?")
                                .font(.body)
                            ReorderPicker(value: $menuItem.wouldOrderAgain)
                        }
                    } header: {
                        Text("내 평가")
                    } footer: {
                        Text("점수를 매기지 않으면 이 메뉴를 고른 방문의 별점 평균을 보여 줘요")
                    }
                }

                // 메뉴 정보
                Section("메뉴 정보") {
                    if isEditing {
                        MenuPhotoField(image: $editPhoto)

                        TextField("메뉴 이름", text: $editName)

                        HStack {
                            TextField("가격", text: $editPrice)
                                .keyboardType(.numberPad)
                            Text(Locale.current.currencySymbol ?? "")
                                .foregroundStyle(.secondary)
                        }

                        TextField("메뉴 설명", text: $editDescription, axis: .vertical)
                            .lineLimit(3...5)

                        Toggle("대표 메뉴", isOn: $editIsSignature)
                    } else {
                        HStack {
                            Text("메뉴 이름")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(menuItem.name)
                                .fontWeight(.medium)
                        }

                        HStack {
                            Text("가격")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(menuItem.formattedPrice)
                                .fontWeight(.medium)
                        }

                        if !menuItem.menuDescription.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("설명")
                                    .foregroundStyle(.secondary)
                                Text(menuItem.menuDescription)
                            }
                        }

                        if menuItem.isSignature {
                            HStack {
                                Image(systemName: "crown.fill")
                                    .foregroundStyle(.yellow)
                                Text("대표 메뉴")
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                // 통계
                Section("통계") {
                    LabeledContent("주문 횟수") {
                        Text("\(menuItem.orderCount)회")
                            .fontWeight(.medium)
                    }

                    if menuItem.orderCount > 0 {
                        LabeledContent("평균 별점") {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.caption)
                                    .foregroundStyle(.yellow)
                                Text(String(format: "%.1f", menuItem.averageRating))
                                    .fontWeight(.medium)
                            }
                        }

                        if let lastOrderDate = menuItem.lastOrderDate {
                            LabeledContent("최근 주문일") {
                                Text(lastOrderDate, format: .dateTime.year().month().day())
                                    .fontWeight(.medium)
                            }
                        }
                    }
                }

                // 이 메뉴를 고른 방문의 사진
                let visitPhotos = menuItem.visitPhotos
                if !isEditing, !visitPhotos.isEmpty {
                    Section {
                        PhotoGalleryView(photos: visitPhotos, isEditable: false, onDelete: nil)
                            .padding(.vertical, 4)
                    } header: {
                        Text("방문 사진 (\(visitPhotos.count))")
                    }
                }

                // 평가 히스토리
                Section {
                    if sortedVisits.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 40))
                                .foregroundStyle(.gray.opacity(0.5))
                            Text("아직 평가가 없습니다")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("방문 기록 추가 시 이 메뉴를 선택해주세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(sortedVisits) { visit in
                            MenuVisitRowView(visit: visit)
                        }
                    }
                } header: {
                    Text("평가 히스토리 (\(sortedVisits.count))")
                }
            }
            #if !os(visionOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .onChange(of: menuItem.myRating) { _, _ in modelContext.saveNow() }
            .onChange(of: menuItem.wouldOrderAgain) { _, _ in modelContext.saveNow() }
            .navigationTitle(menuItem.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? LocalizedStringKey("완료") : LocalizedStringKey("편집"), systemImage: isEditing ? "checkmark" : "pencil") {
                        if isEditing {
                            saveChanges()
                        } else {
                            startEditing()
                        }
                        isEditing.toggle()
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing {
                        Button("취소", systemImage: "xmark") {
                            isEditing = false
                        }
                    } else {
                        Button("닫기", systemImage: "xmark") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }

    private func startEditing() {
        editName = menuItem.name
        editPrice = menuItem.price.map { String($0) } ?? ""
        editDescription = menuItem.menuDescription
        editIsSignature = menuItem.isSignature
        editPhoto = menuItem.photoData.flatMap { PhotoDownsampler.image(from: $0, maxPixel: 1024) }
        originalEditPhoto = editPhoto
    }

    private func saveChanges() {
        menuItem.name = editName
        menuItem.price = Int(editPrice.filter { $0.isNumber })
        menuItem.menuDescription = editDescription
        menuItem.isSignature = editIsSignature
        if editPhoto !== originalEditPhoto {
            menuItem.setPhoto(editPhoto)
        }
        editPhoto = nil
        originalEditPhoto = nil
        // 고친 것을 바로 내린다
        modelContext.saveNow()
    }
}

// MARK: - Menu Visit Row View
struct MenuVisitRowView: View {
    let visit: Visit

    var body: some View {
        if !visit.isGone { row }
    }

    private var row: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(visit.visitDate, format: .dateTime.year().month().day())
                    .font(.headline)

                Spacer()

                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < visit.rating ? "star.fill" : "star")
                            .foregroundStyle(index < visit.rating ? .yellow : .gray)
                            .font(.system(size: 12))
                    }
                }
                .starRatingLabel(Double(visit.rating))
            }

            if !visit.notes.isEmpty {
                Text(visit.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if visit.hasTasteNote {
                HStack(spacing: 4) {
                    Image(systemName: "chart.pie.fill")
                        .font(.caption2)
                    Text("맛 평가됨")
                        .font(.caption2)
                }
                .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, MenuItem.self, Visit.self, configurations: config)

    let restaurant = Restaurant(
        name: "테스트 식당",
        address: "서울시",
        latitude: 37.5,
        longitude: 127.0
    )
    container.mainContext.insert(restaurant)

    let menuItem = MenuItem(name: "불고기", price: 15000, menuDescription: "특제 양념에 재운 불고기", isSignature: true, restaurant: restaurant)
    container.mainContext.insert(menuItem)

    let visit1 = Visit(restaurant: restaurant, visitDate: Date(), notes: "정말 맛있었어요!", rating: 5)
    visit1.menu = menuItem
    container.mainContext.insert(visit1)

    let visit2 = Visit(restaurant: restaurant, visitDate: Date().addingTimeInterval(-86400 * 7), notes: "양념이 딱 좋았어요", rating: 4)
    visit2.menu = menuItem
    container.mainContext.insert(visit2)

    return MenuDetailView(menuItem: menuItem)
        .modelContainer(container)
}

// MARK: - 메뉴 평가 · 사진 고르기 (메뉴 추가 · 메뉴 자세히 · 방문 추가가 같이 쓴다)

/// 메뉴 점수 1~5. 고른 별을 다시 누르면 지운다(0 = 안 매김).
struct MenuRatingPicker: View {
    @Binding var rating: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(1...5, id: \.self) { index in
                Image(systemName: index <= rating ? "star.fill" : "star")
                    .foregroundStyle(index <= rating ? .yellow : .gray)
                    .font(.system(size: 28))
                    .accessibleStar(index, rating: rating) {
                        rating = rating == index ? 0 : index
                    }
            }
        }
    }
}

/// 다음에 또 시킬지. 고른 쪽을 다시 누르면 '안 정함'(nil)으로 돌아간다.
struct ReorderPicker: View {
    @Binding var value: Bool?

    var body: some View {
        AdaptiveStack(spacing: 12) {
            choice(true)
            choice(false)
        }
    }

    private func choice(_ option: Bool) -> some View {
        let selected = value == option
        return Button {
            value = selected ? nil : option
        } label: {
            ReorderLabel(again: option)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .tint(selected ? (option ? .green : .orange) : .gray)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// "또 시킬래요" / "다음엔 안 시킬래요" 한 줄
struct ReorderLabel: View {
    let again: Bool

    var body: some View {
        Label(again ? LocalizedStringKey("또 시킬래요") : LocalizedStringKey("다음엔 안 시킬래요"),
              systemImage: again ? "hand.thumbsup.fill" : "hand.thumbsdown.fill")
            .font(.body)
    }
}

/// 메뉴 사진 한 장 — 새로 고르면 바꾸고, 엑스로 뗀다.
struct MenuPhotoField: View {
    @Binding var image: UIImage?
    @State private var picked: [UIImage] = []

    var body: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topTrailing) {
                    Button {
                        self.image = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.white, .red)
                            .shadow(radius: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("사진 삭제"))
                    .padding(8)
                }
        }
        PhotoPickerView(selectedImages: $picked)
            .onChange(of: picked) { _, newValue in
                // 여러 장을 골라도 메뉴 사진은 한 장 — 마지막 것을 쓴다
                guard let last = newValue.last else { return }
                image = last
                picked = []
            }
    }
}
