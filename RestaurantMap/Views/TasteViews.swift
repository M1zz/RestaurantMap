//
//  TasteViews.swift
//  인생 맛집
//
//  맛 축을 적고 보여 주는 조각들 (→ Models/Taste.swift).
//  적을 때는 양 끝 말 사이의 다섯 점, 볼 때는 같은 막대 위의 한 점 — 같은 모양이라 따로 배우지 않는다.
//

import SwiftUI

// MARK: - 적기

/// 방문의 맛. 기본 두 축은 늘 보이고, 계열 축은 접어 둔다. 모두 선택이고, 고른 점을 다시 누르면 지워진다.
struct TasteInputSection: View {
    let family: TasteFamily
    @Binding var values: [TasteAxis: Int]
    @State private var showsFamily: Bool

    init(family: TasteFamily, values: Binding<[TasteAxis: Int]>) {
        self.family = family
        _values = values
        // 이미 적어 둔 계열 축이 있으면 펼쳐서 보여 준다
        _showsFamily = State(initialValue: family.axes.contains { values.wrappedValue[$0] != nil })
    }

    var body: some View {
        Section {
            ForEach(TasteAxis.basic) { axis in
                TasteAxisInput(axis: axis, value: binding(axis))
            }
            if !family.axes.isEmpty {
                DisclosureGroup(isExpanded: $showsFamily) {
                    ForEach(family.axes) { axis in
                        TasteAxisInput(axis: axis, value: binding(axis))
                    }
                } label: {
                    Text("\(family.emoji) \(family.title) 맛 더 적기", comment: "Expand optional taste notes for a food family, e.g. '🥩 Meat: more notes'")
                }
            }
        } header: {
            Text("맛")
        } footer: {
            Text("어떤 맛이었는지 적어요. 잘 만들었는지는 미식 기준에서 봐요.")
        }
    }

    private func binding(_ axis: TasteAxis) -> Binding<Int?> {
        Binding(get: { values[axis] }, set: { values[axis] = $0 })
    }
}

/// 축 하나 — 왼쪽 끝 말, 다섯 점, 오른쪽 끝 말.
struct TasteAxisInput: View {
    let axis: TasteAxis
    @Binding var value: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: axis.title)
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 8) {
                Text(verbatim: axis.low)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .leading)
                ForEach(1...5, id: \.self) { step in
                    Circle()
                        .fill(value == step ? Color.teal : Color.gray.opacity(0.2))
                        .frame(width: 26, height: 26)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture { value = value == step ? nil : step }
                }
                Text(verbatim: axis.high)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 64, alignment: .trailing)
            }
            .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "\(axis.title), \(axis.low) – \(axis.high)"))
        .accessibilityValue(value.map { Text(verbatim: axis.describe(Double($0))) } ?? Text("적지 않음"))
        .accessibilityAdjustableAction { direction in
            let now = value ?? 0
            switch direction {
            case .increment: value = min(now + 1, 5)
            case .decrement: value = now > 1 ? now - 1 : nil
            @unknown default: break
            }
        }
    }
}

// MARK: - 보기

/// 축 하나의 값(평균이면 소수)을 막대 위 한 점으로.
struct TasteAxisBar: View {
    let axis: TasteAxis
    let value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(verbatim: axis.title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(verbatim: axis.describe(value))
                    .font(.caption)
                    .foregroundStyle(.teal)
            }
            HStack(spacing: 8) {
                Text(verbatim: axis.low)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .leading)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.gray.opacity(0.15)).frame(height: 6)
                        Circle()
                            .fill(.teal)
                            .frame(width: 14, height: 14)
                            .offset(x: (geo.size.width - 14) * (min(max(value, 1), 5) - 1) / 4)
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(height: 14)
                Text(verbatim: axis.high)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 56, alignment: .trailing)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: axis.title))
        .accessibilityValue(Text(verbatim: axis.describe(value)))
    }
}
