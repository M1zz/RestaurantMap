//
//  TasteProfileView.swift
//  인생 맛집
//
//  취향 — 묻지 않고 기록에서 센다 (→ Models/Taste.swift `TasteReport`).
//
//   · 맛 지도: 가로 진하기 · 세로 자극. 다녀온 집이 도장으로 찍히고, 별을 많이 준 쪽으로 '기록의 나'가 선다.
//     위스키 플레이버 맵처럼 축 두 개로 한 장에 놓는다.
//   · 내가 생각하는 나: 내가 찍는 점 하나. 기록의 나와 어긋나면 그게 발견이다.
//   · 자주 가는 종류: 다녀온 날로 센다.
//   · 기록이 말하는 취향 (Plus): 무엇에 별을 많이 주는지, 고기 · 생선 … 계열마다 어느 쪽을 먹는지.
//

import SwiftUI
import SwiftData

struct TasteProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [TasteProfile]
    @Query private var storedRestaurants: [Restaurant]
    /// 지워진 식당은 읽지 않는다(→ ContentView 와 같은 까닭).
    private var restaurants: [Restaurant] { storedRestaurants.filter { !$0.isGone } }

    @State private var purchases = Purchases.shared
    @State private var paywallFeature: RestaurantFeature?
    @State private var opened: Restaurant?

    private var report: TasteReport { TasteReport(restaurants: restaurants) }
    private var profile: TasteProfile? { profiles.first }

    var body: some View {
        let report = report
        NavigationStack {
            List {
                mapSection(report)
                selfSection
                if !report.favorites.isEmpty { favoritesSection(report) }
                insightSection(report)
            }
            .navigationTitle("취향")
            .sheet(item: $opened) { RestaurantDetailView(restaurant: $0) }
            .paywall(for: $paywallFeature)
        }
    }

    // MARK: 맛 지도

    private func mapSection(_ report: TasteReport) -> some View {
        Section {
            TasteMapView(report: report,
                         selfPoint: profile.flatMap { p in p.selfDepth.flatMap { d in p.selfKick.map { (d, $0) } } },
                         onOpen: { opened = $0 })
                .aspectRatio(1, contentMode: .fit)
                .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
            HStack(spacing: 16) {
                legend { VisitStamp(days: 4, level: .regular, size: 16) } text: { Text("다녀온 집") }
                legend { TasteMapMarker(kind: .record, size: 16) } text: { Text("기록의 나") }
                legend { TasteMapMarker(kind: .guess, size: 16) } text: { Text("내가 생각하는 나") }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        } header: {
            Text("맛 지도")
        } footer: {
            if report.spots.isEmpty {
                Text("방문을 기록할 때 진하기와 자극을 적으면 다녀온 집이 여기 찍혀요.")
            } else {
                Text("집마다 적은 맛의 평균이에요. 별을 많이 준 집일수록 '기록의 나'를 더 끌어당겨요. 도장을 누르면 그 집이 열려요.")
            }
        }
    }

    private func legend(@ViewBuilder _ mark: () -> some View, @ViewBuilder text: () -> Text) -> some View {
        HStack(spacing: 6) {
            mark().accessibilityHidden(true)
            text()
        }
    }

    // MARK: 내가 생각하는 나

    private var selfSection: some View {
        Section {
            TasteAxisInput(axis: .depth, value: selfBinding(\.selfDepth))
            TasteAxisInput(axis: .kick, value: selfBinding(\.selfKick))
        } header: {
            Text("내가 생각하는 나")
        } footer: {
            Text("지도 위 점선 원이에요. 기록의 나와 얼마나 가까운지 보세요.")
        }
    }

    private func selfBinding(_ key: ReferenceWritableKeyPath<TasteProfile, Double?>) -> Binding<Int?> {
        Binding(
            get: { profile?[keyPath: key].flatMap { $0.isFinite ? Int(min(max($0, 1), 5).rounded()) : nil } },
            set: { value in
                let target = profile ?? { let new = TasteProfile(); modelContext.insert(new); return new }()
                target[keyPath: key] = value.map(Double.init)
                target.updatedAt = .now
                modelContext.saveNow()
            })
    }

    // MARK: 자주 가는 종류

    private func favoritesSection(_ report: TasteReport) -> some View {
        Section("자주 가는 종류") {
            ForEach(report.favorites) { favorite in
                LabeledContent {
                    Text(favorite.regulars > 0
                         ? String(localized: "\(favorite.days)번 · 단골 \(favorite.regulars)곳", comment: "Favorite food type: visit days and regular places")
                         : String(localized: "\(favorite.days)번", comment: "Favorite food type: visit days"))
                } label: {
                    Text(verbatim: favorite.category.displayName)
                }
            }
        }
    }

    // MARK: 기록이 말하는 취향 (Plus)

    @ViewBuilder
    private func insightSection(_ report: TasteReport) -> some View {
        if !purchases.allows(.tasteProfile) {
            Section {
                Button { paywallFeature = .tasteProfile } label: {
                    LockedLabel(title: "기록이 말하는 취향", systemImage: "sparkles", feature: .tasteProfile)
                }
            } footer: {
                Text("무엇에 별을 많이 주는지, 고기 · 생선 · 면은 어느 쪽으로 먹는지 기록에서 찾아 드려요.")
            }
        } else {
            Section {
                if let criterion = report.drivingCriterion {
                    Label(criterion.starSentence, systemImage: criterion.symbol)
                } else {
                    Text("미식 기준을 \(TasteReport.criterionMinimum)번 넘게 적으면, 무엇에 별을 많이 주는지 알려 드려요.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("기록이 말하는 취향")
            }
            if report.families.isEmpty {
                Section {
                    Text("고기 · 생선 · 면처럼 계열 맛을 \(TasteReport.familyMinimum)번 넘게 적으면 계열마다 어느 쪽을 먹는지 보여 드려요.")
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(report.families) { note in
                Section {
                    ForEach(note.axes, id: \.axis) { item in
                        TasteAxisBar(axis: item.axis, value: item.value)
                    }
                } header: {
                    Text(verbatim: "\(note.family.emoji) \(note.family.title)")
                } footer: {
                    Text("\(note.visits)번 적은 기록이에요.")
                }
            }
        }
    }
}

// MARK: - 맛 지도

/// 가로 진하기(담백 → 진함) · 세로 자극(순함 → 자극적). 1~5 를 판 안쪽에 고르게 편다.
struct TasteMapView: View {
    let report: TasteReport
    let selfPoint: (depth: Double, kick: Double)?
    let onOpen: (Restaurant) -> Void

    private let stamp: CGFloat = 26

    var body: some View {
        GeometryReader { geo in
            let inset: CGFloat = 30
            let side = CGSize(width: geo.size.width - inset * 2, height: geo.size.height - inset * 2)
            let place = { (depth: Double, kick: Double) -> CGPoint in
                CGPoint(x: inset + side.width * (depth - 1) / 4,
                        y: inset + side.height * (1 - (kick - 1) / 4))
            }
            ZStack {
                board(inset: inset)
                ForEach(Array(spread(report.spots).enumerated()), id: \.element.spot.id) { _, item in
                    Button { onOpen(item.spot.restaurant) } label: {
                        VisitStamp(restaurant: item.spot.restaurant, size: stamp)
                            .background(.background, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(verbatim: "\(item.spot.restaurant.name), \(TasteAxis.depth.describe(item.spot.depth)), \(TasteAxis.kick.describe(item.spot.kick))"))
                    .position(place(item.spot.depth, item.spot.kick) + item.offset)
                }
                if let selfPoint {
                    TasteMapMarker(kind: .guess, size: 30)
                        .position(place(selfPoint.depth, selfPoint.kick))
                        .accessibilityLabel(Text("내가 생각하는 나"))
                }
                if let center = report.center {
                    TasteMapMarker(kind: .record, size: 30)
                        .position(place(center.depth, center.kick))
                        .accessibilityLabel(Text("기록의 나"))
                        .accessibilityValue(Text(verbatim: "\(TasteAxis.depth.describe(center.depth)), \(TasteAxis.kick.describe(center.kick))"))
                }
            }
        }
    }

    /// 판: 가운데 십자선과 네 끝의 말.
    private func board(inset: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(.teal.opacity(0.06))
            GeometryReader { geo in
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: inset / 2))
                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height - inset / 2))
                    path.move(to: CGPoint(x: inset / 2, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width - inset / 2, y: geo.size.height / 2))
                }
                .stroke(.teal.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            VStack {
                Text(verbatim: TasteAxis.kick.high)
                Spacer()
                Text(verbatim: TasteAxis.kick.low)
            }
            .padding(.vertical, 6)
            HStack {
                Text(verbatim: TasteAxis.depth.low)
                Spacer()
                Text(verbatim: TasteAxis.depth.high)
            }
            .padding(.horizontal, 8)
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }

    /// 같은 자리에 겹친 집은 그 둘레로 살짝 벌린다.
    private func spread(_ spots: [TasteReport.Spot]) -> [(spot: TasteReport.Spot, offset: CGSize)] {
        let groups = Dictionary(grouping: spots) { "\(Int((($0.depth) * 4).rounded()))-\(Int((($0.kick) * 4).rounded()))" }
        return groups.values.flatMap { group in
            group.enumerated().map { index, spot in
                guard group.count > 1 else { return (spot, .zero) }
                let angle = Double(index) / Double(group.count) * 2 * .pi
                return (spot, CGSize(width: cos(angle) * stamp * 0.6, height: sin(angle) * stamp * 0.6))
            }
        }
        .sorted { $0.spot.restaurant.regular.days < $1.spot.restaurant.regular.days }
    }
}

/// 맛 지도 위의 나 — 기록의 나(꽉 찬 원) · 내가 생각하는 나(점선 원).
struct TasteMapMarker: View {
    enum Kind { case record, guess }
    let kind: Kind
    var size: CGFloat = 30

    var body: some View {
        ZStack {
            switch kind {
            case .record:
                Circle().fill(.teal.gradient)
                Image(systemName: "person.fill")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(.white)
            case .guess:
                Circle().fill(.background)
                Circle().strokeBorder(.teal, style: StrokeStyle(lineWidth: max(size * 0.08, 1.5), dash: [3, 2]))
                Image(systemName: "person")
                    .font(.system(size: size * 0.45))
                    .foregroundStyle(.teal)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(kind == .record ? 0.2 : 0), radius: 2)
    }
}

private extension CGPoint {
    static func + (point: CGPoint, offset: CGSize) -> CGPoint {
        CGPoint(x: point.x + offset.width, y: point.y + offset.height)
    }
}

#Preview {
    TasteProfileView()
        .modelContainer(for: [Restaurant.self, TasteProfile.self], inMemory: true)
}
