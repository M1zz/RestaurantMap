import Foundation
import CoreLocation
import UserNotifications
import SwiftData
import OSLog

/// 저장된 가게 근처 방문 후 40분 뒤 리뷰 요청 푸시 알림을 관리하는 서비스
@Observable
class VisitReminderManager: NSObject, CLLocationManagerDelegate {
    static let shared = VisitReminderManager()

    private let locationManager = CLLocationManager()
    private let logger = Logger(subsystem: "com.restaurantmap", category: "VisitReminder")

    // 설정값
    private let proximityRadius: CLLocationDistance = 50 // 가게 근처 판정 반경 (미터)
    private let reminderDelay: TimeInterval = 40 * 60 // 40분 (초 단위)

    // 상태 추적
    private var modelContainer: ModelContainer?
    private var currentlyVisitingRestaurant: (id: String, name: String, enteredAt: Date)?
    private var scheduledNotificationId: String?
    private var lastCheckedRestaurants: [RestaurantLocation] = []

    // 간단한 레스토랑 위치 정보 구조체
    private struct RestaurantLocation {
        let id: String
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.pausesLocationUpdatesAutomatically = false
        locationManager.distanceFilter = 20 // 20미터마다 업데이트
    }

    // MARK: - Public Methods

    /// ModelContainer 설정
    func configure(with container: ModelContainer) {
        self.modelContainer = container
        logger.info("VisitReminderManager configured with ModelContainer")
    }

    /// 알림 권한 요청
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            )
            logger.info("알림 권한 요청 결과: \(granted)")
            return granted
        } catch {
            logger.error("알림 권한 요청 실패: \(error.localizedDescription)")
            return false
        }
    }

    /// 위치 추적 시작
    func startMonitoring() {
        let status = locationManager.authorizationStatus

        switch status {
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
            refreshRestaurantList()
            logger.info("위치 모니터링 시작됨 (Always 권한)")
        case .authorizedWhenInUse:
            // WhenInUse 권한일 경우 Always 권한 요청
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
            refreshRestaurantList()
            logger.info("위치 모니터링 시작됨 (WhenInUse 권한, Always 권한 요청)")
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            logger.warning("위치 권한이 거부됨")
        @unknown default:
            break
        }
    }

    /// 위치 추적 중지
    func stopMonitoring() {
        locationManager.stopUpdatingLocation()
        logger.info("위치 모니터링 중지됨")
    }

    /// 저장된 레스토랑 목록 새로고침
    func refreshRestaurantList() {
        guard let container = modelContainer else {
            logger.warning("ModelContainer가 설정되지 않음")
            return
        }

        Task { @MainActor in
            do {
                let context = container.mainContext
                let descriptor = FetchDescriptor<Restaurant>()
                let restaurants = try context.fetch(descriptor)

                lastCheckedRestaurants = restaurants.map { restaurant in
                    RestaurantLocation(
                        id: restaurant.name + restaurant.address, // 고유 식별자
                        name: restaurant.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: restaurant.latitude,
                            longitude: restaurant.longitude
                        )
                    )
                }

                logger.info("레스토랑 목록 새로고침: \(self.lastCheckedRestaurants.count)개")
            } catch {
                logger.error("레스토랑 목록 가져오기 실패: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }

        checkProximityToRestaurants(currentLocation: currentLocation)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedAlways:
            locationManager.startUpdatingLocation()
            refreshRestaurantList()
            logger.info("Always 위치 권한 허용됨")
        case .authorizedWhenInUse:
            locationManager.requestAlwaysAuthorization()
            locationManager.startUpdatingLocation()
            refreshRestaurantList()
            logger.info("WhenInUse 위치 권한 허용됨, Always 권한 요청")
        case .denied, .restricted:
            logger.warning("위치 권한이 거부됨")
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("위치 업데이트 실패: \(error.localizedDescription)")
    }

    // MARK: - Private Methods

    /// 현재 위치가 저장된 레스토랑 근처인지 확인
    private func checkProximityToRestaurants(currentLocation: CLLocation) {
        // 가장 가까운 레스토랑 찾기
        var nearestRestaurant: RestaurantLocation?
        var nearestDistance: CLLocationDistance = .infinity

        for restaurant in lastCheckedRestaurants {
            let restaurantLocation = CLLocation(
                latitude: restaurant.coordinate.latitude,
                longitude: restaurant.coordinate.longitude
            )
            let distance = currentLocation.distance(from: restaurantLocation)

            if distance < proximityRadius && distance < nearestDistance {
                nearestDistance = distance
                nearestRestaurant = restaurant
            }
        }

        // 상태 업데이트
        if let restaurant = nearestRestaurant {
            // 가게 근처에 있음
            if currentlyVisitingRestaurant == nil || currentlyVisitingRestaurant?.id != restaurant.id {
                // 새로운 가게에 도착
                enterRestaurant(restaurant)
            }
        } else {
            // 가게 근처에 없음
            if currentlyVisitingRestaurant != nil {
                // 가게를 떠남
                leaveRestaurant()
            }
        }
    }

    /// 가게에 도착했을 때
    private func enterRestaurant(_ restaurant: RestaurantLocation) {
        // 이전 알림 취소
        cancelScheduledNotification()

        currentlyVisitingRestaurant = (
            id: restaurant.id,
            name: restaurant.name,
            enteredAt: Date()
        )

        logger.info("가게 도착: \(restaurant.name)")
    }

    /// 가게를 떠났을 때
    private func leaveRestaurant() {
        guard let visiting = currentlyVisitingRestaurant else { return }

        let stayDuration = Date().timeIntervalSince(visiting.enteredAt)

        // 최소 5분 이상 머물렀을 때만 알림 예약
        if stayDuration >= 5 * 60 {
            scheduleReminderNotification(restaurantName: visiting.name)
            logger.info("가게 떠남: \(visiting.name), 체류시간: \(Int(stayDuration / 60))분, 알림 예약됨")
        } else {
            logger.info("가게 떠남: \(visiting.name), 체류시간: \(Int(stayDuration / 60))분, 알림 예약 안함 (최소 체류시간 미달)")
        }

        currentlyVisitingRestaurant = nil
    }

    /// 40분 후 알림 예약
    private func scheduleReminderNotification(restaurantName: String) {
        // 이전 알림 취소
        cancelScheduledNotification()

        let content = UNMutableNotificationContent()
        content.title = "오늘 방문은 어떠셨나요? 🍽️"
        content.body = "\(restaurantName)에서의 식사는 만족스러우셨나요? 방문 기록을 남겨보세요!"
        content.sound = .default
        content.categoryIdentifier = "VISIT_REMINDER"
        content.userInfo = ["restaurantName": restaurantName]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: reminderDelay,
            repeats: false
        )

        let notificationId = UUID().uuidString
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.error("알림 예약 실패: \(error.localizedDescription)")
            } else {
                self?.scheduledNotificationId = notificationId
                self?.logger.info("알림 예약 완료: \(restaurantName), 40분 후 발송")
            }
        }
    }

    /// 예약된 알림 취소
    private func cancelScheduledNotification() {
        if let notificationId = scheduledNotificationId {
            UNUserNotificationCenter.current().removePendingNotificationRequests(
                withIdentifiers: [notificationId]
            )
            scheduledNotificationId = nil
            logger.info("예약된 알림 취소됨")
        }
    }
}
