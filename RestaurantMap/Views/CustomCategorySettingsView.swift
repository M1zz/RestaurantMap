import SwiftUI

struct CustomCategorySettingsView: View {
    @StateObject private var repository = FoodCategoryRepository.shared
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: FoodCategory?

    var body: some View {
        List {
            Section("기본 제공") {
                ForEach(FoodCategoryRepository.builtInCategories) { category in
                    HStack {
                        Text(category.displayName)
                        Spacer()
                        Text("기본")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                ForEach(repository.customCategories) { category in
                    HStack {
                        Text(category.displayName)
                        Spacer()
                    }
                }
                .onDelete(perform: deleteCategories)

                Button {
                    showingAddSheet = true
                } label: {
                    Label("새 종류 추가", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("내가 추가한 종류")
            } footer: {
                if repository.customCategories.isEmpty {
                    Text("자주 가는 음식 종류를 직접 추가할 수 있습니다")
                }
            }
        }
        .navigationTitle("음식 종류 관리")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSheet) {
            AddCustomCategoryView()
        }
    }

    private func deleteCategories(at offsets: IndexSet) {
        for index in offsets {
            let category = repository.customCategories[index]
            repository.deleteCustomCategory(id: category.id)
        }
    }
}

#Preview {
    NavigationStack {
        CustomCategorySettingsView()
    }
}
