import SwiftUI
import MapKit
import SwiftData

struct AddRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let coordinate: CLLocationCoordinate2D?
    
    @State private var name = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var rating = 0
    @State private var category = ""
    @State private var phoneNumber = ""
    @State private var visitDate = Date()
    
    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var region: MKCoordinateRegion
    @State private var showingMap = false
    
    init(coordinate: CLLocationCoordinate2D?) {
        self.coordinate = coordinate
        let initialCoordinate = coordinate ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        _selectedCoordinate = State(initialValue: initialCoordinate)
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("식당 이름", text: $name)
                    TextField("주소", text: $address)
                    TextField("카테고리 (예: 한식, 중식)", text: $category)
                    TextField("전화번호", text: $phoneNumber)
                        .keyboardType(.phonePad)
                }
                
                Section("방문 정보") {
                    DatePicker("방문 날짜", selection: $visitDate, displayedComponents: .date)
                    
                    VStack(alignment: .leading) {
                        Text("별점")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        HStack(spacing: 8) {
                            ForEach(1..<6) { index in
                                Image(systemName: index <= rating ? "star.fill" : "star")
                                    .foregroundStyle(index <= rating ? .yellow : .gray)
                                    .font(.system(size: 24))
                                    .onTapGesture {
                                        rating = index
                                    }
                            }
                        }
                    }
                }
                
                Section("위치") {
                    Button {
                        showingMap = true
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("위도: \(selectedCoordinate.latitude, specifier: "%.6f")")
                                Text("경도: \(selectedCoordinate.longitude, specifier: "%.6f")")
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Image(systemName: "map")
                                .foregroundStyle(.blue)
                        }
                    }
                }
                
                Section("메모") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("식당 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveRestaurant()
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
            .sheet(isPresented: $showingMap) {
                MapSelectionView(coordinate: $selectedCoordinate)
            }
        }
    }
    
    private func saveRestaurant() {
        let restaurant = Restaurant(
            name: name,
            address: address,
            latitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude,
            notes: notes,
            rating: rating,
            visitDate: visitDate,
            category: category,
            phoneNumber: phoneNumber
        )
        
        modelContext.insert(restaurant)
        dismiss()
    }
}

struct MapSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var coordinate: CLLocationCoordinate2D
    
    @State private var position: MapCameraPosition
    @State private var selectedLocation: CLLocationCoordinate2D
    
    init(coordinate: Binding<CLLocationCoordinate2D>) {
        _coordinate = coordinate
        _selectedLocation = State(initialValue: coordinate.wrappedValue)
        _position = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate.wrappedValue,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }
    
    var body: some View {
        NavigationStack {
            Map(position: $position)
                .onMapCameraChange { context in
                    selectedLocation = context.region.center
                }
                .navigationTitle("위치 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("선택") {
                            coordinate = selectedLocation
                            dismiss()
                        }
                    }
                }
                .overlay(alignment: .center) {
                    Image(systemName: "mappin")
                        .foregroundStyle(.red)
                        .font(.system(size: 40))
                        .offset(y: -20)
                }
        }
    }
}

#Preview {
    AddRestaurantView(coordinate: nil)
        .modelContainer(for: Restaurant.self, inMemory: true)
}
