import SwiftUI
import SwiftData

struct MenuListView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurant: Restaurant

    @State private var showingAddMenu = false
    @State private var selectedMenu: MenuItem?

    var sortedMenus: [MenuItem] {
        (restaurant.menus ?? []).sorted { menu1, menu2 in
            // 대표 메뉴가 먼저
            if menu1.isSignature != menu2.isSignature {
                return menu1.isSignature
            }
            // 주문 횟수가 많은 순
            if menu1.orderCount != menu2.orderCount {
                return menu1.orderCount > menu2.orderCount
            }
            // 이름 순
            return menu1.name < menu2.name
        }
    }

    var body: some View {
        List {
            if sortedMenus.isEmpty {
                Section {
                    VStack(spacing: 16) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.5))

                        Text("등록된 메뉴가 없습니다")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        Button {
                            showingAddMenu = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("첫 메뉴 추가하기")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            } else {
                Section {
                    ForEach(sortedMenus) { menu in
                        Button {
                            selectedMenu = menu
                        } label: {
                            MenuRowView(menuItem: menu)
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete(perform: deleteMenus)
                } header: {
                    HStack {
                        Text("메뉴 목록 (\(sortedMenus.count))")
                        Spacer()
                        Button {
                            showingAddMenu = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("\(restaurant.name)의 메뉴")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddMenu) {
            AddMenuView(restaurant: restaurant)
        }
        .sheet(item: $selectedMenu) { menu in
            MenuDetailView(menuItem: menu)
        }
    }

    private func deleteMenus(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedMenus[index])
        }
    }
}

// MARK: - Menu Row View
struct MenuRowView: View {
    let menuItem: MenuItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(menuItem.name)
                    .font(.headline)

                if menuItem.isSignature {
                    Image(systemName: "crown.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                }

                Spacer()

                Text(menuItem.formattedPrice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if !menuItem.menuDescription.isEmpty {
                Text(menuItem.menuDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            HStack(spacing: 12) {
                // 평균 별점
                if menuItem.orderCount > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                        Text(String(format: "%.1f", menuItem.averageRating))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                // 주문 횟수
                HStack(spacing: 2) {
                    Image(systemName: "cart.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                    Text("\(menuItem.orderCount)회")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 최근 주문일
                if let lastOrderDate = menuItem.lastOrderDate {
                    HStack(spacing: 2) {
                        Image(systemName: "clock.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text(lastOrderDate, format: .dateTime.month().day())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
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

    let menuItem1 = MenuItem(name: "불고기", price: 15000, menuDescription: "특제 양념에 재운 불고기", isSignature: true, restaurant: restaurant)
    let menuItem2 = MenuItem(name: "된장찌개", price: 8000, restaurant: restaurant)
    container.mainContext.insert(menuItem1)
    container.mainContext.insert(menuItem2)

    return NavigationStack {
        MenuListView(restaurant: restaurant)
            .modelContainer(container)
    }
}
