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

enum EvaluationMode {
    case intensity
    case appropriateness
}

struct VisitDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var visit: Visit

    @State private var isEditing = false
    @State private var editingMode: EvaluationMode = .intensity

    private let logger = Logger(subsystem: "com.restaurantmap", category: "VisitDetail")

    var body: some View {
        NavigationStack {
            Form {
                Section("방문 정보") {
                    if isEditing {
                        DatePicker("방문 날짜", selection: $visit.visitDate, displayedComponents: .date)

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

                // 맛 평가 섹션
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
                            // 편집 모드 선택
                            Picker("평가 유형", selection: $editingMode) {
                                Text("맛 강도").tag(EvaluationMode.intensity)
                                Text("적절함").tag(EvaluationMode.appropriateness)
                            }
                            .pickerStyle(.segmented)
                            .padding(.bottom, 8)

                            if editingMode == .intensity {
                                intensityEditingView
                            } else {
                                appropriatenessEditingView
                            }
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
            }
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

    // MARK: - Intensity Editing View
    private var intensityEditingView: some View {
        VStack(spacing: 12) {
            Text("맛의 강도를 평가하세요")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let restaurant = visit.restaurant {
                switch restaurant.foodCategory {
                case .general:
                    IntensitySliderRow(title: "🌶️ 맵기", subtitle: "순한 ↔ 매운", value: Binding(
                        get: { visit.spicy ?? 5.0 },
                        set: { visit.spicy = $0 }
                    ))
                    IntensitySliderRow(title: "💪 진한맛", subtitle: "담백 ↔ 진한", value: Binding(
                        get: { visit.boldness ?? 5.0 },
                        set: { visit.boldness = $0 }
                    ))
                    IntensitySliderRow(title: "🍯 단맛", subtitle: "안좋아함 ↔ 좋아함", value: Binding(
                        get: { visit.sweetness ?? 5.0 },
                        set: { visit.sweetness = $0 }
                    ))
                    IntensitySliderRow(title: "🧂 짠맛", subtitle: "싱거움 ↔ 짭짤", value: Binding(
                        get: { visit.saltiness ?? 5.0 },
                        set: { visit.saltiness = $0 }
                    ))
                    IntensitySliderRow(title: "🥓 기름진", subtitle: "담백 ↔ 고소", value: Binding(
                        get: { visit.richness ?? 5.0 },
                        set: { visit.richness = $0 }
                    ))
                    IntensitySliderRow(title: "🌿 본연의맛", subtitle: "양념 ↔ 재료맛", value: Binding(
                        get: { visit.naturalTaste ?? 5.0 },
                        set: { visit.naturalTaste = $0 }
                    ))

                case .steak:
                    IntensitySliderRow(title: "🔥 굽기", subtitle: "레어 ↔ 웰던", value: Binding(
                        get: { visit.steakDoneness ?? 5.0 },
                        set: { visit.steakDoneness = $0 }
                    ))
                    IntensitySliderRow(title: "🥩 육즙", subtitle: "퍽퍽 ↔ 촉촉", value: Binding(
                        get: { visit.steakJuiciness ?? 5.0 },
                        set: { visit.steakJuiciness = $0 }
                    ))
                    IntensitySliderRow(title: "✨ 부드러움", subtitle: "질김 ↔ 부드러움", value: Binding(
                        get: { visit.steakTenderness ?? 5.0 },
                        set: { visit.steakTenderness = $0 }
                    ))
                    IntensitySliderRow(title: "🧂 간", subtitle: "싱거움 ↔ 짭짤", value: Binding(
                        get: { visit.steakSeasoning ?? 5.0 },
                        set: { visit.steakSeasoning = $0 }
                    ))
                    IntensitySliderRow(title: "🌿 육향", subtitle: "약함 ↔ 강함", value: Binding(
                        get: { visit.steakFlavor ?? 5.0 },
                        set: { visit.steakFlavor = $0 }
                    ))
                    IntensitySliderRow(title: "🍖 마블링", subtitle: "적음 ↔ 많음", value: Binding(
                        get: { visit.steakMarbling ?? 5.0 },
                        set: { visit.steakMarbling = $0 }
                    ))

                case .sushi:
                    IntensitySliderRow(title: "🍚 샤리(밥)", subtitle: "흐물 ↔ 단단", value: Binding(
                        get: { visit.sushiShari ?? 5.0 },
                        set: { visit.sushiShari = $0 }
                    ))
                    IntensitySliderRow(title: "🐟 네타(재료)", subtitle: "신선도", value: Binding(
                        get: { visit.sushiNeta ?? 5.0 },
                        set: { visit.sushiNeta = $0 }
                    ))
                    IntensitySliderRow(title: "🌿 와사비", subtitle: "약함 ↔ 강함", value: Binding(
                        get: { visit.sushiWasabi ?? 5.0 },
                        set: { visit.sushiWasabi = $0 }
                    ))
                    IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: Binding(
                        get: { visit.sushiBalance ?? 5.0 },
                        set: { visit.sushiBalance = $0 }
                    ))
                    IntensitySliderRow(title: "✋ 쥐기", subtitle: "풀림 ↔ 결속", value: Binding(
                        get: { visit.sushiGrip ?? 5.0 },
                        set: { visit.sushiGrip = $0 }
                    ))
                    IntensitySliderRow(title: "🌡️ 온도", subtitle: "차가움 ↔ 따뜻함", value: Binding(
                        get: { visit.sushiTemperature ?? 5.0 },
                        set: { visit.sushiTemperature = $0 }
                    ))

                case .ramen:
                    IntensitySliderRow(title: "🥣 국물", subtitle: "깊이/감칠맛", value: Binding(
                        get: { visit.ramenBroth ?? 5.0 },
                        set: { visit.ramenBroth = $0 }
                    ))
                    IntensitySliderRow(title: "🍜 면발", subtitle: "부드러움 ↔ 쫄깃함", value: Binding(
                        get: { visit.ramenNoodle ?? 5.0 },
                        set: { visit.ramenNoodle = $0 }
                    ))
                    IntensitySliderRow(title: "🥓 차슈", subtitle: "퍽퍽 ↔ 부드러움", value: Binding(
                        get: { visit.ramenChashu ?? 5.0 },
                        set: { visit.ramenChashu = $0 }
                    ))
                    IntensitySliderRow(title: "🥚 토핑", subtitle: "부실 ↔ 풍부", value: Binding(
                        get: { visit.ramenTopping ?? 5.0 },
                        set: { visit.ramenTopping = $0 }
                    ))
                    IntensitySliderRow(title: "🔥 온도", subtitle: "미지근 ↔ 뜨거움", value: Binding(
                        get: { visit.ramenTemperature ?? 5.0 },
                        set: { visit.ramenTemperature = $0 }
                    ))
                    IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: Binding(
                        get: { visit.ramenBalance ?? 5.0 },
                        set: { visit.ramenBalance = $0 }
                    ))

                case .pizza:
                    IntensitySliderRow(title: "🫓 도우", subtitle: "질김 ↔ 쫄깃함", value: Binding(
                        get: { visit.pizzaDough ?? 5.0 },
                        set: { visit.pizzaDough = $0 }
                    ))
                    IntensitySliderRow(title: "🍅 소스", subtitle: "적음 ↔ 많음", value: Binding(
                        get: { visit.pizzaSauce ?? 5.0 },
                        set: { visit.pizzaSauce = $0 }
                    ))
                    IntensitySliderRow(title: "🧀 치즈", subtitle: "적음 ↔ 많음", value: Binding(
                        get: { visit.pizzaCheese ?? 5.0 },
                        set: { visit.pizzaCheese = $0 }
                    ))
                    IntensitySliderRow(title: "🔥 굽기", subtitle: "덜익음 ↔ 바삭함", value: Binding(
                        get: { visit.pizzaBaking ?? 5.0 },
                        set: { visit.pizzaBaking = $0 }
                    ))
                    IntensitySliderRow(title: "🌟 토핑", subtitle: "부실 ↔ 풍부", value: Binding(
                        get: { visit.pizzaTopping ?? 5.0 },
                        set: { visit.pizzaTopping = $0 }
                    ))
                    IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: Binding(
                        get: { visit.pizzaBalance ?? 5.0 },
                        set: { visit.pizzaBalance = $0 }
                    ))

                case .wine:
                    IntensitySliderRow(title: "💪 바디", subtitle: "가벼움 ↔ 묵직함", value: Binding(
                        get: { visit.wineBody ?? 5.0 },
                        set: { visit.wineBody = $0 }
                    ))
                    IntensitySliderRow(title: "🍇 타닌", subtitle: "약함 ↔ 떫음", value: Binding(
                        get: { visit.wineTannin ?? 5.0 },
                        set: { visit.wineTannin = $0 }
                    ))
                    IntensitySliderRow(title: "🍋 산도", subtitle: "낮음 ↔ 높음", value: Binding(
                        get: { visit.wineAcidity ?? 5.0 },
                        set: { visit.wineAcidity = $0 }
                    ))
                    IntensitySliderRow(title: "🌸 아로마", subtitle: "단순 ↔ 복잡", value: Binding(
                        get: { visit.wineAroma ?? 5.0 },
                        set: { visit.wineAroma = $0 }
                    ))
                    IntensitySliderRow(title: "✨ 피니시", subtitle: "짧음 ↔ 긴 여운", value: Binding(
                        get: { visit.wineFinish ?? 5.0 },
                        set: { visit.wineFinish = $0 }
                    ))
                    IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: Binding(
                        get: { visit.wineBalance ?? 5.0 },
                        set: { visit.wineBalance = $0 }
                    ))

                case .coffee:
                    IntensitySliderRow(title: "🍋 산미", subtitle: "낮음 ↔ 밝음", value: Binding(
                        get: { visit.coffeeAcidity ?? 5.0 },
                        set: { visit.coffeeAcidity = $0 }
                    ))
                    IntensitySliderRow(title: "💪 바디", subtitle: "가벼움 ↔ 묵직함", value: Binding(
                        get: { visit.coffeeBody ?? 5.0 },
                        set: { visit.coffeeBody = $0 }
                    ))
                    IntensitySliderRow(title: "🌸 향미", subtitle: "단순 ↔ 복잡", value: Binding(
                        get: { visit.coffeeFlavor ?? 5.0 },
                        set: { visit.coffeeFlavor = $0 }
                    ))
                    IntensitySliderRow(title: "✨ 후미", subtitle: "짧음 ↔ 긴 여운", value: Binding(
                        get: { visit.coffeeAftertaste ?? 5.0 },
                        set: { visit.coffeeAftertaste = $0 }
                    ))
                    IntensitySliderRow(title: "🍯 단맛", subtitle: "쓴맛 ↔ 단맛", value: Binding(
                        get: { visit.coffeeSweetness ?? 5.0 },
                        set: { visit.coffeeSweetness = $0 }
                    ))
                    IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: Binding(
                        get: { visit.coffeeBalance ?? 5.0 },
                        set: { visit.coffeeBalance = $0 }
                    ))
                }
            }
        }
    }

    // MARK: - Appropriateness Editing View
    private var appropriatenessEditingView: some View {
        VStack(spacing: 12) {
            Text("이 음식에 적절했나요? (3 = 딱 좋음)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let restaurant = visit.restaurant {
                switch restaurant.foodCategory {
                case .general:
                    AppropriatenessRow(title: "🌶️ 맵기", value: Binding(
                        get: { visit.spicyAppropriate ?? 3 },
                        set: { visit.spicyAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "💪 진한맛", value: Binding(
                        get: { visit.boldnessAppropriate ?? 3 },
                        set: { visit.boldnessAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🍯 단맛", value: Binding(
                        get: { visit.sweetnessAppropriate ?? 3 },
                        set: { visit.sweetnessAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🧂 짠맛", value: Binding(
                        get: { visit.saltinessAppropriate ?? 3 },
                        set: { visit.saltinessAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🥓 기름진", value: Binding(
                        get: { visit.richnessAppropriate ?? 3 },
                        set: { visit.richnessAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🌿 본연의맛", value: Binding(
                        get: { visit.naturalTasteAppropriate ?? 3 },
                        set: { visit.naturalTasteAppropriate = $0 }
                    ))

                case .steak:
                    AppropriatenessRow(title: "🔥 굽기", value: Binding(
                        get: { visit.steakDonenessAppropriate ?? 3 },
                        set: { visit.steakDonenessAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🥩 육즙", value: Binding(
                        get: { visit.steakJuicinessAppropriate ?? 3 },
                        set: { visit.steakJuicinessAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "✨ 부드러움", value: Binding(
                        get: { visit.steakTendernessAppropriate ?? 3 },
                        set: { visit.steakTendernessAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🧂 간", value: Binding(
                        get: { visit.steakSeasoningAppropriate ?? 3 },
                        set: { visit.steakSeasoningAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🌿 육향", value: Binding(
                        get: { visit.steakFlavorAppropriate ?? 3 },
                        set: { visit.steakFlavorAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🍖 마블링", value: Binding(
                        get: { visit.steakMarblingAppropriate ?? 3 },
                        set: { visit.steakMarblingAppropriate = $0 }
                    ))

                case .sushi:
                    AppropriatenessRow(title: "🍚 샤리(밥)", value: Binding(
                        get: { visit.sushiShariAppropriate ?? 3 },
                        set: { visit.sushiShariAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🐟 네타(재료)", value: Binding(
                        get: { visit.sushiNetaAppropriate ?? 3 },
                        set: { visit.sushiNetaAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🌿 와사비", value: Binding(
                        get: { visit.sushiWasabiAppropriate ?? 3 },
                        set: { visit.sushiWasabiAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "⚖️ 밸런스", value: Binding(
                        get: { visit.sushiBalanceAppropriate ?? 3 },
                        set: { visit.sushiBalanceAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "✋ 쥐기", value: Binding(
                        get: { visit.sushiGripAppropriate ?? 3 },
                        set: { visit.sushiGripAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🌡️ 온도", value: Binding(
                        get: { visit.sushiTemperatureAppropriate ?? 3 },
                        set: { visit.sushiTemperatureAppropriate = $0 }
                    ))

                case .ramen:
                    AppropriatenessRow(title: "🥣 국물", value: Binding(
                        get: { visit.ramenBrothAppropriate ?? 3 },
                        set: { visit.ramenBrothAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🍜 면발", value: Binding(
                        get: { visit.ramenNoodleAppropriate ?? 3 },
                        set: { visit.ramenNoodleAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🥓 차슈", value: Binding(
                        get: { visit.ramenChashuAppropriate ?? 3 },
                        set: { visit.ramenChashuAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🥚 토핑", value: Binding(
                        get: { visit.ramenToppingAppropriate ?? 3 },
                        set: { visit.ramenToppingAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🔥 온도", value: Binding(
                        get: { visit.ramenTemperatureAppropriate ?? 3 },
                        set: { visit.ramenTemperatureAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "⚖️ 밸런스", value: Binding(
                        get: { visit.ramenBalanceAppropriate ?? 3 },
                        set: { visit.ramenBalanceAppropriate = $0 }
                    ))

                case .pizza:
                    AppropriatenessRow(title: "🫓 도우", value: Binding(
                        get: { visit.pizzaDoughAppropriate ?? 3 },
                        set: { visit.pizzaDoughAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🍅 소스", value: Binding(
                        get: { visit.pizzaSauceAppropriate ?? 3 },
                        set: { visit.pizzaSauceAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🧀 치즈", value: Binding(
                        get: { visit.pizzaCheeseAppropriate ?? 3 },
                        set: { visit.pizzaCheeseAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🔥 굽기", value: Binding(
                        get: { visit.pizzaBakingAppropriate ?? 3 },
                        set: { visit.pizzaBakingAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🌟 토핑", value: Binding(
                        get: { visit.pizzaToppingAppropriate ?? 3 },
                        set: { visit.pizzaToppingAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "⚖️ 밸런스", value: Binding(
                        get: { visit.pizzaBalanceAppropriate ?? 3 },
                        set: { visit.pizzaBalanceAppropriate = $0 }
                    ))

                case .wine:
                    AppropriatenessRow(title: "💪 바디", value: Binding(
                        get: { visit.wineBodyAppropriate ?? 3 },
                        set: { visit.wineBodyAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🍇 타닌", value: Binding(
                        get: { visit.wineTanninAppropriate ?? 3 },
                        set: { visit.wineTanninAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🍋 산도", value: Binding(
                        get: { visit.wineAcidityAppropriate ?? 3 },
                        set: { visit.wineAcidityAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🌸 아로마", value: Binding(
                        get: { visit.wineAromaAppropriate ?? 3 },
                        set: { visit.wineAromaAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "✨ 피니시", value: Binding(
                        get: { visit.wineFinishAppropriate ?? 3 },
                        set: { visit.wineFinishAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "⚖️ 밸런스", value: Binding(
                        get: { visit.wineBalanceAppropriate ?? 3 },
                        set: { visit.wineBalanceAppropriate = $0 }
                    ))

                case .coffee:
                    AppropriatenessRow(title: "🍋 산미", value: Binding(
                        get: { visit.coffeeAcidityAppropriate ?? 3 },
                        set: { visit.coffeeAcidityAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "💪 바디", value: Binding(
                        get: { visit.coffeeBodyAppropriate ?? 3 },
                        set: { visit.coffeeBodyAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🌸 향미", value: Binding(
                        get: { visit.coffeeFlavorAppropriate ?? 3 },
                        set: { visit.coffeeFlavorAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "✨ 후미", value: Binding(
                        get: { visit.coffeeAftertasteAppropriate ?? 3 },
                        set: { visit.coffeeAftertasteAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "🍯 단맛", value: Binding(
                        get: { visit.coffeeSweetnessAppropriate ?? 3 },
                        set: { visit.coffeeSweetnessAppropriate = $0 }
                    ))
                    AppropriatenessRow(title: "⚖️ 밸런스", value: Binding(
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

                // 맛 강도 외곽선 (파란색) - 맛의 형태
                hexagonDataPath(center: center, radius: radius, data: intensityData)
                    .stroke(.blue, lineWidth: 2.5)

                // 적절함에 따른 채움 - 각 축별로 그라데이션
                ForEach(0..<intensityData.count, id: \.self) { index in
                    let nextIndex = (index + 1) % intensityData.count

                    // 현재 축과 다음 축의 데이터
                    let currentIntensity = intensityData[index].1
                    let nextIntensity = intensityData[nextIndex].1

                    // 적절함 점수 (1-5를 0-1로 정규화)
                    let currentAppropriateness = appropriatenessData[index].1 / 10.0 // 이미 *2 되어 있음
                    let nextAppropriateness = appropriatenessData[nextIndex].1 / 10.0

                    // 삼각형 영역 그리기
                    let angle1 = angleForIndex(index, total: intensityData.count)
                    let angle2 = angleForIndex(nextIndex, total: intensityData.count)

                    let distance1 = radius * (currentIntensity / maxValue)
                    let distance2 = radius * (nextIntensity / maxValue)

                    let point1 = pointOnCircle(center: center, radius: distance1, angle: angle1)
                    let point2 = pointOnCircle(center: center, radius: distance2, angle: angle2)

                    // 적절함에 따른 투명도 계산 (평균)
                    let averageAppropriateness = (currentAppropriateness + nextAppropriateness) / 2.0

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point1)
                        path.addLine(to: point2)
                        path.closeSubpath()
                    }
                    .fill(.green.opacity(averageAppropriateness * 0.6))
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

// MARK: - Intensity Slider Row
struct IntensitySliderRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(Int(value))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }

            Slider(value: $value, in: 0...10, step: 1)
                .tint(.blue)

            HStack {
                Text(subtitle.components(separatedBy: " ↔ ").first ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(subtitle.components(separatedBy: " ↔ ").last ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Appropriateness Row
struct AppropriatenessRow: View {
    let title: String
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                Spacer()
                Text("\(value)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.yellow)
            }

            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Int($0.rounded()) }
            ), in: 1...5, step: 1)
                .tint(.yellow)

            HStack {
                Text("부족함")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("딱 좋음")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("과함")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
