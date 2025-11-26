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

    // 맛 평가 관련 상태
    @State private var evaluationMode: EvaluationMode = .intensity

    // 일반 평가
    @State private var spicy: Double = 5.0
    @State private var boldness: Double = 5.0
    @State private var sweetness: Double = 5.0
    @State private var saltiness: Double = 5.0
    @State private var richness: Double = 5.0
    @State private var naturalTaste: Double = 5.0

    @State private var spicyAppropriate: Int = 3
    @State private var boldnessAppropriate: Int = 3
    @State private var sweetnessAppropriate: Int = 3
    @State private var saltinessAppropriate: Int = 3
    @State private var richnessAppropriate: Int = 3
    @State private var naturalTasteAppropriate: Int = 3

    // 스테이크 평가
    @State private var steakDoneness: Double = 5.0
    @State private var steakJuiciness: Double = 5.0
    @State private var steakTenderness: Double = 5.0
    @State private var steakSeasoning: Double = 5.0
    @State private var steakFlavor: Double = 5.0
    @State private var steakMarbling: Double = 5.0

    @State private var steakDonenessAppropriate: Int = 3
    @State private var steakJuicinessAppropriate: Int = 3
    @State private var steakTendernessAppropriate: Int = 3
    @State private var steakSeasoningAppropriate: Int = 3
    @State private var steakFlavorAppropriate: Int = 3
    @State private var steakMarblingAppropriate: Int = 3

    // 초밥 평가
    @State private var sushiShari: Double = 5.0
    @State private var sushiNeta: Double = 5.0
    @State private var sushiWasabi: Double = 5.0
    @State private var sushiBalance: Double = 5.0
    @State private var sushiGrip: Double = 5.0
    @State private var sushiTemperature: Double = 5.0

    @State private var sushiShariAppropriate: Int = 3
    @State private var sushiNetaAppropriate: Int = 3
    @State private var sushiWasabiAppropriate: Int = 3
    @State private var sushiBalanceAppropriate: Int = 3
    @State private var sushiGripAppropriate: Int = 3
    @State private var sushiTemperatureAppropriate: Int = 3

    // 라멘 평가
    @State private var ramenBroth: Double = 5.0
    @State private var ramenNoodle: Double = 5.0
    @State private var ramenChashu: Double = 5.0
    @State private var ramenTopping: Double = 5.0
    @State private var ramenTemperature: Double = 5.0
    @State private var ramenBalance: Double = 5.0

    @State private var ramenBrothAppropriate: Int = 3
    @State private var ramenNoodleAppropriate: Int = 3
    @State private var ramenChashuAppropriate: Int = 3
    @State private var ramenToppingAppropriate: Int = 3
    @State private var ramenTemperatureAppropriate: Int = 3
    @State private var ramenBalanceAppropriate: Int = 3

    // 피자 평가
    @State private var pizzaDough: Double = 5.0
    @State private var pizzaSauce: Double = 5.0
    @State private var pizzaCheese: Double = 5.0
    @State private var pizzaBaking: Double = 5.0
    @State private var pizzaTopping: Double = 5.0
    @State private var pizzaBalance: Double = 5.0

    @State private var pizzaDoughAppropriate: Int = 3
    @State private var pizzaSauceAppropriate: Int = 3
    @State private var pizzaCheeseAppropriate: Int = 3
    @State private var pizzaBakingAppropriate: Int = 3
    @State private var pizzaToppingAppropriate: Int = 3
    @State private var pizzaBalanceAppropriate: Int = 3

    // 와인 평가
    @State private var wineBody: Double = 5.0
    @State private var wineTannin: Double = 5.0
    @State private var wineAcidity: Double = 5.0
    @State private var wineAroma: Double = 5.0
    @State private var wineFinish: Double = 5.0
    @State private var wineBalance: Double = 5.0

    @State private var wineBodyAppropriate: Int = 3
    @State private var wineTanninAppropriate: Int = 3
    @State private var wineAcidityAppropriate: Int = 3
    @State private var wineAromaAppropriate: Int = 3
    @State private var wineFinishAppropriate: Int = 3
    @State private var wineBalanceAppropriate: Int = 3

    // 커피 평가
    @State private var coffeeAcidity: Double = 5.0
    @State private var coffeeBody: Double = 5.0
    @State private var coffeeFlavor: Double = 5.0
    @State private var coffeeAftertaste: Double = 5.0
    @State private var coffeeSweetness: Double = 5.0
    @State private var coffeeBalance: Double = 5.0

    @State private var coffeeAcidityAppropriate: Int = 3
    @State private var coffeeBodyAppropriate: Int = 3
    @State private var coffeeFlavorAppropriate: Int = 3
    @State private var coffeeAftertasteAppropriate: Int = 3
    @State private var coffeeSweetnessAppropriate: Int = 3
    @State private var coffeeBalanceAppropriate: Int = 3

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
                                    .onTapGesture {
                                        rating = index
                                    }
                            }
                        }
                    }
                }

                Section("메모") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                // 맛 평가 섹션
                Section {
                    VStack(spacing: 16) {
                        Text("인생 맛집 평가하기")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // 평가 유형 선택
                        Picker("평가 유형", selection: $evaluationMode) {
                            Text("맛 강도").tag(EvaluationMode.intensity)
                            Text("적절함").tag(EvaluationMode.appropriateness)
                        }
                        .pickerStyle(.segmented)
                        .padding(.bottom, 8)

                        if evaluationMode == .intensity {
                            intensityEditingView
                        } else {
                            appropriatenessEditingView
                        }
                    }
                } header: {
                    Text("이 방문은 어땠나요?")
                } footer: {
                    Text("맛 평가는 선택 사항입니다. 나중에 방문 기록에서 추가하거나 수정할 수 있습니다.")
                        .font(.caption)
                }
            }
            .navigationTitle("방문 기록 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        logger.info("🔵 취소 버튼 클릭")
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("저장") {
                        logger.info("🔵 저장 버튼 클릭")
                        saveVisit()
                    }
                }
            }
            .onAppear {
                logger.info("🟢 AddVisitView.onAppear")
                logger.info("  - Restaurant: \(restaurant.name)")
            }
        }
    }

    private func saveVisit() {
        logger.info("🟢 saveVisit() 시작")
        logger.info("  - Restaurant: \(restaurant.name)")
        logger.info("  - Visit Date: \(visitDate)")
        logger.info("  - Rating: \(rating)")
        logger.info("  - Notes: \(notes)")

        let visit = Visit(
            restaurant: restaurant,
            visitDate: visitDate,
            notes: notes,
            rating: rating
        )

        // 맛 평가 저장 - 카테고리별로 다르게 저장
        switch restaurant.foodCategory {
        case .general:
            visit.spicy = spicy
            visit.boldness = boldness
            visit.sweetness = sweetness
            visit.saltiness = saltiness
            visit.richness = richness
            visit.naturalTaste = naturalTaste

            visit.spicyAppropriate = spicyAppropriate
            visit.boldnessAppropriate = boldnessAppropriate
            visit.sweetnessAppropriate = sweetnessAppropriate
            visit.saltinessAppropriate = saltinessAppropriate
            visit.richnessAppropriate = richnessAppropriate
            visit.naturalTasteAppropriate = naturalTasteAppropriate

        case .steak:
            visit.steakDoneness = steakDoneness
            visit.steakJuiciness = steakJuiciness
            visit.steakTenderness = steakTenderness
            visit.steakSeasoning = steakSeasoning
            visit.steakFlavor = steakFlavor
            visit.steakMarbling = steakMarbling

            visit.steakDonenessAppropriate = steakDonenessAppropriate
            visit.steakJuicinessAppropriate = steakJuicinessAppropriate
            visit.steakTendernessAppropriate = steakTendernessAppropriate
            visit.steakSeasoningAppropriate = steakSeasoningAppropriate
            visit.steakFlavorAppropriate = steakFlavorAppropriate
            visit.steakMarblingAppropriate = steakMarblingAppropriate

        case .sushi:
            visit.sushiShari = sushiShari
            visit.sushiNeta = sushiNeta
            visit.sushiWasabi = sushiWasabi
            visit.sushiBalance = sushiBalance
            visit.sushiGrip = sushiGrip
            visit.sushiTemperature = sushiTemperature

            visit.sushiShariAppropriate = sushiShariAppropriate
            visit.sushiNetaAppropriate = sushiNetaAppropriate
            visit.sushiWasabiAppropriate = sushiWasabiAppropriate
            visit.sushiBalanceAppropriate = sushiBalanceAppropriate
            visit.sushiGripAppropriate = sushiGripAppropriate
            visit.sushiTemperatureAppropriate = sushiTemperatureAppropriate

        case .ramen:
            visit.ramenBroth = ramenBroth
            visit.ramenNoodle = ramenNoodle
            visit.ramenChashu = ramenChashu
            visit.ramenTopping = ramenTopping
            visit.ramenTemperature = ramenTemperature
            visit.ramenBalance = ramenBalance

            visit.ramenBrothAppropriate = ramenBrothAppropriate
            visit.ramenNoodleAppropriate = ramenNoodleAppropriate
            visit.ramenChashuAppropriate = ramenChashuAppropriate
            visit.ramenToppingAppropriate = ramenToppingAppropriate
            visit.ramenTemperatureAppropriate = ramenTemperatureAppropriate
            visit.ramenBalanceAppropriate = ramenBalanceAppropriate

        case .pizza:
            visit.pizzaDough = pizzaDough
            visit.pizzaSauce = pizzaSauce
            visit.pizzaCheese = pizzaCheese
            visit.pizzaBaking = pizzaBaking
            visit.pizzaTopping = pizzaTopping
            visit.pizzaBalance = pizzaBalance

            visit.pizzaDoughAppropriate = pizzaDoughAppropriate
            visit.pizzaSauceAppropriate = pizzaSauceAppropriate
            visit.pizzaCheeseAppropriate = pizzaCheeseAppropriate
            visit.pizzaBakingAppropriate = pizzaBakingAppropriate
            visit.pizzaToppingAppropriate = pizzaToppingAppropriate
            visit.pizzaBalanceAppropriate = pizzaBalanceAppropriate

        case .wine:
            visit.wineBody = wineBody
            visit.wineTannin = wineTannin
            visit.wineAcidity = wineAcidity
            visit.wineAroma = wineAroma
            visit.wineFinish = wineFinish
            visit.wineBalance = wineBalance

            visit.wineBodyAppropriate = wineBodyAppropriate
            visit.wineTanninAppropriate = wineTanninAppropriate
            visit.wineAcidityAppropriate = wineAcidityAppropriate
            visit.wineAromaAppropriate = wineAromaAppropriate
            visit.wineFinishAppropriate = wineFinishAppropriate
            visit.wineBalanceAppropriate = wineBalanceAppropriate

        case .coffee:
            visit.coffeeAcidity = coffeeAcidity
            visit.coffeeBody = coffeeBody
            visit.coffeeFlavor = coffeeFlavor
            visit.coffeeAftertaste = coffeeAftertaste
            visit.coffeeSweetness = coffeeSweetness
            visit.coffeeBalance = coffeeBalance

            visit.coffeeAcidityAppropriate = coffeeAcidityAppropriate
            visit.coffeeBodyAppropriate = coffeeBodyAppropriate
            visit.coffeeFlavorAppropriate = coffeeFlavorAppropriate
            visit.coffeeAftertasteAppropriate = coffeeAftertasteAppropriate
            visit.coffeeSweetnessAppropriate = coffeeSweetnessAppropriate
            visit.coffeeBalanceAppropriate = coffeeBalanceAppropriate
        }

        logger.info("  - Visit 생성됨")
        logger.info("  - Visit.restaurant: \(visit.restaurant?.name ?? "nil")")
        logger.info("  - 맛 평가 데이터 저장됨")

        modelContext.insert(visit)
        logger.info("  ✅ modelContext.insert 완료")

        // SwiftData가 자동으로 relationship을 관리하므로 수동 append 제거
        // restaurant.visits?.append(visit)
        logger.info("  ✅ relationship은 SwiftData가 자동 관리")

        try? modelContext.save()
        logger.info("  ✅ modelContext.save 완료")

        dismiss()
        logger.info("  ✅ dismiss 호출")
    }

    // MARK: - Intensity Editing View
    private var intensityEditingView: some View {
        VStack(spacing: 12) {
            Text("맛의 강도를 평가하세요")
                .font(.caption)
                .foregroundStyle(.secondary)

            switch restaurant.foodCategory {
            case .general:
                IntensitySliderRow(title: "🌶️ 맵기", subtitle: "순한 ↔ 매운", value: $spicy)
                IntensitySliderRow(title: "💪 진한맛", subtitle: "담백 ↔ 진한", value: $boldness)
                IntensitySliderRow(title: "🍯 단맛", subtitle: "안좋아함 ↔ 좋아함", value: $sweetness)
                IntensitySliderRow(title: "🧂 짠맛", subtitle: "싱거움 ↔ 짭짤", value: $saltiness)
                IntensitySliderRow(title: "🥓 기름진", subtitle: "담백 ↔ 고소", value: $richness)
                IntensitySliderRow(title: "🌿 본연의맛", subtitle: "양념 ↔ 재료맛", value: $naturalTaste)

            case .steak:
                IntensitySliderRow(title: "🔥 굽기", subtitle: "레어 ↔ 웰던", value: $steakDoneness)
                IntensitySliderRow(title: "🥩 육즙", subtitle: "퍽퍽 ↔ 촉촉", value: $steakJuiciness)
                IntensitySliderRow(title: "✨ 부드러움", subtitle: "질김 ↔ 부드러움", value: $steakTenderness)
                IntensitySliderRow(title: "🧂 간", subtitle: "싱거움 ↔ 짭짤", value: $steakSeasoning)
                IntensitySliderRow(title: "🌿 육향", subtitle: "약함 ↔ 강함", value: $steakFlavor)
                IntensitySliderRow(title: "🍖 마블링", subtitle: "적음 ↔ 많음", value: $steakMarbling)

            case .sushi:
                IntensitySliderRow(title: "🍚 샤리(밥)", subtitle: "흐물 ↔ 단단", value: $sushiShari)
                IntensitySliderRow(title: "🐟 네타(재료)", subtitle: "신선도", value: $sushiNeta)
                IntensitySliderRow(title: "🌿 와사비", subtitle: "약함 ↔ 강함", value: $sushiWasabi)
                IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: $sushiBalance)
                IntensitySliderRow(title: "✋ 쥐기", subtitle: "풀림 ↔ 결속", value: $sushiGrip)
                IntensitySliderRow(title: "🌡️ 온도", subtitle: "차가움 ↔ 따뜻함", value: $sushiTemperature)

            case .ramen:
                IntensitySliderRow(title: "🥣 국물", subtitle: "깊이/감칠맛", value: $ramenBroth)
                IntensitySliderRow(title: "🍜 면발", subtitle: "부드러움 ↔ 쫄깃함", value: $ramenNoodle)
                IntensitySliderRow(title: "🥓 차슈", subtitle: "퍽퍽 ↔ 부드러움", value: $ramenChashu)
                IntensitySliderRow(title: "🥚 토핑", subtitle: "부실 ↔ 풍부", value: $ramenTopping)
                IntensitySliderRow(title: "🔥 온도", subtitle: "미지근 ↔ 뜨거움", value: $ramenTemperature)
                IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: $ramenBalance)

            case .pizza:
                IntensitySliderRow(title: "🫓 도우", subtitle: "질김 ↔ 쫄깃함", value: $pizzaDough)
                IntensitySliderRow(title: "🍅 소스", subtitle: "적음 ↔ 많음", value: $pizzaSauce)
                IntensitySliderRow(title: "🧀 치즈", subtitle: "적음 ↔ 많음", value: $pizzaCheese)
                IntensitySliderRow(title: "🔥 굽기", subtitle: "덜익음 ↔ 바삭함", value: $pizzaBaking)
                IntensitySliderRow(title: "🌟 토핑", subtitle: "부실 ↔ 풍부", value: $pizzaTopping)
                IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: $pizzaBalance)

            case .wine:
                IntensitySliderRow(title: "💪 바디", subtitle: "가벼움 ↔ 묵직함", value: $wineBody)
                IntensitySliderRow(title: "🍇 타닌", subtitle: "약함 ↔ 떫음", value: $wineTannin)
                IntensitySliderRow(title: "🍋 산도", subtitle: "낮음 ↔ 높음", value: $wineAcidity)
                IntensitySliderRow(title: "🌸 아로마", subtitle: "단순 ↔ 복잡", value: $wineAroma)
                IntensitySliderRow(title: "✨ 피니시", subtitle: "짧음 ↔ 긴 여운", value: $wineFinish)
                IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: $wineBalance)

            case .coffee:
                IntensitySliderRow(title: "🍋 산미", subtitle: "낮음 ↔ 밝음", value: $coffeeAcidity)
                IntensitySliderRow(title: "💪 바디", subtitle: "가벼움 ↔ 묵직함", value: $coffeeBody)
                IntensitySliderRow(title: "🌸 향미", subtitle: "단순 ↔ 복잡", value: $coffeeFlavor)
                IntensitySliderRow(title: "✨ 후미", subtitle: "짧음 ↔ 긴 여운", value: $coffeeAftertaste)
                IntensitySliderRow(title: "🍯 단맛", subtitle: "쓴맛 ↔ 단맛", value: $coffeeSweetness)
                IntensitySliderRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", value: $coffeeBalance)
            }
        }
    }

    // MARK: - Appropriateness Editing View
    private var appropriatenessEditingView: some View {
        VStack(spacing: 12) {
            Text("이 음식에 적절했나요? (3 = 딱 좋음)")
                .font(.caption)
                .foregroundStyle(.secondary)

            switch restaurant.foodCategory {
            case .general:
                AppropriatenessRow(title: "🌶️ 맵기", value: $spicyAppropriate)
                AppropriatenessRow(title: "💪 진한맛", value: $boldnessAppropriate)
                AppropriatenessRow(title: "🍯 단맛", value: $sweetnessAppropriate)
                AppropriatenessRow(title: "🧂 짠맛", value: $saltinessAppropriate)
                AppropriatenessRow(title: "🥓 기름진", value: $richnessAppropriate)
                AppropriatenessRow(title: "🌿 본연의맛", value: $naturalTasteAppropriate)

            case .steak:
                AppropriatenessRow(title: "🔥 굽기", value: $steakDonenessAppropriate)
                AppropriatenessRow(title: "🥩 육즙", value: $steakJuicinessAppropriate)
                AppropriatenessRow(title: "✨ 부드러움", value: $steakTendernessAppropriate)
                AppropriatenessRow(title: "🧂 간", value: $steakSeasoningAppropriate)
                AppropriatenessRow(title: "🌿 육향", value: $steakFlavorAppropriate)
                AppropriatenessRow(title: "🍖 마블링", value: $steakMarblingAppropriate)

            case .sushi:
                AppropriatenessRow(title: "🍚 샤리(밥)", value: $sushiShariAppropriate)
                AppropriatenessRow(title: "🐟 네타(재료)", value: $sushiNetaAppropriate)
                AppropriatenessRow(title: "🌿 와사비", value: $sushiWasabiAppropriate)
                AppropriatenessRow(title: "⚖️ 밸런스", value: $sushiBalanceAppropriate)
                AppropriatenessRow(title: "✋ 쥐기", value: $sushiGripAppropriate)
                AppropriatenessRow(title: "🌡️ 온도", value: $sushiTemperatureAppropriate)

            case .ramen:
                AppropriatenessRow(title: "🥣 국물", value: $ramenBrothAppropriate)
                AppropriatenessRow(title: "🍜 면발", value: $ramenNoodleAppropriate)
                AppropriatenessRow(title: "🥓 차슈", value: $ramenChashuAppropriate)
                AppropriatenessRow(title: "🥚 토핑", value: $ramenToppingAppropriate)
                AppropriatenessRow(title: "🔥 온도", value: $ramenTemperatureAppropriate)
                AppropriatenessRow(title: "⚖️ 밸런스", value: $ramenBalanceAppropriate)

            case .pizza:
                AppropriatenessRow(title: "🫓 도우", value: $pizzaDoughAppropriate)
                AppropriatenessRow(title: "🍅 소스", value: $pizzaSauceAppropriate)
                AppropriatenessRow(title: "🧀 치즈", value: $pizzaCheeseAppropriate)
                AppropriatenessRow(title: "🔥 굽기", value: $pizzaBakingAppropriate)
                AppropriatenessRow(title: "🌟 토핑", value: $pizzaToppingAppropriate)
                AppropriatenessRow(title: "⚖️ 밸런스", value: $pizzaBalanceAppropriate)

            case .wine:
                AppropriatenessRow(title: "💪 바디", value: $wineBodyAppropriate)
                AppropriatenessRow(title: "🍇 타닌", value: $wineTanninAppropriate)
                AppropriatenessRow(title: "🍋 산도", value: $wineAcidityAppropriate)
                AppropriatenessRow(title: "🌸 아로마", value: $wineAromaAppropriate)
                AppropriatenessRow(title: "✨ 피니시", value: $wineFinishAppropriate)
                AppropriatenessRow(title: "⚖️ 밸런스", value: $wineBalanceAppropriate)

            case .coffee:
                AppropriatenessRow(title: "🍋 산미", value: $coffeeAcidityAppropriate)
                AppropriatenessRow(title: "💪 바디", value: $coffeeBodyAppropriate)
                AppropriatenessRow(title: "🌸 향미", value: $coffeeFlavorAppropriate)
                AppropriatenessRow(title: "✨ 후미", value: $coffeeAftertasteAppropriate)
                AppropriatenessRow(title: "🍯 단맛", value: $coffeeSweetnessAppropriate)
                AppropriatenessRow(title: "⚖️ 밸런스", value: $coffeeBalanceAppropriate)
            }
        }
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
