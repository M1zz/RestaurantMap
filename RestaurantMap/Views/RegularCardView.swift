//
//  RegularCardView.swift
//  인생 맛집
//
//  단골 후기 한 장 — 후기 목록, 올리기 전 미리보기, 그림으로 내보내는 카드가 모두 이것을 쓴다.
//

import SwiftUI

struct RegularCardView: View {
    let review: RegularReview
    /// 그림으로 내보낼 때는 앱 이름을 발치에 넣고, 올린 날은 뺀다.
    var forExport = false

    private var tint: Color { review.level == .lifetime ? .orange : .pink }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VisitStamp(days: review.days, level: review.level, size: 44)

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: review.placeName)
                        .font(.headline)
                    if !review.address.isEmpty {
                        Text(verbatim: review.address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                if review.rating > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill").foregroundStyle(.yellow)
                        Text(verbatim: review.rating.formatted(.number.precision(.fractionLength(1))))
                    }
                    .font(.subheadline.weight(.semibold))
                    .starRatingLabel(review.rating)
                }
            }

            HStack(spacing: 8) {
                HStack(spacing: 3) {
                    Image(systemName: review.level.symbol).font(.caption2).accessibilityHidden(true)
                    Text(verbatim: review.level.title).font(.caption.weight(.semibold))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(tint.opacity(0.15), in: Capsule())
                .foregroundStyle(tint)

                Text(verbatim: review.visitLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !review.criteria.isEmpty {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    let shown = GourmetCriterion.allCases.filter { review.criteria[$0] != nil }
                    ForEach(Array(stride(from: 0, to: shown.count, by: 2)), id: \.self) { index in
                        GridRow {
                            meter(shown[index])
                            if index + 1 < shown.count { meter(shown[index + 1]) }
                        }
                    }
                }
            }

            if let consistency = review.consistency {
                Label {
                    Text(verbatim: consistency.title)
                } icon: {
                    Image(systemName: "equal.circle.fill").foregroundStyle(.orange)
                }
                .font(.caption)
            }

            if !review.text.isEmpty {
                Text(verbatim: review.text)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Text(verbatim: review.nickname)
                    .font(.caption.weight(.semibold))
                if forExport {
                    Spacer()
                    Text("인생 맛집")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.orange)
                } else {
                    Text(review.postedAt, format: .relative(presentation: .named))
                        .font(.caption)
                    Spacer()
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func meter(_ criterion: GourmetCriterion) -> some View {
        let value = review.criteria[criterion] ?? 0
        return HStack(spacing: 6) {
            Text(verbatim: criterion.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            // 도형으로 그린다 — 그림으로 내보낼 때(ImageRenderer) 시스템 진행 막대는 그려지지 않는다
            ZStack(alignment: .leading) {
                Capsule().fill(.gray.opacity(0.25))
                Capsule().fill(.orange).frame(width: 44 * min(max(value, 0), 5) / 5)
            }
            .frame(width: 44, height: 4)
            Text(verbatim: value.formatted(.number.precision(.fractionLength(1))))
                .font(.caption.monospacedDigit())
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: criterion.title))
        .accessibilityValue(Text("\(value.formatted(.number.precision(.fractionLength(1))))점"))
    }
}

// MARK: - 그림으로 내보내기

/// 단골 카드를 그림으로 만들어 공유 시트에 넘긴다. 서버를 거치지 않는다.
struct RegularCardShareLink: View {
    let review: RegularReview
    @Environment(\.displayScale) private var displayScale
    @State private var image: Image?

    var body: some View {
        Group {
            if let image {
                ShareLink(item: image, preview: SharePreview(Text(verbatim: review.placeName), image: image)) {
                    Label("단골 카드 공유", systemImage: "square.and.arrow.up")
                }
            } else {
                Label("단골 카드 공유", systemImage: "square.and.arrow.up")
                    .foregroundStyle(.secondary)
            }
        }
        .task(id: review) { image = render() }
    }

    @MainActor
    private func render() -> Image? {
        let card = RegularCardView(review: review, forExport: true)
            .padding(24)
            .frame(width: 360)
            .background(Color(red: 1.0, green: 0.97, blue: 0.91))
            .environment(\.colorScheme, .light)
        let renderer = ImageRenderer(content: card)
        renderer.scale = max(displayScale, 2)
        return renderer.uiImage.map(Image.init(uiImage:))
    }
}
