import SwiftUI
import MapKit
import SwiftData

struct RestaurantDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var restaurant: Restaurant
    
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    if isEditing {
                        TextField("식당 이름", text: $restaurant.name)
                        TextField("주소", text: $restaurant.address)
                        TextField("카테고리", text: $restaurant.category)
                        TextField("전화번호", text: $restaurant.phoneNumber)
                    } else {
                        LabeledContent("식당 이름", value: restaurant.name)
                        LabeledContent("주소", value: restaurant.address)
                        if !restaurant.category.isEmpty {
                            LabeledContent("카테고리", value: restaurant.category)
                        }
                        if !restaurant.phoneNumber.isEmpty {
                            LabeledContent("전화번호") {
                                Link(restaurant.phoneNumber, destination: URL(string: "tel://\(restaurant.phoneNumber)")!)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                Section("방문 정보") {
                    if isEditing {
                        DatePicker("방문 날짜", selection: $restaurant.visitDate, displayedComponents: .date)
                        
                        VStack(alignment: .leading) {
                            Text("별점")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                ForEach(1..<6) { index in
                                    Image(systemName: index <= restaurant.rating ? "star.fill" : "star")
                                        .foregroundStyle(index <= restaurant.rating ? .yellow : .gray)
                                        .font(.system(size: 24))
                                        .onTapGesture {
                                            restaurant.rating = index
                                        }
                                }
                            }
                        }
                    } else {
                        LabeledContent("방문 날짜") {
                            Text(restaurant.visitDate, format: .dateTime.year().month().day())
                        }
                        
                        LabeledContent("별점") {
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < restaurant.rating ? "star.fill" : "star")
                                        .foregroundStyle(index < restaurant.rating ? .yellow : .gray)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                    }
                }
                
                Section("위치") {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: restaurant.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))) {
                        Annotation(restaurant.name, coordinate: restaurant.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 14))
                            }
                        }
                    }
                    .frame(height: 200)
                    .listRowInsets(EdgeInsets())
                    
                    LabeledContent("좌표") {
                        VStack(alignment: .trailing) {
                            Text("위도: \(restaurant.latitude, specifier: "%.6f")")
                            Text("경도: \(restaurant.longitude, specifier: "%.6f")")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "http://maps.apple.com/?ll=\(restaurant.latitude),\(restaurant.longitude)")!) {
                        HStack {
                            Text("Apple 지도에서 열기")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
                
                Section("메모") {
                    if isEditing {
                        TextEditor(text: $restaurant.notes)
                            .frame(minHeight: 100)
                    } else {
                        if restaurant.notes.isEmpty {
                            Text("메모 없음")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(restaurant.notes)
                        }
                    }
                }
                
                if !isEditing {
                    Section {
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("식당 삭제")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(restaurant.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "완료" : "편집") {
                        isEditing.toggle()
                    }
                }
            }
            .alert("식당 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    deleteRestaurant()
                }
            } message: {
                Text("'\(restaurant.name)'을(를) 삭제하시겠습니까?")
            }
        }
    }
    
    private func deleteRestaurant() {
        modelContext.delete(restaurant)
        dismiss()
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    let restaurant = Restaurant(
        name: "샘플 식당",
        address: "서울시 중구 태평로 1가",
        latitude: 37.5665,
        longitude: 126.9780,
        notes: "맛있었어요!",
        rating: 4,
        category: "한식"
    )
    container.mainContext.insert(restaurant)
    
    return RestaurantDetailView(restaurant: restaurant)
        .modelContainer(container)
}
