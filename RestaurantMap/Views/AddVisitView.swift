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

                Section {
                    Text("맛 평가는 방문 기록 저장 후 추가할 수 있습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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

        logger.info("  - Visit 생성됨")
        logger.info("  - Visit.restaurant: \(visit.restaurant?.name ?? "nil")")

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
