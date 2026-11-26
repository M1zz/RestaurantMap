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
    /// 첫 방문의 100점 점수 (→ VisitScore.swift)
    @State private var score: Int?
    @State private var category = ""
    @State private var phoneNumber = ""
    @State private var visitDate = Date()
    @State private var menuItem = "" // 첫 방문 시 먹은 메뉴
    @State private var saveFailed = false
    @State private var categoryIcon = "fork.knife"
    @State private var foodCategory: FoodCategory = FoodCategoryRepository.builtInCategories[0]
    @State private var listType: RestaurantListType = .visited // 가본곳/가볼곳 구분

    @State private var selectedCoordinate: CLLocationCoordinate2D
    @State private var region: MKCoordinateRegion
    @State private var showingMap = false

    /// 무료 한도(식당 30곳)를 세는 데 쓴다. 가본 곳 · 가볼 곳을 합친다.
    @Query private var savedRestaurants: [Restaurant]
    @State private var purchases = Purchases.shared
    @State private var paywallFeature: RestaurantFeature?
    @State private var pendingSave = false

    /// 빈 칸으로 열었을 때(목록의 +) 지금 위치 근처 식당을 띄워 고르면 채운다 (→ NearbyRestaurants).
    @StateObject private var locator = LocationDelegate()
    @State private var nearby: [MKMapItem] = []
    @State private var nearbyState = NearbyState.idle
    @State private var nearbyCenter: CLLocation?
    @State private var pickedNearby: MKMapItem?

    private enum NearbyState { case idle, locating, searching, done, denied }

    /// 장소 정보 없이 빈 칸으로 열었나.
    private var startsBlank: Bool { mapItem == nil && initialName == nil }

    private let logger = Logger(subsystem: "com.restaurantmap", category: "AddRestaurant")

    private let iconOptions = [
        ("fork.knife", String(localized: "포크&나이프")),
        ("cup.and.saucer.fill", String(localized: "카페")),
        ("wineglass.fill", String(localized: "술집")),
        ("birthday.cake.fill", String(localized: "디저트")),
        ("basket.fill", String(localized: "분식")),
        ("takeoutbag.and.cup.and.straw.fill", String(localized: "패스트푸드"))
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

        // 지도에 찍을 수 없는 좌표(범위 밖 · NaN)로 지도 영역을 만들면 죽는다 — 그런 좌표는 기본 위치로 바꾼다
        let initialCoordinate = coordinate.flatMap { $0.isMappable ? $0 : nil }
            ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
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

        // 장소의 분류 · 이름으로 음식 종류를 미리 고른다 (고를 수 있게 그대로 둔다)
        let hints = [initialCategory, initialName, mapItem?.pointOfInterestCategory?.rawValue, mapItem?.name].compactMap { $0 }
        if !hints.isEmpty {
            _foodCategory = State(initialValue: FoodCategoryRepository.guess(from: hints))
        }

        // MKMapItem이 있으면 자동으로 정보 채우기 (초기값이 없을 때만)
        if let mapItem = mapItem, initialName == nil {
            _name = State(initialValue: mapItem.name ?? "")

            if initialAddress == nil {
                _address = State(initialValue: mapItem.restaurantAddress)
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
                if startsBlank && nearbyState != .idle {
                    nearbySection
                }

                Section("기본 정보") {
                    FoodCategoryPicker(selection: $foodCategory)

                    TextField("식당 이름", text: $name)
                    TextField("주소", text: $address)
                    TextField("카테고리 (예: 한식, 중식)", text: $category)
                    TextField("전화번호", text: $phoneNumber)
                        .keyboardType(.phonePad)

                    if mapItem != nil || initialName != nil || pickedNearby != nil {
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
                                        .accessibleStar(index, rating: rating) {
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

                if listType == .visited {
                    VisitScoreSection(score: $score, stars: rating)
                }

                Section("카테고리 설정") {
                    Group {
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
                                        .accessibleTap {
                                            categoryIcon = icon
                                        }
                                        .accessibilityAddTraits(categoryIcon == icon ? .isSelected : [])
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
                        .accessibilityLabel(Text("메모"))
                        .frame(minHeight: 100)
                }
            }
            #if !os(visionOS)
            .scrollDismissesKeyboard(.interactively)
            #endif
            .navigationTitle("식당 추가")
            .saveFailureAlert($saveFailed)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소", systemImage: "xmark") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장", systemImage: "checkmark") {
                        if purchases.canAddRestaurant(having: savedRestaurants.count) {
                            saveRestaurant()
                        } else {
                            // 적은 내용은 그대로 둔다. Plus 를 열고 돌아오면 바로 저장된다.
                            paywallFeature = .restaurants
                        }
                    }
                    .disabled(name.isEmpty || address.isEmpty)
                }
            }
            .onChange(of: locator.userLocation?.latitude) { _, _ in
                guard nearbyState == .locating, let here = locator.userLocation else { return }
                if here.isMappable {
                    selectedCoordinate = here
                    region.center = here
                }
                searchNearby(around: here)
            }
            .onChange(of: locator.authorizationStatus) { _, status in
                if nearbyState == .locating, status == .denied || status == .restricted { nearbyState = .denied }
            }
            .sheet(isPresented: $showingMap) {
                MapSelectionView(coordinate: $selectedCoordinate)
            }
            .sheet(item: $paywallFeature, onDismiss: {
                // 막혀서 페이월에 갔다가 열고 돌아왔으면 하던 저장을 마친다.
                if pendingSave, purchases.canAddRestaurant(having: savedRestaurants.count) { saveRestaurant() }
                pendingSave = false
            }) { feature in
                PaywallView(highlight: feature)
                    .onAppear { pendingSave = feature == .restaurants }
            }
            .onAppear {
                startNearbySearch()
                logger.info("AddRestaurantView appeared")
                logger.info("  - coordinate: \(String(describing: coordinate))")
                logger.info("  - foodCategory: \(foodCategory.name)")
            }
        }
    }
    
    // MARK: 근처 식당

    @ViewBuilder
    private var nearbySection: some View {
        Section {
            switch nearbyState {
            case .idle:
                EmptyView()
            case .locating, .searching:
                HStack(spacing: 12) {
                    ProgressView()
                    Text("지금 있는 곳 근처 식당을 찾는 중…")
                        .foregroundStyle(.secondary)
                }
            case .denied:
                Text("위치 권한을 주면 지금 있는 식당을 골라 이름과 주소를 바로 채울 수 있어요.")
                    .foregroundStyle(.secondary)
            case .done:
                if nearby.isEmpty {
                    Text("근처에서 식당을 찾지 못했어요. 직접 적어 주세요.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(nearby, id: \.self) { item in
                        Button { fill(from: item) } label: { nearbyRow(item) }
                            .accessibilityAddTraits(pickedNearby == item ? .isSelected : [])
                    }
                }
            }
        } header: {
            Text("혹시 여기인가요?")
        } footer: {
            if nearbyState == .done, !nearby.isEmpty {
                Text("고르면 이름 · 주소 · 전화번호 · 음식 종류를 채워요. 고친 뒤 저장해도 돼요.")
                    .font(.body)
            }
        }
    }

    private func nearbyRow(_ item: MKMapItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: item.name ?? "")
                    .font(.headline)
                    .foregroundStyle(.primary)
                let address = item.restaurantAddress
                if !address.isEmpty {
                    Text(verbatim: address)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            if let nearbyCenter {
                Text(verbatim: NearbyRestaurants.distanceText(NearbyRestaurants.distance(item, from: nearbyCenter)))
                    .foregroundStyle(.secondary)
            }
            if pickedNearby == item {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    /// 빈 칸으로 열었으면 지금 위치(넘겨받은 좌표가 있으면 그 자리) 근처를 찾는다.
    private func startNearbySearch() {
        guard startsBlank, nearbyState == .idle else { return }
        if let coordinate, coordinate.isMappable {
            searchNearby(around: coordinate)
            return
        }
        switch locator.authorizationStatus {
        case .denied, .restricted:
            nearbyState = .denied
        default:
            nearbyState = .locating
            locator.requestLocation()
        }
    }

    private func searchNearby(around center: CLLocationCoordinate2D) {
        nearbyState = .searching
        nearbyCenter = CLLocation(latitude: center.latitude, longitude: center.longitude)
        Task {
            let found = await NearbyRestaurants.search(around: center)
            nearby = found
            nearbyState = .done
        }
    }

    private func fill(from item: MKMapItem) {
        pickedNearby = item
        name = item.name ?? name
        let address = item.restaurantAddress
        if !address.isEmpty { self.address = address }
        if let phone = item.phoneNumber, !phone.isEmpty { phoneNumber = phone }
        if let raw = item.pointOfInterestCategory?.rawValue {
            category = POICategoryMapper.toKorean(raw)
        }
        foodCategory = FoodCategoryRepository.guess(
            from: [item.pointOfInterestCategory?.rawValue, item.name].compactMap { $0 })
        let spot = item.placemark.coordinate
        if spot.isMappable {
            selectedCoordinate = spot
            region.center = spot
        }
    }

    private func saveRestaurant() {
        logger.info("식당 저장 시작: 이름=\(name), 주소=\(address), 카테고리=\(category), 별점=\(rating), 메뉴=\(menuItem), 구분=\(listType.displayName)")

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
            categoryIcon: categoryIcon,
            foodCategory: foodCategory,
            listType: listType
        )

        modelContext.insert(restaurant)
        // 저장에 실패하면 이번에 넣은 것만 걷어 낸다
        var inserted: [any PersistentModel] = [restaurant]

        // 가본곳일 때만 첫 방문 기록 생성 (별점이 있거나 메뉴가 입력된 경우)
        if listType == .visited && (rating > 0 || !menuItem.isEmpty || score != nil) {
            let firstVisit = Visit(
                restaurant: restaurant,
                visitDate: visitDate,
                notes: notes,
                rating: rating
            )
            firstVisit.menuItem = menuItem
            firstVisit.score = score
            modelContext.insert(firstVisit)
            inserted.append(firstVisit)
            logger.info("첫 방문 기록 생성: 메뉴=\(menuItem), 별점=\(rating)")
        }

        // 자동 저장에 맡기지 않는다 — 실패하면 알리고 화면을 닫지 않는다
        do {
            try modelContext.save()
        } catch {
            logger.error("식당 저장 실패: \(error.localizedDescription)")
            // 저장되지 않은 식당을 컨텍스트에 남겨 두면 다시 '저장' 을 누를 때마다 같은 식당이 하나씩 더 생긴다.
            // rollback() 은 같은 컨텍스트에서 아직 저장되지 않은 다른 화면의 고침까지 버리므로, 이번에 넣은 것만 지운다.
            for model in inserted.reversed() { modelContext.delete(model) }
            saveFailed = true
            return
        }
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
                    // 쓸 수 없는 중심(지구가 다 보이게 줄였을 때 등)은 받지 않는다 — 식당 좌표로 저장된다
                    if context.region.center.isMappable { selectedLocation = context.region.center }
                }
                .navigationTitle("위치 선택")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("취소", systemImage: "xmark") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .confirmationAction) {
                        Button("선택", systemImage: "checkmark") {
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
