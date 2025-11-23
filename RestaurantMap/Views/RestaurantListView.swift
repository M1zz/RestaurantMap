import SwiftUI
import SwiftData

struct RestaurantListView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]
    @State private var showingAddSheet = false
    @State private var selectedRestaurant: Restaurant?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(restaurants) { restaurant in
                    RestaurantRow(restaurant: restaurant)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedRestaurant = restaurant
                            showingDetail = true
                        }
                }
                .onDelete(perform: deleteRestaurants)
            }
            .navigationTitle("식당 목록")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddRestaurantView(coordinate: nil)
            }
            .sheet(isPresented: $showingDetail) {
                if let restaurant = selectedRestaurant {
                    RestaurantDetailView(restaurant: restaurant)
                }
            }
            .overlay {
                if restaurants.isEmpty {
                    ContentUnavailableView {
                        Label("식당 없음", systemImage: "fork.knife.circle")
                    } description: {
                        Text("식당을 추가하여 시작하세요")
                    } actions: {
                        Button("식당 추가") {
                            showingAddSheet = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }
    
    private func deleteRestaurants(offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(restaurants[index])
        }
    }
}

struct RestaurantRow: View {
    let restaurant: Restaurant
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(restaurant.name)
                    .font(.headline)
                
                Spacer()
                
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < restaurant.rating ? "star.fill" : "star")
                            .foregroundStyle(index < restaurant.rating ? .yellow : .gray)
                            .font(.system(size: 12))
                    }
                }
            }
            
            Text(restaurant.address)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if !restaurant.category.isEmpty {
                Text(restaurant.category)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.1))
                    .foregroundStyle(.blue)
                    .clipShape(Capsule())
            }
            
            Text(restaurant.visitDate, format: .dateTime.year().month().day())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RestaurantListView(restaurants: [])
        .modelContainer(for: Restaurant.self, inMemory: true)
}
