import Foundation
import CoreLocation
import UserNotifications
import SwiftData
import OSLog

/// 저장한 가게에 다녀오면 40분 뒤 방문 기록을 남기라고 알린다.
///
/// 설정 ▸ '다녀온 뒤 기록 알림' 을 켠 사람만 돈다 (Pro). 앱을 열 때 저절로 권한을 묻거나 위치를 따라가지 않는다.
/// 켜고 끄는 길은 `apply(allowed:)` 하나다 — 켠 사람이고 칸이 허락할 때만 위치를 본다.
///
/// ⚠️ 위치를 계속 받지 않는다. 시스템의 **방문 감지**(`startMonitoringVisits`)만 쓴다 —
///    어딘가에 머물다 떠나면 시스템이 한 번 알려 주고, 그때 저장한 가게 근처였는지만 본다.
///    예전에는 백그라운드에서 최고 정확도 위치를 20m 마다 받아 배터리를 많이 썼다.
///    앱이 꺼져 있어도 시스템이 깨워 주므로 `resume(allowed:)` 을 앱이 뜰 때마다 부른다.
@Observable
class VisitReminderManager: NSObject, CLLocationManagerDelegate {
    static let shared = VisitReminderManager()

    private let locationManager = CLLocationManager()
    private let logger = Logger(subsystem: "com.restaurantmap", category: "VisitReminder")

    // 설정값
    private let proximityRadius: CLLocationDistance = 100 // 가게 근처 판정 반경 (미터). 방문 감지는 GPS 보다 거칠다.
    private let reminderDelay: TimeInterval = 40 * 60 // 떠난 뒤 40분
    private let minimumStay: TimeInterval = 5 * 60 // 이만큼은 머물러야 다녀온 것으로 본다

    // 상태 추적
    private var modelContainer: ModelContainer?
    private var scheduledNotificationId: String?

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

    /// 앱이 뜰 때(시스템이 방문을 알리려고 깨울 때 포함) 감지를 다시 건다. 권한을 묻지 않는다.
    func resume(allowed: Bool) {
        #if !os(visionOS)
        guard allowed, wantsReminders, locationManager.authorizationStatus == .authorizedAlways else { return }
        isActive = true
        locationManager.startMonitoringVisits()
        #endif
    }

    private override init() {
        super.init()
        locationManager.delegate = self
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

    /// 방문 감지 시작
    func startMonitoring() {
        #if os(visionOS)
        // Vision Pro 를 들고 식당에 가지 않는다 — 다녀온 뒤 알림은 iPhone 에서만 돈다.
        return
        #else
        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            locationManager.startMonitoringVisits()
        case .authorizedWhenInUse, .notDetermined:
            // 앱이 꺼져 있을 때 다녀온 것을 알려면 '항상' 권한이 필요하다. 받으면 권한 변경 콜백에서 시작한다.
            locationManager.requestAlwaysAuthorization()
        case .denied, .restricted:
            logger.warning("위치 권한이 거부됨")
        @unknown default:
            break
        }
        #endif
    }

    /// 방문 감지 중지
    func stopMonitoring() {
        #if !os(visionOS)
        locationManager.stopMonitoringVisits()
        #endif
    }

    // MARK: - CLLocationManagerDelegate

    #if !os(visionOS)
    /// 시스템이 "어딘가에 머물다 떠났다"고 알려 줄 때. 도착만 알린 것(아직 머무는 중)은 넘긴다.
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        guard isActive, visit.departureDate != .distantFuture, visit.arrivalDate != .distantPast,
              visit.departureDate.timeIntervalSince(visit.arrivalDate) >= minimumStay else { return }
        let place = CLLocation(latitude: visit.coordinate.latitude, longitude: visit.coordinate.longitude)
        let radius = max(proximityRadius, visit.horizontalAccuracy)
        let departure = visit.departureDate
        Task { @MainActor in
            guard let name = nearestRestaurantName(to: place, within: radius) else { return }
            // 떠난 지 40분 되는 때. 시스템이 늦게 알려 줘 이미 지났으면 곧바로.
            scheduleReminderNotification(restaurantName: name,
                                         after: max(60, reminderDelay - Date().timeIntervalSince(departure)))
        }
    }
    #endif

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // 꺼져 있으면 권한이 바뀌어도 위치를 따라가지 않는다 (만들어질 때도 한 번 불린다).
        guard isActive else { return }
        #if !os(visionOS)
        if manager.authorizationStatus == .authorizedAlways {
            locationManager.startMonitoringVisits()
        }
        #endif
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("위치 업데이트 실패: \(error.localizedDescription)")
    }

    // MARK: - Private Methods

    /// 그 자리에서 가장 가까운 저장한 가게. 반경 안에 없으면 nil.
    @MainActor
    private func nearestRestaurantName(to place: CLLocation, within radius: CLLocationDistance) -> String? {
        guard let restaurants = try? modelContainer?.mainContext.fetch(FetchDescriptor<Restaurant>()) else { return nil }
        return restaurants
            .map { ($0.name, place.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude))) }
            .filter { $0.1 <= radius }
            .min { $0.1 < $1.1 }?.0
    }

    /// 40분 후 알림 예약
    private func scheduleReminderNotification(restaurantName: String, after delay: TimeInterval) {
        // 이전 알림 취소
        cancelScheduledNotification()

        let content = UNMutableNotificationContent()
        content.title = String(localized: "오늘 방문은 어떠셨나요? 🍽️")
        content.body = String(localized: "\(restaurantName)에서의 식사는 만족스러우셨나요? 방문 기록을 남겨보세요!")
        content.sound = .default
        content.categoryIdentifier = "VISIT_REMINDER"
        content.userInfo = ["restaurantName": restaurantName]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: delay,
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
                self?.logger.info("알림 예약 완료")
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
