import SwiftUI
import LeeoKit
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

    /// 화면에 보여 줄 이름 — 현재 언어로 번역한다. `toKorean` 은 저장값(식당 category)이라 바꾸지 않는다.
    /// MapKit raw 값과 저장된 한국어 이름을 모두 받는다. 모르는 값(카카오·사용자 입력)은 그대로 둔다.
    static func displayName(_ rawValue: String) -> String {
        switch toKorean(rawValue) {
        case "카페": return String(localized: "카페")
        case "레스토랑": return String(localized: "레스토랑")
        case "베이커리": return String(localized: "베이커리")
        case "브루어리": return String(localized: "브루어리")
        case "나이트라이프": return String(localized: "나이트라이프")
        case "와이너리": return String(localized: "와이너리")
        case "식품마켓": return String(localized: "식품마켓")
        case "바": return String(localized: "바")
        case "패스트푸드": return String(localized: "패스트푸드")
        default: return toKorean(rawValue)
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

// MARK: - 지도에 넘겨도 되는 좌표 · 영역

extension CLLocationCoordinate2D {
    /// 지도에 찍어도 되는 좌표인가. 위도 ±90 · 경도 ±180 밖이거나 NaN 인 좌표를 MapKit 에 넘기면
    /// "Invalid Coordinate / Invalid Region" 예외로 앱이 죽는다 (가져온 파일 · 되살린 백업 · 남이 올린 후기에서 들어올 수 있다).
    var isMappable: Bool {
        latitude.isFinite && longitude.isFinite && CLLocationCoordinate2DIsValid(self)
    }
}

extension MKCoordinateRegion {
    /// 검색 · 카메라에 써도 되는 영역으로 다듬는다. 쓸 수 없으면 nil.
    /// 지도를 지구가 다 보이게 줄였을 때 넘어오는 영역은 폭이 180°/360° 를 넘거나 NaN 일 수 있다.
    var mappable: MKCoordinateRegion? {
        guard center.isMappable, span.latitudeDelta.isFinite, span.longitudeDelta.isFinite,
              span.latitudeDelta > 0, span.longitudeDelta > 0 else { return nil }
        return MKCoordinateRegion(center: center,
                                  span: MKCoordinateSpan(latitudeDelta: min(span.latitudeDelta, 180),
                                                         longitudeDelta: min(span.longitudeDelta, 360)))
    }
}

struct MapView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]
    /// 나의 미슐랭 순위 (→ Regular.swift). 부르는 쪽이 한 번 세어 넘긴다.
    var ranks: [PersistentIdentifier: Int] = [:]

    @StateObject private var locationDelegate = LocationDelegate()
    @State private var position: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var hasInitializedPosition = false
    @State private var showingAddSheet = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedRestaurant: Restaurant?
    @Environment(\.foldLayout) private var fold
    @Environment(FoldRestaurantPick.self) private var foldPick: FoldRestaurantPick?
    @State private var showingDetail = false
    @State private var temporaryPin: CLLocationCoordinate2D?
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearchingManual = false
    @State private var selectedMapItem: MKMapItem?
    @State private var selectedPOI: MKMapItem?
    @State private var showingPOIDetail = false
    /// 지도에서 고른 것: 애플 지도가 그려 둔 식당 · 카페 표시(MapFeature)를 누르면 여기로 온다.
    @State private var mapSelection: MapSelection<MKMapItem>?
    @State private var showSavedOnly = false
    @State private var kakaoPlaces: [KakaoPlace] = []
    @State private var kakaoSearchResults: [KakaoPlace] = []  // 검색 결과 (파란색으로 표시)
    @State private var mapRegion: MKCoordinateRegion?  // 지금 보고 있는 지도 영역

    /// 한국 안을 보고 있으면 카카오, 밖이면 Apple 지도로 찾는다.
    /// 지도를 아직 못 봤으면 내 위치, 그것도 없으면 기기 지역으로 정한다.
    private var isUsingKakaoSearch: Bool {
        if let center = mapRegion?.center ?? locationDelegate.userLocation {
            return KakaoLocalSearchService.covers(center)
        }
        return Locale.current.region == .southKorea
    }
    /// 카카오 주변 장소 핀 — 지도에 찍을 수 있고, 검색 결과(파란 핀)와 겹치지 않는 것만.
    private var nearbyKakaoPins: [KakaoPlace] {
        let searched = Set(kakaoSearchResults.map(\.id))
        return kakaoPlaces.filter { $0.coordinate.isMappable && !searched.contains($0.id) }
    }
    /// 지도에 한 번에 세우는 저장한 식당 핀의 최대 수.
    /// 지도는 핀을 맞추는 일을 메인 스레드에서 한다. 구글 지도에서 한꺼번에 옮겨 오면 수백 개가 되는데,
    /// 그만큼 세우면 지도를 움직일 때마다 멈추고 앱을 닫을 때 시간 안에 못 끝나 시스템이 앱을 죽인다(0x8BADF00D).
    static let savedPinLimit = 150

    /// 지도에 세울 저장한 식당. 지워진 식당 · 찍을 수 없는 좌표는 빼고(목록에서는 그대로 보인다),
    /// 한도를 넘으면 지금 보는 곳(없으면 내 위치)에서 가까운 것부터 한도만큼.
    private var savedPins: [Restaurant] {
        Self.pins(of: restaurants, near: mapRegion?.center ?? locationDelegate.userLocation)
    }

    static func pins(of restaurants: [Restaurant], near center: CLLocationCoordinate2D?, limit: Int = savedPinLimit) -> [Restaurant] {
        let pins = restaurants.filter { !$0.isGone && $0.coordinate.isMappable }
        guard pins.count > limit else { return pins }
        guard let center, center.isMappable else { return Array(pins.prefix(limit)) }
        // 가까운 순 — 경도 차는 위도에 따라 줄어드는 만큼 줄여 잰다 (정확한 거리까지는 필요 없다)
        let shrink = cos(center.latitude * .pi / 180)
        func distance(_ c: CLLocationCoordinate2D) -> Double {
            let dLat = c.latitude - center.latitude
            var dLon = abs(c.longitude - center.longitude)
            if dLon > 180 { dLon = 360 - dLon }
            return dLat * dLat + (dLon * shrink) * (dLon * shrink)
        }
        return pins.map { ($0, distance($0.coordinate)) }
            .sorted { $0.1 < $1.1 }
            .prefix(limit)
            .map(\.0)
    }
    @State private var isKakaoSearching = false
    @State private var selectedKakaoPlace: KakaoPlace?
    @State private var kakaoPlaceForAdd: KakaoPlace?  // AddRestaurantView에 전달할 장소 정보
    @State private var showingKakaoDetail = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showSettings = false  // 설정 화면 표시 여부
    @Environment(\.accessibilityReduceMotion) private var reduceMotion  // 지도 이동을 미끄러지지 않고 바로

    @StateObject private var kakaoService = KakaoLocalSearchService.shared
    private let logger = Logger(subsystem: "com.restaurantmap", category: "MapView")
    
    /// 식당 자세히: 아이폰 듀오를 폈으면 결과 쪽 판에, 아니면 지금처럼 시트로.
    private func openDetail(_ restaurant: Restaurant) {
        guard !restaurant.isGone else { return }
        if foldPick?.show(restaurant, in: fold) == true { return }
        selectedRestaurant = restaurant
        showingDetail = true
    }

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
                    .accessibilityLabel(Text("더 보기"))
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
                // 시트 안에서 식당을 지우면 내려가는 동안에도 이 자리가 다시 그려진다 — 지워진 식당은 넘기지 않는다
                if let restaurant = selectedRestaurant, !restaurant.isGone {
                    RestaurantDetailView(restaurant: restaurant)
                }
            }
            .onChange(of: showingDetail) { _, isShowing in
                // 닫힌 뒤에는 쥐고 있지 않는다 (지워진 식당을 계속 가리키지 않게). 내려가는 동안 빈 화면이 되지 않게 조금 뒤에.
                if !isShowing {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if !showingDetail { selectedRestaurant = nil }
                    }
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
                locationDelegate.requestLocation()
            }
            .onChange(of: locationDelegate.locationUpdated) { _, _ in
                // 앱 시작 시 한 번만 현재 위치로 이동
                if !hasInitializedPosition, let location = locationDelegate.userLocation, location.isMappable {
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
                    ForEach(kakaoSearchResults.filter(\.coordinate.isMappable)) { place in
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
                    ForEach(nearbyKakaoPins) { place in
                        Annotation(place.placeName, coordinate: place.coordinate) {
                            KakaoPlacePinView(place: place) {
                                logger.info("🎯 카카오 장소 마커 탭됨: \(place.placeName)")
                                // item 바인딩 사용: place 설정만으로 자동으로 시트 열림
                                selectedKakaoPlace = place
                            }
                        }
                    }
                }

                ForEach(searchResults, id: \.self) { item in
                    if let coord = item.placemark.location?.coordinate, coord.isMappable {
                        Annotation(item.name ?? String(localized: "장소"), coordinate: coord) {
                            SearchResultPinView(mapItem: item) {
                                selectSearchResult(item)
                            }
                        }
                    }
                }
            }

            ForEach(savedPins) { restaurant in
                Annotation(restaurant.name, coordinate: restaurant.coordinate) {
                    RestaurantPinView(restaurant: restaurant, rank: ranks[restaurant.persistentModelID]) {
                        openDetail(restaurant)
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

            // 지구가 다 보이게 줄였을 때의 영역은 검색에 넘길 수 없다 — 다듬어서 쓰고, 안 되면 이번은 건너뛴다
            guard let region = context.region.mappable else { return }
            mapRegion = region
        }
        // 지도에 그려진 식당 · 카페 이름만 누를 수 있게 (나라 · 산 · 강 이름은 빼고)
        .mapFeatureSelectionDisabled { $0.kind != .pointOfInterest }
        .onChange(of: mapSelection) { _, newValue in
            guard let newValue else { return }
            // 같은 곳을 다시 눌러도 열리도록 고른 것은 바로 놓는다
            mapSelection = nil
            if let item = newValue.value {
                showPOIDetail(item)
            } else if let feature = newValue.feature {
                openMapFeature(feature)
            }
        }
    }

    private func showPOIDetail(_ item: MKMapItem) {
        logger.info("POI 상세 시트 표시: \(item.name ?? "이름 없음")")
        selectedPOI = item
        showingPOIDetail = true
    }

    /// 지도에 그려진 장소 표시를 눌렀을 때: 이름 · 주소 · 전화번호를 애플 지도에서 받아 장소 정보를 연다.
    /// 받지 못하면 표시에 적힌 이름과 좌표만으로 연다 — 나머지는 식당 추가에서 직접 적는다.
    private func openMapFeature(_ feature: MapFeature) {
        logger.info("지도 장소 표시 탭됨: \(feature.title ?? "이름 없음")")
        Task {
            let item: MKMapItem
            if let fetched = try? await MKMapItemRequest(feature: feature).mapItem {
                item = fetched
            } else {
                guard feature.coordinate.isMappable else { return }
                item = MKMapItem(placemark: MKPlacemark(coordinate: feature.coordinate))
                item.name = feature.title
                item.pointOfInterestCategory = feature.pointOfInterestCategory
            }
            showPOIDetail(item)
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
        .accessibilityLabel(Text("주변 식당 보기"))
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

        // 한국이면 카카오로 찾아 핀을 세운다. 밖에서는 지도가 그리는 식당 · 카페 표시가 곧 주변 장소다 — 그리로 옮긴다.
        if KakaoLocalSearchService.covers(center) {
            searchKakaoPlaces(in: region)
        } else {
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
                position = .region(region)
            }
        }
    }

    private func addRestaurantAtCurrentLocation() {
        // 현재 위치를 사용하거나, 없으면 기본 위치 사용
        let coordinate = locationDelegate.userLocation ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        selectedCoordinate = coordinate
        selectedMapItem = nil
        logger.info("현재 위치에 식당 추가 시작: 위도=\(coordinate.latitude), 경도=\(coordinate.longitude)")
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
                            errorMessage = String(localized: "'\(searchText)' 검색 결과가 없습니다.\n\n다른 키워드로 시도해보세요.")
                            showingError = true
                            searchText = ""
                            return
                        }

                        // 첫 번째 결과로 지도 이동 및 줌인
                        if let firstPlace = result.documents.first(where: \.coordinate.isMappable) {
                            // 애니메이션과 함께 이동 (줌인된 상태 유지)
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
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
                                errorMessage = String(localized: "카카오 API 키가 설정되지 않았습니다.\n\nInfo.plist에 KAKAO_REST_API_KEY를 추가해주세요.")
                            case .httpError(401):
                                errorMessage = String(localized: "카카오 API 인증 실패 (401)\n\nAPI 키가 올바른지 확인해주세요.\n카카오 개발자 콘솔에서 REST API 키를 확인하세요.")
                            case .httpError(let code):
                                errorMessage = String(localized: "카카오 API 오류 (HTTP \(code))\n\n잠시 후 다시 시도해주세요.")
                            default:
                                errorMessage = String(localized: "검색 중 오류가 발생했습니다.\n\n\(error.localizedDescription)")
                            }
                        } else {
                            errorMessage = String(localized: "검색 중 오류가 발생했습니다.\n\n인터넷 연결을 확인해주세요.")
                        }
                        showingError = true
                    }
                }
            }
        } else {
            // Apple Maps 검색
            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = searchText
            // 지금 보는 지도 근처부터 찾는다
            if let mapRegion { request.region = mapRegion }

            let search = MKLocalSearch(request: request)
            search.start { [self] response, error in
                if let error = error {
                    logger.error("검색 실패: \(error.localizedDescription)")

                    // 사용자에게 에러 알림
                    errorMessage = String(localized: "검색 실패\n\n\(error.localizedDescription)\n\n인터넷 연결을 확인하거나\n다른 키워드로 시도해주세요.")
                    showingError = true
                    return
                }

                if let response = response {
                    searchResults = response.mapItems
                    logger.info("검색 결과: \(response.mapItems.count)개")
                    if searchResults.isEmpty {
                        // 결과가 없으면 아무 일도 없던 것처럼 보였다 — 카카오 검색과 같은 말로 알린다
                        errorMessage = String(localized: "'\(searchText)' 검색 결과가 없습니다.\n\n다른 키워드로 시도해보세요.")
                        showingError = true
                    } else {
                        isSearchingManual = true

                        // 첫 번째 결과로 지도 이동
                        if let firstResult = response.mapItems.first(where: \.placemark.coordinate.isMappable) {
                            // 애니메이션과 함께 이동 (줌인된 상태 유지)
                            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.5)) {
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

    private func selectSearchResult(_ mapItem: MKMapItem) {
        logger.info("검색 결과 선택: \(mapItem.name ?? "이름 없음")")

        // 좌표를 쓸 수 없는 결과면 지도는 그대로 두고 추가 화면만 연다 (추가 화면이 기본 위치에서 시작한다)
        let coordinate = mapItem.placemark.coordinate
        if coordinate.isMappable {
            selectedCoordinate = coordinate
            temporaryPin = coordinate

            // 선택한 위치로 지도 이동
            position = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))
        } else {
            selectedCoordinate = nil
            temporaryPin = nil
        }
        selectedMapItem = mapItem

        isSearchingManual = false
        searchText = ""
        showingAddSheet = true
    }

    // MARK: - Kakao Search Methods

    private func searchKakaoPlaces(in region: MKCoordinateRegion) {
        isKakaoSearching = true
        logger.info("🔍 카카오 주변 장소 검색 시작")

        Task {
            do {
                // 반경 계산 (span을 미터로 변환)
                // 유한한 값으로 먼저 자른 뒤에 Int 로 바꾼다 (NaN · 무한대를 Int 로 바꾸면 죽는다). 최대 20km
                let meters = region.span.latitudeDelta * 111_000 / 2  // 1도 ≈ 111km
                let clampedRadius = meters.isFinite ? Int(min(max(meters, 1), 20000)) : 20000

                let places = try await kakaoService.searchNearbyPlaces(
                    coordinate: region.center,
                    radius: clampedRadius
                )

                await MainActor.run {
                    // 누른 자리의 주변 장소로 바꾼다. 예전에는 누를 때마다 쌓아 핀이 끝없이 늘었고,
                    // 지도는 화면이 바뀔 때마다 그 핀을 모두 다시 맞춰 보느라 메인 스레드를 붙잡았다(0x8BADF00D).
                    kakaoPlaces = places
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
                            errorMessage = String(localized: "카카오 API 키가 설정되지 않았습니다.\n\n좌측 상단에서 Apple Maps로 전환하거나,\nInfo.plist에 KAKAO_REST_API_KEY를 추가해주세요.")
                            showingError = true
                        case .httpError(401):
                            // 401 에러도 한 번만 알림
                            errorMessage = String(localized: "카카오 API 인증 실패\n\nApple Maps 모드로 전환하거나,\nAPI 키를 확인해주세요.")
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

}

// MARK: - Supporting Views

struct TemporaryPinView: View {
    var body: some View {
        Image(systemName: "mappin.circle.fill")
            .font(.system(size: 40))
            .foregroundStyle(.orange)
            .shadow(radius: 3)
            .accessibilityHidden(true)
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
        .accessibleTap {
            showingOptions = true
        }
        .accessibilityLabel(Text(verbatim: mapItem.name ?? ""))
        .accessibilityValue(Text("검색 결과"))
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
    /// 나의 미슐랭 순위 (→ Regular.swift). 순위에 없으면 nil.
    var rank: Int? = nil
    let onTap: () -> Void
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        // 지워진 식당의 핀이 한 박자 남아 다시 그려져도 모델을 읽지 않는다
        if !restaurant.isGone { pin }
    }

    private var pin: some View {
        // 얼마나 자주 갔는지가 한눈에 보이는 도장 (→ VisitStamp.swift). 지도 위라 흰 바탕과 그림자를 깐다.
        VisitStamp(restaurant: restaurant, rank: rank, size: 40)
            .background(.background, in: Circle())
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .shadow(radius: 2)
        // 색을 구별하기 어려우면 저장한 식당 핀에 책갈피를 달아 검색 결과(파란 핀)와 모양으로도 가른다
        .overlay(alignment: .topTrailing) {
            if differentiateWithoutColor && rank == nil {
                Image(systemName: "bookmark.fill")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .padding(3)
                    .background(.black.opacity(0.7), in: Circle())
                    .offset(x: 6, y: -6)
            }
        }
        .accessibleTap(onTap)
        .accessibilityLabel(Text(verbatim: restaurant.name))
        .accessibilityValue(rank.map { Text("나의 미슐랭 \($0)위") } ?? Text("저장한 식당"))
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
                            Text(item.name ?? String(localized: "이름 없음"))
                                .font(.headline)
                                .foregroundStyle(.primary)

                            if let address = item.placemark.title {
                                Text(address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            if let category = item.pointOfInterestCategory?.rawValue {
                                Text(POICategoryMapper.displayName(category))
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
                    .accessibilityLabel(Text("닫기"))
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
                    Text(mapItem.name ?? String(localized: "이름 없음"))
                        .font(.title2)
                        .fontWeight(.bold)

                    if let category = mapItem.pointOfInterestCategory?.rawValue {
                        Text(POICategoryMapper.displayName(category))
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
                        // 번호로 바꿀 수 없는 문자열이면 누를 수 없는 글자로 보인다 (강제로 풀지 않는다)
                        if let call = URL(string: "tel:\(phone.filter { $0.isASCII && ($0.isNumber || $0 == "+") })") {
                            Link(phone, destination: call)
                                .font(.body)
                        } else {
                            Text(phone)
                                .font(.body)
                        }
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

                // 한 번에 가볼 곳에 저장 — 나머지는 나중에 식당 자세히에서 적는다
                QuickSaveButton(
                    name: mapItem.name ?? "",
                    address: mapItem.restaurantAddress,
                    phone: mapItem.phoneNumber ?? "",
                    category: mapItem.pointOfInterestCategory.map { POICategoryMapper.toKorean($0.rawValue) } ?? "",
                    categoryHints: [mapItem.pointOfInterestCategory?.rawValue ?? "", mapItem.name ?? ""],
                    coordinate: mapItem.placemark.coordinate
                )
                .padding(.horizontal)

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
        .accessibleTap(onTap)
        .accessibilityLabel(Text(verbatim: place.placeName))
        .accessibilityValue(Text("검색 결과"))
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
        .accessibleTap(onTap)
        .accessibilityLabel(Text(verbatim: place.placeName))
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
                            if let call = URL(string: "tel:\(place.phone.filter { $0.isASCII && ($0.isNumber || $0 == "+") })") {
                                Link(place.phone, destination: call)
                                    .font(.body)
                            } else {
                                Text(place.phone)
                                    .font(.body)
                            }
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

                    // 한 번에 가볼 곳에 저장 — 나머지는 나중에 식당 자세히에서 적는다
                    QuickSaveButton(
                        name: place.placeName,
                        address: !place.roadAddressName.isEmpty ? place.roadAddressName : place.addressName,
                        phone: place.phone,
                        category: place.categoryGroupName,
                        categoryHints: [place.categoryName, place.placeName],
                        coordinate: place.coordinate
                    )
                    .padding(.horizontal)

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
                    .accessibilityLabel(Text("닫기"))
                }
            }
        }
    }
}

// MARK: - 지도에서 바로 저장

extension MKMapItem {
    /// 식당 주소로 쓸 글: 길 이름 · 번지 · 동네, 없으면 지도가 주는 한 줄 주소.
    var restaurantAddress: String {
        let parts = [placemark.thoroughfare, placemark.subThoroughfare, placemark.locality].compactMap { $0 }
        return parts.isEmpty ? (placemark.title ?? "") : parts.joined(separator: " ")
    }
}

/// 장소 정보에서 한 번 눌러 '가볼 곳' 에 저장한다. 이름 · 주소 · 전화번호 · 음식 종류는 장소에서 채우고,
/// 별점 · 메뉴 · 메모는 나중에 식당 자세히에서 적는다. 이미 저장한 곳(이름이 같고 100m 안)이면 저장했다고만 보인다.
struct QuickSaveButton: View {
    let name: String
    let address: String
    let phone: String
    let category: String
    let categoryHints: [String]
    let coordinate: CLLocationCoordinate2D

    @Environment(\.modelContext) private var modelContext
    @Query private var savedRestaurants: [Restaurant]
    @State private var purchases = Purchases.shared
    @State private var paywallFeature: RestaurantFeature?
    @State private var pendingSave = false
    @State private var justSaved = false
    @State private var saveFailed = false

    private var alreadySaved: Bool {
        guard coordinate.isMappable else { return false }
        let here = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return savedRestaurants.contains { restaurant in
            !restaurant.isGone && restaurant.name == name && restaurant.coordinate.isMappable
                && CLLocation(latitude: restaurant.coordinate.latitude, longitude: restaurant.coordinate.longitude)
                    .distance(from: here) < 100
        }
    }

    var body: some View {
        Group {
            if justSaved || alreadySaved {
                Label(justSaved ? "가볼 곳에 저장했어요" : "이미 저장한 식당이에요", systemImage: "checkmark.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundStyle(.green)
                    .background(.green.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Button {
                    if purchases.canAddRestaurant(having: savedRestaurants.count) {
                        save()
                    } else {
                        paywallFeature = .restaurants
                    }
                } label: {
                    Label("가볼 곳에 저장", systemImage: "bookmark.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.orange)
                        .background(.orange.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(name.isEmpty || !coordinate.isMappable)
            }
        }
        // Vision Pro 에는 손끝 진동이 없다 (visionOS 2 에는 이 API 도 없다)
        #if !os(visionOS)
        .sensoryFeedback(.success, trigger: justSaved)
        #endif
        .saveFailureAlert($saveFailed)
        .sheet(item: $paywallFeature, onDismiss: {
            // Plus 를 열고 돌아왔으면 하던 저장을 마친다
            if pendingSave, purchases.canAddRestaurant(having: savedRestaurants.count) { save() }
            pendingSave = false
        }) { feature in
            PaywallView(highlight: feature)
                .onAppear { pendingSave = feature == .restaurants }
        }
    }

    private func save() {
        guard !justSaved, !alreadySaved else { return }
        let restaurant = Restaurant(
            name: name,
            address: address,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            category: category,
            phoneNumber: phone,
            categoryIcon: POICategoryMapper.toIcon(category),
            foodCategory: FoodCategoryRepository.guess(from: categoryHints + [category]),
            listType: .wishlist
        )
        modelContext.insert(restaurant)
        do {
            try modelContext.save()
            justSaved = true
        } catch {
            // 이번에 넣은 것만 걷어 낸다 (rollback 은 다른 화면의 고침까지 버린다)
            modelContext.delete(restaurant)
            saveFailed = true
        }
    }
}

// MARK: - LocationDelegate
class LocationDelegate: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var userLocation: CLLocationCoordinate2D?
    @Published var locationUpdated = false
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined

    private let logger = Logger(subsystem: "com.restaurantmap", category: "Location")

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = manager.authorizationStatus
        logger.info("LocationDelegate 초기화됨")
    }

    func requestLocation() {
        #if DEBUG
        if ScreenshotScene.current != nil { return }  // 스크린샷 장면에는 권한 창이 없어야 한다
        #endif
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
        #if DEBUG
        if ScreenshotScene.current != nil { return }  // 스크린샷 장면에는 권한 창이 없어야 한다
        #endif
        let status = manager.authorizationStatus
        authorizationStatus = status
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
