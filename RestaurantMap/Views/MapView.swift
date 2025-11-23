import SwiftUI
import MapKit
import SwiftData

struct MapView: View {
    @Environment(\.modelContext) private var modelContext
    let restaurants: [Restaurant]

    @State private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic
    @State private var showingAddSheet = false
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var selectedRestaurant: Restaurant?
    @State private var showingDetail = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $position) {
                    if locationManager.userLocation != nil {
                        UserAnnotation()
                    }
                    
                    ForEach(restaurants) { restaurant in
                        Annotation(restaurant.name, coordinate: restaurant.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(.red)
                                    .frame(width: 30, height: 30)
                                Image(systemName: "fork.knife")
                                    .foregroundStyle(.white)
                                    .font(.system(size: 14))
                            }
                            .onTapGesture {
                                selectedRestaurant = restaurant
                                showingDetail = true
                            }
                        }
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                }
                
                // 플로팅 버튼
                VStack(spacing: 12) {
                    // 현재 위치에 추가 버튼
                    Button {
                        addRestaurantAtCurrentLocation()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.blue)
                                .frame(width: 56, height: 56)
                                .shadow(radius: 4)
                            Image(systemName: "location.fill")
                                .foregroundStyle(.white)
                                .font(.system(size: 24))
                        }
                    }
                    
                    // 수동으로 위치 선택 버튼
                    Button {
                        showingAddSheet = true
                    } label: {
                        ZStack {
                            Circle()
                                .fill(.green)
                                .frame(width: 56, height: 56)
                                .shadow(radius: 4)
                            Image(systemName: "plus")
                                .foregroundStyle(.white)
                                .font(.system(size: 24))
                        }
                    }
                }
                .padding(.trailing, 16)
                .padding(.bottom, 16)
            }
            .navigationTitle("식당 지도")
            .sheet(isPresented: $showingAddSheet) {
                AddRestaurantView(coordinate: selectedCoordinate)
            }
            .sheet(isPresented: $showingDetail) {
                if let restaurant = selectedRestaurant {
                    RestaurantDetailView(restaurant: restaurant)
                }
            }
            .onAppear {
                locationManager.requestLocation()
            }
            .onChange(of: locationManager.userLocation) { oldValue, newValue in
                if let location = newValue {
                    // 사용자 위치를 중심으로 적절한 줌 레벨로 지도 이동
                    // span 값: 0.01은 약 1km 반경을 보여줍니다
                    position = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    ))
                }
            }
        }
    }
    
    private func addRestaurantAtCurrentLocation() {
        // 현재 위치를 사용하거나, 없으면 기본 위치 사용
        selectedCoordinate = locationManager.userLocation ?? CLLocationCoordinate2D(latitude: 37.5665, longitude: 126.9780)
        showingAddSheet = true
    }
}

#Preview {
    MapView(restaurants: [])
        .modelContainer(for: Restaurant.self, inMemory: true)
}
