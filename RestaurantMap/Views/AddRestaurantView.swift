import SwiftUI
import MapKit
import SwiftData
import OSLog

struct AddRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let coordinate: CLLocationCoordinate2D?
    let mapItem: MKMapItem?

    @State private var name = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var rating = 0
    @State private var category = ""
    @State private var phoneNumber = ""
    @State private var visitDate = Date()
    @State private var isTop6 = false
    @State private var top6Rank: Int? = nil
    @State private var categoryIcon = "fork.knife"
    @State private var foodCategory: FoodCategory = .general

    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var region: MKCoordinateRegion
    @State private var showingMap = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "AddRestaurant")

    private let iconOptions = [
        ("fork.knife", "포크&나이프"),
        ("cup.and.saucer.fill", "카페"),
        ("wineglass.fill", "술집"),
        ("Birthday-cake", "디저트"),
        ("basket.fill", "분식"),
        ("takeoutbag.and.cup.and.straw.fill", "패스트푸드")
    ]

    init(coordinate: CLLocationCoordinate2D?, mapItem: MKMapItem? = nil) {
        self.coordinate = coordinate
        self.mapItem = mapItem

        let initialCoordinate = coordinate ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        _selectedCoordinate = State(initialValue: initialCoordinate)
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))

        // MKMapItem이 있으면 자동으로 정보 채우기
        if let mapItem = mapItem {
            _name = State(initialValue: mapItem.name ?? "")

            // 주소 정보 추출
            let placemark = mapItem.placemark
            var addressComponents: [String] = []

            if let thoroughfare = placemark.thoroughfare {
                addressComponents.append(thoroughfare)
            }
            if let subThoroughfare = placemark.subThoroughfare {
                addressComponents.append(subThoroughfare)
            }
            if let locality = placemark.locality {
                addressComponents.append(locality)
            }

            _address = State(initialValue: addressComponents.isEmpty ? (placemark.title ?? "") : addressComponents.joined(separator: " "))

            // 전화번호
            if let phone = mapItem.phoneNumber {
                _phoneNumber = State(initialValue: phone)
            }

            // 카테고리
            if let category = mapItem.pointOfInterestCategory?.rawValue {
                _category = State(initialValue: category)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    Picker("음식 종류", selection: $foodCategory) {
                        ForEach(FoodCategory.allCases) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        logger.info("Picker onAppear - foodCategory: \(foodCategory.rawValue)")
                    }

                    TextField("식당 이름", text: $name)
                    TextField("주소", text: $address)
                    TextField("카테고리 (예: 한식, 중식)", text: $category)
                    TextField("전화번호", text: $phoneNumber)
                        .keyboardType(.phonePad)

                    if mapItem != nil {
                        Label("검색 결과에서 자동 입력됨", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
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

                Section("카테고리 설정") {
                    Toggle("나의 최애 탑6", isOn: $isTop6)

                    if isTop6 {
                        Picker("랭킹", selection: $top6Rank) {
                            Text("선택 안함").tag(nil as Int?)
                            ForEach(1...6, id: \.self) { rank in
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text("\(rank)위")
                                }
                                .tag(rank as Int?)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("카테고리 아이콘")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(iconOptions, id: \.0) { icon, name in
                                        VStack {
                                            ZStack {
                                                Circle()
                                                    .fill(categoryIcon == icon ? .yellow.opacity(0.3) : .gray.opacity(0.1))
                                                    .frame(width: 50, height: 50)
                                                Image(systemName: icon)
                                                    .font(.system(size: 24))
                                                    .foregroundStyle(categoryIcon == icon ? .orange : .gray)
                                            }
                                            Text(name)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .onTapGesture {
                                            categoryIcon = icon
                                        }
                                    }
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
            .onAppear {
                logger.info("AddRestaurantView appeared")
                logger.info("  - coordinate: \(String(describing: coordinate))")
                logger.info("  - foodCategory: \(foodCategory.rawValue)")
            }
        }
    }
    
    private func saveRestaurant() {
        logger.info("식당 저장 시작: 이름=\(name), 주소=\(address), 카테고리=\(category), 별점=\(rating), 탑6=\(isTop6)")

        let restaurant = Restaurant(
            name: name,
            address: address,
            latitude: selectedCoordinate.latitude,
            longitude: selectedCoordinate.longitude,
            notes: notes,
            rating: rating,
            visitDate: visitDate,
            category: category,
            phoneNumber: phoneNumber,
            isTop6: isTop6,
            top6Rank: isTop6 ? top6Rank : nil,
            categoryIcon: categoryIcon,
            foodCategory: foodCategory
        )

        modelContext.insert(restaurant)
        logger.info("식당 저장 완료: \(name) (탑6=\(isTop6), 랭킹=\(top6Rank ?? 0), 아이콘=\(categoryIcon))")
        dismiss()
    }
}

struct MapSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var coordinate: CLLocationCoordinate2D

    @State private var position: MapCameraPosition
    @State private var selectedLocation: CLLocationCoordinate2D

    private let logger = Logger(subsystem: "com.restaurantmap", category: "MapSelection")

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
                            logger.info("위치 선택됨: 위도=\(selectedLocation.latitude), 경도=\(selectedLocation.longitude)")
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
