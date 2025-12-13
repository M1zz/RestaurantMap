import SwiftUI
import SwiftData

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

    @Query private var restaurants: [Restaurant]

    var body: some View {
        NavigationStack {
            List {
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
                } header: {
                    Text("데이터 관리")
                }

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

                    // 백업 버튼
                    Button {
                        showBackupAlert = true
                    } label: {
                        HStack {
                            Label("iCloud에 백업", systemImage: "icloud.and.arrow.up")
                            Spacer()
                            if backupService.isBackingUp {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(backupService.isBackingUp || backupService.isRestoring)

                    // 복구 버튼
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
                        Text("iCloud에 로그인되어 있어야 백업/복구가 가능합니다.")
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
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
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

    private func performBackup() {
        let container = modelContext.container

        Task {
            let success = await backupService.backup(modelContainer: container)
            await MainActor.run {
                isSuccess = success
                resultMessage = success ? "백업이 완료되었습니다." : (backupService.errorMessage ?? "백업에 실패했습니다.")
                showResultAlert = true
            }
        }
    }

    private func performRestore() {
        let container = modelContext.container

        Task {
            let success = await backupService.restore(modelContainer: container)
            await MainActor.run {
                isSuccess = success
                resultMessage = success ? "복구가 완료되었습니다." : (backupService.errorMessage ?? "복구에 실패했습니다.")
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
                resultMessage = success ? "모든 데이터가 삭제되었습니다." : (backupService.errorMessage ?? "초기화에 실패했습니다.")
                showResultAlert = true
            }
        }
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Restaurant.self, inMemory: true)
}
