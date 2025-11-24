import SwiftUI
import SwiftData

struct TasteProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var profiles: [TasteProfile]

    @State private var profile: TasteProfile
    @State private var isEditing = false

    init() {
        // 초기 프로필 생성
        _profile = State(initialValue: TasteProfile())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // 레이더 차트
                    RadarChartView(data: profile.radarData)
                        .frame(height: 300)
                        .padding()

                    // 설명
                    VStack(spacing: 8) {
                        Text("나의 미식 DNA")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("6가지 속성으로 나의 취향을 표현합니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // 슬라이더 섹션
                    if isEditing {
                        editingSection
                    } else {
                        attributesListView
                    }

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .navigationTitle("취향 프로필")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "완료" : "수정") {
                        withAnimation {
                            isEditing.toggle()
                            if !isEditing {
                                saveProfile()
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadProfile()
            }
        }
    }

    private var attributesListView: some View {
        VStack(spacing: 16) {
            Text("맛 선호도")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

            AttributeRowView(title: "🌶️ 맵기", value: profile.spicy, subtitle: "순한 ↔ 매운")
            AttributeRowView(title: "💪 진한맛", value: profile.boldness, subtitle: "담백 ↔ 진한")
            AttributeRowView(title: "🍯 단맛", value: profile.sweetness, subtitle: "안좋아함 ↔ 좋아함")
            AttributeRowView(title: "🧂 짠맛", value: profile.saltiness, subtitle: "싱거움 ↔ 짭짤")
            AttributeRowView(title: "🥓 기름진", value: profile.richness, subtitle: "담백 ↔ 고소")

            Divider()
                .padding(.vertical, 8)

            Text("음식 스타일")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            AttributeRowView(title: "🌿 본연의맛", value: profile.naturalTaste, subtitle: "양념 ↔ 재료맛")
            AttributeRowView(title: "✨ 질감", value: profile.texture, subtitle: "부드러움 ↔ 쫄깃")
            AttributeRowView(title: "🔥 조리법", value: profile.cooking, subtitle: "날것 ↔ 구이")
        }
        .padding(.horizontal)
    }

    private var editingSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 16) {
                Text("맛 선호도")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                SliderRowView(title: "🌶️ 맵기", subtitle: "순한 ↔ 매운", value: $profile.spicy)
                SliderRowView(title: "💪 진한맛", subtitle: "담백 ↔ 진한", value: $profile.boldness)
                SliderRowView(title: "🍯 단맛", subtitle: "안좋아함 ↔ 좋아함", value: $profile.sweetness)
                SliderRowView(title: "🧂 짠맛", subtitle: "싱거움 ↔ 짭짤", value: $profile.saltiness)
                SliderRowView(title: "🥓 기름진", subtitle: "담백 ↔ 고소", value: $profile.richness)
            }

            Divider()

            VStack(spacing: 16) {
                Text("음식 스타일")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                SliderRowView(title: "🌿 본연의맛", subtitle: "양념 ↔ 재료맛", value: $profile.naturalTaste)
                SliderRowView(title: "✨ 질감", subtitle: "부드러움 ↔ 쫄깃", value: $profile.texture)
                SliderRowView(title: "🔥 조리법", subtitle: "날것 ↔ 구이", value: $profile.cooking)
            }
        }
        .padding(.horizontal)
    }

    private func loadProfile() {
        if let existingProfile = profiles.first {
            profile = existingProfile
        } else {
            // 새 프로필 생성
            let newProfile = TasteProfile()
            modelContext.insert(newProfile)
            profile = newProfile
        }
    }

    private func saveProfile() {
        profile.updatedAt = Date()
        try? modelContext.save()
    }
}

// MARK: - Attribute Row View
struct AttributeRowView: View {
    let title: String
    let value: Double
    let subtitle: String

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(Int(value))")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 배경
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.gray.opacity(0.15))

                    // 값 표시
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.blue.gradient)
                        .frame(width: geometry.size.width * (value / 10))
                }
            }
            .frame(height: 20)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Slider Row View
struct SliderRowView: View {
    let title: String
    let subtitle: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(Int(value))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
            }

            Slider(value: $value, in: 0...10, step: 1)
                .tint(.blue)

            HStack {
                Text(subtitle.components(separatedBy: " ↔ ").first ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(subtitle.components(separatedBy: " ↔ ").last ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.gray.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Radar Chart View
struct RadarChartView: View {
    let data: [(String, Double, String)]
    let maxValue: Double = 10.0

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2 - 40

            ZStack {
                // 배경 그리드 (3단계)
                ForEach(1...3, id: \.self) { level in
                    radarPolygon(
                        center: center,
                        radius: radius * Double(level) / 3,
                        sides: data.count
                    )
                    .stroke(.gray.opacity(0.2), lineWidth: 1)
                }

                // 메인 데이터 영역
                radarDataPolygon(center: center, radius: radius)
                    .fill(.blue.opacity(0.2))

                radarDataPolygon(center: center, radius: radius)
                    .stroke(.blue, lineWidth: 2)

                // 축 선
                ForEach(0..<data.count, id: \.self) { index in
                    let angle = angleForIndex(index, total: data.count)
                    let endPoint = pointOnCircle(
                        center: center,
                        radius: radius,
                        angle: angle
                    )

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: endPoint)
                    }
                    .stroke(.gray.opacity(0.3), lineWidth: 1)
                }

                // 데이터 포인트
                ForEach(0..<data.count, id: \.self) { index in
                    let angle = angleForIndex(index, total: data.count)
                    let value = data[index].1
                    let distance = radius * (value / maxValue)
                    let point = pointOnCircle(
                        center: center,
                        radius: distance,
                        angle: angle
                    )

                    Circle()
                        .fill(.blue)
                        .frame(width: 8, height: 8)
                        .position(point)
                }

                // 라벨
                ForEach(0..<data.count, id: \.self) { index in
                    let angle = angleForIndex(index, total: data.count)
                    let labelRadius = radius + 30
                    let point = pointOnCircle(
                        center: center,
                        radius: labelRadius,
                        angle: angle
                    )

                    Text(data[index].0)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .position(point)
                }
            }
        }
    }

    private func radarPolygon(center: CGPoint, radius: CGFloat, sides: Int) -> Path {
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

    private func radarDataPolygon(center: CGPoint, radius: CGFloat) -> Path {
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
    TasteProfileView()
        .modelContainer(for: TasteProfile.self, inMemory: true)
}
