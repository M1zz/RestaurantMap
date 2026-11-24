//
//  GoogleImportView.swift
//  인생 맛집
//
//  구글 지도에 저장한 곳을 한 번에 가져온다. 안내 → 파일 고르기 → 확인 → 저장.
//  이미 저장한 곳은 빼고, 무료 한도(30곳)는 새로 저장할 때처럼 지킨다 (→ RestaurantPlan).
//

import SwiftUI
import SwiftData
import CoreLocation

struct GoogleImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var restaurants: [Restaurant]
    @State private var purchases = Purchases.shared

    @State private var picking = false
    @State private var lists: [ImportedList] = []
    /// 확인 화면에서 사용자가 뺀 장소.
    @State private var excluded: Set<UUID> = []
    @State private var progress: (done: Int, total: Int)?
    @State private var work: Task<Void, Never>?
    @State private var failure: String?
    @State private var savedCount: Int?
    @State private var paywallFeature: RestaurantFeature?

    private static let takeoutURL = URL(string: "https://takeout.google.com/")!

    var body: some View {
        NavigationStack {
            Group {
                if let progress { reading(progress) } else if lists.isEmpty { guide } else { review }
            }
            .navigationTitle("구글 지도에서 가져오기")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                if !lists.isEmpty && progress == nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("\(saveCount)곳 저장") { save() }
                            .disabled(saveCount == 0)
                    }
                }
            }
            .fileImporter(isPresented: $picking, allowedContentTypes: [.zip, .json, .commaSeparatedText],
                          allowsMultipleSelection: true) { result in
                if case .success(let urls) = result, !urls.isEmpty { load(urls) }
            }
            .alert("가져오지 못했어요", isPresented: Binding(get: { failure != nil }, set: { if !$0 { failure = nil } })) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(failure ?? "")
            }
            .alert("\(savedCount ?? 0)곳을 가져왔어요", isPresented: Binding(get: { savedCount != nil }, set: { _ in })) {
                Button("확인") { dismiss() }
            }
            .paywall(for: $paywallFeature)
            .onDisappear { work?.cancel() }
        }
    }

    // MARK: - 안내

    private var guide: some View {
        List {
            Section {
                step(1, "구글 데이터 내보내기에서 '모두 선택 해제'를 누른 뒤 '지도(내 장소)'와 '저장됨'만 골라 내보내요.")
                Link(destination: Self.takeoutURL) {
                    Label("구글 데이터 내보내기 열기", systemImage: "arrow.up.forward.square")
                }
            }
            Section {
                step(2, "구글이 보낸 메일에서 zip 파일을 내려받아요. 보통 몇 분 걸려요.")
            }
            Section {
                step(3, "내려받은 zip 파일을 그대로 골라요. 압축을 풀지 않아도 돼요.")
                Button { picking = true } label: {
                    Label("파일 고르기", systemImage: "doc.badge.plus")
                }
            } footer: {
                Text("구글 계정에 로그인하지 않아요. 파일은 이 기기 안에서만 읽어요.")
            }
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "\(number).circle.fill").foregroundStyle(.tint)
        }
    }

    // MARK: - 읽는 중

    private func reading(_ progress: (done: Int, total: Int)) -> some View {
        VStack(spacing: 16) {
            if progress.total > 0 {
                ProgressView(value: Double(progress.done), total: Double(progress.total))
                Text("장소 위치를 찾는 중이에요 \(progress.done)/\(progress.total)")
            } else {
                ProgressView()
                Text("파일을 읽는 중이에요")
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func load(_ urls: [URL]) {
        progress = (0, 0)
        work = Task {
            do {
                var read = try GoogleMapsImport.read(urls)
                await GoogleMapsImport.locate(&read) { progress = ($0, $1) }
                guard !Task.isCancelled else { return }
                lists = read
            } catch {
                failure = error.localizedDescription
            }
            progress = nil
        }
    }

    // MARK: - 확인

    private var review: some View {
        List {
            Section {
                LabeledContent("가져올 곳", value: String(localized: "\(chosen.count)곳"))
            } footer: {
                if saveCount < chosen.count {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("무료로는 \(capacity)곳만 더 저장할 수 있어서, 위에서부터 \(capacity)곳만 저장돼요.")
                        Button("Plus로 모두 가져오기") { paywallFeature = .restaurants }
                            .font(.footnote.weight(.semibold))
                    }
                }
            }
            ForEach($lists) { $list in
                Section(list.name) {
                    Picker("넣을 곳", selection: $list.visited) {
                        Text(RestaurantListType.wishlist.displayName).tag(false)
                        Text(RestaurantListType.visited.displayName).tag(true)
                    }
                    ForEach(list.places) { place in row(place) }
                }
            }
        }
    }

    private func row(_ place: ImportedPlace) -> some View {
        let status = status(of: place)
        let isOn = status == nil && !excluded.contains(place.id)
        return Button {
            if excluded.contains(place.id) { excluded.remove(place.id) } else { excluded.insert(place.id) }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    .imageScale(.large)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name).foregroundStyle(status == nil ? .primary : .secondary)
                    if let detail = status ?? (place.address.isEmpty ? nil : place.address) {
                        Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
        }
        .disabled(status != nil)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// 저장할 수 없는 까닭. 저장할 수 있으면 nil.
    private func status(of place: ImportedPlace) -> String? {
        if isAlreadySaved(place) { return String(localized: "이미 저장한 곳이에요") }
        if place.coordinate == nil { return String(localized: "위치를 찾지 못했어요") }
        return nil
    }

    /// 이름이 같고 200m 안이면 같은 집으로 본다.
    private func isAlreadySaved(_ place: ImportedPlace) -> Bool {
        let name = place.name.lowercased().filter { !$0.isWhitespace }
        return restaurants.contains { saved in
            guard saved.name.lowercased().filter({ !$0.isWhitespace }) == name else { return false }
            guard let c = place.coordinate else { return true }
            return CLLocation(latitude: c.latitude, longitude: c.longitude)
                .distance(from: CLLocation(latitude: saved.latitude, longitude: saved.longitude)) < 200
        }
    }

    // MARK: - 저장

    private var chosen: [(place: ImportedPlace, visited: Bool)] {
        lists.flatMap { list in
            list.places.filter { status(of: $0) == nil && !excluded.contains($0.id) }.map { ($0, list.visited) }
        }
    }

    /// 지금 칸에서 더 저장할 수 있는 식당 수.
    private var capacity: Int {
        purchases.allows(.restaurants) ? .max : max(0, RestaurantPlan.freeRestaurants - restaurants.count)
    }

    private var saveCount: Int { min(chosen.count, capacity) }

    private func save() {
        let places = chosen.prefix(saveCount)
        for (place, visited) in places {
            guard let c = place.coordinate else { continue }
            let restaurant = Restaurant(name: place.name, address: place.address,
                                        latitude: c.latitude, longitude: c.longitude,
                                        notes: place.note, rating: place.rating, visitDate: place.date ?? Date(),
                                        listType: visited ? .visited : .wishlist)
            modelContext.insert(restaurant)
            // 구글에 별점을 남긴 곳은 그날 한 번 다녀온 것으로 적는다.
            if visited && place.rating > 0 {
                modelContext.insert(Visit(restaurant: restaurant, visitDate: place.date ?? Date(),
                                          notes: place.note, rating: place.rating))
            }
        }
        do {
            try modelContext.save()
            savedCount = places.count
        } catch {
            modelContext.rollback()
            failure = error.localizedDescription
        }
    }
}
