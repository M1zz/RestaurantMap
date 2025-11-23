import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import OSLog

struct MapView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]

    @StateObject private var locationDelegate = LocationDelegate()
    @State private var position: MapCameraPosition = .automatic
    @State private var showingAddSheet = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedRestaurant: Restaurant?
    @State private var showingDetail = false
    @State private var temporaryPin: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedMapItem: MKMapItem?
    @State private var showHelpMessage = true
    @State private var showNearbyPlaces = false
    @State private var nearbyPlaces: [MKMapItem] = []
    @State private var tappedCoordinate: CLLocationCoordinate2D?

    private let logger = Logger(subsystem: "com.restaurantmap", category: "MapView")
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                mapView
                floatingButton
                helpMessage
            }
            .navigationTitle("식당 지도")
            .searchable(text: $searchText, prompt: "식당이나 장소 검색")
            .onSubmit(of: .search) {
                performSearch()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddRestaurantView(coordinate: selectedCoordinate, mapItem: selectedMapItem)
            }
            .sheet(isPresented: $isSearching) {
                SearchResultsView(
                    searchResults: searchResults,
                    onSelect: { mapItem in
                        selectSearchResult(mapItem)
                    },
                    onViewOnMap: {
                        isSearching = false
                    },
                    onDismiss: {
                        isSearching = false
                        searchResults = []
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .onChange(of: showingAddSheet) { _, isShowing in
                // Sheet가 닫힐 때 임시 핀 제거
                if !isShowing {
                    temporaryPin = nil
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let restaurant = selectedRestaurant {
                    RestaurantDetailView(restaurant: restaurant)
                }
            }
            .sheet(isPresented: $showNearbyPlaces) {
                NearbyPlacesView(
                    places: nearbyPlaces,
                    tappedCoordinate: tappedCoordinate,
                    onSelect: { mapItem in
                        selectNearbyPlace(mapItem)
                    },
                    onDismiss: {
                        showNearbyPlaces = false
                        nearbyPlaces = []
                        tappedCoordinate = nil
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .onAppear {
                logger.info("MapView appeared")
                locationDelegate.requestLocation()

                // 5초 후 안내 메시지 자동으로 숨기기
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation {
                        showHelpMessage = false
                    }
                }
            }
            .onChange(of: locationDelegate.locationUpdated) { _, _ in
                if let location = locationDelegate.userLocation {
                    logger.info("지도 위치 업데이트: 위도=\(location.latitude), 경도=\(location.longitude)")
                    // 사용자 위치를 중심으로 적절한 줌 레벨로 지도 이동
                    // span 값: 0.01은 약 1km 반경을 보여줍니다
                    position = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }
    
    // MARK: - Computed Views

    private var mapView: some View {
        MapReader { proxy in
            Map(position: $position) {
                UserAnnotation()

                if let tempPin = temporaryPin {
                    Annotation("", coordinate: tempPin) {
                        TemporaryPinView()
                    }
                }

                ForEach(searchResults, id: \.self) { item in
                    if let coord = item.placemark.location?.coordinate {
                        Annotation(item.name ?? "장소", coordinate: coord) {
                            SearchResultPinView(mapItem: item) {
                                selectSearchResult(item)
                            }
                        }
                    }
                }

                ForEach(restaurants) { restaurant in
                    Annotation(restaurant.name, coordinate: restaurant.coordinate) {
                        RestaurantPinView(restaurant: restaurant) {
                            selectedRestaurant = restaurant
                            showingDetail = true
                        }
                    }
                }
            }
            .onTapGesture { location in
                if let coordinate = proxy.convert(location, from: .local) {
                    handleMapTap(coordinate: coordinate)
                }
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        handleLongPressGesture(value, proxy: proxy)
                    }
            )
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
        }
    }

    private var floatingButton: some View {
        VStack(spacing: 12) {
            Button(action: addRestaurantAtCurrentLocation) {
                FloatingButtonView()
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var helpMessage: some View {
        if showHelpMessage && temporaryPin == nil && restaurants.isEmpty {
            VStack {
                Text("지도를 길게 눌러서 식당을 추가하세요")
                    .font(.subheadline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture {
                withAnimation {
                    showHelpMessage = false
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func handleLongPressGesture(_ value: SequenceGesture<LongPressGesture, DragGesture>.Value, proxy: MapProxy) {
        switch value {
        case .second(true, let drag):
            if let location = drag?.location,
               let coordinate = proxy.convert(location, from: .local) {
                temporaryPin = coordinate
                selectedCoordinate = coordinate
                logger.info("지도 롱프레스: 위도=\(coordinate.latitude), 경도=\(coordinate.longitude)")

                // 사용자가 액션을 취하면 안내 메시지 숨기기
                withAnimation {
                    showHelpMessage = false
                }

                showingAddSheet = true
            }
        default:
            break
        }
    }

    private func addRestaurantAtCurrentLocation() {
        // 현재 위치를 사용하거나, 없으면 기본 위치 사용
        selectedCoordinate = locationDelegate.userLocation ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        selectedMapItem = nil
        logger.info("현재 위치에 식당 추가 시작: 위도=\(selectedCoordinate!.latitude), 경도=\(selectedCoordinate!.longitude)")
        showingAddSheet = true
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }

        logger.info("장소 검색 시작: \(searchText)")

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                logger.error("검색 실패: \(error.localizedDescription)")
                return
            }

            if let response = response {
                searchResults = response.mapItems
                logger.info("검색 결과: \(response.mapItems.count)개")
                if !searchResults.isEmpty {
                    isSearching = true
                }
            }
        }
    }

    private func selectSearchResult(_ mapItem: MKMapItem) {
        logger.info("검색 결과 선택: \(mapItem.name ?? "이름 없음")")

        selectedCoordinate = mapItem.placemark.coordinate
        selectedMapItem = mapItem
        temporaryPin = mapItem.placemark.coordinate

        // 선택한 위치로 지도 이동
        position = .region(MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))

        isSearching = false
        searchText = ""
        showingAddSheet = true
    }

    private func handleMapTap(coordinate: CLLocationCoordinate2D) {
        logger.info("지도 탭: 위도=\(coordinate.latitude), 경도=\(coordinate.longitude)")

        tappedCoordinate = coordinate
        searchNearbyPlaces(at: coordinate)
    }

    private func searchNearbyPlaces(at coordinate: CLLocationCoordinate2D) {
        logger.info("주변 장소 검색 시작")

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant cafe food"
        request.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        )

        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let error = error {
                logger.error("주변 장소 검색 실패: \(error.localizedDescription)")
                return
            }

            if let response = response {
                nearbyPlaces = response.mapItems
                logger.info("주변 장소: \(response.mapItems.count)개")
                if !nearbyPlaces.isEmpty {
                    showNearbyPlaces = true
                }
            }
        }
    }

    private func selectNearbyPlace(_ mapItem: MKMapItem) {
        logger.info("주변 장소 선택: \(mapItem.name ?? "이름 없음")")

        selectedCoordinate = mapItem.placemark.coordinate
        selectedMapItem = mapItem
        temporaryPin = mapItem.placemark.coordinate

        // 선택한 위치로 지도 이동
        position = .region(MKCoordinateRegion(
            center: mapItem.placemark.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))

        showNearbyPlaces = false
        showingAddSheet = true
    }
}

// MARK: - Supporting Views

struct TemporaryPinView: View {
    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 40))
            .foregroundStyle(.orange)
            .shadow(radius: 3)
    }
}

struct SearchResultPinView: View {
    let mapItem: MKMapItem
    let onTap: () -> Void
    @State private var showingOptions = false

    var body: some View {
        Image(systemName: "magnifyingglass.circle.fill")
            .font(.system(size: 30))
            .foregroundStyle(.blue)
            .background(Circle().fill(.white))
            .onTapGesture {
                showingOptions = true
            }
            .popover(isPresented: $showingOptions, arrowEdge: .bottom) {
                VStack(spacing: 0) {
                    Button {
                        showingOptions = false
                        onTap()
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("식당으로 추가")
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }

                    Divider()

                    Button {
                        showingOptions = false
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("닫기")
                            Spacer()
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(width: 200)
                .presentationCompactAdaptation(.popover)
            }
    }
}

struct RestaurantPinView: View {
    let restaurant: Restaurant
    let onTap: () -> Void

    var body: some View {
        ZStack {
            if restaurant.isTop6 {
                // 탑6 - 노란 별
                Image(systemName: "star.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
                    .shadow(radius: 2)

                if let rank = restaurant.top6Rank {
                    // 랭킹 숫자 표시
                    Text("\(rank)")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.black)
                }
            } else {
                // 일반 식당 - 원
                Circle()
                    .fill(.orange.gradient)
                    .frame(width: 40, height: 40)
                    .shadow(radius: 2)

                // 카테고리 아이콘
                Image(systemName: restaurant.categoryIcon)
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
            }
        }
        .onTapGesture(perform: onTap)
    }
}

struct FloatingButtonView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.blue)
                .frame(width: 56, height: 56)
                .shadow(radius: 4)
            VStack(spacing: 2) {
                Image(systemName: "location.fill")
                    .font(.system(size: 20))
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
            }
            .foregroundStyle(.white)
        }
    }
}

// MARK: - SearchResultsView
struct SearchResultsView: View {
    let searchResults: [MKMapItem]
    let onSelect: (MKMapItem) -> Void
    let onViewOnMap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 버튼 영역
                HStack(spacing: 12) {
                    Button {
                        onViewOnMap()
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("지도에서 보기")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    Button {
                        onDismiss()
                    } label: {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                            Text("목록 닫기")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.gray.opacity(0.2))
                        .foregroundStyle(.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()

                Divider()

                // 검색 결과 리스트
                List(searchResults, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "이름 없음")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if let address = item.placemark.title {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let category = item.pointOfInterestCategory?.rawValue {
                                Text(category)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(.blue.opacity(0.1))
                                    .foregroundStyle(.blue)
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("검색 결과 \(searchResults.count)개")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - NearbyPlacesView
struct NearbyPlacesView: View {
    let places: [MKMapItem]
    let tappedCoordinate: CLLocationCoordinate2D?
    let onSelect: (MKMapItem) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 안내 메시지
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("장소를 선택하여 식당으로 저장하세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding()
                .background(.blue.opacity(0.1))

                Divider()

                // 주변 장소 리스트
                if places.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "map.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray)
                        Text("주변에 장소가 없습니다")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        Text("다른 위치를 선택해보세요")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List(places, id: \.self) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.name ?? "이름 없음")
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                if let address = item.placemark.title {
                                    Text(address)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }

                                if let category = item.pointOfInterestCategory?.rawValue {
                                    Text(category)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(.green.opacity(0.1))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }

                                if let phone = item.phoneNumber {
                                    HStack {
                                        Image(systemName: "phone.fill")
                                            .font(.caption)
                                        Text(phone)
                                            .font(.caption)
                                    }
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("주변 장소 \(places.count)개")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }
}

// MARK: - LocationDelegate
class LocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var locationUpdated = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "Location")

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        logger.info("LocationDelegate 초기화됨")
    }

    func requestLocation() {
        logger.info("위치 권한 요청 시작")
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        logger.info("위치 업데이트 성공: 위도=\(location.coordinate.latitude), 경도=\(location.coordinate.longitude), 정확도=\(location.horizontalAccuracy)m")
        userLocation = location.coordinate
        locationUpdated.toggle()
        manager.stopUpdatingLocation()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("위치 가져오기 실패: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        logger.info("위치 권한 상태 변경: \(String(describing: status))")

        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            logger.info("위치 권한 승인됨, 위치 업데이트 시작")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            logger.warning("위치 권한이 거부되었습니다")
        case .notDetermined:
            logger.info("위치 권한 미결정, 권한 요청")
            manager.requestWhenInUseAuthorization()
        @unknown default:
            logger.warning("알 수 없는 위치 권한 상태")
            break
        }
    }
}

#Preview {
    MapView(restaurants: [])
        .modelContainer(for: Restaurant.self, inMemory: true)
}
