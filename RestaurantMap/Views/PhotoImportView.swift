//
//  PhotoImportView.swift
//  인생 맛집
//
//  사진첩의 음식 사진으로 지난 맛집을 한꺼번에 불러온다.
//
//  1. 사진을 고른다 (사진 고르기 화면 — 사진첩 전체 접근 권한을 묻지 않는다)
//  2. 사진에 담긴 찍은 자리 · 시각을 읽어, 같은 날 150m 안에서 찍은 것끼리 한 끼로 묶는다
//  3. 묶음마다 찍은 자리 가까운 식당을 찾아 가장 가까운 곳을 미리 고른다 (→ NearbyRestaurants)
//  4. 확인한 묶음만 식당 + 그날 방문 + 사진으로 넣는다. 이미 저장한 집이면 방문만 더하고, 같은 날 방문이 있으면 사진만 붙인다
//
//  위치가 없는 사진(사진 고르기의 '옵션' 에서 위치를 끈 경우 · 스크린숏 등)은 건너뛰고 몇 장인지 알린다.
//  메모리를 아끼려고 읽을 때는 작은 미리보기만 쥐고, 넣을 때 사진을 다시 읽어 줄여 붙인다.
//

import SwiftUI
import SwiftData
import PhotosUI
import MapKit
import ImageIO
import OSLog

// MARK: - 사진 읽기 · 묶기

struct MealPhoto: Identifiable {
    let id = UUID()
    let item: PhotosPickerItem
    let date: Date
    let coordinate: CLLocationCoordinate2D
    let thumbnail: UIImage?
}

/// 같은 날 한 자리에서 찍은 사진 묶음 = 한 끼.
struct PhotoMeal: Identifiable {
    let id = UUID()
    var photos: [MealPhoto]
    var candidates: [MKMapItem] = []
    /// 고른 후보. nil 이면 넣지 않는다.
    var choice: Int?
    var searched = false

    var date: Date { photos.map(\.date).min() ?? Date() }
    var anchor: CLLocationCoordinate2D { photos[0].coordinate }
    var chosen: MKMapItem? { choice.flatMap { candidates.indices.contains($0) ? candidates[$0] : nil } }
}

enum PhotoLibraryImport {
    /// 같은 끼니로 묶는 거리.
    static let mealRadius: CLLocationDistance = 150
    /// 방문 하나에 붙이는 사진 수.
    static let photosPerVisit = 6
    static let maxSelection = 200

    /// 사진 데이터에서 찍은 시각 · 자리. 위치가 없으면 nil.
    static func metadata(of data: Data) -> (date: Date?, coordinate: CLLocationCoordinate2D?) {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return (nil, nil) }

        var coordinate: CLLocationCoordinate2D?
        if let gps = props[kCGImagePropertyGPSDictionary] as? [CFString: Any],
           var lat = gps[kCGImagePropertyGPSLatitude] as? Double,
           var lon = gps[kCGImagePropertyGPSLongitude] as? Double {
            if (gps[kCGImagePropertyGPSLatitudeRef] as? String)?.uppercased() == "S" { lat = -lat }
            if (gps[kCGImagePropertyGPSLongitudeRef] as? String)?.uppercased() == "W" { lon = -lon }
            let c = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            // 0,0 은 위치를 못 잡은 사진이 흔히 남기는 값이다
            if c.isMappable, !(lat == 0 && lon == 0) { coordinate = c }
        }

        var date: Date?
        if let exif = props[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let raw = exif[kCGImagePropertyExifDateTimeOriginal] as? String {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            if let offset = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String {
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
                date = formatter.date(from: raw + offset)
            }
            if date == nil {
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                formatter.timeZone = .current
                date = formatter.date(from: raw)
            }
        }
        return (date, coordinate)
    }

    /// 같은 날, 첫 사진에서 150m 안이면 같은 끼니.
    static func group(_ photos: [MealPhoto], calendar: Calendar = .current) -> [PhotoMeal] {
        var meals: [PhotoMeal] = []
        for photo in photos.sorted(by: { $0.date < $1.date }) {
            let here = CLLocation(latitude: photo.coordinate.latitude, longitude: photo.coordinate.longitude)
            if let index = meals.firstIndex(where: { meal in
                calendar.isDate(meal.date, inSameDayAs: photo.date)
                    && here.distance(from: CLLocation(latitude: meal.anchor.latitude, longitude: meal.anchor.longitude)) <= mealRadius
            }) {
                meals[index].photos.append(photo)
            } else {
                meals.append(PhotoMeal(photos: [photo]))
            }
        }
        return meals.sorted { $0.date > $1.date }
    }

    static func normalized(_ name: String) -> String {
        name.lowercased().filter { !$0.isWhitespace }
    }
}

// MARK: - 화면

struct PhotoImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var storedRestaurants: [Restaurant]
    private var restaurants: [Restaurant] { storedRestaurants.filter { !$0.isGone } }

    @State private var purchases = Purchases.shared
    @State private var paywallFeature: RestaurantFeature?

    @State private var selection: [PhotosPickerItem] = []
    @State private var meals: [PhotoMeal] = []
    @State private var skippedNoLocation = 0
    @State private var progress: (label: LocalizedStringKey, done: Int, total: Int)?
    @State private var work: Task<Void, Never>?
    @State private var result: (restaurants: Int, visits: Int, photos: Int)?
    @State private var failure: String?

    private let logger = Logger(subsystem: "com.restaurantmap", category: "PhotoImport")

    var body: some View {
        NavigationStack {
            Group {
                if let result {
                    done(result)
                } else if let progress {
                    working(progress)
                } else if meals.isEmpty {
                    intro
                } else {
                    review
                }
            }
            .navigationTitle("사진으로 불러오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기", systemImage: "xmark") {
                        work?.cancel()
                        dismiss()
                    }
                }
                if !meals.isEmpty, result == nil, progress == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("넣기", systemImage: "checkmark") { startSaving() }
                            .disabled(chosenMeals.isEmpty)
                    }
                }
            }
            .paywall(for: $paywallFeature)
            .alert("불러오지 못했어요", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(verbatim: failure ?? "")
            }
            .onChange(of: selection) { _, items in
                guard !items.isEmpty else { return }
                read(items)
            }
            .onDisappear { work?.cancel() }
        }
    }

    // MARK: 처음

    private var intro: some View {
        List {
            Section {
                step(1, "지난 음식 사진을 골라요")
                step(2, "사진에 담긴 찍은 날과 자리로, 같은 날 한 자리에서 찍은 사진끼리 묶어요")
                step(3, "찍은 자리 가까운 식당을 찾아 미리 골라 둬요. 맞는지 보고 넣으면 돼요")
            } footer: {
                Text("사진첩 전체를 열어 보지 않아요. 고른 사진만 읽어요.")
                    .font(.body)
            }
            Section {
                PhotosPicker(selection: $selection, maxSelectionCount: PhotoLibraryImport.maxSelection,
                             selectionBehavior: .ordered, matching: .images, photoLibrary: .shared()) {
                    Label("음식 사진 고르기", systemImage: "photo.on.rectangle.angled")
                        .font(.headline)
                }
            } footer: {
                Text("한 번에 \(PhotoLibraryImport.maxSelection)장까지 고를 수 있어요. 고르는 화면의 '옵션' 에서 위치가 켜져 있어야 자리를 알 수 있어요.")
                    .font(.body)
            }
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(verbatim: "\(number)")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.orange, in: Circle())
            Text(text)
        }
    }

    private func working(_ progress: (label: LocalizedStringKey, done: Int, total: Int)) -> some View {
        VStack(spacing: 16) {
            ProgressView(value: Double(progress.done), total: Double(max(progress.total, 1)))
            Text(progress.label).font(.headline)
            Text(verbatim: "\(progress.done) / \(progress.total)")
                .font(.body.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(32)
    }

    private func done(_ result: (restaurants: Int, visits: Int, photos: Int)) -> some View {
        ContentUnavailableView {
            Label("불러왔어요", systemImage: "checkmark.circle.fill")
        } description: {
            Text("새 식당 \(result.restaurants)곳, 방문 \(result.visits)번, 사진 \(result.photos)장을 넣었어요.")
        } actions: {
            Button("닫기") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    // MARK: 확인

    private var review: some View {
        List {
            Section {
                LabeledContent("넣을 끼니", value: String(localized: "\(chosenMeals.count)번"))
                if skippedNoLocation > 0 {
                    Text("위치 정보가 없는 사진 \(skippedNoLocation)장은 건너뛰었어요.")
                        .foregroundStyle(.secondary)
                }
                if newRestaurantCount > capacity {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("무료로는 식당을 \(capacity)곳만 더 저장할 수 있어서, 최근 것부터 \(capacity)곳만 새로 저장돼요. 이미 저장한 집의 방문은 모두 들어가요.")
                        Button("Plus로 모두 불러오기") { paywallFeature = .restaurants }
                            .fontWeight(.semibold)
                    }
                }
            } footer: {
                Text("식당 이름을 눌러 다른 후보로 바꾸거나 빼세요.")
                    .font(.body)
            }
            Section {
                ForEach($meals) { $meal in
                    mealRow($meal)
                }
            }
        }
    }

    private func mealRow(_ meal: Binding<PhotoMeal>) -> some View {
        let value = meal.wrappedValue
        let center = CLLocation(latitude: value.anchor.latitude, longitude: value.anchor.longitude)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(value.photos.prefix(4)) { photo in
                    Group {
                        if let thumbnail = photo.thumbnail {
                            Image(uiImage: thumbnail).resizable().scaledToFill()
                        } else {
                            Color.gray.opacity(0.2)
                        }
                    }
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .accessibilityHidden(true)
                }
                if value.photos.count > 4 {
                    Text(verbatim: "+\(value.photos.count - 4)")
                        .foregroundStyle(.secondary)
                }
            }
            Text("\(value.date.formatted(date: .abbreviated, time: .shortened)) · 사진 \(value.photos.count)장")
                .foregroundStyle(.secondary)

            if !value.searched {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("근처 식당을 찾는 중…").foregroundStyle(.secondary)
                }
            } else if value.candidates.isEmpty {
                Text("근처에서 식당을 찾지 못했어요")
                    .foregroundStyle(.secondary)
            } else {
                Menu {
                    Picker("식당", selection: meal.choice) {
                        ForEach(value.candidates.indices, id: \.self) { index in
                            let item = value.candidates[index]
                            Text(verbatim: "\(item.name ?? "") · \(NearbyRestaurants.distanceText(NearbyRestaurants.distance(item, from: center)))")
                                .tag(Optional(index))
                        }
                        Text("넣지 않기").tag(nil as Int?)
                    }
                } label: {
                    HStack {
                        Image(systemName: value.chosen == nil ? "circle" : "checkmark.circle.fill")
                            .foregroundStyle(value.chosen == nil ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
                            .imageScale(.large)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: value.chosen?.name ?? String(localized: "넣지 않기"))
                                .font(.headline)
                                .foregroundStyle(value.chosen == nil ? .secondary : .primary)
                            if let chosen = value.chosen, existing(for: chosen) != nil {
                                Text("이미 저장한 식당 — 방문으로 더해요")
                                    .foregroundStyle(.green)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: 읽기

    private func read(_ items: [PhotosPickerItem]) {
        work?.cancel()
        work = Task {
            progress = ("사진을 읽는 중…", 0, items.count)
            var photos: [MealPhoto] = []
            var skipped = 0
            for (index, item) in items.enumerated() {
                if Task.isCancelled { return }
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let meta = PhotoLibraryImport.metadata(of: data)
                    if let coordinate = meta.coordinate {
                        photos.append(MealPhoto(item: item, date: meta.date ?? Date(), coordinate: coordinate,
                                                  thumbnail: PhotoDownsampler.image(from: data, maxPixel: 168)))
                    } else {
                        skipped += 1
                    }
                } else {
                    skipped += 1
                }
                progress = ("사진을 읽는 중…", index + 1, items.count)
            }
            selection = []
            skippedNoLocation = skipped
            let grouped = PhotoLibraryImport.group(photos)
            progress = nil
            guard !grouped.isEmpty else {
                failure = String(localized: "고른 사진에서 찍은 자리를 찾지 못했어요. 사진 고르기 화면의 '옵션' 에서 위치를 켜고 다시 골라 주세요.")
                return
            }
            meals = grouped
            await findRestaurants()
        }
    }

    /// 끼니마다 가까운 식당을 차례로 찾는다. 지도 검색은 짧은 시간에 많이 부르면 막히므로 사이를 둔다.
    private func findRestaurants() async {
        for index in meals.indices {
            if Task.isCancelled { return }
            var found = await NearbyRestaurants.search(around: meals[index].anchor, radius: 100, limit: 5)
            if found.isEmpty {
                found = await NearbyRestaurants.search(around: meals[index].anchor, radius: 250, limit: 5)
            }
            guard meals.indices.contains(index) else { return }
            meals[index].candidates = found
            meals[index].choice = found.isEmpty ? nil : 0
            meals[index].searched = true
            try? await Task.sleep(for: .milliseconds(400))
        }
    }

    // MARK: 넣기

    private var chosenMeals: [PhotoMeal] { meals.filter { $0.chosen != nil } }

    /// 이름이 같고 200m 안이면 이미 저장한 집.
    private func existing(for item: MKMapItem) -> Restaurant? {
        let name = PhotoLibraryImport.normalized(item.name ?? "")
        let spot = item.placemark.coordinate
        let here = CLLocation(latitude: spot.latitude, longitude: spot.longitude)
        return restaurants.first { saved in
            PhotoLibraryImport.normalized(saved.name) == name
                && CLLocation(latitude: saved.latitude, longitude: saved.longitude).distance(from: here) < 200
        }
    }

    /// 새로 만들 식당 수 (같은 집을 여러 날 갔으면 한 곳).
    private var newRestaurantCount: Int {
        Set(chosenMeals.compactMap { meal -> String? in
            guard let item = meal.chosen, existing(for: item) == nil else { return nil }
            return PhotoLibraryImport.normalized(item.name ?? "")
        }).count
    }

    private var capacity: Int {
        purchases.allows(.restaurants) ? .max : max(0, RestaurantPlan.freeRestaurants - restaurants.count)
    }

    private func startSaving() {
        let meals = chosenMeals
        work = Task { await save(meals) }
    }

    /// 끼니마다 저장한다 — 사진이 많아도 메모리에 한꺼번에 쥐지 않게. 하나가 실패해도 앞에 넣은 것은 남는다.
    private func save(_ meals: [PhotoMeal]) async {
        var created: [String: Restaurant] = [:]
        var room = capacity
        var counts = (restaurants: 0, visits: 0, photos: 0)
        let calendar = Calendar.current

        // 오래된 끼니부터 넣어야 식당의 '처음 간 날' 이 맞는다. 한도가 모자라면 최근 것을 먼저 살리려고 새 식당 자리는 최근 순으로 잡는다.
        let recentFirst = meals.sorted { $0.date > $1.date }
        var allowedNew = Set<String>()
        for meal in recentFirst {
            guard let item = meal.chosen, existing(for: item) == nil else { continue }
            let key = PhotoLibraryImport.normalized(item.name ?? "")
            if allowedNew.contains(key) { continue }
            if room > 0 { allowedNew.insert(key); room -= 1 }
        }

        let ordered = meals.sorted { $0.date < $1.date }
        for (index, meal) in ordered.enumerated() {
            if Task.isCancelled { break }
            progress = ("사진을 넣는 중…", index, ordered.count)
            guard let item = meal.chosen else { continue }
            let key = PhotoLibraryImport.normalized(item.name ?? "")

            var inserted: [any PersistentModel] = []
            let restaurant: Restaurant
            if let saved = existing(for: item) ?? created[key] {
                restaurant = saved
            } else if allowedNew.contains(key) {
                let spot = item.placemark.coordinate
                let raw = item.pointOfInterestCategory?.rawValue
                restaurant = Restaurant(
                    name: item.name ?? "", address: item.restaurantAddress,
                    latitude: spot.latitude, longitude: spot.longitude,
                    visitDate: meal.date,
                    category: raw.map(POICategoryMapper.toKorean) ?? "",
                    phoneNumber: item.phoneNumber ?? "",
                    foodCategory: FoodCategoryRepository.guess(from: [raw, item.name].compactMap { $0 }),
                    listType: .visited)
                modelContext.insert(restaurant)
                inserted.append(restaurant)
                created[key] = restaurant
            } else {
                continue
            }

            // 같은 날 방문이 이미 있으면 사진만 붙인다
            let visit: Visit
            if let sameDay = (restaurant.visits ?? []).first(where: { !$0.isDeleted && calendar.isDate($0.visitDate, inSameDayAs: meal.date) }) {
                visit = sameDay
            } else {
                visit = Visit(restaurant: restaurant, visitDate: meal.date)
                modelContext.insert(visit)
                inserted.append(visit)
            }
            // 가볼 곳이었던 집을 다녀왔다면 가본 곳으로
            if restaurant.isWishlist { restaurant.isWishlist = false }

            var added = 0
            for photo in meal.photos.prefix(PhotoLibraryImport.photosPerVisit) {
                if Task.isCancelled { break }
                guard let data = try? await photo.item.loadTransferable(type: Data.self),
                      let image = PhotoDownsampler.image(from: data, maxPixel: 1024),
                      let attached = visit.addPhoto(image) else { continue }
                inserted.append(attached)
                added += 1
            }

            do {
                try modelContext.save()
                if inserted.contains(where: { $0 is Restaurant }) { counts.restaurants += 1 }
                if inserted.contains(where: { $0 is Visit }) { counts.visits += 1 }
                counts.photos += added
            } catch {
                logger.error("사진 불러오기 저장 실패: \(error.localizedDescription)")
                for model in inserted.reversed() { modelContext.delete(model) }
                if inserted.contains(where: { $0 is Restaurant }) { created[key] = nil }
                failure = error.localizedDescription
                break
            }
        }
        progress = nil
        result = counts
    }
}
