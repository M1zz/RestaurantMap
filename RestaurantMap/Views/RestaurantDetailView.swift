import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import OSLog

struct RestaurantDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var restaurant: Restaurant

    @State private var showingDeleteAlert = false
    @State private var showingAddVisit = false
    @State private var selectedVisit: Visit?
    @State private var isEditing = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "RestaurantDetail")

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
                                    .foregroundStyle(.orange)
                                Text(String(format: "%.0f", restaurant.satisfactionScore))
                                    .font(.headline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.orange)
                                Text("/ 100")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
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
                            ForEach(FoodCategory.allCases) { category in
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

                Section("탑6 설정") {
                    if isEditing {
                        Toggle("나의 최애 탑6", isOn: $restaurant.isTop6)

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
                    } else {
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
                            Text("Apple 지도에서 열기")
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
