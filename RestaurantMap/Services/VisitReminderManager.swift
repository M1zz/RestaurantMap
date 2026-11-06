import Foundation
import CoreLocation
import UserNotifications
import SwiftData
import OSLog

/// 저장된 가게 근처 방문 후 40분 뒤 리뷰 요청 푸시 알림을 관리하는 서비스
///
/// 설정 ▸ '다녀온 뒤 기록 알림' 을 켠 사람만 돈다 (Pro). 앱을 열 때 저절로 권한을 묻거나 위치를 따라가지 않는다.
/// 켜고 끄는 길은 `apply(allowed:)` 하나다 — 켠 사람이고 칸이 허락할 때만 위치를 본다.
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

    /// 지금 위치를 보고 있는가. 꺼져 있으면 위치 권한이 바뀌어도 따라가지 않는다.
    private(set) var isActive = false

    /// 알림을 허락받지 못해 켜지 못했는가 (설정에서 그렇다고 알린다).
    private(set) var notificationsDenied = false

    // MARK: - 켜고 끄기

    private static let enabledKey = "visitReminder.enabled"

    /// 사용자가 이 알림을 원하는가. 처음엔 꺼져 있다.
    var wantsReminders = UserDefaults.standard.bool(forKey: VisitReminderManager.enabledKey) {
        didSet { UserDefaults.standard.set(wantsReminders, forKey: Self.enabledKey) }
    }

    /// 예전 빌드는 앱을 열 때마다 알림을 켰다. 그때 알림을 허락한 사람은 켜 둔 채로 잇는다 (한 번만 본다).
    func carryOverEarlierChoice() async {
        guard UserDefaults.standard.object(forKey: Self.enabledKey) == nil else { return }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        wantsReminders = settings.authorizationStatus == .authorized
    }

    /// 원하는 사람이고 칸이 허락하면 켜고, 아니면 끈다.
    func apply(allowed: Bool) async {
        guard allowed, wantsReminders else {
            if isActive { stopMonitoring() }
            isActive = false
            cancelScheduledNotification()
            return
        }
        guard await requestNotificationPermission() else {
            notificationsDenied = true
            if isActive { stopMonitoring() }
            isActive = false
            return
        }
        notificationsDenied = false
        guard !isActive else { return }
        isActive = true
        startMonitoring()
    }

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
        guard isActive, let currentLocation = locations.last else { return }

        checkProximityToRestaurants(currentLocation: currentLocation)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 꺼져 있으면 권한이 바뀌어도 위치를 따라가지 않는다 (만들어질 때도 한 번 불린다).
        guard isActive else { return }
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
        content.title = String(localized: "오늘 방문은 어떠셨나요? 🍽️")
        content.body = String(localized: "\(restaurantName)에서의 식사는 만족스러우셨나요? 방문 기록을 남겨보세요!")
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
