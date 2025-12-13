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
    @State private var editingPhotos: [UIImage] = [] // 편집 중 추가할 새 사진들
    @State private var photosToDelete: Set<String> = [] // 편집 중 삭제 표시된 사진 파일명들

    private let logger = Logger(subsystem: "com.restaurantmap", category: "VisitDetail")

    var body: some View {
        NavigationStack {
            Form {
                // 히어로 이미지 (읽기 모드만)
                if !isEditing, let heroURL = visit.heroImageURL {
                    Section {
                        HeroImageView(imageURL: heroURL)
                            .listRowInsets(EdgeInsets())
                    }
                }

                // 맛 평가 섹션 - 가장 먼저 표시
                Section {
                    VStack(spacing: 16) {
                        HStack {
                            Text("인생 맛집 평가하기")
                                .font(.headline)
                            Spacer()
                            if visit.hasTasteProfile && !isEditing {
                                Text("✓ 평가됨")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }

                        if visit.hasTasteProfile && !isEditing {
                            // 이중 레이더 차트 표시
                            DualRadarChartView(
                                intensityData: visit.intensityData,
                                appropriatenessData: visit.appropriatenessData
                            )
                            .frame(height: 380)
                        }

                        if isEditing {
                            combinedEvaluationView
                        } else if !visit.hasTasteProfile {
                            Text("이 방문의 맛 취향을 평가하려면 '편집'을 눌러주세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("이 방문은 어땠나요?")
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
                                        .onTapGesture {
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
                if !visit.photoFilenames.isEmpty || isEditing {
                    Section {
                        if isEditing {
                            // 편집 모드: 추가/삭제
                            PhotoPickerView(selectedImages: $editingPhotos)

                            if !visit.photoURLs.isEmpty {
                                PhotoGalleryView(
                                    photoURLs: visit.photoURLs.filter { url in
                                        // 삭제 표시된 사진 제외
                                        let filename = url.lastPathComponent
                                        return !photosToDelete.contains(filename)
                                    },
                                    isEditable: true,
                                    onDelete: { index in
                                        // 원본 photoURLs에서 index 계산 (필터링 전)
                                        let filteredURLs = visit.photoURLs.filter { url in
                                            let filename = url.lastPathComponent
                                            return !photosToDelete.contains(filename)
                                        }
                                        if index < filteredURLs.count {
                                            let urlToDelete = filteredURLs[index]
                                            let filename = urlToDelete.lastPathComponent
                                            photosToDelete.insert(filename)
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
                                                        .padding(4)
                                                    }
                                            }
                                        }
                                    }
                                }
                            }
                        } else {
                            // 읽기 모드: 갤러리 표시
                            if !visit.photoURLs.isEmpty {
                                PhotoGalleryView(
                                    photoURLs: visit.photoURLs,
                                    isEditable: false,
                                    onDelete: nil
                                )
                            }
                        }
                    } header: {
                        let currentPhotoCount = visit.photoFilenames.count - photosToDelete.count + editingPhotos.count
                        Text("사진 (\(currentPhotoCount))")
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(visit.restaurant?.name ?? "방문 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        logger.info("🔵 닫기 버튼 클릭")
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "완료" : "편집") {
                        logger.info("🔵 편집 버튼 클릭 - isEditing: \(isEditing) -> \(!isEditing)")

                        if isEditing {
                            // 편집 완료: 사진 저장 및 삭제 처리
                            // 1. 새 사진 저장
                            for image in editingPhotos {
                                if let filename = PhotoStorageManager.shared.savePhoto(image, for: visit.photoId) {
                                    visit.photoFilenames.append(filename)
                                }
                            }
                            logger.info("  - \(editingPhotos.count)장의 새 사진 저장됨")

                            // 2. 표시된 사진 삭제
                            for filename in photosToDelete {
                                PhotoStorageManager.shared.deletePhoto(filename: filename, visitID: visit.photoId)
                                if let index = visit.photoFilenames.firstIndex(of: filename) {
                                    visit.photoFilenames.remove(at: index)
                                }
                            }
                            logger.info("  - \(photosToDelete.count)장의 사진 삭제됨")

                            // 3. 상태 초기화
                            editingPhotos.removeAll()
                            photosToDelete.removeAll()

                            // 4. 변경사항 저장
                            try? modelContext.save()
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
                logger.info("  - Has Taste Profile: \(visit.hasTasteProfile)")
            }
        }
    }

    // MARK: - Combined Evaluation View (통합)
    private var combinedEvaluationView: some View {
        VStack(spacing: 16) {
            if let restaurant = visit.restaurant {
                switch restaurant.evaluationType {
                case .general:
                    CombinedEvaluationRow(title: "🌶️ 맵기", subtitle: "순한 ↔ 매운", intensityValue: Binding(
                        get: { visit.spicy ?? 5.0 },
                        set: { visit.spicy = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.spicyAppropriate ?? 3 },
                        set: { visit.spicyAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "💪 진한맛", subtitle: "담백 ↔ 진한", intensityValue: Binding(
                        get: { visit.boldness ?? 5.0 },
                        set: { visit.boldness = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.boldnessAppropriate ?? 3 },
                        set: { visit.boldnessAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🍯 단맛", subtitle: "안좋아함 ↔ 좋아함", intensityValue: Binding(
                        get: { visit.sweetness ?? 5.0 },
                        set: { visit.sweetness = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.sweetnessAppropriate ?? 3 },
                        set: { visit.sweetnessAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🧂 짠맛", subtitle: "싱거움 ↔ 짭짤", intensityValue: Binding(
                        get: { visit.saltiness ?? 5.0 },
                        set: { visit.saltiness = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.saltinessAppropriate ?? 3 },
                        set: { visit.saltinessAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🥓 기름진", subtitle: "담백 ↔ 고소", intensityValue: Binding(
                        get: { visit.richness ?? 5.0 },
                        set: { visit.richness = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.richnessAppropriate ?? 3 },
                        set: { visit.richnessAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🌿 본연의맛", subtitle: "양념 ↔ 재료맛", intensityValue: Binding(
                        get: { visit.naturalTaste ?? 5.0 },
                        set: { visit.naturalTaste = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.naturalTasteAppropriate ?? 3 },
                        set: { visit.naturalTasteAppropriate = $0 }
                    ))

                case .steak:
                    CombinedEvaluationRow(title: "🔥 굽기", subtitle: "레어 ↔ 웰던", intensityValue: Binding(
                        get: { visit.steakDoneness ?? 5.0 },
                        set: { visit.steakDoneness = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.steakDonenessAppropriate ?? 3 },
                        set: { visit.steakDonenessAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🥩 육즙", subtitle: "퍽퍽 ↔ 촉촉", intensityValue: Binding(
                        get: { visit.steakJuiciness ?? 5.0 },
                        set: { visit.steakJuiciness = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.steakJuicinessAppropriate ?? 3 },
                        set: { visit.steakJuicinessAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "✨ 부드러움", subtitle: "질김 ↔ 부드러움", intensityValue: Binding(
                        get: { visit.steakTenderness ?? 5.0 },
                        set: { visit.steakTenderness = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.steakTendernessAppropriate ?? 3 },
                        set: { visit.steakTendernessAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🧂 간", subtitle: "싱거움 ↔ 짭짤", intensityValue: Binding(
                        get: { visit.steakSeasoning ?? 5.0 },
                        set: { visit.steakSeasoning = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.steakSeasoningAppropriate ?? 3 },
                        set: { visit.steakSeasoningAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🌿 육향", subtitle: "약함 ↔ 강함", intensityValue: Binding(
                        get: { visit.steakFlavor ?? 5.0 },
                        set: { visit.steakFlavor = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.steakFlavorAppropriate ?? 3 },
                        set: { visit.steakFlavorAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🍖 마블링", subtitle: "적음 ↔ 많음", intensityValue: Binding(
                        get: { visit.steakMarbling ?? 5.0 },
                        set: { visit.steakMarbling = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.steakMarblingAppropriate ?? 3 },
                        set: { visit.steakMarblingAppropriate = $0 }
                    ))

                case .sushi:
                    CombinedEvaluationRow(title: "🍚 샤리(밥)", subtitle: "흐물 ↔ 단단", intensityValue: Binding(
                        get: { visit.sushiShari ?? 5.0 },
                        set: { visit.sushiShari = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.sushiShariAppropriate ?? 3 },
                        set: { visit.sushiShariAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🐟 네타(재료)", subtitle: "신선도", intensityValue: Binding(
                        get: { visit.sushiNeta ?? 5.0 },
                        set: { visit.sushiNeta = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.sushiNetaAppropriate ?? 3 },
                        set: { visit.sushiNetaAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🌿 와사비", subtitle: "약함 ↔ 강함", intensityValue: Binding(
                        get: { visit.sushiWasabi ?? 5.0 },
                        set: { visit.sushiWasabi = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.sushiWasabiAppropriate ?? 3 },
                        set: { visit.sushiWasabiAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: Binding(
                        get: { visit.sushiBalance ?? 5.0 },
                        set: { visit.sushiBalance = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.sushiBalanceAppropriate ?? 3 },
                        set: { visit.sushiBalanceAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "✋ 쥐기", subtitle: "풀림 ↔ 결속", intensityValue: Binding(
                        get: { visit.sushiGrip ?? 5.0 },
                        set: { visit.sushiGrip = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.sushiGripAppropriate ?? 3 },
                        set: { visit.sushiGripAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🌡️ 온도", subtitle: "차가움 ↔ 따뜻함", intensityValue: Binding(
                        get: { visit.sushiTemperature ?? 5.0 },
                        set: { visit.sushiTemperature = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.sushiTemperatureAppropriate ?? 3 },
                        set: { visit.sushiTemperatureAppropriate = $0 }
                    ))

                case .ramen:
                    CombinedEvaluationRow(title: "🥣 국물", subtitle: "깊이/감칠맛", intensityValue: Binding(
                        get: { visit.ramenBroth ?? 5.0 },
                        set: { visit.ramenBroth = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.ramenBrothAppropriate ?? 3 },
                        set: { visit.ramenBrothAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🍜 면발", subtitle: "부드러움 ↔ 쫄깃함", intensityValue: Binding(
                        get: { visit.ramenNoodle ?? 5.0 },
                        set: { visit.ramenNoodle = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.ramenNoodleAppropriate ?? 3 },
                        set: { visit.ramenNoodleAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🥓 차슈", subtitle: "퍽퍽 ↔ 부드러움", intensityValue: Binding(
                        get: { visit.ramenChashu ?? 5.0 },
                        set: { visit.ramenChashu = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.ramenChashuAppropriate ?? 3 },
                        set: { visit.ramenChashuAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🥚 토핑", subtitle: "부실 ↔ 풍부", intensityValue: Binding(
                        get: { visit.ramenTopping ?? 5.0 },
                        set: { visit.ramenTopping = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.ramenToppingAppropriate ?? 3 },
                        set: { visit.ramenToppingAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🔥 온도", subtitle: "미지근 ↔ 뜨거움", intensityValue: Binding(
                        get: { visit.ramenTemperature ?? 5.0 },
                        set: { visit.ramenTemperature = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.ramenTemperatureAppropriate ?? 3 },
                        set: { visit.ramenTemperatureAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: Binding(
                        get: { visit.ramenBalance ?? 5.0 },
                        set: { visit.ramenBalance = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.ramenBalanceAppropriate ?? 3 },
                        set: { visit.ramenBalanceAppropriate = $0 }
                    ))

                case .pizza:
                    CombinedEvaluationRow(title: "🫓 도우", subtitle: "질김 ↔ 쫄깃함", intensityValue: Binding(
                        get: { visit.pizzaDough ?? 5.0 },
                        set: { visit.pizzaDough = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.pizzaDoughAppropriate ?? 3 },
                        set: { visit.pizzaDoughAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🍅 소스", subtitle: "적음 ↔ 많음", intensityValue: Binding(
                        get: { visit.pizzaSauce ?? 5.0 },
                        set: { visit.pizzaSauce = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.pizzaSauceAppropriate ?? 3 },
                        set: { visit.pizzaSauceAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🧀 치즈", subtitle: "적음 ↔ 많음", intensityValue: Binding(
                        get: { visit.pizzaCheese ?? 5.0 },
                        set: { visit.pizzaCheese = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.pizzaCheeseAppropriate ?? 3 },
                        set: { visit.pizzaCheeseAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🔥 굽기", subtitle: "덜익음 ↔ 바삭함", intensityValue: Binding(
                        get: { visit.pizzaBaking ?? 5.0 },
                        set: { visit.pizzaBaking = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.pizzaBakingAppropriate ?? 3 },
                        set: { visit.pizzaBakingAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🌟 토핑", subtitle: "부실 ↔ 풍부", intensityValue: Binding(
                        get: { visit.pizzaTopping ?? 5.0 },
                        set: { visit.pizzaTopping = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.pizzaToppingAppropriate ?? 3 },
                        set: { visit.pizzaToppingAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: Binding(
                        get: { visit.pizzaBalance ?? 5.0 },
                        set: { visit.pizzaBalance = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.pizzaBalanceAppropriate ?? 3 },
                        set: { visit.pizzaBalanceAppropriate = $0 }
                    ))

                case .wine:
                    CombinedEvaluationRow(title: "💪 바디", subtitle: "가벼움 ↔ 묵직함", intensityValue: Binding(
                        get: { visit.wineBody ?? 5.0 },
                        set: { visit.wineBody = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.wineBodyAppropriate ?? 3 },
                        set: { visit.wineBodyAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🍇 타닌", subtitle: "약함 ↔ 떫음", intensityValue: Binding(
                        get: { visit.wineTannin ?? 5.0 },
                        set: { visit.wineTannin = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.wineTanninAppropriate ?? 3 },
                        set: { visit.wineTanninAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🍋 산도", subtitle: "낮음 ↔ 높음", intensityValue: Binding(
                        get: { visit.wineAcidity ?? 5.0 },
                        set: { visit.wineAcidity = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.wineAcidityAppropriate ?? 3 },
                        set: { visit.wineAcidityAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🌸 아로마", subtitle: "단순 ↔ 복잡", intensityValue: Binding(
                        get: { visit.wineAroma ?? 5.0 },
                        set: { visit.wineAroma = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.wineAromaAppropriate ?? 3 },
                        set: { visit.wineAromaAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "✨ 피니시", subtitle: "짧음 ↔ 긴 여운", intensityValue: Binding(
                        get: { visit.wineFinish ?? 5.0 },
                        set: { visit.wineFinish = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.wineFinishAppropriate ?? 3 },
                        set: { visit.wineFinishAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: Binding(
                        get: { visit.wineBalance ?? 5.0 },
                        set: { visit.wineBalance = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.wineBalanceAppropriate ?? 3 },
                        set: { visit.wineBalanceAppropriate = $0 }
                    ))

                case .coffee:
                    CombinedEvaluationRow(title: "🍋 산미", subtitle: "낮음 ↔ 밝음", intensityValue: Binding(
                        get: { visit.coffeeAcidity ?? 5.0 },
                        set: { visit.coffeeAcidity = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.coffeeAcidityAppropriate ?? 3 },
                        set: { visit.coffeeAcidityAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "💪 바디", subtitle: "가벼움 ↔ 묵직함", intensityValue: Binding(
                        get: { visit.coffeeBody ?? 5.0 },
                        set: { visit.coffeeBody = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.coffeeBodyAppropriate ?? 3 },
                        set: { visit.coffeeBodyAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🌸 향미", subtitle: "단순 ↔ 복잡", intensityValue: Binding(
                        get: { visit.coffeeFlavor ?? 5.0 },
                        set: { visit.coffeeFlavor = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.coffeeFlavorAppropriate ?? 3 },
                        set: { visit.coffeeFlavorAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "✨ 후미", subtitle: "짧음 ↔ 긴 여운", intensityValue: Binding(
                        get: { visit.coffeeAftertaste ?? 5.0 },
                        set: { visit.coffeeAftertaste = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.coffeeAftertasteAppropriate ?? 3 },
                        set: { visit.coffeeAftertasteAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "🍯 단맛", subtitle: "쓴맛 ↔ 단맛", intensityValue: Binding(
                        get: { visit.coffeeSweetness ?? 5.0 },
                        set: { visit.coffeeSweetness = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.coffeeSweetnessAppropriate ?? 3 },
                        set: { visit.coffeeSweetnessAppropriate = $0 }
                    ))
                    CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: Binding(
                        get: { visit.coffeeBalance ?? 5.0 },
                        set: { visit.coffeeBalance = $0 }
                    ), appropriatenessValue: Binding(
                        get: { visit.coffeeBalanceAppropriate ?? 3 },
                        set: { visit.coffeeBalanceAppropriate = $0 }
                    ))
                }
            }
        }
    }
}

// MARK: - Dual Radar Chart View
struct DualRadarChartView: View {
    let intensityData: [(String, Double)]
    let appropriatenessData: [(String, Double)]

    var body: some View {
        VStack(spacing: 12) {
            // 범례
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.blue, lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Text("맛의 형태")
                        .font(.caption)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.green.opacity(0.6))
                        .frame(width: 12, height: 12)
                    Text("만족도")
                        .font(.caption)
                }
            }

            // 새로운 레이더 차트: 맛 강도로 형태, 적절함으로 채움
            CalibratedRadarChartForVisit(
                intensityData: intensityData,
                appropriatenessData: appropriatenessData
            )
        }
    }
}

// MARK: - Overlapped Radar Chart For Visit
struct OverlappedRadarChartForVisit: View {
    let intensityData: [(String, Double)]
    let appropriatenessData: [(String, Double)]
    let maxValue: Double = 10.0

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 50

            ZStack {
                // 배경 그리드
                ForEach(1...3, id: \.self) { level in
                    hexagonPath(center: center, radius: radius * Double(level) / 3, sides: 6)
                        .stroke(.gray.opacity(0.2), lineWidth: 1)
                }

                // 적절함 차트 (노란색)
                hexagonDataPath(center: center, radius: radius, data: appropriatenessData)
                    .fill(.yellow.opacity(0.3))
                hexagonDataPath(center: center, radius: radius, data: appropriatenessData)
                    .stroke(.yellow.opacity(0.8), lineWidth: 2)

                // 맛 강도 차트 (파란색)
                hexagonDataPath(center: center, radius: radius, data: intensityData)
                    .fill(.blue.opacity(0.2))
                hexagonDataPath(center: center, radius: radius, data: intensityData)
                    .stroke(.blue, lineWidth: 2)

                // 축 선
                ForEach(0..<6, id: \.self) { index in
                    let angle = angleForIndex(index, total: 6)
                    let endPoint = pointOnCircle(center: center, radius: radius, angle: angle)

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: endPoint)
                    }
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                }

                // 라벨
                ForEach(0..<intensityData.count, id: \.self) { index in
                    let angle = angleForIndex(index, total: 6)
                    let labelRadius = radius + 30
                    let point = pointOnCircle(center: center, radius: labelRadius, angle: angle)

                    Text(intensityData[index].0)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .position(point)
                }
            }
        }
    }

    private func hexagonPath(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
        var path = Path()
        for i in 0..<sides {
            let angle = angleForIndex(i, total: sides)
            let point = pointOnCircle(center: center, radius: radius, angle: angle)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func hexagonDataPath(center: CGPoint, radius: CGFloat, data: [(String, Double)]) -> Path {
        var path = Path()
        for i in 0..<data.count {
            let angle = angleForIndex(i, total: data.count)
            let value = data[i].1
            let distance = radius * (value / maxValue)
            let point = pointOnCircle(center: center, radius: distance, angle: angle)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func angleForIndex(_ index: Int, total: Int) -> Double {
        let angleStep = 2 * .pi / Double(total)
        return angleStep * Double(index) - .pi / 2
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Calibrated Radar Chart For Visit (새로운 버전)
struct CalibratedRadarChartForVisit: View {
    let intensityData: [(String, Double)]
    let appropriatenessData: [(String, Double)]
    let maxValue: Double = 10.0
    let appropriatenessMaxValue: Double = 5.0  // 적절함은 5점 만점

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 50

            ZStack {
                // 배경 그리드
                ForEach(1...5, id: \.self) { level in
                    hexagonPath(center: center, radius: radius * Double(level) / 5, sides: 6)
                        .stroke(.gray.opacity(0.15), lineWidth: 1)
                }

                // 축 선
                ForEach(0..<6, id: \.self) { index in
                    let angle = angleForIndex(index, total: 6)
                    let endPoint = pointOnCircle(center: center, radius: radius, angle: angle)

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: endPoint)
                    }
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                }

                // 적절함 영역 (채워진 도형) - 맛 강도 범위 내에서 비율만큼 채움
                appropriatenessFilledPath(center: center, radius: radius)
                    .fill(.green.opacity(0.5))

                // 맛 강도 외곽선 (파란색 테두리만) - 맛의 형태
                hexagonDataPath(center: center, radius: radius, data: intensityData)
                    .stroke(.blue, lineWidth: 2.5)

                // 라벨
                ForEach(0..<intensityData.count, id: \.self) { index in
                    let angle = angleForIndex(index, total: 6)
                    let labelRadius = radius + 30
                    let point = pointOnCircle(center: center, radius: labelRadius, angle: angle)

                    Text(intensityData[index].0)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .position(point)
                }
            }
        }
    }

    private func hexagonPath(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
        var path = Path()
        for i in 0..<sides {
            let angle = angleForIndex(i, total: sides)
            let point = pointOnCircle(center: center, radius: radius, angle: angle)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func hexagonDataPath(center: CGPoint, radius: CGFloat, data: [(String, Double)]) -> Path {
        var path = Path()
        for i in 0..<data.count {
            let angle = angleForIndex(i, total: data.count)
            let value = data[i].1
            let distance = radius * (value / maxValue)
            let point = pointOnCircle(center: center, radius: distance, angle: angle)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    // 적절함 비율에 따라 맛 강도 범위 내에서 채워진 도형
    private func appropriatenessFilledPath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()

        for i in 0..<intensityData.count {
            let angle = angleForIndex(i, total: intensityData.count)
            let intensityValue = intensityData[i].1

            // appropriatenessData는 이미 *2 되어 있으므로 10으로 나눔 (원래 5점 만점 → 10점으로 변환됨)
            let appropriatenessValue = appropriatenessData[i].1 / 2.0  // 다시 5점 만점으로
            let appropriatenessRatio = appropriatenessValue / appropriatenessMaxValue  // 0~1 비율

            // 맛 강도 범위 내에서 적절함 비율만큼만 거리 계산
            let intensityDistance = radius * (intensityValue / maxValue)
            let filledDistance = intensityDistance * appropriatenessRatio

            let point = pointOnCircle(center: center, radius: filledDistance, angle: angle)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        path.closeSubpath()
        return path
    }

    private func angleForIndex(_ index: Int, total: Int) -> Double {
        let angleStep = 2 * .pi / Double(total)
        return angleStep * Double(index) - .pi / 2
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        return CGPoint(x: x, y: y)
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
