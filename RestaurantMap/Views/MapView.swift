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
    @State private var isSearchingManual = false
    @State private var selectedMapItem: MKMapItem?
    @State private var selectedPOI: MKMapItem?
    @State private var showingPOIDetail = false
    @State private var mapSelection: MKMapItem?
    @State private var nearbyPOIs: [MKMapItem] = []
    @State private var searchedRegions: Set<String> = []
    @State private var isPOISearching = false
    @State private var lastSearchTime: Date?
    @State private var showSavedOnly = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "MapView")
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                mapView
                floatingButton
            }
            .navigationTitle("식당 지도")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $showSavedOnly) {
                        Label("저장된 식당만", systemImage: showSavedOnly ? "bookmark.fill" : "bookmark")
                    }
                    .toggleStyle(.button)
                    .tint(showSavedOnly ? .blue : .gray)
                }
            }
            .searchable(text: $searchText, prompt: "식당이나 장소 검색")
            .onSubmit(of: .search) {
                performSearch()
            }
            .sheet(isPresented: $showingAddSheet) {
                AddRestaurantView(coordinate: selectedCoordinate, mapItem: selectedMapItem)
            }
            .sheet(isPresented: $isSearchingManual) {
                SearchResultsView(
                    searchResults: searchResults,
                    onSelect: { mapItem in
                        selectSearchResult(mapItem)
                    },
                    onViewOnMap: {
                        isSearchingManual = false
                    },
                    onDismiss: {
                        isSearchingManual = false
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
            .sheet(isPresented: $showingPOIDetail) {
                if let poi = selectedPOI {
                    POIDetailView(mapItem: poi, onAddRestaurant: {
                        selectedCoordinate = poi.placemark.coordinate
                        selectedMapItem = poi
                        showingPOIDetail = false
                        showingAddSheet = true
                    })
                }
            }
            .onAppear {
                logger.info("🚀 MapView appeared")
                logger.info("🚀 nearbyPOIs 초기 개수: \(nearbyPOIs.count)")
                locationDelegate.requestLocation()
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
            .onChange(of: nearbyPOIs) { oldValue, newValue in
                logger.info("🔄 nearbyPOIs 배열 변경됨: \(oldValue.count) -> \(newValue.count)")
            }
        }
    }
    
    // MARK: - Computed Views

    private var mapView: some View {
        Map(position: $position, selection: $mapSelection) {
            UserAnnotation()

            if let tempPin = temporaryPin {
                Annotation("", coordinate: tempPin) {
                    TemporaryPinView()
                }
            }

            // 주변 POI 마커 표시 (저장된 식당만 보기가 꺼져있을 때만)
            if !showSavedOnly {
                ForEach(nearbyPOIs, id: \.self) { item in
                    if let coord = item.placemark.location?.coordinate {
                        Annotation(item.name ?? "장소", coordinate: coord) {
                            NearbyPOIPinView(mapItem: item) {
                                logger.info("🎯 POI 마커 탭됨: \(item.name ?? "이름없음")")
                                selectedPOI = item
                                showingPOIDetail = true
                            }
                        }
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
        .mapStyle(.standard(pointsOfInterest: .including([.cafe, .restaurant, .bakery, .brewery, .foodMarket])))
        .mapControls {
            MapUserLocationButton()
            MapCompass()
        }
        .onMapCameraChange(frequency: .onEnd) { context in
            logger.info("📍 지도 카메라 변경 감지 - 중심: \(context.region.center.latitude), \(context.region.center.longitude)")
            logger.info("📍 지도 범위 - span: \(context.region.span.latitudeDelta), \(context.region.span.longitudeDelta)")
            searchNearbyPOIsIfNeeded(in: context.region)
        }
        .onChange(of: mapSelection) { oldValue, newValue in
            logger.info("맵 선택 변경: \(String(describing: newValue?.name))")
            if let newValue = newValue {
                selectedPOI = newValue
                showingPOIDetail = true
                logger.info("POI 상세 시트 표시: \(newValue.name ?? "이름 없음")")
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


    // MARK: - Helper Methods

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
                    isSearchingManual = true
                }
            }
        }
    }

    private func searchNearbyPOIsIfNeeded(in region: MKCoordinateRegion) {
        // 중복 검색 방지: 같은 영역을 이미 검색했는지 확인
        let regionKey = regionToKey(region)

        // 이미 검색 중이거나, 최근에 검색한 영역이면 스킵
        if isPOISearching {
            logger.info("⏸️ 이미 검색 중이므로 스킵")
            return
        }

        // 같은 영역을 최근에 검색했으면 스킵 (캐싱)
        if searchedRegions.contains(regionKey) {
            logger.info("💾 캐시된 영역이므로 스킵: \(regionKey)")
            return
        }

        // 너무 자주 검색하지 않도록 throttling (최소 1초 간격)
        if let lastTime = lastSearchTime, Date().timeIntervalSince(lastTime) < 1.0 {
            logger.info("⏱️ 검색 간격이 너무 짧아서 스킷 (throttling)")
            return
        }

        lastSearchTime = Date()
        searchedRegions.insert(regionKey)
        searchNearbyPOIs(in: region)
    }

    private func regionToKey(_ region: MKCoordinateRegion) -> String {
        // 소수점 3자리로 반올림하여 비슷한 영역을 같은 것으로 취급
        let lat = round(region.center.latitude * 1000) / 1000
        let lon = round(region.center.longitude * 1000) / 1000
        let spanLat = round(region.span.latitudeDelta * 1000) / 1000
        let spanLon = round(region.span.longitudeDelta * 1000) / 1000
        return "\(lat),\(lon),\(spanLat),\(spanLon)"
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

        isSearchingManual = false
        searchText = ""
        showingAddSheet = true
    }

    private func searchNearbyPOIs(in region: MKCoordinateRegion, retryCount: Int = 0) {
        isPOISearching = true
        logger.info("🔍 화면 영역의 POI 검색 시작 (시도: \(retryCount + 1))")
        logger.info("🔍 검색 영역 중심: \(region.center.latitude), \(region.center.longitude)")
        logger.info("🔍 검색 범위: \(region.span.latitudeDelta) x \(region.span.longitudeDelta)")

        // 여러 키워드로 병렬 검색 (먹고 마실 수 있는 모든 곳)
        let keywords = [
            "restaurant",    // 식당
            "cafe",          // 카페
            "food",          // 음식점
            "bar",           // 바
            "bakery",        // 베이커리
            "coffee",        // 커피숍
            "dessert",       // 디저트
            "pizza",         // 피자
            "burger",        // 버거
            "pub",           // 펍
            "brewery",       // 양조장
            "chicken",       // 치킨
            "bbq",           // 바베큐
            "noodle",        // 국수/면
            "sushi"          // 초밥/일식
        ]
        var allResults: [MKMapItem] = []
        let group = DispatchGroup()
        var hasError = false
        var lastError: Error?

        for keyword in keywords {
            group.enter()

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = keyword
            request.region = region
            request.resultTypes = .pointOfInterest

            logger.info("🔍 '\(keyword)' 검색 시작")

            let search = MKLocalSearch(request: request)
            search.start { response, error in
                defer { group.leave() }

                if let error = error {
                    let nsError = error as NSError
                    logger.error("❌ '\(keyword)' 검색 실패: \(error.localizedDescription) (code: \(nsError.code))")
                    hasError = true
                    lastError = error
                    return
                }

                if let response = response {
                    logger.info("✅ '\(keyword)' 검색 성공: \(response.mapItems.count)개")
                    allResults.append(contentsOf: response.mapItems)
                }
            }
        }

        group.notify(queue: .main) { [self] in
            isPOISearching = false

            // 네트워크 오류 발생 시 재시도
            if hasError, let error = lastError {
                let nsError = error as NSError
                if nsError.domain == "MKErrorDomain" && nsError.code == 4 && retryCount < 3 {
                    logger.warning("⚠️ 네트워크 오류 - 1초 후 재시도...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.searchNearbyPOIs(in: region, retryCount: retryCount + 1)
                    }
                    return
                } else {
                    logger.error("❌ 검색 포기 (최대 재시도 횟수 초과 또는 다른 오류)")
                }
            }

            if !allResults.isEmpty {
                logger.info("✅ 전체 검색 완료! 원본 결과: \(allResults.count)개")

                // 기존 POI와 새로운 POI를 합치고 중복 제거
                var combinedPOIs = nearbyPOIs + allResults
                var uniquePOIs: [MKMapItem] = []
                var seenCoordinates = Set<String>()

                for item in combinedPOIs {
                    if let coord = item.placemark.location?.coordinate {
                        let key = "\(coord.latitude),\(coord.longitude)"
                        if !seenCoordinates.contains(key) {
                            seenCoordinates.insert(key)
                            uniquePOIs.append(item)
                        }
                    }
                }

                nearbyPOIs = uniquePOIs
                logger.info("✅ nearbyPOIs 배열 업데이트 완료: \(nearbyPOIs.count)개 (중복 제거 후)")
            } else {
                logger.warning("⚠️ 모든 검색이 실패하거나 결과가 없습니다")
            }
        }
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

struct NearbyPOIPinView: View {
    let mapItem: MKMapItem
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)
                .background(Circle().fill(.white))
                .shadow(radius: 2)
        }
        .onTapGesture(perform: onTap)
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

// MARK: - POIDetailView
struct POIDetailView: View {
    let mapItem: MKMapItem
    let onAddRestaurant: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = true
    @State private var hasError = false

    var body: some View {
        NavigationStack {
            Group {
                if hasError {
                    // 오류 발생 시
                    errorView
                } else if isLoading {
                    // 로딩 중
                    loadingView
                } else {
                    // 정상 표시
                    contentView
                }
            }
            .navigationTitle("장소 정보")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.gray)
                    }
                }
            }
            .onAppear {
                // 데이터 검증
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        // 최소한의 정보가 있는지 확인
                        if mapItem.name == nil && mapItem.placemark.title == nil {
                            hasError = true
                        }
                        isLoading = false
                    }
                }
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            Text("장소 정보를 불러오는 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var errorView: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("정보를 불러올 수 없습니다")
                    .font(.headline)

                Text("지도를 이동하거나 다른 장소를 선택한 후\n다시 시도해주세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("닫기")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var contentView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 장소 이름
                VStack(alignment: .leading, spacing: 8) {
                    Text(mapItem.name ?? "이름 없음")
                        .font(.title2)
                        .fontWeight(.bold)

                    if let category = mapItem.pointOfInterestCategory?.rawValue {
                        Text(category)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal)

                Divider()

                // 주소
                if let address = mapItem.placemark.title {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("주소", systemImage: "location.fill")
                            .font(.headline)
                        Text(address)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // 전화번호
                if let phone = mapItem.phoneNumber {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("전화번호", systemImage: "phone.fill")
                            .font(.headline)
                        Link(phone, destination: URL(string: "tel:\(phone.filter { !$0.isWhitespace && $0 != "-" })")!)
                            .font(.body)
                    }
                    .padding(.horizontal)
                }

                // URL
                if let url = mapItem.url {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("웹사이트", systemImage: "safari.fill")
                            .font(.headline)
                        Link(url.absoluteString, destination: url)
                            .font(.body)
                            .lineLimit(1)
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)

                // 식당으로 추가 버튼
                Button {
                    onAddRestaurant()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("내 식당 목록에 추가")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
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
