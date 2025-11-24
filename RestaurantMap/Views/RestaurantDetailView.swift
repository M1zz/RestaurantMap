import SwiftUI
import MapKit
import SwiftData

struct RestaurantDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var restaurant: Restaurant
    
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    if isEditing {
                        TextField("식당 이름", text: $restaurant.name)
                        TextField("주소", text: $restaurant.address)
                        TextField("카테고리", text: $restaurant.category)
                        TextField("전화번호", text: $restaurant.phoneNumber)
                    } else {
                        LabeledContent("식당 이름", value: restaurant.name)
                        LabeledContent("주소", value: restaurant.address)
                        if !restaurant.category.isEmpty {
                            LabeledContent("카테고리", value: restaurant.category)
                        }
                        if !restaurant.phoneNumber.isEmpty {
                            LabeledContent("전화번호") {
                                Link(restaurant.phoneNumber, destination: URL(string: "tel://\(restaurant.phoneNumber)")!)
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
                
                Section("방문 정보") {
                    if isEditing {
                        DatePicker("방문 날짜", selection: $restaurant.visitDate, displayedComponents: .date)
                        
                        VStack(alignment: .leading) {
                            Text("별점")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                ForEach(1..<6) { index in
                                    Image(systemName: index <= restaurant.rating ? "star.fill" : "star")
                                        .foregroundStyle(index <= restaurant.rating ? .yellow : .gray)
                                        .font(.system(size: 24))
                                        .onTapGesture {
                                            restaurant.rating = index
                                        }
                                }
                            }
                        }
                    } else {
                        LabeledContent("방문 날짜") {
                            Text(restaurant.visitDate, format: .dateTime.year().month().day())
                        }
                        
                        LabeledContent("별점") {
                            HStack(spacing: 2) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < restaurant.rating ? "star.fill" : "star")
                                        .foregroundStyle(index < restaurant.rating ? .yellow : .gray)
                                        .font(.system(size: 14))
                                }
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
                    
                    LabeledContent("좌표") {
                        VStack(alignment: .trailing) {
                            Text("위도: \(restaurant.latitude, specifier: "%.6f")")
                            Text("경도: \(restaurant.longitude, specifier: "%.6f")")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "http://maps.apple.com/?ll=\(restaurant.latitude),\(restaurant.longitude)")!) {
                        HStack {
                            Text("Apple 지도에서 열기")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
                
                Section("메모") {
                    if isEditing {
                        TextEditor(text: $restaurant.notes)
                            .frame(minHeight: 100)
                    } else {
                        if restaurant.notes.isEmpty {
                            Text("메모 없음")
                                .foregroundStyle(.secondary)
                        } else {
                            Text(restaurant.notes)
                        }
                    }
                }

                // 취향 프로필 섹션
                Section {
                    VStack(spacing: 16) {
                        HStack {
                            Text("맛 취향 프로필")
                                .font(.headline)
                            Spacer()
                            if restaurant.hasTasteProfile && !isEditing {
                                Text("✓ 평가됨")
                                    .font(.caption)
                                    .foregroundStyle(.green)
                            }
                        }

                        if restaurant.hasTasteProfile && !isEditing {
                            // 레이더 차트 표시
                            RadarChartView(data: restaurant.tasteRadarData)
                                .frame(height: 250)
                        }

                        if isEditing {
                            VStack(spacing: 12) {
                                TasteSliderRow(title: "🌶️ 맵기", subtitle: "순한 ↔ 매운", value: Binding(
                                    get: { restaurant.spicy ?? 5.0 },
                                    set: { restaurant.spicy = $0 }
                                ))
                                TasteSliderRow(title: "💪 진한맛", subtitle: "담백 ↔ 진한", value: Binding(
                                    get: { restaurant.boldness ?? 5.0 },
                                    set: { restaurant.boldness = $0 }
                                ))
                                TasteSliderRow(title: "🍯 단맛", subtitle: "안좋아함 ↔ 좋아함", value: Binding(
                                    get: { restaurant.sweetness ?? 5.0 },
                                    set: { restaurant.sweetness = $0 }
                                ))
                                TasteSliderRow(title: "🧂 짠맛", subtitle: "싱거움 ↔ 짭짤", value: Binding(
                                    get: { restaurant.saltiness ?? 5.0 },
                                    set: { restaurant.saltiness = $0 }
                                ))
                                TasteSliderRow(title: "🥓 기름진", subtitle: "담백 ↔ 고소", value: Binding(
                                    get: { restaurant.richness ?? 5.0 },
                                    set: { restaurant.richness = $0 }
                                ))
                                TasteSliderRow(title: "🌿 본연의맛", subtitle: "양념 ↔ 재료맛", value: Binding(
                                    get: { restaurant.naturalTaste ?? 5.0 },
                                    set: { restaurant.naturalTaste = $0 }
                                ))
                                TasteSliderRow(title: "✨ 질감", subtitle: "부드러움 ↔ 쫄깃", value: Binding(
                                    get: { restaurant.texture ?? 5.0 },
                                    set: { restaurant.texture = $0 }
                                ))
                                TasteSliderRow(title: "🔥 조리법", subtitle: "날것 ↔ 구이", value: Binding(
                                    get: { restaurant.cooking ?? 5.0 },
                                    set: { restaurant.cooking = $0 }
                                ))
                            }
                        } else if !restaurant.hasTasteProfile {
                            Text("이 식당의 맛 취향을 평가하려면 '편집'을 눌러주세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }
                    }
                } header: {
                    Text("이 식당은 어땠나요?")
                }
                
                if !isEditing {
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
                Text("'\(restaurant.name)'을(를) 삭제하시겠습니까?")
            }
        }
    }
    
    private func deleteRestaurant() {
        modelContext.delete(restaurant)
        dismiss()
    }
}

// MARK: - Taste Slider Row
struct TasteSliderRow: View {
    let title: String
    let subtitle: String
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
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

            Slider(value: $value, in: 0...10, step: 1)
                .tint(.blue)

            HStack {
                Text(subtitle.components(separatedBy: " ↔ ").first ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(subtitle.components(separatedBy: " ↔ ").last ?? "")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Restaurant.self, configurations: config)
    
    let restaurant = Restaurant(
        name: "샘플 식당",
        address: "서울시 중구 태평로 1가",
        latitude: 37.5665,
        longitude: 126.9780,
        notes: "맛있었어요!",
        rating: 4,
        category: "한식"
    )
    container.mainContext.insert(restaurant)
    
    return RestaurantDetailView(restaurant: restaurant)
        .modelContainer(container)
}
