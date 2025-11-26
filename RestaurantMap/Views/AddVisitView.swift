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
