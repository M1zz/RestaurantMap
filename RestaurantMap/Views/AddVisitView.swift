import SwiftUI
import SwiftData
import OSLog

struct AddVisitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let restaurant: Restaurant

    @State private var visitDate = Date()
    @State private var notes = ""
    @State private var rating = 3
    /// 미식 기준 (→ Gourmet.swift). 적지 않은 기준은 들어 있지 않다.
    @State private var gourmet: [GourmetCriterion: Int] = [:]
    @State private var saveFailed = false
    @State private var menuItem = "" // 먹은 메뉴 이름 (텍스트)
    @State private var selectedMenu: MenuItem? // 선택한 메뉴 (등록된 메뉴 중)
    @State private var showingAddMenu = false // 메뉴 추가 시트 표시 여부
    @State private var selectedPhotos: [UIImage] = [] // 선택한 사진들
    /// 먹은 메뉴를 다음에 또 시킬지 (메뉴에 남긴다). nil 은 안 정함.
    @State private var wouldOrderAgain: Bool?

    /// 맛 (→ Taste.swift). 적지 않은 축은 들어 있지 않다.
    @State private var tastes: [TasteAxis: Int] = [:]

    private let logger = Logger(subsystem: "com.restaurantmap", category: "AddVisit")

    var body: some View {
        NavigationStack {
            Form {
                Section("방문 정보") {
                    DatePicker("방문 날짜", selection: $visitDate, displayedComponents: .date)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("별점")
                            .font(.subheadline)

                        HStack(spacing: 8) {
                            ForEach(1...5, id: \.self) { index in
                                Image(systemName: index <= rating ? "star.fill" : "star")
                                    .foregroundStyle(index <= rating ? .yellow : .gray)
                                    .font(.system(size: 28))
                                    .accessibleStar(index, rating: rating) {
                                        rating = index
                                    }
                            }
                        }
                    }
                }

                GourmetInputSection(values: $gourmet)
                TasteInputSection(family: restaurant.tasteFamily, values: $tastes)

                // 메뉴 입력 섹션 (필수)
                Section {
                    // 등록된 메뉴가 있으면 선택 옵션 제공
                    if let menus = restaurant.menus, !menus.isEmpty {
                        Picker("메뉴 선택", selection: $selectedMenu) {
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
                        .onChange(of: selectedMenu) { _, newMenu in
                            // 메뉴 선택 시 텍스트 필드 비우기
                            if newMenu != nil {
                                menuItem = ""
                            }
                            // 지난번에 정해 둔 것을 보여 준다
                            wouldOrderAgain = newMenu?.wouldOrderAgain
                        }
                    }

                    // 메뉴를 직접 입력하는 경우 (메뉴가 없거나 "직접 입력" 선택 시)
                    if selectedMenu == nil {
                        TextField("먹은 메뉴 (예: 불고기정식, 마르게리따 피자)", text: $menuItem)
                    }

                    // 메뉴가 하나도 없을 때 메뉴 추가 버튼
                    if restaurant.menus?.isEmpty ?? true {
                        Button {
                            showingAddMenu = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                                Text("메뉴 등록하러 가기")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("메뉴")
                        Text("*")
                            .foregroundStyle(.red)
                    }
                } footer: {
                    if restaurant.menus?.isEmpty ?? true {
                        Text("이 식당에 등록된 메뉴가 없습니다. 메뉴를 먼저 등록하거나 직접 입력하세요.")
                            .foregroundStyle(.secondary)
                    }
                }

                // 먹은 메뉴를 또 시킬지 — 메뉴 목록에 남는다
                if selectedMenu != nil || !menuItem.trimmingCharacters(in: .whitespaces).isEmpty {
                    Section {
                        ReorderPicker(value: $wouldOrderAgain)
                    } header: {
                        Text("이 메뉴, 다음에 또 시킬까요?")
                    } footer: {
                        Text("메뉴 목록에서 다시 볼 수 있어요")
                    }
                }

                // 사진 섹션
                Section("사진") {
                    PhotoPickerView(selectedImages: $selectedPhotos)

                    if !selectedPhotos.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(Array(selectedPhotos.enumerated()), id: \.offset) { index, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 100)
                                        .clipped()
                                        .cornerRadius(8)
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                selectedPhotos.remove(at: index)
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
                            .padding(.vertical, 4)
                        }

                        Text("\(selectedPhotos.count)장의 사진")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("메모") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

            }
            #if !os(visionOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .navigationTitle("방문 기록 추가")
            .saveFailureAlert($saveFailed)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", systemImage: "xmark") {
                        logger.info("🔵 취소 버튼 클릭")
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("저장", systemImage: "checkmark") {
                        logger.info("🔵 저장 버튼 클릭")
                        saveVisit()
                    }
                    .disabled(selectedMenu == nil && menuItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showingAddMenu) {
                AddMenuView(restaurant: restaurant)
            }
        }
    }

    private func saveVisit() {
        logger.info("🟢 saveVisit() 시작")
        logger.info("  - Restaurant: \(restaurant.name)")
        logger.info("  - Visit Date: \(visitDate)")
        logger.info("  - Rating: \(rating)")
        logger.info("  - Selected Menu: \(selectedMenu?.name ?? "None")")
        logger.info("  - Menu Item: \(menuItem)")
        logger.info("  - Notes: \(notes)")

        let visit = Visit(
            restaurant: restaurant,
            visitDate: visitDate,
            notes: notes,
            rating: rating
        )

        // 메뉴 저장 (등록된 메뉴 우선, 없으면 자동 생성)
        if let selectedMenu = selectedMenu {
            visit.menu = selectedMenu
            visit.menuItem = selectedMenu.name // 하위 호환용
        } else if !menuItem.trimmingCharacters(in: .whitespaces).isEmpty {
            // 직접 입력한 메뉴 처리
            let trimmedMenuName = menuItem.trimmingCharacters(in: .whitespaces)

            // 같은 이름의 메뉴가 이미 존재하는지 확인
            if let existingMenu = restaurant.menus?.first(where: { $0.name == trimmedMenuName }) {
                // 이미 존재하면 해당 메뉴 사용
                logger.info("  - 기존 메뉴 사용: \(existingMenu.name)")
                visit.menu = existingMenu
                visit.menuItem = existingMenu.name
            } else {
                // 새로운 메뉴 자동 생성
                let newMenuItem = MenuItem(
                    name: trimmedMenuName,
                    price: nil,
                    menuDescription: "",
                    isSignature: false,
                    restaurant: restaurant
                )
                modelContext.insert(newMenuItem)
                logger.info("  - 새 메뉴 자동 생성: \(trimmedMenuName)")

                visit.menu = newMenuItem
                visit.menuItem = trimmedMenuName
            }
        }

        if let wouldOrderAgain, let menu = visit.menu {
            menu.wouldOrderAgain = wouldOrderAgain
        }

        visit.tastes = tastes

        logger.info("  - Visit 생성됨")
        logger.info("  - Visit.restaurant: \(visit.restaurant?.name ?? "nil")")

        // 사진 저장
        for image in selectedPhotos {
            visit.addPhoto(image)
        }
        logger.info("  - \(selectedPhotos.count)장의 사진 저장됨")

        for (criterion, value) in gourmet { visit[criterion] = value }

        modelContext.insert(visit)
        logger.info("  ✅ modelContext.insert 완료")

        // SwiftData가 자동으로 relationship을 관리하므로 수동 append 제거
        // restaurant.visits?.append(visit)
        logger.info("  ✅ relationship은 SwiftData가 자동 관리")

        // 실패하면 알리고 화면을 닫지 않는다 — 적은 내용이 그대로 남아 있다
        do {
            try modelContext.save()
        } catch {
            logger.error("방문 저장 실패: \(error.localizedDescription)")
            modelContext.delete(visit)
            saveFailed = true
            return
        }
        logger.info("  ✅ modelContext.save 완료")
        let restaurant = restaurant
        Task { await RegularReviews.shared.refreshSnapshot(for: restaurant) }

        dismiss()
        logger.info("  ✅ dismiss 호출")
    }

}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, Visit.self, configurations: config)

    let restaurant = Restaurant(
        name: "샘플 식당",
        address: "서울시",
        latitude: 37.5,
        longitude: 127.0
    )
    container.mainContext.insert(restaurant)

    return AddVisitView(restaurant: restaurant)
        .modelContainer(container)
}

// MARK: - 미식 기준 입력

/// 접시 위의 음식을 네 가지 기준으로. 모두 선택이고, 고른 점수를 다시 누르면 지워진다.
struct GourmetInputSection: View {
    @Binding var values: [GourmetCriterion: Int]

    var body: some View {
        Section {
            ForEach(GourmetCriterion.allCases) { criterion in
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: criterion.symbol)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text(verbatim: criterion.title)
                            .font(.subheadline.weight(.semibold))
                        Text(verbatim: criterion.hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 10) {
                        ForEach(1...5, id: \.self) { score in
                            let isOn = score <= (values[criterion] ?? 0)
                            Circle()
                                .fill(isOn ? Color.orange : Color.gray.opacity(0.2))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    Text(verbatim: "\(score)")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(isOn ? .white : .secondary)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture { set(criterion, score) }
                        }
                    }
                    .accessibilityHidden(true)
                }
                .padding(.vertical, 2)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(verbatim: criterion.title))
                .accessibilityHint(Text(verbatim: criterion.hint))
                .accessibilityValue(values[criterion].map { Text("\($0)점") } ?? Text("적지 않음"))
                .accessibilityAdjustableAction { direction in
                    let now = values[criterion] ?? 0
                    switch direction {
                    case .increment: values[criterion] = min(now + 1, 5)
                    case .decrement: values[criterion] = now > 1 ? now - 1 : nil
                    @unknown default: break
                    }
                }
            }
        } header: {
            Text("미식 기준")
        } footer: {
            Text("접시 위의 음식만 봐요. 적고 싶은 것만 적어도 돼요.")
        }
    }

    private func set(_ criterion: GourmetCriterion, _ score: Int) {
        values[criterion] = values[criterion] == score ? nil : score
    }
}
