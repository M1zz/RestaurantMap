import SwiftUI

struct CustomCategorySettingsView: View {
    @StateObject private var repository = FoodCategoryRepository.shared
    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var categoryToDelete: FoodCategory?
    @State private var purchases = Purchases.shared
    @State private var paywallFeature: RestaurantFeature?

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

                // 이미 더한 종류는 그대로 쓰고 지울 수 있다. 새로 더하는 것만 Plus.
                Button {
                    if purchases.allows(.customCategory) {
                        showingAddSheet = true
                    } else {
                        paywallFeature = .customCategory
                    }
                } label: {
                    LockedLabel(title: "새 종류 추가", systemImage: "plus.circle.fill", feature: .customCategory)
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
        .paywall(for: $paywallFeature)
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
