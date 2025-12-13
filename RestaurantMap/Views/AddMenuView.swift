import SwiftUI
import SwiftData

struct AddMenuView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let restaurant: Restaurant

    @State private var name = ""
    @State private var price = ""
    @State private var menuDescription = ""
    @State private var isSignature = false

    var body: some View {
        NavigationStack {
            Form {
                Section("메뉴 정보") {
                    TextField("메뉴 이름", text: $name)

                    HStack {
                        TextField("가격", text: $price)
                            .keyboardType(.numberPad)
                        Text("원")
                            .foregroundStyle(.secondary)
                    }

                    TextField("메뉴 설명 (선택)", text: $menuDescription, axis: .vertical)
                        .lineLimit(3...5)
                }

                Section {
                    Toggle("대표 메뉴로 설정", isOn: $isSignature)
                } footer: {
                    Text("대표 메뉴는 메뉴 목록 상단에 표시됩니다")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("메뉴 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveMenuItem()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }

    private func saveMenuItem() {
        let priceValue = Int(price.filter { $0.isNumber })

        let menu = MenuItem(
            name: name,
            price: priceValue,
            menuDescription: menuDescription,
            isSignature: isSignature,
            restaurant: restaurant
        )

        modelContext.insert(menu)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, MenuItem.self, configurations: config)

    let restaurant = Restaurant(
        name: "테스트 식당",
        address: "서울시",
        latitude: 37.5,
        longitude: 127.0
    )
    container.mainContext.insert(restaurant)

    return AddMenuView(restaurant: restaurant)
        .modelContainer(container)
}
