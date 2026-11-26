import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import OSLog
import LeeoKit

struct RestaurantDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var restaurant: Restaurant
    /// 시트가 아니라 아이폰 듀오의 결과 쪽 판에 설 때, 닫기가 할 일(판을 비운다).
    var onClose: (() -> Void)? = nil
    @Query private var storedRestaurants: [Restaurant]
    /// 다른 식당이 막 지워진 순간에도 순위를 셀 수 있게 지워진 것은 뺀다(→ ContentView 와 같은 까닭).
    private var allRestaurants: [Restaurant] { storedRestaurants.filter { !$0.isGone } }

    @State private var showingDeleteAlert = false
    @State private var showingAddVisit = false
    @State private var selectedVisit: Visit?
    @State private var isEditing = false
    @State private var purchases = Purchases.shared
    @State private var paywallFeature: RestaurantFeature?
    @State private var composingReview = false

    private let logger = Logger(subsystem: "com.restaurantmap", category: "RestaurantDetail")

    /// 나의 미슐랭 순위. 순위에 없으면 nil.
    private var rank: Int? {
        allRestaurants.regularRanks()[restaurant.persistentModelID]
    }

    @AppStorage(SignatureList.nameKey) private var signatureName = ""

    var sortedVisits: [Visit] {
        // 지우기로 표시된 방문은 저장 전까지 관계에 남아 있을 수 있다 — 줄로 그리지 않는다
        (restaurant.visits ?? []).filter { !$0.isDeleted }.sorted(by: { $0.visitDate > $1.visitDate })
    }

    var body: some View {
        // 이 화면에서 식당을 지우면(또는 동기화 · 복원으로 지워지면) 닫히는 동안에도 다시 그려진다.
        // 지워진 식당의 속성을 읽으면 죽으므로 빈 화면으로 둔다.
        if restaurant.isGone {
            Color.clear
        } else {
            content
        }
    }

    private var content: some View {
        NavigationStack {
            Form {
                if !restaurant.isWishlist {
                    regularSection
                    ScoreSection(restaurant: restaurant,
                                 signatureRank: allRestaurants.signatureRanks()[restaurant.persistentModelID],
                                 signatureTitle: SignatureList.title(signatureName))
                    TasteShiftSection(restaurant: restaurant)
                    gourmetSection
                    tasteSection
                    shareSection
                }

                // 응원 부탁 — 이미 Pro 인 사람에게만, 방문 기록을 꽤 쌓아 온 때 드물게(방문을 남기고 돌아온 자리)
                if purchases.tier == .pro {
                    Section {
                        LeeoTipAskSlot<RestaurantMapSpec>(tipJar: RestaurantMapTip.tipJar,
                                                          reached: RestaurantMapTipMoments.reachedNow(in: allRestaurants))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
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
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // 또 시킬 메뉴 — 다음에 와서 바로 본다
                    let again = (restaurant.menus ?? []).filter { !$0.isDeleted && $0.wouldOrderAgain == true }
                        .sorted { $0.displayRating > $1.displayRating }
                    if !again.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ReorderLabel(again: true)
                                .foregroundStyle(.green)
                            Text(again.map(\.name).formatted(.list(type: .and)))
                                .font(.body)
                        }
                        .accessibilityElement(children: .combine)
                    }
                } header: {
                    Text("메뉴")
                } footer: {
                    Text("메뉴마다 사진 · 내 점수 · 또 시킬지를 남길 수 있어요")
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
                                .accessibleTap {
                                    logger.info("🔵 [방문 기록 탭] Date: \(visit.visitDate.formatted()), HasTaste: \(visit.hasTasteNote)")
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
                            .accessibilityLabel(Text("방문 기록 추가"))
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

                        FoodCategoryPicker(selection: Binding(
                            get: { restaurant.foodCategory },
                            set: { restaurant.foodCategory = $0 }
                        ))
                    } else {
                        // 보기 모드
                        LabeledContent("식당 이름", value: restaurant.name)
                        LabeledContent("주소", value: restaurant.address)
                        if !restaurant.category.isEmpty {
                            LabeledContent("카테고리", value: POICategoryMapper.displayName(restaurant.category))
                        }
                        LabeledContent("음식 종류", value: restaurant.foodCategory.displayName)
                        if !restaurant.phoneNumber.isEmpty {
                            LabeledContent("전화번호") {
                                if let call = URL(string: "tel://" + restaurant.phoneNumber.filter { $0.isNumber || $0 == "+" }) {
                                    Link(restaurant.phoneNumber, destination: call)
                                        .foregroundStyle(.blue)
                                } else {
                                    Text(restaurant.phoneNumber)
                                }
                            }
                        }
                    }
                }

                // 가본곳/가볼곳 구분
                Section {
                    if isEditing {
                        Picker("구분", selection: Binding(
                            get: { restaurant.listType },
                            set: { restaurant.listType = $0 }
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
                }

                Section("위치") {
                    // 지도에 찍을 수 없는 좌표(가져온 파일 · 옛 백업)면 지도를 그리지 않는다 — 잘못된 영역은 예외로 죽는다
                    if restaurant.coordinate.isMappable {
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
                    }

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
                    Button("닫기", systemImage: "xmark") {
                        if let onClose { onClose() } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? LocalizedStringKey("완료") : LocalizedStringKey("편집"), systemImage: isEditing ? "checkmark" : "pencil") {
                        isEditing.toggle()
                        // 고친 것을 '완료' 에서 바로 내린다 (자동 저장만 믿으면 직후에 꺼질 때 사라진다)
                        if !isEditing { modelContext.saveNow() }
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
            .paywall(for: $paywallFeature)
            .sheet(isPresented: $composingReview) { ReviewComposeView(restaurant: restaurant) }
            .sheet(isPresented: $showingAddVisit) {
                AddVisitView(restaurant: restaurant)
            }
            .sheet(item: $selectedVisit) { visit in
                VisitDetailViewWrapper(visit: visit)
            }
            // 편집 중에 닫아도 고친 것이 남게
            .onDisappear { modelContext.saveNow() }
        }
    }

    private func deleteRestaurant() {
        // 이 화면이 쥐고 있던 방문부터 놓는다 (같이 지워진다)
        selectedVisit = nil
        modelContext.delete(restaurant)
        modelContext.saveNow()
        if let onClose { onClose() } else { dismiss() }
    }

    private func deleteVisits(at offsets: IndexSet) {
        // 지우는 동안 목록이 바뀌어도 번호가 어긋나지 않게 먼저 한 번만 읽는다
        let visits = sortedVisits
        for index in offsets where index < visits.count {
            modelContext.delete(visits[index])
        }
        modelContext.saveNow()
    }

    private func openInAppleMaps() {
        guard restaurant.coordinate.isMappable else { return }
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

// MARK: - 단골 인정 · 미식 기준

extension RestaurantDetailView {
    /// 다녀온 날로 앱이 인정한 단계와, 다음 단계까지 남은 길.
    var regularSection: some View {
        let regular = restaurant.regular
        return Section {
            LabeledContent("단골 인정") {
                if regular.level > .none {
                    RegularBadge(regular: regular)
                } else {
                    Text("아직이에요").foregroundStyle(.secondary)
                }
            }
            if let rank {
                LabeledContent("나의 미슐랭") {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill").foregroundStyle(.yellow).accessibilityHidden(true)
                        Text("\(rank)위")
                    }
                }
            }
            LabeledContent("다녀온 날", value: String(localized: "\(regular.days)회"))
            if let first = regular.first, regular.days > 1 {
                LabeledContent("처음 간 날") {
                    Text(first, format: .dateTime.year().month().day())
                }
            }
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
            }
        } header: {
            Text("단골 인정")
        } footer: {
            if let hint = regular.nextStep {
                Text(verbatim: hint)
            } else {
                Text("직접 고르지 않아요. 다녀온 날이 쌓이면 앱이 인정해요.")
            }
        }
    }

    /// 단골이 된 집은 한마디를 적고, 모두에게 올리거나, 카드 그림으로 내보낼 수 있다.
    @ViewBuilder
    var shareSection: some View {
        if restaurant.regular.isRanked {
            Section {
                // 나만 보는 한마디. 누르면 적고, 거기서 모두에게 올릴 수도 있다.
                Button {
                    composingReview = true
                } label: {
                    if restaurant.regularWord.isEmpty {
                        Label("이 집을 왜 계속 가나요?", systemImage: "square.and.pencil")
                    } else {
                        HStack(alignment: .top) {
                            Text(verbatim: restaurant.regularWord)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 8)
                            if restaurant.sharedReviewID != nil {
                                Text("올림", comment: "Badge: this regular's note is posted publicly")
                                    .font(.caption2.weight(.semibold))
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Color.pink.opacity(0.15), in: Capsule())
                                    .foregroundStyle(.pink)
                            }
                        }
                    }
                }
                if !purchases.allows(.regularCard) {
                    // 카드로 꾸며 내보내기는 Plus
                    Button { paywallFeature = .regularCard } label: {
                        LockedLabel(title: "단골 카드 공유", systemImage: "square.and.arrow.up", feature: .regularCard)
                    }
                } else if let card = RegularReview(restaurant: restaurant, id: "card", text: restaurant.regularWord,
                                                   nickname: RegularReviews.shared.nickname, author: "") {
                    RegularCardShareLink(review: card)
                }
            } header: {
                Text("한마디")
            } footer: {
                Text("단골이 된 집만 후기를 올릴 수 있어요.")
            }
        }
    }

    /// 방문마다 적은 미식 기준의 평균과, 갈 때마다 한결같았는지.
    @ViewBuilder
    var gourmetSection: some View {
        if !(restaurant.hasGourmetNotes || restaurant.consistency != nil) {
            EmptyView()
        } else if !purchases.allows(.gourmetSummary) {
            // 모아 보기는 Plus. 방문마다 적은 점수는 각 방문 기록에서 그대로 보인다.
            Section {
                Button { paywallFeature = .gourmetSummary } label: {
                    LockedLabel(title: "미식 총평", systemImage: "leaf.fill", feature: .gourmetSummary)
                }
            } header: {
                Text("미식 기준")
            } footer: {
                Text("방문마다 적은 점수는 각 방문 기록에서 그대로 볼 수 있어요.")
            }
        } else {
            Section {
                ForEach(GourmetCriterion.allCases) { criterion in
                    if let average = restaurant.gourmetAverage(criterion) {
                        GourmetBar(criterion: criterion, value: average)
                    }
                }
                if let consistency = restaurant.consistency {
                    LabeledContent {
                        Text(verbatim: consistency.title)
                    } label: {
                        Label("한결같음", systemImage: "equal.circle.fill")
                    }
                }
            } header: {
                Text("미식 기준")
            } footer: {
                Text("접시 위의 음식만 봐요. 한결같음은 여러 번 간 기록으로 앱이 세요.")
            }
        }
    }
}

extension RestaurantDetailView {
    /// 이 집에서 적은 맛의 평균 — 어떤 맛의 집인지. 좋고 나쁨은 위의 미식 기준이 본다.
    @ViewBuilder
    var tasteSection: some View {
        let axes = restaurant.notedTasteAxes
        if !axes.isEmpty {
            Section {
                ForEach(axes) { axis in
                    if let average = restaurant.tasteAverage(axis) {
                        TasteAxisBar(axis: axis, value: average)
                    }
                }
            } header: {
                Text("맛")
            } footer: {
                Text("방문마다 적은 맛의 평균이에요.")
            }
        }
    }
}

/// 미식 기준 하나를 1~5 막대로.
struct GourmetBar: View {
    let criterion: GourmetCriterion
    let value: Double

    var body: some View {
        HStack(spacing: 12) {
            Label(criterion.title, systemImage: criterion.symbol)
                .frame(minWidth: 72, alignment: .leading)
            ProgressView(value: min(max(value, 0), 5), total: 5)
                .tint(.orange)
            Text(verbatim: value.formatted(.number.precision(.fractionLength(1))))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: criterion.title))
        .accessibilityValue(Text("\(value.formatted(.number.precision(.fractionLength(1))))점"))
    }
}

// MARK: - Visit Row View
struct VisitRowView: View {
    let visit: Visit

    var body: some View {
        // 지워진 방문의 줄이 한 박자 남아 다시 그려져도 모델을 읽지 않는다
        if !visit.isGone { row }
    }

    private var row: some View {
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
                .starRatingLabel(Double(visit.rating))
            }

            if !visit.displayMenuName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "fork.knife")
                        .font(.caption)
                        .accessibilityHidden(true)
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

            if visit.hasTasteNote {
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
