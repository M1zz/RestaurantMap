import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var restaurants: [Restaurant]
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            MapView(restaurants: restaurants)
                .tabItem {
                    Label("지도", systemImage: "map")
                }
                .tag(0)

            RestaurantListView(restaurants: restaurants)
                .tabItem {
                    Label("목록", systemImage: "list.bullet")
                }
                .tag(1)

            TasteProfileView()
                .tabItem {
                    Label("취향", systemImage: "person.crop.circle")
                }
                .tag(2)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Restaurant.self, TasteProfile.self], inMemory: true)
}
