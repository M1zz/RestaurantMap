import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import OSLog

// MARK: - POI Category Helper
enum POICategoryMapper {
    static func toKorean(_ rawValue: String) -> String {
        switch rawValue {
        case "MKPOICategoryCafe":
            return "카페"
        case "MKPOICategoryRestaurant":
            return "레스토랑"
        case "MKPOICategoryBakery":
            return "베이커리"
        case "MKPOICategoryBrewery":
            return "브루어리"
        case "MKPOICategoryNightlife":
            return "나이트라이프"
        case "MKPOICategoryWinery":
            return "와이너리"
        case "MKPOICategoryFoodMarket":
            return "식품마켓"
        case "MKPOICategoryBar":
            return "바"
        case "MKPOICategoryFastFood":
            return "패스트푸드"
        default:
            if rawValue.hasPrefix("MKPOICategory") {
                return String(rawValue.dropFirst("MKPOICategory".count))
            }
            return rawValue
        }
    }

    static func toIcon(_ rawValue: String) -> String {
        switch rawValue {
        case "MKPOICategoryCafe", "카페":
            return "cup.and.saucer.fill"
        case "MKPOICategoryRestaurant", "레스토랑":
            return "fork.knife"
        case "MKPOICategoryBakery", "베이커리":
            return "birthday.cake.fill"
        case "MKPOICategoryBrewery", "브루어리":
            return "mug.fill"
        case "MKPOICategoryNightlife", "나이트라이프":
            return "moon.stars.fill"
        case "MKPOICategoryWinery", "와이너리":
            return "wineglass.fill"
        case "MKPOICategoryFoodMarket", "식품마켓":
            return "cart.fill"
        case "MKPOICategoryBar", "바":
            return "wineglass.fill"
        case "MKPOICategoryFastFood", "패스트푸드":
            return "takeoutbag.and.cup.and.straw.fill"
        default:
            return "fork.knife"
        }
    }
}

struct MapView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]

    @StateObject private var locationDelegate = LocationDelegate()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var hasInitializedPosition = false
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
    @State private var kakaoPlaces: [KakaoPlace] = []
    @State private var kakaoSearchResults: [KakaoPlace] = []  // 검색 결과 (파란색으로 표시)
    @State private var isUsingKakaoSearch = true  // 기본값: 카카오 검색 사용
    @State private var isKakaoSearching = false
    @State private var selectedKakaoPlace: KakaoPlace?
    @State private var kakaoPlaceForAdd: KakaoPlace?  // AddRestaurantView에 전달할 장소 정보
    @State private var showingKakaoDetail = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showSettings = false  // 설정 화면 표시 여부

    @StateObject private var kakaoService = KakaoLocalSearchService.shared
    private let logger = Logger(subsystem: "com.restaurantmap", category: "MapView")
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                mapView
                floatingButton
            }
            .navigationTitle("식당 지도")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        // 저장된 식당만 보기 토글
                        Button {
                            showSavedOnly.toggle()
                        } label: {
                            Label(
                                showSavedOnly ? "모든 장소 보기" : "저장된 식당만 보기",
                                systemImage: showSavedOnly ? "map" : "bookmark.fill"
                            )
                        }

                        Divider()

                        // 카카오 검색 / Apple Maps 검색 전환
                        Button {
                            isUsingKakaoSearch.toggle()
                        } label: {
                            Label(
                                isUsingKakaoSearch ? "Apple Maps 검색 사용" : "카카오 검색 사용",
                                systemImage: isUsingKakaoSearch ? "applelogo" : "magnifyingglass"
                            )
                        }

                        Divider()

                        // 설정
                        Button {
                            showSettings = true
                        } label: {
                            Label("설정", systemImage: "gearshape")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(.blue)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "식당이나 장소 검색")
            .onSubmit(of: .search) {
                performSearch()
            }
            .sheet(isPresented: $showingAddSheet) {
                if let kakaoPlace = kakaoPlaceForAdd {
                    // 카카오 장소 정보로 미리 채워진 상태로 식당 추가
                    AddRestaurantView(
                        coordinate: selectedCoordinate,
                        mapItem: selectedMapItem,
                        initialName: kakaoPlace.placeName,
                        initialAddress: !kakaoPlace.roadAddressName.isEmpty ? kakaoPlace.roadAddressName : kakaoPlace.addressName,
                        initialPhone: !kakaoPlace.phone.isEmpty ? kakaoPlace.phone : nil,
                        initialCategory: kakaoPlace.categoryGroupName
                    )
                } else {
                    // 일반 장소 또는 MKMapItem 정보로 채우기
                    AddRestaurantView(coordinate: selectedCoordinate, mapItem: selectedMapItem)
                }
            }
            .onChange(of: showingAddSheet) { _, isShowing in
                // 시트가 닫히면 kakaoPlaceForAdd 초기화
                if !isShowing {
                    kakaoPlaceForAdd = nil
                }
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
            .sheet(item: $selectedKakaoPlace) { place in
                // item 바인딩 사용: place가 nil이 아닐 때만 시트 표시 (타이밍 이슈 완전 해결)
                KakaoPlaceDetailView(place: place, onAddRestaurant: {
                    // 식당 추가 뷰에 전달할 정보 저장
                    kakaoPlaceForAdd = place
                    selectedCoordinate = place.coordinate
                    selectedMapItem = nil
                    selectedKakaoPlace = nil  // 카카오 상세 시트 닫기
                    // 시트 닫힘을 보장하기 위해 약간의 지연
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        showingAddSheet = true
                    }
                })
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .onAppear {
                logger.info("🚀 MapView appeared")
                logger.info("🚀 nearbyPOIs 초기 개수: \(nearbyPOIs.count)")
                locationDelegate.requestLocation()
            }
            .onChange(of: locationDelegate.locationUpdated) { _, _ in
                // 앱 시작 시 한 번만 현재 위치로 이동
                if !hasInitializedPosition, let location = locationDelegate.userLocation {
                    logger.info("지도 초기 위치 설정: 위도=\(location.latitude), 경도=\(location.longitude)")
                    // 사용자 위치를 중심으로 적절한 줌 레벨로 지도 이동
                    // span 값: 0.01은 약 1km 반경을 보여줍니다
                    position = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                    hasInitializedPosition = true
                }
            }
            .onChange(of: nearbyPOIs) { oldValue, newValue in
                logger.info("🔄 nearbyPOIs 배열 변경됨: \(oldValue.count) -> \(newValue.count)")
            }
            .alert("오류", isPresented: $showingError) {
                Button("확인", role: .cancel) {
                    errorMessage = nil
                }
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
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
                // 카카오 검색 결과 마커 (파란색 - 우선 표시)
                if isUsingKakaoSearch {
                    ForEach(kakaoSearchResults) { place in
                        Annotation(place.placeName, coordinate: place.coordinate) {
                            KakaoSearchResultPinView(place: place) {
                                logger.info("🎯 카카오 검색 결과 마커 탭됨: \(place.placeName)")
                                // item 바인딩 사용: place 설정만으로 자동으로 시트 열림
                                selectedKakaoPlace = place
                            }
                        }
                    }
                }

                // 카카오 주변 장소 마커 (기본색 - 검색 결과가 아닌 것들만)
                if isUsingKakaoSearch {
                    ForEach(kakaoPlaces) { place in
                        // 검색 결과에 포함되지 않은 것만 표시
                        if !kakaoSearchResults.contains(where: { $0.id == place.id }) {
                            Annotation(place.placeName, coordinate: place.coordinate) {
                                KakaoPlacePinView(place: place) {
                                    logger.info("🎯 카카오 장소 마커 탭됨: \(place.placeName)")
                                    // item 바인딩 사용: place 설정만으로 자동으로 시트 열림
                                    selectedKakaoPlace = place
                                }
                            }
                        }
                    }
                }

                // Apple Maps POI 마커
                if !isUsingKakaoSearch {
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

            // 애플맵으로 주변 POI 검색 (카카오는 검색창에서만 사용)
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
        // 주변 식당 보기 버튼
        Button {
            loadNearbyPlaces()
        } label: {
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 56, height: 56)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                Image(systemName: "map")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 16)
        .padding(.bottom, 16)
    }


    // MARK: - Helper Methods

    private func loadNearbyPlaces() {
        logger.info("🗺️ 주변 식당 보기 버튼 탭됨")

        // 현재 위치를 중심으로 검색 영역 생성
        let center = locationDelegate.userLocation ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        let region = MKCoordinateRegion(center: center, span: span)

        // 저장된 식당만 보기 모드를 끄고, 주변 POI 표시
        showSavedOnly = false

        // 카카오 검색 모드 활성화
        if !isUsingKakaoSearch {
            isUsingKakaoSearch = true
        }

        // 주변 장소 검색 강제 실행
        searchKakaoPlaces(in: region)
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

        if isUsingKakaoSearch {
            // 카카오 키워드 검색
            Task {
                do {
                    let result = try await kakaoService.searchByKeyword(
                        query: searchText,
                        coordinate: locationDelegate.userLocation,
                        radius: 20000,
                        size: 15
                    )

                    await MainActor.run {
                        // 카카오 검색 결과를 별도로 저장 (파란색으로 표시될 것)
                        kakaoSearchResults = result.documents
                        logger.info("✅ 카카오 키워드 검색 완료: \(result.documents.count)개 (파란색으로 표시)")

                        // 검색 결과가 없을 때 사용자에게 안내
                        if result.documents.isEmpty {
                            errorMessage = "'\(searchText)' 검색 결과가 없습니다.\n\n다른 키워드로 시도해보세요."
                            showingError = true
                            searchText = ""
                            return
                        }

                        // 첫 번째 결과로 지도 이동 및 줌인
                        if let firstPlace = result.documents.first {
                            // 애니메이션과 함께 이동 (줌인된 상태 유지)
                            withAnimation(.easeInOut(duration: 0.5)) {
                                position = .region(MKCoordinateRegion(
                                    center: firstPlace.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                ))
                            }

                            logger.info("📍 지도를 '\(firstPlace.placeName)'로 이동 및 줌인")

                            // 검색 텍스트 초기화
                            searchText = ""
                        }
                    }
                } catch {
                    logger.error("❌ 카카오 검색 실패: \(error.localizedDescription)")

                    await MainActor.run {
                        // 사용자에게 친절한 에러 메시지 표시
                        if let kakaoError = error as? KakaoSearchError {
                            switch kakaoError {
                            case .noAPIKey:
                                errorMessage = "카카오 API 키가 설정되지 않았습니다.\n\nInfo.plist에 KAKAO_REST_API_KEY를 추가해주세요."
                            case .httpError(401):
                                errorMessage = "카카오 API 인증 실패 (401)\n\nAPI 키가 올바른지 확인해주세요.\n카카오 개발자 콘솔에서 REST API 키를 확인하세요."
                            case .httpError(let code):
                                errorMessage = "카카오 API 오류 (HTTP \(code))\n\n잠시 후 다시 시도해주세요."
                            default:
                                errorMessage = "검색 중 오류가 발생했습니다.\n\n\(error.localizedDescription)"
                            }
                        } else {
                            errorMessage = "검색 중 오류가 발생했습니다.\n\n인터넷 연결을 확인해주세요."
                        }
                        showingError = true
                    }
                }
            }
        } else {
            // Apple Maps 검색
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchText

            let search = MKLocalSearch(request: request)
            search.start { [self] response, error in
                if let error = error {
                    logger.error("검색 실패: \(error.localizedDescription)")

                    // 사용자에게 에러 알림
                    errorMessage = "검색 실패\n\n\(error.localizedDescription)\n\n인터넷 연결을 확인하거나\n다른 키워드로 시도해주세요."
                    showingError = true
                    return
                }

                if let response = response {
                    searchResults = response.mapItems
                    logger.info("검색 결과: \(response.mapItems.count)개")
                    if !searchResults.isEmpty {
                        isSearchingManual = true

                        // 첫 번째 결과로 지도 이동
                        if let firstResult = response.mapItems.first {
                            // 애니메이션과 함께 이동 (줌인된 상태 유지)
                            withAnimation(.easeInOut(duration: 0.5)) {
                                position = .region(MKCoordinateRegion(
                                    center: firstResult.placemark.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                                ))
                            }

                            logger.info("📍 지도를 '\(firstResult.name ?? "검색 결과")'로 이동")
                        }
                    }
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

    // MARK: - Kakao Search Methods

    private func searchKakaoPlacesIfNeeded(in region: MKCoordinateRegion) {
        // 중복 검색 방지
        let regionKey = regionToKey(region)

        if isKakaoSearching {
            logger.info("⏸️ 이미 카카오 검색 중이므로 스킵")
            return
        }

        if searchedRegions.contains(regionKey) {
            logger.info("💾 캐시된 영역이므로 스킵: \(regionKey)")
            return
        }

        if let lastTime = lastSearchTime, Date().timeIntervalSince(lastTime) < 1.0 {
            logger.info("⏱️ 검색 간격이 너무 짧아서 스킵 (throttling)")
            return
        }

        lastSearchTime = Date()
        searchedRegions.insert(regionKey)
        searchKakaoPlaces(in: region)
    }

    private func searchKakaoPlaces(in region: MKCoordinateRegion) {
        isKakaoSearching = true
        logger.info("🔍 카카오 주변 장소 검색 시작")

        Task {
            do {
                // 반경 계산 (span을 미터로 변환)
                let radiusInMeters = Int(region.span.latitudeDelta * 111_000 / 2)  // 1도 ≈ 111km
                let clampedRadius = min(radiusInMeters, 20000)  // 최대 20km

                let places = try await kakaoService.searchNearbyPlaces(
                    coordinate: region.center,
                    radius: clampedRadius
                )

                await MainActor.run {
                    // 기존 장소와 새 장소를 합치고 중복 제거
                    let combined = kakaoPlaces + places
                    var uniquePlaces: [KakaoPlace] = []
                    var seenIDs = Set<String>()

                    for place in combined {
                        if !seenIDs.contains(place.id) {
                            seenIDs.insert(place.id)
                            uniquePlaces.append(place)
                        }
                    }

                    kakaoPlaces = uniquePlaces
                    logger.info("✅ 카카오 검색 완료: \(kakaoPlaces.count)개 장소")

                    // 자동 주변 검색에서는 지도를 강제로 이동하지 않음
                    // 사용자가 원하는 위치를 보고 있을 수 있으므로

                    isKakaoSearching = false
                }
            } catch {
                logger.error("❌ 카카오 검색 실패: \(error.localizedDescription)")
                await MainActor.run {
                    isKakaoSearching = false

                    // 자동 검색 실패 시에는 조용히 처리 (알림 없음)
                    // 사용자가 직접 검색한 경우에만 알림 표시
                    if let kakaoError = error as? KakaoSearchError {
                        switch kakaoError {
                        case .noAPIKey:
                            // API 키 누락은 한 번만 알림
                            errorMessage = "카카오 API 키가 설정되지 않았습니다.\n\n좌측 상단에서 Apple Maps로 전환하거나,\nInfo.plist에 KAKAO_REST_API_KEY를 추가해주세요."
                            showingError = true
                        case .httpError(401):
                            // 401 에러도 한 번만 알림
                            errorMessage = "카카오 API 인증 실패\n\nApple Maps 모드로 전환하거나,\nAPI 키를 확인해주세요."
                            showingError = true
                        default:
                            // 다른 에러는 로그만 (UI 알림 없음)
                            break
                        }
                    }
                }
            }
        }
    }

    // MARK: - Apple Maps Search Methods

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
                let combinedPOIs = nearbyPOIs + allResults
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

    private var iconName: String {
        if let category = mapItem.pointOfInterestCategory?.rawValue {
            return POICategoryMapper.toIcon(category)
        }
        return "fork.knife"
    }

    private var iconColor: Color {
        if let category = mapItem.pointOfInterestCategory?.rawValue {
            switch category {
            case "MKPOICategoryCafe":
                return .brown
            case "MKPOICategoryBakery":
                return .orange
            case "MKPOICategoryBar", "MKPOICategoryWinery", "MKPOICategoryBrewery":
                return .purple
            case "MKPOICategoryNightlife":
                return .indigo
            case "MKPOICategoryFastFood":
                return .red
            default:
                return .green
            }
        }
        return .green
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }
            .shadow(radius: 2)
        }
        .onTapGesture(perform: onTap)
    }
}

struct SearchResultPinView: View {
    let mapItem: MKMapItem
    let onTap: () -> Void
    @State private var showingOptions = false

    private var iconName: String {
        if let category = mapItem.pointOfInterestCategory?.rawValue {
            return POICategoryMapper.toIcon(category)
        }
        return "mappin"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(.blue)
                .frame(width: 32, height: 32)
            Image(systemName: iconName)
                .font(.system(size: 16))
                .foregroundStyle(.white)
        }
        .shadow(radius: 2)
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
                                Text(POICategoryMapper.toKorean(category))
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
                        Text(POICategoryMapper.toKorean(category))
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

// MARK: - Kakao Place Views

struct KakaoSearchResultPinView: View {
    let place: KakaoPlace
    let onTap: () -> Void

    private var iconName: String {
        if place.categoryGroupCode == "FD6" {
            return "fork.knife"
        } else if place.categoryGroupCode == "CE7" {
            return "cup.and.saucer.fill"
        }
        return "mappin.circle.fill"
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // 파란색 외곽 링 (검색 결과 강조)
                Circle()
                    .stroke(.blue, lineWidth: 3)
                    .frame(width: 40, height: 40)

                // 내부 원
                Circle()
                    .fill(.blue)
                    .frame(width: 36, height: 36)

                // 흰색 내부 원
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)

                // 아이콘
                Image(systemName: iconName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.blue)
            }
            .shadow(color: .blue.opacity(0.5), radius: 4)
        }
        .onTapGesture(perform: onTap)
    }
}

struct KakaoPlacePinView: View {
    let place: KakaoPlace
    let onTap: () -> Void

    private var iconName: String {
        if place.categoryGroupCode == "FD6" {
            return "fork.knife"
        } else if place.categoryGroupCode == "CE7" {
            return "cup.and.saucer.fill"
        }
        return "mappin.circle.fill"
    }

    private var iconColor: Color {
        if place.categoryGroupCode == "FD6" {
            return .orange
        } else if place.categoryGroupCode == "CE7" {
            return .brown
        }
        return .blue
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 32, height: 32)
                Image(systemName: iconName)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
            }
            .shadow(radius: 2)
        }
        .onTapGesture(perform: onTap)
    }
}

struct KakaoPlaceDetailView: View {
    let place: KakaoPlace
    let onAddRestaurant: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 장소 이름
                    VStack(alignment: .leading, spacing: 8) {
                        Text(place.placeName)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(place.categoryGroupName)
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal)

                    Divider()

                    // 카테고리 상세
                    VStack(alignment: .leading, spacing: 8) {
                        Label("카테고리", systemImage: "tag.fill")
                            .font(.headline)
                        Text(place.categoryName)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)

                    // 주소
                    if !place.roadAddressName.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("도로명 주소", systemImage: "location.fill")
                                .font(.headline)
                            Text(place.roadAddressName)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    if !place.addressName.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("지번 주소", systemImage: "mappin.circle")
                                .font(.headline)
                            Text(place.addressName)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                    }

                    // 전화번호
                    if !place.phone.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("전화번호", systemImage: "phone.fill")
                                .font(.headline)
                            Link(place.phone, destination: URL(string: "tel:\(place.phone.filter { !$0.isWhitespace && $0 != "-" })")!)
                                .font(.body)
                        }
                        .padding(.horizontal)
                    }

                    // 거리
                    if !place.distance.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("현재 위치에서", systemImage: "location.circle")
                                .font(.headline)
                            Text("\(place.distance)m")
                                .font(.body)
                                .foregroundStyle(.secondary)
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

// MARK: - Kakao API Models

struct KakaoSearchResponse: Codable {
    let documents: [KakaoPlace]
    let meta: KakaoMeta
}

struct KakaoPlace: Codable, Identifiable {
    let id: String
    let placeName: String
    let categoryName: String
    let categoryGroupCode: String
    let categoryGroupName: String
    let phone: String
    let addressName: String
    let roadAddressName: String
    let x: String  // longitude
    let y: String  // latitude
    let placeUrl: String
    let distance: String

    enum CodingKeys: String, CodingKey {
        case id
        case placeName = "place_name"
        case categoryName = "category_name"
        case categoryGroupCode = "category_group_code"
        case categoryGroupName = "category_group_name"
        case phone
        case addressName = "address_name"
        case roadAddressName = "road_address_name"
        case x
        case y
        case placeUrl = "place_url"
        case distance
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: Double(y) ?? 0,
            longitude: Double(x) ?? 0
        )
    }
}

struct KakaoMeta: Codable {
    let isEnd: Bool
    let pageableCount: Int
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case isEnd = "is_end"
        case pageableCount = "pageable_count"
        case totalCount = "total_count"
    }
}

// MARK: - Kakao Category

enum KakaoCategory: String, CaseIterable {
    case restaurant = "FD6"  // 음식점
    case cafe = "CE7"        // 카페

    var displayName: String {
        switch self {
        case .restaurant: return "음식점"
        case .cafe: return "카페"
        }
    }
}

// MARK: - Kakao Local Search Service

class KakaoLocalSearchService: ObservableObject {
    static let shared = KakaoLocalSearchService()

    private let logger = Logger(subsystem: "com.restaurantmap", category: "KakaoSearch")

    // ⚠️ 실제 사용 시 카카오 REST API 키를 여기에 입력하세요
    // https://developers.kakao.com/console/app 에서 발급받을 수 있습니다
    private var apiKey: String {
        // 🔧 디버깅: 여기에 직접 REST API 키를 입력해서 테스트해보세요
        // let key = "여기에_REST_API_키_직접_입력"  // 테스트용

        // Info.plist에서 읽어오기 (정식)
        let key = Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""

        self.logger.info("🔑 카카오 API 키 로드됨: \(key.prefix(4))***\(key.suffix(4)) (길이: \(key.count))")
        return key
    }

    private let baseURL = "https://dapi.kakao.com/v2/local"

    private init() {}

    // MARK: - 키워드 검색

    /// 키워드로 장소 검색
    func searchByKeyword(
        query: String,
        coordinate: CLLocationCoordinate2D? = nil,
        radius: Int = 5000,
        page: Int = 1,
        size: Int = 15
    ) async throws -> KakaoSearchResponse {
        guard !apiKey.isEmpty else {
            throw KakaoSearchError.noAPIKey
        }

        var urlString = "\(baseURL)/search/keyword.json?"
        urlString += "query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"

        if let coord = coordinate {
            urlString += "&x=\(coord.longitude)"
            urlString += "&y=\(coord.latitude)"
            urlString += "&radius=\(radius)"
        }

        urlString += "&page=\(page)"
        urlString += "&size=\(size)"
        urlString += "&sort=accuracy"

        guard let url = URL(string: urlString) else {
            throw KakaoSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")

        logger.info("🔍 카카오 검색 요청: \(query)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KakaoSearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("❌ 카카오 API 오류: \(httpResponse.statusCode)")
            throw KakaoSearchError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(KakaoSearchResponse.self, from: data)

        logger.info("✅ 카카오 검색 성공: \(result.documents.count)개 결과")

        return result
    }

    // MARK: - 카테고리 검색

    /// 카테고리로 장소 검색
    func searchByCategory(
        category: KakaoCategory,
        coordinate: CLLocationCoordinate2D,
        radius: Int = 5000,
        page: Int = 1,
        size: Int = 15
    ) async throws -> KakaoSearchResponse {
        guard !apiKey.isEmpty else {
            throw KakaoSearchError.noAPIKey
        }

        var urlString = "\(baseURL)/search/category.json?"
        urlString += "category_group_code=\(category.rawValue)"
        urlString += "&x=\(coordinate.longitude)"
        urlString += "&y=\(coordinate.latitude)"
        urlString += "&radius=\(radius)"
        urlString += "&page=\(page)"
        urlString += "&size=\(size)"
        urlString += "&sort=distance"

        guard let url = URL(string: urlString) else {
            throw KakaoSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let authHeader = "KakaoAK \(apiKey)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        logger.info("🔍 카카오 카테고리 검색: \(category.displayName)")
        logger.info("🔍 요청 URL: \(urlString)")
        logger.info("🔍 Authorization 헤더: KakaoAK \(self.apiKey.prefix(4))***\(self.apiKey.suffix(4))")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KakaoSearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("❌ 카카오 API 오류: \(httpResponse.statusCode)")
            logger.error("❌ 요청 URL: \(urlString)")
            logger.error("❌ Authorization: KakaoAK \(self.apiKey.prefix(4))***\(self.apiKey.suffix(4))")

            if let errorString = String(data: data, encoding: .utf8) {
                logger.error("에러 내용: \(errorString)")
            }

            throw KakaoSearchError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(KakaoSearchResponse.self, from: data)

        logger.info("✅ 카카오 카테고리 검색 성공: \(result.documents.count)개 결과")

        return result
    }

    // MARK: - 주변 음식점/카페 검색

    /// 주변 음식점과 카페를 한 번에 검색
    func searchNearbyPlaces(
        coordinate: CLLocationCoordinate2D,
        radius: Int = 5000
    ) async throws -> [KakaoPlace] {
        async let restaurants = searchByCategory(
            category: .restaurant,
            coordinate: coordinate,
            radius: radius,
            size: 15
        )

        async let cafes = searchByCategory(
            category: .cafe,
            coordinate: coordinate,
            radius: radius,
            size: 15
        )

        let (restaurantResult, cafeResult) = try await (restaurants, cafes)

        let allPlaces = restaurantResult.documents + cafeResult.documents

        var uniquePlaces: [KakaoPlace] = []
        var seenIDs = Set<String>()

        for place in allPlaces {
            if !seenIDs.contains(place.id) {
                seenIDs.insert(place.id)
                uniquePlaces.append(place)
            }
        }

        logger.info("✅ 주변 장소 검색 완료: \(uniquePlaces.count)개")

        return uniquePlaces
    }
}

// MARK: - Errors

enum KakaoSearchError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "카카오 REST API 키가 설정되지 않았습니다"
        case .invalidURL:
            return "잘못된 URL입니다"
        case .invalidResponse:
            return "잘못된 응답입니다"
        case .httpError(let code):
            return "HTTP 오류: \(code)"
        case .decodingError(let error):
            return "디코딩 오류: \(error.localizedDescription)"
        }
    }
}

#Preview {
    MapView(restaurants: [])
        .modelContainer(for: Restaurant.self, inMemory: true)
}
