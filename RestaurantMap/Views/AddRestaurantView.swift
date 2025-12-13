import SwiftUI
import MapKit
import SwiftData
import OSLog

struct AddRestaurantView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let coordinate: CLLocationCoordinate2D?
    let mapItem: MKMapItem?
    let initialName: String?
    let initialAddress: String?
    let initialPhone: String?
    let initialCategory: String?

    @State private var name = ""
    @State private var address = ""
    @State private var notes = ""
    @State private var rating = 0
    @State private var category = ""
    @State private var phoneNumber = ""
    @State private var visitDate = Date()
    @State private var menuItem = "" // 첫 방문 시 먹은 메뉴
    @State private var isTop6 = false
    @State private var top6Rank: Int? = nil
    @State private var categoryIcon = "fork.knife"
    @State private var foodCategory: FoodCategory = FoodCategoryRepository.builtInCategories[0]
    @State private var listType: RestaurantListType = .visited // 가본곳/가볼곳 구분

    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var region: MKCoordinateRegion
    @State private var showingMap = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "AddRestaurant")

    private let iconOptions = [
        ("fork.knife", "포크&나이프"),
        ("cup.and.saucer.fill", "카페"),
        ("wineglass.fill", "술집"),
        ("birthday.cake.fill", "디저트"),
        ("basket.fill", "분식"),
        ("takeoutbag.and.cup.and.straw.fill", "패스트푸드")
    ]


    init(
        coordinate: CLLocationCoordinate2D?,
        mapItem: MKMapItem? = nil,
        initialName: String? = nil,
        initialAddress: String? = nil,
        initialPhone: String? = nil,
        initialCategory: String? = nil
    ) {
        self.coordinate = coordinate
        self.mapItem = mapItem
        self.initialName = initialName
        self.initialAddress = initialAddress
        self.initialPhone = initialPhone
        self.initialCategory = initialCategory

        let initialCoordinate = coordinate ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        _selectedCoordinate = State(initialValue: initialCoordinate)
        _region = State(initialValue: MKCoordinateRegion(
            center: initialCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))

        // 초기값이 직접 전달된 경우 (카카오 장소 정보)
        if let initialName = initialName {
            _name = State(initialValue: initialName)
        }
        if let initialAddress = initialAddress {
            _address = State(initialValue: initialAddress)
        }
        if let initialPhone = initialPhone {
            _phoneNumber = State(initialValue: initialPhone)
        }
        if let initialCategory = initialCategory {
            _category = State(initialValue: initialCategory)
        }

        // MKMapItem이 있으면 자동으로 정보 채우기 (초기값이 없을 때만)
        if let mapItem = mapItem, initialName == nil {
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

            if initialAddress == nil {
                _address = State(initialValue: addressComponents.isEmpty ? (placemark.title ?? "") : addressComponents.joined(separator: " "))
            }

            // 전화번호
            if let phone = mapItem.phoneNumber, initialPhone == nil {
                _phoneNumber = State(initialValue: phone)
            }

            // 카테고리 (한글로 매핑)
            if let poiCategory = mapItem.pointOfInterestCategory?.rawValue, initialCategory == nil {
                _category = State(initialValue: POICategoryMapper.toKorean(poiCategory))
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    Picker("음식 종류", selection: $foodCategory) {
                        ForEach(FoodCategoryRepository.builtInCategories) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .onAppear {
                        logger.info("Picker onAppear - foodCategory: \(foodCategory.name)")
                    }

                    TextField("식당 이름", text: $name)
                    TextField("주소", text: $address)
                    TextField("카테고리 (예: 한식, 중식)", text: $category)
                    TextField("전화번호", text: $phoneNumber)
                        .keyboardType(.phonePad)

                    if mapItem != nil || initialName != nil {
                        Label("장소 정보에서 자동 입력됨", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
                
                Section("방문 정보") {
                    // 가본곳/가볼곳 선택
                    Picker("구분", selection: $listType) {
                        Text(RestaurantListType.visited.displayName).tag(RestaurantListType.visited)
                        Text(RestaurantListType.wishlist.displayName).tag(RestaurantListType.wishlist)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: listType) { oldValue, newValue in
                        // 가볼곳으로 변경하면 탑6 자동 해제
                        if newValue == .wishlist {
                            isTop6 = false
                            top6Rank = nil
                        }
                    }

                    if listType == .visited {
                        DatePicker("방문 날짜", selection: $visitDate, displayedComponents: .date)

                        TextField("먹은 메뉴 (예: 불고기정식, 마르게리따 피자)", text: $menuItem)

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
                    } else {
                        Text("아직 방문하지 않은 식당입니다")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("카테고리 설정") {
                    // 탑6는 가본곳일 때만 설정 가능
                    if listType == .visited {
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
                        }
                    }

                    if !isTop6 {
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
            .scrollDismissesKeyboard(.interactively)
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
                logger.info("  - foodCategory: \(foodCategory.name)")
            }
        }
    }
    
    private func saveRestaurant() {
        logger.info("식당 저장 시작: 이름=\(name), 주소=\(address), 카테고리=\(category), 별점=\(rating), 메뉴=\(menuItem), 탑6=\(isTop6), 구분=\(listType.displayName)")

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
            foodCategory: foodCategory,
            listType: listType
        )

        modelContext.insert(restaurant)

        // 가본곳일 때만 첫 방문 기록 생성 (별점이 있거나 메뉴가 입력된 경우)
        if listType == .visited && (rating > 0 || !menuItem.isEmpty) {
            let firstVisit = Visit(
                restaurant: restaurant,
                visitDate: visitDate,
                notes: notes,
                rating: rating
            )
            firstVisit.menuItem = menuItem
            modelContext.insert(firstVisit)
            logger.info("첫 방문 기록 생성: 메뉴=\(menuItem), 별점=\(rating)")
        }

        logger.info("식당 저장 완료: \(name) (탑6=\(isTop6), 랭킹=\(top6Rank ?? 0), 아이콘=\(categoryIcon), 구분=\(listType.displayName))")
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
