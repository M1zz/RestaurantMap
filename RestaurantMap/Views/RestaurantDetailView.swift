import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import OSLog

struct RestaurantDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var restaurant: Restaurant
    @Query private var allRestaurants: [Restaurant]

    @State private var showingDeleteAlert = false
    @State private var showingAddVisit = false
    @State private var selectedVisit: Visit?
    @State private var isEditing = false
    @State private var showingTop6LimitAlert = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "RestaurantDetail")

    private var top6Count: Int {
        allRestaurants.filter { $0.isTop6 }.count
    }

    var sortedVisits: [Visit] {
        (restaurant.visits ?? []).sorted(by: { $0.visitDate > $1.visitDate })
    }

    var body: some View {
        NavigationStack {
            Form {
                // 총평 (평균 레이더 차트) - 가장 먼저 표시
                if !restaurant.averageIntensity.isEmpty {
                    Section {
                        VStack(spacing: 12) {
                            HStack {
                                Text("총평 (전체 방문 평균)")
                                    .font(.headline)
                                Spacer()
                                Text("\(restaurant.visitCount)회 방문")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            AverageRadarChartView(
                                intensityData: restaurant.averageIntensity,
                                appropriatenessData: restaurant.averageAppropriateness
                            )
                            .frame(height: 380)
                        }
                    } header: {
                        Text("이 식당은 전반적으로...")
                    }
                }

                Section("방문 통계") {
                    LabeledContent("총 방문 횟수", value: "\(restaurant.visitCount)회")

                    if let lastVisit = restaurant.lastVisitDate {
                        LabeledContent("최근 방문일") {
                            Text(lastVisit, format: .dateTime.year().month().day())
                        }
                    }

                    if restaurant.visitCount > 0 {
                        LabeledContent("평균 별점") {
                            HStack(spacing: 4) {
                                FractionalStarRatingView(rating: restaurant.averageRating, starSize: 14)
                                Text(String(format: "%.1f", restaurant.averageRating))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 리이오미슐랭 만족도 점수
                        LabeledContent("리이오미슐랭 점수") {
                            HStack(spacing: 4) {
                                Image(systemName: "medal.fill")
                                    .foregroundStyle(.green)
                                Text(String(format: "%.0f", restaurant.satisfactionScore))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                                Text("/ 100")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // 메뉴 목록
                Section {
                    NavigationLink(destination: MenuListView(restaurant: restaurant)) {
                        HStack {
                            Image(systemName: "fork.knife.circle.fill")
                                .foregroundStyle(.orange)
                            Text("메뉴 관리")
                            Spacer()
                            if let menuCount = restaurant.menus?.count, menuCount > 0 {
                                Text("\(menuCount)개")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("메뉴")
                } footer: {
                    Text("메뉴를 등록하면 방문 기록 추가 시 선택할 수 있습니다")
                }

                // 방문 기록 목록
                Section {
                    if sortedVisits.isEmpty {
                        Button {
                            showingAddVisit = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("첫 방문 기록 추가하기")
                                Spacer()
                            }
                            .foregroundStyle(.blue)
                        }
                    } else {
                        ForEach(sortedVisits) { visit in
                            VisitRowView(visit: visit)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    logger.info("🔵 [방문 기록 탭] Date: \(visit.visitDate.formatted()), HasProfile: \(visit.hasTasteProfile)")
                                    selectedVisit = visit
                                }
                        }
                        .onDelete(perform: deleteVisits)
                    }
                } header: {
                    HStack {
                        Text("방문 기록")
                        Spacer()
                        if !sortedVisits.isEmpty {
                            Button {
                                showingAddVisit = true
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                Section("기본 정보") {
                    if isEditing {
                        // 편집 모드
                        TextField("식당 이름", text: $restaurant.name)
                        TextField("주소", text: $restaurant.address)
                        TextField("카테고리", text: $restaurant.category)
                        TextField("전화번호", text: $restaurant.phoneNumber)
                            .keyboardType(.phonePad)

                        Picker("음식 종류", selection: Binding(
                            get: { restaurant.foodCategory },
                            set: { restaurant.foodCategory = $0 }
                        )) {
                            ForEach(FoodCategoryRepository.builtInCategories) { category in
                                Text(category.displayName).tag(category)
                            }
                        }
                        .pickerStyle(.menu)
                    } else {
                        // 보기 모드
                        LabeledContent("식당 이름", value: restaurant.name)
                        LabeledContent("주소", value: restaurant.address)
                        if !restaurant.category.isEmpty {
                            LabeledContent("카테고리", value: POICategoryMapper.toKorean(restaurant.category))
                        }
                        LabeledContent("음식 종류", value: restaurant.foodCategory.displayName)
                        if !restaurant.phoneNumber.isEmpty {
                            LabeledContent("전화번호") {
                                Link(restaurant.phoneNumber, destination: URL(string: "tel://\(restaurant.phoneNumber)")!)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }

                // 가본곳/가볼곳 구분
                Section {
                    if isEditing {
                        Picker("구분", selection: Binding(
                            get: { restaurant.listType },
                            set: { newValue in
                                restaurant.listType = newValue
                                // 가볼곳으로 변경하면 탑6 자동 해제
                                if newValue == .wishlist {
                                    restaurant.isTop6 = false
                                    restaurant.top6Rank = nil
                                }
                            }
                        )) {
                            ForEach([RestaurantListType.visited, RestaurantListType.wishlist], id: \.self) { type in
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.displayName)
                                }
                                .tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        LabeledContent("구분") {
                            HStack {
                                Image(systemName: restaurant.listType.icon)
                                Text(restaurant.listType.displayName)
                            }
                        }
                    }
                } header: {
                    Text("식당 구분")
                } footer: {
                    if isEditing && restaurant.listType == .wishlist {
                        Text("가볼 곳으로 설정된 식당은 탑6로 지정할 수 없습니다")
                    }
                }

                Section {
                    if isEditing && restaurant.listType == .visited {
                        Toggle("나의 최애 탑6", isOn: Binding(
                            get: { restaurant.isTop6 },
                            set: { newValue in
                                // 탑6를 켜려고 할 때
                                if newValue && !restaurant.isTop6 {
                                    // 현재 탑6가 6개 이상이면 경고
                                    if top6Count >= 6 {
                                        showingTop6LimitAlert = true
                                    } else {
                                        restaurant.isTop6 = true
                                    }
                                } else {
                                    // 탑6를 끄는 경우는 제한 없음
                                    restaurant.isTop6 = newValue
                                    if !newValue {
                                        restaurant.top6Rank = nil
                                    }
                                }
                            }
                        ))

                        if restaurant.isTop6 {
                            Picker("랭킹", selection: $restaurant.top6Rank) {
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
                    } else if restaurant.listType == .visited {
                        LabeledContent("탑6 여부") {
                            if restaurant.isTop6 {
                                HStack {
                                    Image(systemName: "star.fill")
                                        .foregroundStyle(.yellow)
                                    Text("\(restaurant.top6Rank ?? 0)위")
                                }
                            } else {
                                Text("아니오")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    if restaurant.listType == .visited || isEditing {
                        Text("탑6 설정")
                    }
                } footer: {
                    if isEditing && restaurant.listType == .visited {
                        Text("탑6는 최대 6개까지만 지정할 수 있습니다 (현재: \(top6Count)/6)")
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

                    Button {
                        openInAppleMaps()
                    } label: {
                        HStack {
                            Image(systemName: "map")
                                .foregroundStyle(.blue)
                            Text("Apple 지도에서 열기")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }

                    Button {
                        openInKakaoMap()
                    } label: {
                        HStack {
                            Text("🗺️")
                            Text("카카오맵에서 열기")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }

                    Button {
                        openInNaverMap()
                    } label: {
                        HStack {
                            Text("🧭")
                            Text("네이버맵에서 열기")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }

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
                Text("'\(restaurant.name)'과(와) 모든 방문 기록을 삭제하시겠습니까?")
            }
            .alert("탑6 제한", isPresented: $showingTop6LimitAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text("탑6는 최대 6개까지만 지정할 수 있습니다. 다른 식당의 탑6를 해제한 후 다시 시도해주세요.")
            }
            .sheet(isPresented: $showingAddVisit) {
                AddVisitView(restaurant: restaurant)
            }
            .sheet(item: $selectedVisit) { visit in
                VisitDetailViewWrapper(visit: visit)
            }
        }
    }

    private func deleteRestaurant() {
        modelContext.delete(restaurant)
        dismiss()
    }

    private func deleteVisits(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sortedVisits[index])
        }
    }

    private func openInAppleMaps() {
        let coordinate = CLLocationCoordinate2D(
            latitude: restaurant.latitude,
            longitude: restaurant.longitude
        )
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = restaurant.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func openInKakaoMap() {
        let lat = restaurant.latitude
        let lng = restaurant.longitude
        let name = restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? restaurant.name

        // 카카오맵 URL Scheme
        let kakaoMapURL = "kakaomap://look?p=\(lat),\(lng)"

        if let url = URL(string: kakaoMapURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 카카오맵 앱이 없으면 웹으로 열기
            let webURL = "https://map.kakao.com/link/map/\(name),\(lat),\(lng)"
            if let url = URL(string: webURL) {
                UIApplication.shared.open(url)
            }
        }
    }

    private func openInNaverMap() {
        let lat = restaurant.latitude
        let lng = restaurant.longitude
        let name = restaurant.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? restaurant.name

        // 네이버맵 URL Scheme
        let naverMapURL = "nmap://place?lat=\(lat)&lng=\(lng)&name=\(name)&appname=com.restaurantmap"

        if let url = URL(string: naverMapURL), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 네이버맵 앱이 없으면 웹으로 열기
            let webURL = "https://map.naver.com/v5/search/\(name)"
            if let url = URL(string: webURL) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// MARK: - Visit Row View
struct VisitRowView: View {
    let visit: Visit

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(visit.visitDate, format: .dateTime.year().month().day())
                    .font(.headline)

                Spacer()

                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < visit.rating ? "star.fill" : "star")
                            .foregroundStyle(index < visit.rating ? .yellow : .gray)
                            .font(.system(size: 12))
                    }
                }
            }

            if !visit.displayMenuName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                    Text(visit.displayMenuName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if visit.menu?.isSignature == true {
                        Image(systemName: "crown.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }
                }
                .foregroundStyle(.orange)
            }

            if !visit.notes.isEmpty {
                Text(visit.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if visit.hasTasteProfile {
                HStack(spacing: 4) {
                    Image(systemName: "chart.pie.fill")
                        .font(.caption2)
                    Text("맛 평가됨")
                        .font(.caption2)
                }
                .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Average Radar Chart View
struct AverageRadarChartView: View {
    let intensityData: [(String, Double)]
    let appropriatenessData: [(String, Double)]

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(.blue, lineWidth: 2)
                        .frame(width: 12, height: 12)
                    Text("맛의 형태")
                        .font(.caption)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.green.opacity(0.6))
                        .frame(width: 12, height: 12)
                    Text("만족도")
                        .font(.caption)
                }
            }

            CalibratedRadarChartForVisit(
                intensityData: intensityData,
                appropriatenessData: appropriatenessData
            )
        }
    }
}

// MARK: - Overlapped Radar Chart
struct OverlappedRadarChart: View {
    let intensityData: [(String, Double)]
    let appropriatenessData: [(String, Double)]
    let maxValue: Double = 10.0

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 50

            ZStack {
                // 배경 그리드
                ForEach(1...3, id: \.self) { level in
                    hexagonPath(center: center, radius: radius * Double(level) / 3, sides: 6)
                        .stroke(.gray.opacity(0.2), lineWidth: 1)
                }

                // 적절함 차트 (노란색)
                if !appropriatenessData.isEmpty {
                    hexagonDataPath(center: center, radius: radius, data: appropriatenessData)
                        .fill(.yellow.opacity(0.3))
                    hexagonDataPath(center: center, radius: radius, data: appropriatenessData)
                        .stroke(.yellow.opacity(0.8), lineWidth: 2)
                }

                // 맛 강도 차트 (파란색)
                if !intensityData.isEmpty {
                    hexagonDataPath(center: center, radius: radius, data: intensityData)
                        .fill(.blue.opacity(0.2))
                    hexagonDataPath(center: center, radius: radius, data: intensityData)
                        .stroke(.blue, lineWidth: 2)
                }

                // 축 선
                ForEach(0..<6, id: \.self) { index in
                    let angle = angleForIndex(index, total: 6)
                    let endPoint = pointOnCircle(center: center, radius: radius, angle: angle)

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: endPoint)
                    }
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                }

                // 라벨
                ForEach(0..<intensityData.count, id: \.self) { index in
                    let angle = angleForIndex(index, total: 6)
                    let labelRadius = radius + 30
                    let point = pointOnCircle(center: center, radius: labelRadius, angle: angle)

                    Text(intensityData[index].0)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .position(point)
                }
            }
        }
    }

    private func hexagonPath(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
        var path = Path()
        for i in 0..<sides {
            let angle = angleForIndex(i, total: sides)
            let point = pointOnCircle(center: center, radius: radius, angle: angle)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func hexagonDataPath(center: CGPoint, radius: CGFloat, data: [(String, Double)]) -> Path {
        var path = Path()
        for i in 0..<data.count {
            let angle = angleForIndex(i, total: data.count)
            let value = data[i].1
            let distance = radius * (value / maxValue)
            let point = pointOnCircle(center: center, radius: distance, angle: angle)

            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func angleForIndex(_ index: Int, total: Int) -> Double {
        let angleStep = 2 * .pi / Double(total)
        return angleStep * Double(index) - .pi / 2
    }

    private func pointOnCircle(center: CGPoint, radius: CGFloat, angle: Double) -> CGPoint {
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, Visit.self, configurations: config)

    let restaurant = Restaurant(
        name: "샘플 식당",
        address: "서울시 중구 태평로 1가",
        latitude: 37.5665,
        longitude: 126.9780,
        category: "한식"
    )
    container.mainContext.insert(restaurant)

    return RestaurantDetailView(restaurant: restaurant)
        .modelContainer(container)
}
