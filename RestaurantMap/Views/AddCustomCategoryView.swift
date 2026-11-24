import SwiftUI

struct AddCustomCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var repository = FoodCategoryRepository.shared

    @State private var name = ""
    @State private var selectedIcon = "🍴"
    @State private var family: TasteFamily = .basic

    /// 만든 종류를 받아 바로 고르게 할 때 쓴다 (→ FoodCategoryPicker).
    var onSave: (FoodCategory) -> Void = { _ in }

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
                        onSave(repository.addCustomCategory(name: name, icon: selectedIcon, family: family))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

/// 식당을 추가 · 고칠 때 음식 종류를 고르는 줄. 내가 만든 종류도 함께 나오고,
/// 맞는 게 없으면 설정까지 가지 않고 그 자리에서 새로 만들어 바로 고른다.
struct FoodCategoryPicker: View {
    @Binding var selection: FoodCategory
    @ObservedObject private var repository = FoodCategoryRepository.shared
    @State private var creating = false

    var body: some View {
        Picker("음식 종류", selection: $selection) {
            ForEach(repository.allCategories) { category in
                Text(category.displayName).tag(category)
            }
        }
        .pickerStyle(.menu)

        Button("새 음식 종류 만들기", systemImage: "plus") { creating = true }
            .sheet(isPresented: $creating) {
                AddCustomCategoryView { selection = $0 }
            }
    }
}

#Preview {
    AddCustomCategoryView()
}
