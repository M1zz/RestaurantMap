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
    @State private var menuItem = "" // 먹은 메뉴 이름 (텍스트)
    @State private var selectedMenu: MenuItem? // 선택한 메뉴 (등록된 메뉴 중)
    @State private var showingAddMenu = false // 메뉴 추가 시트 표시 여부
    @State private var selectedPhotos: [UIImage] = [] // 선택한 사진들

    // 맛 평가 관련 상태 (evaluationMode 제거 - 두 가지 평가 모두 표시)

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

                // 맛 평가 섹션 (통합)
                Section {
                    combinedEvaluationView
                } header: {
                    Text("맛 평가")
                } footer: {
                    Text("각 항목의 맛 강도와 만족도를 평가해주세요. 평가는 선택 사항입니다.")
                        .font(.caption)
                }
            }
            .scrollDismissesKeyboard(.interactively)
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
                    .disabled(selectedMenu == nil && menuItem.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                logger.info("🟢 AddVisitView.onAppear")
                logger.info("  - Restaurant: \(restaurant.name)")
                logger.info("  - Visit Count: \(restaurant.visitCount)")

                // 다회차 방문시 이전 평가 평균값을 초기값으로 설정
                if restaurant.visitCount > 0, !restaurant.averageIntensity.isEmpty {
                    logger.info("  - 다회차 방문: 평균 맛 평가를 초기값으로 설정")
                    loadAverageIntensityValues()
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

        // 맛 평가 저장 - 카테고리별로 다르게 저장
        switch restaurant.evaluationType {
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

        // 사진 저장
        for image in selectedPhotos {
            if let filename = PhotoStorageManager.shared.savePhoto(image, for: visit.photoId) {
                visit.photoFilenames.append(filename)
            }
        }
        logger.info("  - \(selectedPhotos.count)장의 사진 저장됨")

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

    // MARK: - Load Average Intensity Values
    private func loadAverageIntensityValues() {
        let avgData = restaurant.averageIntensity

        switch restaurant.evaluationType {
        case .general:
            // ["맵기", "진한맛", "단맛", "짠맛", "기름진", "본연의맛"] 순서
            if avgData.count >= 6 {
                spicy = avgData[0].1
                boldness = avgData[1].1
                sweetness = avgData[2].1
                saltiness = avgData[3].1
                richness = avgData[4].1
                naturalTaste = avgData[5].1
                logger.info("  - General 평가 초기값: 맵기=\(spicy), 진한맛=\(boldness), 단맛=\(sweetness)")
            }

        case .steak:
            // ["굽기", "육즙", "부드러움", "간", "육향", "마블링"] 순서
            if avgData.count >= 6 {
                steakDoneness = avgData[0].1
                steakJuiciness = avgData[1].1
                steakTenderness = avgData[2].1
                steakSeasoning = avgData[3].1
                steakFlavor = avgData[4].1
                steakMarbling = avgData[5].1
                logger.info("  - Steak 평가 초기값: 굽기=\(steakDoneness), 육즙=\(steakJuiciness)")
            }

        case .sushi:
            // ["샤리(밥)", "네타(재료)", "와사비", "밸런스", "쥐기", "온도"] 순서
            if avgData.count >= 6 {
                sushiShari = avgData[0].1
                sushiNeta = avgData[1].1
                sushiWasabi = avgData[2].1
                sushiBalance = avgData[3].1
                sushiGrip = avgData[4].1
                sushiTemperature = avgData[5].1
                logger.info("  - Sushi 평가 초기값: 샤리=\(sushiShari), 네타=\(sushiNeta)")
            }

        case .ramen:
            // ["국물", "면발", "차슈", "토핑", "온도", "밸런스"] 순서
            if avgData.count >= 6 {
                ramenBroth = avgData[0].1
                ramenNoodle = avgData[1].1
                ramenChashu = avgData[2].1
                ramenTopping = avgData[3].1
                ramenTemperature = avgData[4].1
                ramenBalance = avgData[5].1
                logger.info("  - Ramen 평가 초기값: 국물=\(ramenBroth), 면발=\(ramenNoodle)")
            }

        case .pizza:
            // ["도우", "소스", "치즈", "굽기", "토핑", "밸런스"] 순서
            if avgData.count >= 6 {
                pizzaDough = avgData[0].1
                pizzaSauce = avgData[1].1
                pizzaCheese = avgData[2].1
                pizzaBaking = avgData[3].1
                pizzaTopping = avgData[4].1
                pizzaBalance = avgData[5].1
                logger.info("  - Pizza 평가 초기값: 도우=\(pizzaDough), 소스=\(pizzaSauce)")
            }

        case .wine:
            // ["바디", "타닌", "산미", "아로마", "피니시", "밸런스"] 순서
            if avgData.count >= 6 {
                wineBody = avgData[0].1
                wineTannin = avgData[1].1
                wineAcidity = avgData[2].1
                wineAroma = avgData[3].1
                wineFinish = avgData[4].1
                wineBalance = avgData[5].1
                logger.info("  - Wine 평가 초기값: 바디=\(wineBody), 타닌=\(wineTannin)")
            }

        case .coffee:
            // ["산미", "바디", "풍미", "여운", "단맛", "밸런스"] 순서
            if avgData.count >= 6 {
                coffeeAcidity = avgData[0].1
                coffeeBody = avgData[1].1
                coffeeFlavor = avgData[2].1
                coffeeAftertaste = avgData[3].1
                coffeeSweetness = avgData[4].1
                coffeeBalance = avgData[5].1
                logger.info("  - Coffee 평가 초기값: 산미=\(coffeeAcidity), 바디=\(coffeeBody)")
            }
        }
    }

    // MARK: - Combined Evaluation View (통합)
    private var combinedEvaluationView: some View {
        VStack(spacing: 16) {
            switch restaurant.evaluationType {
            case .general:
                CombinedEvaluationRow(title: "🌶️ 맵기", subtitle: "순한 ↔ 매운", intensityValue: $spicy, appropriatenessValue: $spicyAppropriate)
                CombinedEvaluationRow(title: "💪 진한맛", subtitle: "담백 ↔ 진한", intensityValue: $boldness, appropriatenessValue: $boldnessAppropriate)
                CombinedEvaluationRow(title: "🍯 단맛", subtitle: "안좋아함 ↔ 좋아함", intensityValue: $sweetness, appropriatenessValue: $sweetnessAppropriate)
                CombinedEvaluationRow(title: "🧂 짠맛", subtitle: "싱거움 ↔ 짭짤", intensityValue: $saltiness, appropriatenessValue: $saltinessAppropriate)
                CombinedEvaluationRow(title: "🥓 기름진", subtitle: "담백 ↔ 고소", intensityValue: $richness, appropriatenessValue: $richnessAppropriate)
                CombinedEvaluationRow(title: "🌿 본연의맛", subtitle: "양념 ↔ 재료맛", intensityValue: $naturalTaste, appropriatenessValue: $naturalTasteAppropriate)

            case .steak:
                CombinedEvaluationRow(title: "🔥 굽기", subtitle: "레어 ↔ 웰던", intensityValue: $steakDoneness, appropriatenessValue: $steakDonenessAppropriate)
                CombinedEvaluationRow(title: "🥩 육즙", subtitle: "퍽퍽 ↔ 촉촉", intensityValue: $steakJuiciness, appropriatenessValue: $steakJuicinessAppropriate)
                CombinedEvaluationRow(title: "✨ 부드러움", subtitle: "질김 ↔ 부드러움", intensityValue: $steakTenderness, appropriatenessValue: $steakTendernessAppropriate)
                CombinedEvaluationRow(title: "🧂 간", subtitle: "싱거움 ↔ 짭짤", intensityValue: $steakSeasoning, appropriatenessValue: $steakSeasoningAppropriate)
                CombinedEvaluationRow(title: "🌿 육향", subtitle: "약함 ↔ 강함", intensityValue: $steakFlavor, appropriatenessValue: $steakFlavorAppropriate)
                CombinedEvaluationRow(title: "🍖 마블링", subtitle: "적음 ↔ 많음", intensityValue: $steakMarbling, appropriatenessValue: $steakMarblingAppropriate)

            case .sushi:
                CombinedEvaluationRow(title: "🍚 샤리(밥)", subtitle: "흐물 ↔ 단단", intensityValue: $sushiShari, appropriatenessValue: $sushiShariAppropriate)
                CombinedEvaluationRow(title: "🐟 네타(재료)", subtitle: "신선도", intensityValue: $sushiNeta, appropriatenessValue: $sushiNetaAppropriate)
                CombinedEvaluationRow(title: "🌿 와사비", subtitle: "약함 ↔ 강함", intensityValue: $sushiWasabi, appropriatenessValue: $sushiWasabiAppropriate)
                CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: $sushiBalance, appropriatenessValue: $sushiBalanceAppropriate)
                CombinedEvaluationRow(title: "✋ 쥐기", subtitle: "풀림 ↔ 결속", intensityValue: $sushiGrip, appropriatenessValue: $sushiGripAppropriate)
                CombinedEvaluationRow(title: "🌡️ 온도", subtitle: "차가움 ↔ 따뜻함", intensityValue: $sushiTemperature, appropriatenessValue: $sushiTemperatureAppropriate)

            case .ramen:
                CombinedEvaluationRow(title: "🥣 국물", subtitle: "깊이/감칠맛", intensityValue: $ramenBroth, appropriatenessValue: $ramenBrothAppropriate)
                CombinedEvaluationRow(title: "🍜 면발", subtitle: "부드러움 ↔ 쫄깃함", intensityValue: $ramenNoodle, appropriatenessValue: $ramenNoodleAppropriate)
                CombinedEvaluationRow(title: "🥓 차슈", subtitle: "퍽퍽 ↔ 부드러움", intensityValue: $ramenChashu, appropriatenessValue: $ramenChashuAppropriate)
                CombinedEvaluationRow(title: "🥚 토핑", subtitle: "부실 ↔ 풍부", intensityValue: $ramenTopping, appropriatenessValue: $ramenToppingAppropriate)
                CombinedEvaluationRow(title: "🔥 온도", subtitle: "미지근 ↔ 뜨거움", intensityValue: $ramenTemperature, appropriatenessValue: $ramenTemperatureAppropriate)
                CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: $ramenBalance, appropriatenessValue: $ramenBalanceAppropriate)

            case .pizza:
                CombinedEvaluationRow(title: "🫓 도우", subtitle: "질김 ↔ 쫄깃함", intensityValue: $pizzaDough, appropriatenessValue: $pizzaDoughAppropriate)
                CombinedEvaluationRow(title: "🍅 소스", subtitle: "적음 ↔ 많음", intensityValue: $pizzaSauce, appropriatenessValue: $pizzaSauceAppropriate)
                CombinedEvaluationRow(title: "🧀 치즈", subtitle: "적음 ↔ 많음", intensityValue: $pizzaCheese, appropriatenessValue: $pizzaCheeseAppropriate)
                CombinedEvaluationRow(title: "🔥 굽기", subtitle: "덜익음 ↔ 바삭함", intensityValue: $pizzaBaking, appropriatenessValue: $pizzaBakingAppropriate)
                CombinedEvaluationRow(title: "🌟 토핑", subtitle: "부실 ↔ 풍부", intensityValue: $pizzaTopping, appropriatenessValue: $pizzaToppingAppropriate)
                CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: $pizzaBalance, appropriatenessValue: $pizzaBalanceAppropriate)

            case .wine:
                CombinedEvaluationRow(title: "💪 바디", subtitle: "가벼움 ↔ 묵직함", intensityValue: $wineBody, appropriatenessValue: $wineBodyAppropriate)
                CombinedEvaluationRow(title: "🍇 타닌", subtitle: "약함 ↔ 떫음", intensityValue: $wineTannin, appropriatenessValue: $wineTanninAppropriate)
                CombinedEvaluationRow(title: "🍋 산도", subtitle: "낮음 ↔ 높음", intensityValue: $wineAcidity, appropriatenessValue: $wineAcidityAppropriate)
                CombinedEvaluationRow(title: "🌸 아로마", subtitle: "단순 ↔ 복잡", intensityValue: $wineAroma, appropriatenessValue: $wineAromaAppropriate)
                CombinedEvaluationRow(title: "✨ 피니시", subtitle: "짧음 ↔ 긴 여운", intensityValue: $wineFinish, appropriatenessValue: $wineFinishAppropriate)
                CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: $wineBalance, appropriatenessValue: $wineBalanceAppropriate)

            case .coffee:
                CombinedEvaluationRow(title: "🍋 산미", subtitle: "낮음 ↔ 밝음", intensityValue: $coffeeAcidity, appropriatenessValue: $coffeeAcidityAppropriate)
                CombinedEvaluationRow(title: "💪 바디", subtitle: "가벼움 ↔ 묵직함", intensityValue: $coffeeBody, appropriatenessValue: $coffeeBodyAppropriate)
                CombinedEvaluationRow(title: "🌸 향미", subtitle: "단순 ↔ 복잡", intensityValue: $coffeeFlavor, appropriatenessValue: $coffeeFlavorAppropriate)
                CombinedEvaluationRow(title: "✨ 후미", subtitle: "짧음 ↔ 긴 여운", intensityValue: $coffeeAftertaste, appropriatenessValue: $coffeeAftertasteAppropriate)
                CombinedEvaluationRow(title: "🍯 단맛", subtitle: "쓴맛 ↔ 단맛", intensityValue: $coffeeSweetness, appropriatenessValue: $coffeeSweetnessAppropriate)
                CombinedEvaluationRow(title: "⚖️ 밸런스", subtitle: "불균형 ↔ 조화", intensityValue: $coffeeBalance, appropriatenessValue: $coffeeBalanceAppropriate)
            }
        }
    }

}

// MARK: - Combined Evaluation Row (강도 + 만족도)
struct CombinedEvaluationRow: View {
    let title: String
    let subtitle: String
    @Binding var intensityValue: Double
    @Binding var appropriatenessValue: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 제목
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)

            // 맛 강도 슬라이더
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("맛 강도")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Slider(value: $intensityValue, in: 0...10, step: 0.5)
                    .tint(.blue)
            }

            // 만족도 평가
            VStack(alignment: .leading, spacing: 4) {
                Text("만족도")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { value in
                        Button {
                            appropriatenessValue = value
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(appropriatenessValue == value ? Color.blue : Color.gray.opacity(0.3))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text("\(value)")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundStyle(appropriatenessValue == value ? .white : .gray)
                                    )

                                if value == 1 {
                                    Text("불만족")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                } else if value == 5 {
                                    Text("매우만족")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()
                .padding(.top, 4)
        }
        .padding(.vertical, 4)
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
