//
//  ScoreViews.swift
//  인생 맛집
//
//  100점 점수를 매기는 칸, 이 집 점수의 흐름 · 맛의 변화, 내 이름을 건 맛집 (→ VisitScore.swift).
//

import SwiftUI
import Charts

// MARK: - 매기기

/// 방문 한 번의 100점 점수. 매기지 않아도 된다 — 처음엔 버튼 하나만 보인다.
struct VisitScoreSection: View {
    @Binding var score: Int?
    /// 고른 별 — 처음 매길 때 시작점으로 쓴다.
    var stars: Int = 0

    var body: some View {
        Section {
            if let value = score {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(scoreText(value))
                        .font(.largeTitle.weight(.bold).monospacedDigit())
                        .contentTransition(.numericText())
                    Text(verbatim: VisitScore.meaning(value))
                        .font(.headline)
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("지우기", role: .destructive) { score = nil }
                        .buttonStyle(.borderless)
                }
                .accessibilityElement(children: .combine)

                HStack(spacing: 12) {
                    step(-1, symbol: "minus.circle.fill", label: "1점 내리기")
                    Slider(value: Binding(
                        get: { Double(value) },
                        set: { score = Int($0.rounded()) }
                    ), in: 0...100, step: 1)
                    .accessibilityLabel(Text("100점 점수"))
                    .accessibilityValue(Text(verbatim: "\(scoreText(value)), \(VisitScore.meaning(value))"))
                    step(1, symbol: "plus.circle.fill", label: "1점 올리기")
                }
            } else {
                Button {
                    withAnimation { score = VisitScore.suggested(fromStars: stars) }
                } label: {
                    Label("100점 만점으로 매기기", systemImage: "gauge.with.needle")
                }
            }
        } header: {
            Text("100점 점수")
        } footer: {
            Text("다른 집과 견주지 말고 이 한 끼만 보고 매겨요. 90점은 일부러 찾아갈 맛, 70점은 또 와도 좋은 맛, 50점은 그저 그런 맛이에요.")
                .font(.body)
        }
    }

    private func step(_ delta: Int, symbol: String, label: LocalizedStringKey) -> some View {
        Button {
            guard let value = score else { return }
            withAnimation { score = min(max(value + delta, VisitScore.range.lowerBound), VisitScore.range.upperBound) }
        } label: {
            Image(systemName: symbol).font(.title2)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(label))
    }
}

func scoreText(_ value: Int) -> String {
    String(localized: "\(value)점", comment: "Visit score out of 100, e.g. '87 pts'")
}

func scoreText(_ value: Double) -> String {
    let rounded = value.formatted(.number.precision(.fractionLength(0...1)))
    return String(localized: "\(rounded)점", comment: "Average visit score out of 100, e.g. '86.5 pts'")
}

// MARK: - 이 집의 흐름

/// 방문마다 매긴 점수를 날짜 순으로 잇고, 처음과 요즘을 견준 한 줄을 붙인다.
struct ScoreSection: View {
    let restaurant: Restaurant
    /// 내 이름을 건 맛집 순위. 없으면 nil.
    let signatureRank: Int?
    let signatureTitle: String

    var body: some View {
        if let average = restaurant.averageScore {
            Section {
                LabeledContent("평균 점수") {
                    Text(verbatim: scoreText(average)).font(.headline.monospacedDigit())
                }
                if let signatureRank {
                    LabeledContent {
                        Text("\(signatureRank)위")
                    } label: {
                        Label { Text(verbatim: signatureTitle) } icon: {
                            Image(systemName: "signature").foregroundStyle(.orange)
                        }
                    }
                }
                if let trend = restaurant.scoreTrend {
                    ScoreTrendChart(trend: trend, average: average)
                        .frame(height: 180)
                        .padding(.vertical, 4)
                    Label {
                        Text(verbatim: trend.sentence)
                    } icon: {
                        Image(systemName: trend.symbol).foregroundStyle(color(trend.direction))
                    }
                } else {
                    Text("두 번 넘게 매기면 점수가 어떻게 달라지는지 보여요.")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("내 점수")
            }
        }
    }

    private func color(_ direction: ScoreTrend.Direction) -> Color {
        switch direction {
        case .rising: .green
        case .steady: .blue
        case .falling: .red
        }
    }
}

struct ScoreTrendChart: View {
    let trend: ScoreTrend
    let average: Double

    var body: some View {
        let low = trend.points.map(\.score).min() ?? 0
        let floor = Swift.max(0, (low - 10) / 10 * 10)
        Chart {
            RuleMark(y: .value(Text("평균"), average))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(.secondary)
            ForEach(trend.points) { point in
                LineMark(x: .value(Text("방문 날짜"), point.date), y: .value(Text("점수"), point.score))
                    .interpolationMethod(.monotone)
                    .foregroundStyle(.orange)
                PointMark(x: .value(Text("방문 날짜"), point.date), y: .value(Text("점수"), point.score))
                    .foregroundStyle(.orange)
            }
        }
        .chartYScale(domain: floor...100)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - 내가 느끼는 맛의 변화

/// 같은 집인데 처음과 요즘 맛을 다르게 적었나. 두 번 넘게 적은 축만.
struct TasteShiftSection: View {
    let restaurant: Restaurant

    var body: some View {
        let shifts = restaurant.tasteShifts
        if !shifts.isEmpty {
            let changed = shifts.filter(\.isNoticeable).count
            Section {
                ForEach(shifts) { shift in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(verbatim: shift.axis.title).font(.headline)
                            Spacer()
                            Text(verbatim: shift.axis.describe(shift.early))
                                .foregroundStyle(.secondary)
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                            Text(verbatim: shift.axis.describe(shift.recent))
                                .fontWeight(shift.isNoticeable ? .semibold : .regular)
                        }
                        Text(verbatim: shift.isNoticeable ? shift.sentence : String(localized: "처음과 비슷해요"))
                            .foregroundStyle(shift.isNoticeable ? .orange : .secondary)
                    }
                    .accessibilityElement(children: .combine)
                }
            } header: {
                Text("내가 느끼는 맛의 변화")
            } footer: {
                Group {
                    if changed == 0 {
                        Text("갈 때마다 맛을 비슷하게 느끼고 있어요.")
                    } else {
                        Text("처음 몇 번과 요즘 몇 번에 적은 맛을 견줘요. \(changed)가지가 달라졌어요.")
                    }
                }
                .font(.body)
            }
        }
    }
}

// MARK: - 내 이름을 건 맛집

enum SignatureList {
    static let nameKey = "signature.name"

    /// "레오의 맛집". 이름을 적지 않았으면 단골 후기 별명을, 그것도 없으면 "내 이름을 건 맛집".
    @MainActor
    static func title(_ stored: String) -> String {
        let name = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = RegularReviews.shared.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        let chosen = name.isEmpty ? fallback : name
        return chosen.isEmpty
            ? String(localized: "내 이름을 건 맛집", comment: "Top-6 list by average score, before the user sets a name")
            : String(localized: "\(chosen)의 맛집", comment: "Top-6 list by average score, named after the user, e.g. 'Leeo’s Picks'")
    }
}

/// 내 이름을 건 맛집 한 줄 — 순위 · 이름 · 평균 점수.
struct SignatureRow: View {
    let restaurant: Restaurant
    let rank: Int

    var body: some View {
        if !restaurant.isGone {
            HStack(spacing: 12) {
                Text(verbatim: "\(rank)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(rank <= 3 ? Color.orange : Color.gray, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: restaurant.name).font(.headline)
                    Text(verbatim: restaurant.foodCategory.localizedName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let average = restaurant.averageScore {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: scoreText(average))
                            .font(.title3.weight(.bold).monospacedDigit())
                        Text("\(restaurant.scoredVisits.count)번 매김")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)
        }
    }
}
