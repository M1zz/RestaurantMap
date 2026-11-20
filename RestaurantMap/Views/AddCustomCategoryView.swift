import SwiftUI

struct AddCustomCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var repository = FoodCategoryRepository.shared

    @State private var name = ""
    @State private var selectedIcon = "🍴"
    @State private var family: TasteFamily = .basic

    let commonIcons = [
        "🍴", "🥘", "🍲", "🥗", "🌮", "🌯",
        "🍛", "🍜", "🍝", "🥟", "🥠", "🍢",
        "🥙", "🌭", "🍖", "🥓", "🧆", "🥚",
        "🍳", "🥞", "🧇", "🥐", "🥖", "🥨",
        "🥯", "🧀", "🍿", "🧈", "🥤", "🧃",
        "🧋", "🍵", "🧉", "🥃", "🍻", "🍶"
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        NavigationStack {
            Form {
                Section("이름") {
                    TextField("예: 태국음식, 인도음식", text: $name)
                        .autocorrectionDisabled()
                }

                Section("아이콘") {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(commonIcons, id: \.self) { icon in
                            Text(icon)
                                .font(.system(size: 40))
                                .frame(width: 50, height: 50)
                                .background(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .accessibleTap {
                                    selectedIcon = icon
                                }
                                .accessibilityAddTraits(selectedIcon == icon ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    Picker("맛 기록 계열", selection: $family) {
                        ForEach(TasteFamily.allCases) { family in
                            Text(verbatim: "\(family.emoji) \(family.title)").tag(family)
                        }
                    }
                } footer: {
                    Text("방문을 기록할 때 이 계열에 맞는 맛 항목이 더 나와요. 고기면 굽기 · 육향처럼요.")
                }
            }
            .navigationTitle("새 음식 종류")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", systemImage: "xmark") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", systemImage: "checkmark") {
                        repository.addCustomCategory(name: name, icon: selectedIcon, family: family)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    AddCustomCategoryView()
}
