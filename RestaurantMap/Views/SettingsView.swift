import SwiftUI
import SwiftData
import StoreKit
import LeeoKit

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var backupService = CloudKitBackupService.shared
    @State private var showBackupAlert = false
    @State private var showRestoreAlert = false
    @State private var showResetAlert = false
    @State private var showResultAlert = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    /// 기기의 식당이 iCloud 백업보다 크게 적어 덮어쓰기를 묻는 중 (기기 수, 백업 수)
    @State private var shrinkingBackup: (local: Int, backup: Int)?

    @Query private var storedRestaurants: [Restaurant]
    /// 복원 · 지우기 직후 질의가 새로 고쳐지기 전에 한 박자 남은 지워진 식당은 읽지 않는다(읽으면 죽는다).
    private var restaurants: [Restaurant] { storedRestaurants.filter { !$0.isGone } }

    @State private var purchases = Purchases.shared
    @State private var reminder = VisitReminderManager.shared
    @State private var paywallFeature: RestaurantFeature?
    @State private var showsPaywall = false
    @State private var showsGraduation = false
    @State private var showsManageSubscription = false
    @State private var showsGoogleImport = false
    /// LeeoKit 마스터 모드(버전 7번 누르기). 이 앱은 켜질 때 관리자 비밀번호를 한 번 더 묻는다.
    @AppStorage("dev.masterMode") private var masterMode = false
    @State private var asksPasscode = false
    @State private var passcode = ""
    /// 신고 목록을 여는 열쇠일 뿐 보안 장치는 아니다 — 후기를 지우는 권한은 CloudKit 의 Moderator 역할이 판정한다.
    /// 심사 메모에 적어 심사관에게 알려 준다.
    private static let adminPasscode = "4321"

    var body: some View {
        NavigationStack {
            List {
                plansSection
                // 데이터 현황
                Section {
                    HStack {
                        Label("저장된 가게", systemImage: "storefront")
                        Spacer()
                        Text("\(restaurants.count)개")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Label("총 방문 기록", systemImage: "calendar")
                        Spacer()
                        Text("\(totalVisitCount)개")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("데이터 현황")
                }

                // 데이터 관리
                Section {
                    NavigationLink {
                        CustomCategorySettingsView()
                    } label: {
                        Label("음식 종류 관리", systemImage: "list.bullet")
                    }
                    Button { showsGoogleImport = true } label: {
                        Label("구글 지도에서 가져오기", systemImage: "square.and.arrow.down")
                    }
                    ShareLink(item: RestaurantExport(restaurants: restaurants),
                              preview: SharePreview(RestaurantExport.fileName)) {
                        Label("식당 · 방문 기록 CSV로 내보내기", systemImage: "tablecells")
                    }
                    .disabled(restaurants.isEmpty)
                } header: {
                    Text("데이터 관리")
                } footer: {
                    Text("내보내기는 어느 칸이든 무료예요.")
                }

                #if !os(visionOS)
                // 위치를 늘 봐야 하는 알림이라 Vision Pro 에는 없다.
                reminderSection
                #endif

                // iCloud 백업
                Section {
                    // 마지막 백업 시간
                    if let lastBackup = backupService.lastBackupDate {
                        HStack {
                            Label("마지막 백업", systemImage: "clock")
                            Spacer()
                            Text(lastBackup, style: .relative)
                                .foregroundColor(.secondary)
                        }
                    }

                    // 백업 버튼 (Pro)
                    Button {
                        if purchases.allows(.backup) {
                            showBackupAlert = true
                        } else {
                            paywallFeature = .backup
                        }
                    } label: {
                        HStack {
                            LockedLabel(title: "iCloud에 백업", systemImage: "icloud.and.arrow.up", feature: .backup)
                            Spacer()
                            if backupService.isBackingUp {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                    // 복구 버튼 — 내 기록을 되찾는 길은 잠그지 않는다
                    Button {
                        showRestoreAlert = true
                    } label: {
                        HStack {
                            Label("iCloud에서 복구", systemImage: "icloud.and.arrow.down")
                            Spacer()
                            if backupService.isRestoring {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                } header: {
                    Text("iCloud 백업")
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let progress = backupService.progressMessage {
                            Text(progress)
                                .foregroundColor(.blue)
                        }
                        if let error = backupService.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                        }
                        Text("방문 기록과 사진을 내 iCloud에 백업해요. iCloud에 로그인되어 있어야 백업/복구가 가능합니다.")
                    }
                }

                // 데이터 초기화
                Section {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("모든 데이터 삭제", systemImage: "trash")
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)
                } header: {
                    Text("초기화")
                } footer: {
                    Text("모든 가게와 방문 기록이 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
                }

                // 앱 정보
                Section {
                    HStack {
                        Label("버전", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("앱 정보")
                }

                // 지원
                Section {
                    // 앞으로 만들 기능 — 원본은 RestaurantMapRoadmap.swift
                    NavigationLink(LeeoRoadmapText.entry) { RoadmapScreen() }
                    LeeoShareAppLink<RestaurantMapSpec>()
                    LeeoTipJarLink<RestaurantMapSpec>(tipJar: RestaurantMapTip.tipJar)
                    LeeoSupportSection<RestaurantMapSpec>()
                } header: {
                    Text("지원")
                }

                if masterMode && !asksPasscode {
                    Section {
                        NavigationLink {
                            ReportedReviewsView()
                        } label: {
                            Label("신고된 후기", systemImage: "exclamationmark.bubble")
                        }
                    } header: {
                        Text("관리자")
                    }
                }

                // 개발자 문의
                DeveloperContactSection()
            }
            .onChange(of: masterMode) { _, isOn in
                guard isOn else { return }
                passcode = ""
                asksPasscode = true
            }
            .alert("관리자 비밀번호", isPresented: $asksPasscode) {
                SecureField("비밀번호", text: $passcode)
                    .keyboardType(.numberPad)
                Button("취소", role: .cancel) { masterMode = false }
                Button("확인") {
                    if passcode != Self.adminPasscode { masterMode = false }
                }
            } message: {
                Text("신고된 후기를 보려면 비밀번호를 넣어 주세요.")
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .manageSubscriptionsSheet(isPresented: $showsManageSubscription)
            .paywall(for: $paywallFeature)
            .sheet(isPresented: $showsPaywall) { PaywallView() }
            .sheet(isPresented: $showsGoogleImport) { GoogleImportView() }
            .sheet(isPresented: $showsGraduation) {
                LeeoGraduationOfferView(graduate: purchases.product(RestaurantPlan.graduateID)) {
                    await purchases.refresh()
                }
            }
            .task { await purchases.refresh() }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료", systemImage: "checkmark") {
                        dismiss()
                    }
                }
            }
            // 백업 확인 알림
            .alert("iCloud에 백업", isPresented: $showBackupAlert) {
                Button("취소", role: .cancel) { }
                Button("백업") {
                    performBackup()
                }
            } message: {
                Text("현재 데이터를 iCloud에 백업합니다. 기존 백업이 있다면 덮어씌워집니다.")
            }
            // 기기가 거의 비었는데 백업을 덮어쓰려 할 때 — 새 기기에서 복구 전에 백업을 누르면 iCloud 의 기록이 통째로 사라졌다
            .alert("백업을 덮어쓸까요?", isPresented: Binding(get: { shrinkingBackup != nil }, set: { if !$0 { shrinkingBackup = nil } })) {
                Button("취소", role: .cancel) { }
                Button("그래도 덮어쓰기", role: .destructive) {
                    performBackup(allowShrinking: true)
                }
            } message: {
                if let shrinkingBackup {
                    Text("iCloud 백업에는 식당이 \(shrinkingBackup.backup)곳 있는데, 이 기기에는 \(shrinkingBackup.local)곳뿐이에요. 덮어쓰면 백업에만 있는 기록과 사진이 사라져요. 새 기기라면 먼저 'iCloud에서 복구'를 해 주세요.")
                }
            }
            // 복구 확인 알림
            .alert("iCloud에서 복구", isPresented: $showRestoreAlert) {
                Button("취소", role: .cancel) { }
                Button("복구", role: .destructive) {
                    performRestore()
                }
            } message: {
                Text("iCloud의 백업 데이터로 복구합니다. 현재 기기의 모든 데이터가 삭제되고 백업 데이터로 대체됩니다.")
            }
            // 초기화 확인 알림
            .alert("모든 데이터 삭제", isPresented: $showResetAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    performReset()
                }
            } message: {
                Text("정말로 모든 데이터를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
            }
            // 결과 알림
            .alert(isSuccess ? "완료" : "오류", isPresented: $showResultAlert) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(resultMessage)
            }
        }
    }

    // MARK: - 인생 맛집 Plus · Pro

    private var plansSection: some View {
        Section {
            if purchases.tier == .pro {
                Label {
                    Text(String(localized: "\(RestaurantTier.pro.title) 사용 중"))
                } icon: {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                }
            } else {
                Button {
                    showsPaywall = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(purchases.tier == .plus ? RestaurantTier.pro.title : String(localized: "인생 맛집 Plus · Pro"))
                            .font(.body.weight(.semibold))
                        Text(statusLine)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            // 구독 중인 사람에게는 늘 평생으로 바꾸는 길이 있다.
            if purchases.subscription != nil {
                Button(LeeoLadderText.manageSubscription) { showsManageSubscription = true }
                if purchases.product(RestaurantPlan.graduateID) != nil, !purchases.ownsLifetime(.pro) {
                    Button(LeeoLadderText.switchToLifetimeEntry) { showsGraduation = true }
                }
            }
            Button("구매 복원") {
                Task { await purchases.restore() }
            }
            .disabled(purchases.isWorking)
        } header: {
            Text("인생 맛집 Plus · Pro")
        } footer: {
            if let message = purchases.failureMessage {
                Text(message)
            }
        }
    }

    /// 지금 칸을 한 줄로. 아직 App Store 에 묻는 중이면 '무료'라고 단정하지 않는다.
    private var statusLine: String {
        guard purchases.isKnown else { return String(localized: "확인 중…") }
        return purchases.tier == .plus
            ? String(localized: "\(RestaurantTier.plus.title) 사용 중")
            : String(localized: "식당 무제한, 다녀온 뒤 기록 알림, iCloud 백업")
    }

    // MARK: - 다녀온 뒤 기록 알림 (Pro)

    private var reminderSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { purchases.allows(.visitReminder) && reminder.wantsReminders },
                set: { on in
                    guard purchases.allows(.visitReminder) else {
                        if on { paywallFeature = .visitReminder }
                        return
                    }
                    reminder.wantsReminders = on
                    Task { await reminder.apply(allowed: true) }
                }
            )) {
                LockedLabel(title: "다녀온 뒤 기록 알림", systemImage: "bell.badge", feature: .visitReminder)
            }
        } footer: {
            if reminder.notificationsDenied && reminder.wantsReminders {
                Text("알림이 꺼져 있어요. 설정 앱 ▸ 알림에서 인생 맛집을 허용해 주세요.")
            } else {
                Text("저장한 식당에 5분 넘게 머물다 나오면 40분 뒤에 방문 기록을 남기라고 알려 드려요. 위치를 '항상' 허용해야 해요.")
            }
        }
    }

    // MARK: - Computed Properties

    private var totalVisitCount: Int {
        restaurants.reduce(0) { $0 + ($1.visits?.count ?? 0) }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Actions

    private func performBackup(allowShrinking: Bool = false) {
        let container = modelContext.container

        Task {
            let outcome = await backupService.backup(modelContainer: container, allowShrinking: allowShrinking)
            await MainActor.run {
                switch outcome {
                case .needsConfirmation(let local, let backup):
                    shrinkingBackup = (local, backup)
                case .done:
                    isSuccess = true
                    resultMessage = String(localized: "백업이 완료되었습니다.")
                    showResultAlert = true
                case .failed:
                    isSuccess = false
                    resultMessage = backupService.errorMessage ?? String(localized: "백업에 실패했습니다.")
                    showResultAlert = true
                }
            }
        }
    }

    private func performRestore() {
        let container = modelContext.container

        Task {
            let success = await backupService.restore(modelContainer: container)
            await MainActor.run {
                isSuccess = success
                resultMessage = success ? String(localized: "복구가 완료되었습니다.") : (backupService.errorMessage ?? String(localized: "복구에 실패했습니다."))
                showResultAlert = true
            }
        }
    }

    private func performReset() {
        let container = modelContext.container

        Task {
            let success = await backupService.resetLocalData(modelContainer: container)
            await MainActor.run {
                isSuccess = success
                resultMessage = success ? String(localized: "모든 데이터가 삭제되었습니다.") : (backupService.errorMessage ?? String(localized: "초기화에 실패했습니다."))
                showResultAlert = true
            }
        }
    }
}

// MARK: - 개발자 문의
struct DeveloperContactSection: View {
    var body: some View {
        Section {
            Link(destination: URL(string: "mailto:leeo@kakao.com")!) {
                Label("이메일로 문의하기", systemImage: "envelope")
            }
            Link(destination: URL(string: "https://instagram.com/lee25_ios")!) {
                Label("인스타그램 DM (@lee25_ios)", systemImage: "paperplane")
            }
        } header: {
            Text("개발자에게 문의")
        } footer: {
            Text("버그 제보와 기능 제안을 환영합니다.")
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Restaurant.self, inMemory: true)
}
