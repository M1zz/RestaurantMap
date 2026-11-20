import SwiftUI
import SwiftData
import OSLog

// MARK: - Wrapper with Loading Screen
struct VisitDetailViewWrapper: View {
    let visit: Visit
    @State private var isLoading = true
    @State private var hasError = false
    @State private var showError = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "VisitDetail")

    var body: some View {
        Group {
            if showError {
                ErrorSheetView()
            } else if isLoading {
                LoadingSheetView()
            } else {
                VisitDetailView(visit: visit)
            }
        }
        .onAppear {
            logger.info("🔵 VisitDetailViewWrapper.onAppear - 시작")
            logger.info("  - Visit Date: \(visit.visitDate)")
            logger.info("  - Visit Rating: \(visit.rating)")

            // 데이터 검증
            if visit.restaurant == nil {
                logger.error("❌ visit.restaurant == nil")
                hasError = true
            } else {
                logger.info("  ✅ Restaurant: \(visit.restaurant?.name ?? "Unknown")")
            }

            // 로딩 화면 표시 시간 증가
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                logger.info("🔵 0.5초 후 - hasError: \(hasError), isLoading: \(isLoading)")
                withAnimation {
                    if hasError {
                        logger.warning("⚠️ 에러로 인해 showError = true")
                        showError = true
                    }
                    isLoading = false
                }
            }

            // 하얀 화면 방지: 일정 시간 후에도 로딩 중이면 에러 표시
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if isLoading {
                    logger.error("❌ 2초 타임아웃 - 강제 에러 표시")
                    withAnimation {
                        showError = true
                        isLoading = false
                    }
                }
            }
        }
    }
}

struct VisitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var visit: Visit

    @State private var isEditing = false
    @State private var saveFailed = false
    @State private var editingPhotos: [UIImage] = [] // 편집 중 추가할 새 사진들
    @State private var photosToDelete: Set<UUID> = [] // 편집 중 삭제 표시된 사진들

    private let logger = Logger(subsystem: "com.restaurantmap", category: "VisitDetail")

    var body: some View {
        NavigationStack {
            Form {
                // 히어로 이미지 (읽기 모드만)
                if !isEditing, let hero = visit.heroPhoto {
                    Section {
                        HeroImageView(data: hero.data)
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section("방문 정보") {
                    if isEditing {
                        DatePicker("방문 날짜", selection: $visit.visitDate, displayedComponents: .date)

                        // 등록된 메뉴가 있으면 선택 가능
                        if let restaurant = visit.restaurant, let menus = restaurant.menus, !menus.isEmpty {
                            Picker("메뉴 선택", selection: $visit.menu) {
                                Text("직접 입력").tag(nil as MenuItem?)
                                ForEach(menus.sorted(by: { $0.name < $1.name })) { menu in
                                    HStack {
                                        Text(menu.name)
                                        if menu.isSignature {
                                            Image(systemName: "crown.fill")
                                                .foregroundStyle(.yellow)
                                        }
                                    }
                                    .tag(menu as MenuItem?)
                                }
                            }
                        }

                        // 직접 입력 (메뉴 미선택 시)
                        if visit.menu == nil {
                            TextField("먹은 메뉴", text: $visit.menuItem)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("별점")
                                .font(.subheadline)

                            HStack(spacing: 8) {
                                ForEach(1...5, id: \.self) { index in
                                    Image(systemName: index <= visit.rating ? "star.fill" : "star")
                                        .foregroundStyle(index <= visit.rating ? .yellow : .gray)
                                        .font(.system(size: 28))
                                        .accessibleStar(index, rating: visit.rating) {
                                            visit.rating = index
                                        }
                                }
                            }
                        }
                    } else {
                        LabeledContent("방문 날짜") {
                            Text(visit.visitDate, format: .dateTime.year().month().day())
                        }

                        if !visit.displayMenuName.isEmpty {
                            LabeledContent("먹은 메뉴") {
                                HStack(spacing: 4) {
                                    Image(systemName: "fork.knife")
                                        .font(.caption)
                                    Text(visit.displayMenuName)
                                        .fontWeight(.medium)
                                    if visit.menu?.isSignature == true {
                                        Image(systemName: "crown.fill")
                                            .font(.caption2)
                                            .foregroundStyle(.yellow)
                                    }
                                }
                                .foregroundStyle(.orange)
                            }
                        }

                        LabeledContent("별점") {
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < visit.rating ? "star.fill" : "star")
                                        .foregroundStyle(index < visit.rating ? .yellow : .gray)
                                        .font(.system(size: 14))
                                }
                            }
                            .starRatingLabel(Double(visit.rating))
                        }
                    }
                }

                // 미식 기준 (→ Gourmet.swift)
                if isEditing {
                    GourmetInputSection(values: Binding(
                        get: {
                            Dictionary(uniqueKeysWithValues: GourmetCriterion.allCases.compactMap { criterion in
                                visit[criterion].map { (criterion, $0) }
                            })
                        },
                        set: { new in
                            for criterion in GourmetCriterion.allCases { visit[criterion] = new[criterion] }
                        }))
                } else if visit.hasGourmetNote {
                    Section("미식 기준") {
                        ForEach(GourmetCriterion.allCases) { criterion in
                            if let value = visit[criterion] {
                                GourmetBar(criterion: criterion, value: Double(value))
                            }
                        }
                    }
                }

                // 맛 (→ Taste.swift)
                if isEditing {
                    TasteInputSection(family: visit.restaurant?.tasteFamily ?? .basic,
                                      values: Binding(get: { visit.tastes }, set: { visit.tastes = $0 }))
                } else if visit.hasTasteNote {
                    Section("맛") {
                        ForEach(TasteAxis.allCases.filter { visit[$0] != nil }) { axis in
                            TasteAxisBar(axis: axis, value: Double(visit[axis] ?? 3))
                        }
                    }
                }

                Section("메모") {
                    if isEditing {
                        TextEditor(text: $visit.notes)
                            .frame(minHeight: 100)
                    } else {
                        if visit.notes.isEmpty {
                            Text("메모 없음")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(visit.notes)
                        }
                    }
                }

                // 사진 갤러리
                if visit.hasPhotos || isEditing {
                    Section {
                        if isEditing {
                            // 편집 모드: 추가/삭제
                            PhotoPickerView(selectedImages: $editingPhotos)

                            // 삭제 표시된 사진은 빼고 보인다
                            let remaining = visit.sortedPhotos.filter { !photosToDelete.contains($0.id) }
                            if !remaining.isEmpty {
                                PhotoGalleryView(
                                    photos: remaining,
                                    isEditable: true,
                                    onDelete: { index in
                                        if index < remaining.count {
                                            photosToDelete.insert(remaining[index].id)
                                        }
                                    }
                                )
                            }

                            // 새로 추가된 사진 미리보기
                            if !editingPhotos.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("새로 추가될 사진")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(Array(editingPhotos.enumerated()), id: \.offset) { index, image in
                                                Image(uiImage: image)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 100, height: 100)
                                                    .clipped()
                                                    .cornerRadius(8)
                                                    .overlay(alignment: .topTrailing) {
                                                        Button {
                                                            editingPhotos.remove(at: index)
                                                        } label: {
                                                            Image(systemName: "xmark.circle.fill")
                                                                .font(.system(size: 20))
                                                                .foregroundStyle(.white, .red)
                                                                .shadow(radius: 2)
                                                        }
                                                        .accessibilityLabel(Text("사진 삭제"))
                                                        .padding(4)
                                                    }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // 읽기 모드: 갤러리 표시
                            if visit.hasPhotos {
                                PhotoGalleryView(
                                    photos: visit.sortedPhotos,
                                    isEditable: false,
                                    onDelete: nil
                                )
                            }
                        }
                    } header: {
                        let currentPhotoCount = (visit.photos?.count ?? 0) - photosToDelete.count + editingPhotos.count
                        Text("사진 (\(currentPhotoCount))")
                    }
                }
            }
            #if !os(visionOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .navigationTitle(visit.restaurant?.name ?? String(localized: "방문 기록"))
            .saveFailureAlert($saveFailed)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", systemImage: "xmark") {
                        logger.info("🔵 닫기 버튼 클릭")
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? LocalizedStringKey("완료") : LocalizedStringKey("편집"), systemImage: isEditing ? "checkmark" : "pencil") {
                        logger.info("🔵 편집 버튼 클릭 - isEditing: \(isEditing) -> \(!isEditing)")

                        if isEditing {
                            // 편집 완료: 사진 저장 및 삭제 처리
                            // 1. 새 사진 저장
                            for image in editingPhotos {
                                visit.addPhoto(image)
                            }
                            logger.info("  - \(editingPhotos.count)장의 새 사진 저장됨")

                            // 2. 표시된 사진 삭제
                            for photo in (visit.photos ?? []) where photosToDelete.contains(photo.id) {
                                modelContext.delete(photo)
                            }
                            logger.info("  - \(photosToDelete.count)장의 사진 삭제됨")

                            // 3. 상태 초기화
                            editingPhotos.removeAll()
                            photosToDelete.removeAll()

                            // 4. 변경사항 저장 — 실패하면 알리고 편집을 닫지 않는다
                            do {
                                try modelContext.save()
                            } catch {
                                logger.error("방문 고치기 저장 실패: \(error.localizedDescription)")
                                saveFailed = true
                                return
                            }
                        }

                        isEditing.toggle()
                    }
                }
            }
            .onAppear {
                logger.info("🟢 VisitDetailView.onAppear")
                logger.info("  - Restaurant: \(visit.restaurant?.name ?? "nil")")
                logger.info("  - Visit Date: \(visit.visitDate)")
                logger.info("  - Rating: \(visit.rating)")
            }
        }
    }

}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Visit.self, Restaurant.self, configurations: config)

    let restaurant = Restaurant(
        name: "샘플 식당",
        address: "서울시",
        latitude: 37.5,
        longitude: 127.0
    )
    container.mainContext.insert(restaurant)

    let visit = Visit(restaurant: restaurant, visitDate: Date(), notes: "맛있었어요!", rating: 4)
    container.mainContext.insert(visit)

    return VisitDetailView(visit: visit)
        .modelContainer(container)
}
