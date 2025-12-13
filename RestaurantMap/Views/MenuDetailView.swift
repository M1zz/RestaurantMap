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

    var sortedVisits: [Visit] {
        (menuItem.visits ?? []).sorted(by: { $0.visitDate > $1.visitDate })
    }

    var body: some View {
        NavigationStack {
            List {
                // 메뉴 정보
                Section("메뉴 정보") {
                    if isEditing {
                        TextField("메뉴 이름", text: $editName)

                        HStack {
                            TextField("가격", text: $editPrice)
                                .keyboardType(.numberPad)
                            Text("원")
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
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(menuItem.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "완료" : "편집") {
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
                        Button("취소") {
                            isEditing = false
                        }
                    } else {
                        Button("닫기") {
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
    }

    private func saveChanges() {
        menuItem.name = editName
        menuItem.price = Int(editPrice.filter { $0.isNumber })
        menuItem.menuDescription = editDescription
        menuItem.isSignature = editIsSignature
    }
}

// MARK: - Menu Visit Row View
struct MenuVisitRowView: View {
    let visit: Visit

    var body: some View {
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
            }

            if !visit.notes.isEmpty {
                Text(visit.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if visit.hasTasteProfile {
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
