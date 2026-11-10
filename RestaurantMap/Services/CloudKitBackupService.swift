import Foundation
import CloudKit
import SwiftData
import OSLog

/// CloudKit을 사용한 데이터 백업/복구 서비스
///
/// 내 iCloud 개인 데이터베이스(`iCloud.com.Ysoup.restaurantmap`)에 백업 한 벌을 둔다.
///  · `BackupData/latest` — 식당 · 방문 기록 · 메뉴 · 취향 · 직접 추가한 음식 종류를 담은 JSON 파일(에셋)
///  · `BackupPhoto/photo.<방문 사진 ID>.<파일명>` — 방문 사진 한 장씩. 이미 올린 사진은 다시 올리지 않는다.
/// 레코드 ID 로만 읽고 써서 쿼리 인덱스가 필요 없다. ⚠️ 두 레코드 타입을 Production 스키마에 배포해야 한다.
///
/// 백업은 Pro, 되살리기는 누구나 (내 기록을 되찾는 길은 잠그지 않는다).
@Observable
class CloudKitBackupService {
    static let shared = CloudKitBackupService()

    private let logger = Logger(subsystem: "com.restaurantmap", category: "CloudKitBackup")

    private let containerIdentifier = RestaurantMapApp.cloudContainer
    /// 이번 백업에 올릴 사진 데이터. `fetchLocalData` 가 채우고 `uploadPhotos` 가 읽는다 (레코드 이름 → JPEG).
    private var pendingPhotoData: [String: Data] = [:]
    private let recordType = "BackupData"
    private let photoRecordType = "BackupPhoto"
    private var backupRecordID: CKRecord.ID { CKRecord.ID(recordName: "latest") }

    // 상태
    var isBackingUp = false
    var isRestoring = false
    var lastBackupDate: Date?
    var errorMessage: String?
    var progressMessage: String?

    private init() {
        loadLastBackupDate()
    }

    // CloudKit 컨테이너를 안전하게 가져오는 메서드
    private func getContainer() -> CKContainer? {
        CKContainer(identifier: containerIdentifier)
    }

    // MARK: - Public Methods

    /// iCloud 계정 상태 확인
    func checkiCloudStatus() async -> Bool {
        guard let container = getContainer() else {
            errorMessage = BackupError.cloudKitNotAvailable.localizedDescription
            logger.error("❌ CloudKit 컨테이너를 열지 못함")
            return false
        }

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                logger.info("iCloud 계정 사용 가능")
                return true
            case .noAccount:
                errorMessage = String(localized: "iCloud 계정에 로그인되어 있지 않습니다.")
                return false
            case .restricted:
                errorMessage = String(localized: "iCloud 접근이 제한되어 있습니다.")
                return false
            case .couldNotDetermine:
                errorMessage = String(localized: "iCloud 상태를 확인할 수 없습니다.")
                return false
            case .temporarilyUnavailable:
                errorMessage = String(localized: "iCloud가 일시적으로 사용 불가합니다.")
                return false
            @unknown default:
                errorMessage = String(localized: "알 수 없는 iCloud 상태입니다.")
                return false
            }
        } catch {
            logger.error("iCloud 상태 확인 실패: \(error.localizedDescription)")
            errorMessage = String(localized: "iCloud 상태 확인 실패: \(error.localizedDescription)")
            return false
        }
    }

    /// 데이터 백업
    func backup(modelContainer: ModelContainer) async -> Bool {
        guard await checkiCloudStatus() else { return false }

        isBackingUp = true
        errorMessage = nil
        progressMessage = String(localized: "백업 준비 중...")

        defer { isBackingUp = false }

        do {
            // 1. 로컬 데이터 가져오기
            progressMessage = String(localized: "데이터 수집 중...")
            let backupData = try await fetchLocalData(modelContainer: modelContainer)

            // 2. 사진 올리기 (지난 백업에 이미 있는 사진은 건너뛴다)
            progressMessage = String(localized: "사진 올리는 중...")
            let previous = try? await fetchFromCloudKit()
            let previousPhotos = Set(previous?.photoRecordNames ?? [])
            try await uploadPhotos(of: backupData, skipping: previousPhotos)

            // 3. 새 백업 저장 (같은 자리에 덮어쓴다)
            progressMessage = String(localized: "iCloud에 저장 중...")
            try await saveToCloudKit(data: backupData)

            // 4. 이제 어느 방문에도 없는 사진은 지운다
            try? await deletePhotos(named: previousPhotos.subtracting(backupData.photoRecordNames))

            // 5. 마지막 백업 시간 저장
            lastBackupDate = Date()
            saveLastBackupDate()

            progressMessage = String(localized: "백업 완료!")
            logger.info("백업 성공")
            return true

        } catch {
            logger.error("백업 실패: \(error.localizedDescription)")
            errorMessage = String(localized: "백업 실패: \(error.localizedDescription)")
            progressMessage = nil
            return false
        }
    }

    /// 데이터 복구
    func restore(modelContainer: ModelContainer) async -> Bool {
        guard await checkiCloudStatus() else { return false }

        isRestoring = true
        errorMessage = nil
        progressMessage = String(localized: "복구 준비 중...")

        defer { isRestoring = false }

        do {
            // 1. CloudKit에서 데이터 가져오기
            progressMessage = String(localized: "CloudKit에서 데이터 가져오는 중...")
            guard let backupData = try await fetchFromCloudKit() else {
                errorMessage = String(localized: "백업 데이터가 없습니다.")
                progressMessage = nil
                return false
            }

            // 2. 사진을 먼저 다 받아 둔다 — 받다가 끊겨도 이 기기의 기록은 그대로 남게
            progressMessage = String(localized: "사진 받는 중...")
            let photos = try await downloadPhotos(of: backupData)
            defer { try? FileManager.default.removeItem(at: photos.folder) }

            // 3. 로컬 데이터 삭제
            progressMessage = String(localized: "기존 데이터 정리 중...")
            try await deleteLocalData(modelContainer: modelContainer)

            // 4. 복구된 데이터 저장 — 사진은 기록 안(VisitPhoto)으로
            progressMessage = String(localized: "데이터 복구 중...")
            let restored = try await restoreLocalData(modelContainer: modelContainer, data: backupData)
            try await attachPhotos(photos.files, to: restored, modelContainer: modelContainer)

            progressMessage = String(localized: "복구 완료!")
            logger.info("복구 성공")
            return true

        } catch {
            logger.error("복구 실패: \(error.localizedDescription)")
            errorMessage = String(localized: "복구 실패: \(error.localizedDescription)")
            progressMessage = nil
            return false
        }
    }

    /// 로컬 데이터 초기화 (모든 데이터 삭제)
    func resetLocalData(modelContainer: ModelContainer) async -> Bool {
        progressMessage = String(localized: "데이터 초기화 중...")

        do {
            try await deleteLocalData(modelContainer: modelContainer)
            progressMessage = String(localized: "초기화 완료!")
            logger.info("로컬 데이터 초기화 완료")
            return true
        } catch {
            logger.error("초기화 실패: \(error.localizedDescription)")
            errorMessage = String(localized: "초기화 실패: \(error.localizedDescription)")
            progressMessage = nil
            return false
        }
    }

    // MARK: - Private Methods

    /// 로컬 데이터를 백업 구조체로 변환
    @MainActor
    private func fetchLocalData(modelContainer: ModelContainer) throws -> BackupData {
        let context = modelContainer.mainContext

        // Restaurant 가져오기
        let restaurantDescriptor = FetchDescriptor<Restaurant>()
        let restaurants = try context.fetch(restaurantDescriptor)

        // TasteProfile 가져오기
        let profileDescriptor = FetchDescriptor<TasteProfile>()
        let profiles = try context.fetch(profileDescriptor)

        // 변환
        var backupRestaurants: [BackupRestaurant] = []

        pendingPhotoData = [:]
        for restaurant in restaurants {
            let visits = restaurant.visits?.map { visit -> BackupVisit in
                // 사진은 기록 안(VisitPhoto)에 있다. 레코드 이름을 옛 파일 방식과 같은 꼴로 만들어 옛 백업과 섞여도 된다.
                let photos = visit.sortedPhotos
                for photo in photos {
                    if let data = photo.data {
                        pendingPhotoData[BackupData.photoRecordName(photoId: visit.photoId, filename: photo.filename)] = data
                    }
                }
                return BackupVisit(
                    visitDate: visit.visitDate,
                    notes: visit.notes,
                    rating: visit.rating,
                    menuItem: visit.menuItem,
                    menuName: visit.menu?.name,
                    photoId: visit.photoId,
                    photoFilenames: photos.map(\.filename),
                    // 일반
                    spicy: visit.spicy,
                    boldness: visit.boldness,
                    sweetness: visit.sweetness,
                    saltiness: visit.saltiness,
                    richness: visit.richness,
                    naturalTaste: visit.naturalTaste,
                    texture: visit.texture,
                    cooking: visit.cooking,
                    spicyAppropriate: visit.spicyAppropriate,
                    boldnessAppropriate: visit.boldnessAppropriate,
                    sweetnessAppropriate: visit.sweetnessAppropriate,
                    saltinessAppropriate: visit.saltinessAppropriate,
                    richnessAppropriate: visit.richnessAppropriate,
                    naturalTasteAppropriate: visit.naturalTasteAppropriate,
                    textureAppropriate: visit.textureAppropriate,
                    cookingAppropriate: visit.cookingAppropriate,
                    // 스테이크
                    steakDoneness: visit.steakDoneness,
                    steakJuiciness: visit.steakJuiciness,
                    steakTenderness: visit.steakTenderness,
                    steakSeasoning: visit.steakSeasoning,
                    steakFlavor: visit.steakFlavor,
                    steakMarbling: visit.steakMarbling,
                    steakDonenessAppropriate: visit.steakDonenessAppropriate,
                    steakJuicinessAppropriate: visit.steakJuicinessAppropriate,
                    steakTendernessAppropriate: visit.steakTendernessAppropriate,
                    steakSeasoningAppropriate: visit.steakSeasoningAppropriate,
                    steakFlavorAppropriate: visit.steakFlavorAppropriate,
                    steakMarblingAppropriate: visit.steakMarblingAppropriate,
                    // 초밥
                    sushiShari: visit.sushiShari,
                    sushiNeta: visit.sushiNeta,
                    sushiWasabi: visit.sushiWasabi,
                    sushiBalance: visit.sushiBalance,
                    sushiGrip: visit.sushiGrip,
                    sushiTemperature: visit.sushiTemperature,
                    sushiShariAppropriate: visit.sushiShariAppropriate,
                    sushiNetaAppropriate: visit.sushiNetaAppropriate,
                    sushiWasabiAppropriate: visit.sushiWasabiAppropriate,
                    sushiBalanceAppropriate: visit.sushiBalanceAppropriate,
                    sushiGripAppropriate: visit.sushiGripAppropriate,
                    sushiTemperatureAppropriate: visit.sushiTemperatureAppropriate,
                    // 라멘
                    ramenBroth: visit.ramenBroth,
                    ramenNoodle: visit.ramenNoodle,
                    ramenChashu: visit.ramenChashu,
                    ramenTopping: visit.ramenTopping,
                    ramenTemperature: visit.ramenTemperature,
                    ramenBalance: visit.ramenBalance,
                    ramenBrothAppropriate: visit.ramenBrothAppropriate,
                    ramenNoodleAppropriate: visit.ramenNoodleAppropriate,
                    ramenChashuAppropriate: visit.ramenChashuAppropriate,
                    ramenToppingAppropriate: visit.ramenToppingAppropriate,
                    ramenTemperatureAppropriate: visit.ramenTemperatureAppropriate,
                    ramenBalanceAppropriate: visit.ramenBalanceAppropriate,
                    // 피자
                    pizzaDough: visit.pizzaDough,
                    pizzaSauce: visit.pizzaSauce,
                    pizzaCheese: visit.pizzaCheese,
                    pizzaBaking: visit.pizzaBaking,
                    pizzaTopping: visit.pizzaTopping,
                    pizzaBalance: visit.pizzaBalance,
                    pizzaDoughAppropriate: visit.pizzaDoughAppropriate,
                    pizzaSauceAppropriate: visit.pizzaSauceAppropriate,
                    pizzaCheeseAppropriate: visit.pizzaCheeseAppropriate,
                    pizzaBakingAppropriate: visit.pizzaBakingAppropriate,
                    pizzaToppingAppropriate: visit.pizzaToppingAppropriate,
                    pizzaBalanceAppropriate: visit.pizzaBalanceAppropriate,
                    // 와인
                    wineBody: visit.wineBody,
                    wineTannin: visit.wineTannin,
                    wineAcidity: visit.wineAcidity,
                    wineAroma: visit.wineAroma,
                    wineFinish: visit.wineFinish,
                    wineBalance: visit.wineBalance,
                    wineBodyAppropriate: visit.wineBodyAppropriate,
                    wineTanninAppropriate: visit.wineTanninAppropriate,
                    wineAcidityAppropriate: visit.wineAcidityAppropriate,
                    wineAromaAppropriate: visit.wineAromaAppropriate,
                    wineFinishAppropriate: visit.wineFinishAppropriate,
                    wineBalanceAppropriate: visit.wineBalanceAppropriate,
                    // 커피
                    coffeeAcidity: visit.coffeeAcidity,
                    coffeeBody: visit.coffeeBody,
                    coffeeFlavor: visit.coffeeFlavor,
                    coffeeAftertaste: visit.coffeeAftertaste,
                    coffeeSweetness: visit.coffeeSweetness,
                    coffeeBalance: visit.coffeeBalance,
                    coffeeAcidityAppropriate: visit.coffeeAcidityAppropriate,
                    coffeeBodyAppropriate: visit.coffeeBodyAppropriate,
                    coffeeFlavorAppropriate: visit.coffeeFlavorAppropriate,
                    coffeeAftertasteAppropriate: visit.coffeeAftertasteAppropriate,
                    coffeeSweetnessAppropriate: visit.coffeeSweetnessAppropriate,
                    coffeeBalanceAppropriate: visit.coffeeBalanceAppropriate
                )
            } ?? []

            let backupRestaurant = BackupRestaurant(
                name: restaurant.name,
                address: restaurant.address,
                latitude: restaurant.latitude,
                longitude: restaurant.longitude,
                notes: restaurant.notes,
                rating: restaurant.rating,
                visitDate: restaurant.visitDate,
                category: restaurant.category,
                phoneNumber: restaurant.phoneNumber,
                isTop6: restaurant.isTop6,
                top6Rank: restaurant.top6Rank,
                categoryIcon: restaurant.categoryIcon,
                foodCategoryId: restaurant.foodCategoryId,
                isWishlist: restaurant.isWishlist,
                visits: visits,
                menus: (restaurant.menus ?? []).map {
                    BackupMenu(name: $0.name, price: $0.price, menuDescription: $0.menuDescription, isSignature: $0.isSignature)
                }
            )
            backupRestaurants.append(backupRestaurant)
        }

        let backupProfiles = profiles.map { profile in
            BackupTasteProfile(
                userId: profile.userId,
                spicy: profile.spicy,
                boldness: profile.boldness,
                sweetness: profile.sweetness,
                saltiness: profile.saltiness,
                richness: profile.richness,
                naturalTaste: profile.naturalTaste,
                texture: profile.texture,
                cooking: profile.cooking,
                updatedAt: profile.updatedAt
            )
        }

        return BackupData(
            restaurants: backupRestaurants,
            tasteProfiles: backupProfiles,
            customCategories: FoodCategoryRepository.shared.customCategories,
            backupDate: Date()
        )
    }

    /// CloudKit에 데이터 저장 — JSON 을 파일 에셋으로 (레코드 1MB 한도를 넘지 않게)
    private func saveToCloudKit(data: BackupData) async throws {
        guard let container = getContainer() else {
            throw BackupError.cloudKitNotAvailable
        }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString).json")
        try encoder.encode(data).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let record = CKRecord(recordType: recordType, recordID: backupRecordID)
        record["payload"] = CKAsset(fileURL: file)
        record["backupDate"] = data.backupDate as CKRecordValue

        try await save([record], in: container.privateCloudDatabase)
        logger.info("CloudKit에 백업 저장 완료")
    }

    /// CloudKit에서 데이터 가져오기. 백업이 없으면 nil.
    private func fetchFromCloudKit() async throws -> BackupData? {
        guard let container = getContainer() else {
            throw BackupError.cloudKitNotAvailable
        }

        let record: CKRecord
        do {
            record = try await container.privateCloudDatabase.record(for: backupRecordID)
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }

        guard let url = (record["payload"] as? CKAsset)?.fileURL,
              let jsonData = try? Data(contentsOf: url) else {
            throw BackupError.invalidData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupData.self, from: jsonData)
    }

    /// 방문 사진을 한 장씩 레코드로 올린다. `skipping` 에 있는 것(지난 백업에 이미 있는 사진)은 건너뛴다.
    private func uploadPhotos(of data: BackupData, skipping uploaded: Set<String>) async throws {
        guard let container = getContainer() else { throw BackupError.cloudKitNotAvailable }

        // CKAsset 은 파일 URL 을 받는다 — 기록 안의 데이터를 임시 폴더에 잠깐 쓴다.
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("backup-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        var records: [CKRecord] = []
        for visit in data.allVisits {
            guard let photoId = visit.photoId else { continue }
            for filename in visit.photoFilenames ?? [] {
                let name = BackupData.photoRecordName(photoId: photoId, filename: filename)
                guard !uploaded.contains(name), let bytes = pendingPhotoData[name] else { continue }
                let url = folder.appendingPathComponent(name)
                try bytes.write(to: url)
                let record = CKRecord(recordType: photoRecordType, recordID: CKRecord.ID(recordName: name))
                record["image"] = CKAsset(fileURL: url)
                records.append(record)
            }
        }

        // 한 번에 너무 많이 보내면 CloudKit 이 거절한다 — 나눠서 보낸다.
        for start in stride(from: 0, to: records.count, by: 20) {
            progressMessage = String(localized: "사진 올리는 중... (\(start)/\(records.count))")
            try await save(Array(records[start..<min(start + 20, records.count)]), in: container.privateCloudDatabase)
        }
        logger.info("사진 \(records.count)장 올림")
    }

    /// 백업의 사진을 임시 폴더에 받아 둔다. 백업에서 사라진 사진(지워진 레코드)은 건너뛴다.
    private func downloadPhotos(of data: BackupData) async throws -> (folder: URL, files: [(url: URL, filename: String, visitID: UUID)]) {
        guard let container = getContainer() else { throw BackupError.cloudKitNotAvailable }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("restore-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var wanted: [(id: CKRecord.ID, filename: String, visitID: UUID)] = []
        for visit in data.allVisits {
            guard let photoId = visit.photoId else { continue }
            for filename in visit.photoFilenames ?? [] {
                wanted.append((CKRecord.ID(recordName: BackupData.photoRecordName(photoId: photoId, filename: filename)), filename, photoId))
            }
        }

        var files: [(url: URL, filename: String, visitID: UUID)] = []
        for start in stride(from: 0, to: wanted.count, by: 20) {
            let batch = Array(wanted[start..<min(start + 20, wanted.count)])
            let results = try await container.privateCloudDatabase.records(for: batch.map(\.id))
            for item in batch {
                guard case .success(let record)? = results[item.id],
                      let source = (record["image"] as? CKAsset)?.fileURL else { continue }
                let target = folder.appendingPathComponent("\(item.visitID.uuidString)-\(item.filename)")
                try FileManager.default.copyItem(at: source, to: target)
                files.append((target, item.filename, item.visitID))
            }
        }
        return (folder, files)
    }

    private func deletePhotos(named names: Set<String>) async throws {
        guard !names.isEmpty, let container = getContainer() else { return }
        let ids = names.map { CKRecord.ID(recordName: $0) }
        for start in stride(from: 0, to: ids.count, by: 100) {
            _ = try await container.privateCloudDatabase.modifyRecords(
                saving: [], deleting: Array(ids[start..<min(start + 100, ids.count)]))
        }
    }

    /// 레코드를 덮어쓰며 저장한다. 하나라도 실패하면 그 오류를 던진다.
    private func save(_ records: [CKRecord], in database: CKDatabase) async throws {
        let (results, _) = try await database.modifyRecords(saving: records, deleting: [], savePolicy: .allKeys)
        for (_, result) in results {
            if case .failure(let error) = result { throw error }
        }
    }

    /// 로컬 데이터 삭제
    @MainActor
    private func deleteLocalData(modelContainer: ModelContainer) throws {
        let context = modelContainer.mainContext

        // Visit 삭제
        let visitDescriptor = FetchDescriptor<Visit>()
        let visits = try context.fetch(visitDescriptor)
        for visit in visits {
            context.delete(visit)
        }

        // Restaurant 삭제
        let restaurantDescriptor = FetchDescriptor<Restaurant>()
        let restaurants = try context.fetch(restaurantDescriptor)
        for restaurant in restaurants {
            context.delete(restaurant)
        }

        // TasteProfile 삭제
        let profileDescriptor = FetchDescriptor<TasteProfile>()
        let profiles = try context.fetch(profileDescriptor)
        for profile in profiles {
            context.delete(profile)
        }

        try context.save()
        logger.info("로컬 데이터 삭제 완료")
    }

    /// 복구된 데이터를 로컬에 저장. 되살린 방문을 사진 ID 로 돌려준다 (→ attachPhotos).
    @MainActor
    @discardableResult
    private func restoreLocalData(modelContainer: ModelContainer, data: BackupData) throws -> [UUID: Visit] {
        let context = modelContainer.mainContext
        var restoredVisits: [UUID: Visit] = [:]

        // 직접 추가한 음식 종류를 먼저 되살린다 — 식당이 그 종류를 가리키므로
        FoodCategoryRepository.shared.mergeCustomCategories(data.customCategories ?? [])

        // Restaurant 및 Visit 복구
        for backupRestaurant in data.restaurants {
            // foodCategoryId를 FoodCategory로 변환
            let foodCategory: FoodCategory
            if let uuid = UUID(uuidString: backupRestaurant.foodCategoryId),
               let category = FoodCategoryRepository.shared.findCategory(by: uuid) {
                foodCategory = category
            } else {
                // 백업된 ID를 찾을 수 없으면 기본값 사용
                foodCategory = FoodCategoryRepository.builtInCategories[0]
            }

            let restaurant = Restaurant(
                name: backupRestaurant.name,
                address: backupRestaurant.address,
                latitude: backupRestaurant.latitude,
                longitude: backupRestaurant.longitude,
                notes: backupRestaurant.notes,
                rating: backupRestaurant.rating,
                visitDate: backupRestaurant.visitDate,
                category: backupRestaurant.category,
                phoneNumber: backupRestaurant.phoneNumber,
                isTop6: backupRestaurant.isTop6,
                top6Rank: backupRestaurant.top6Rank,
                categoryIcon: backupRestaurant.categoryIcon,
                foodCategory: foodCategory,
                listType: backupRestaurant.isWishlist ? .wishlist : (backupRestaurant.isTop6 ? .michelin : .visited)
            )

            context.insert(restaurant)

            // 메뉴 복구
            var menusByName: [String: MenuItem] = [:]
            for backupMenu in backupRestaurant.menus ?? [] {
                let menu = MenuItem(name: backupMenu.name, price: backupMenu.price,
                                    menuDescription: backupMenu.menuDescription, isSignature: backupMenu.isSignature,
                                    restaurant: restaurant)
                context.insert(menu)
                menusByName[menu.name] = menu
            }

            // Visit 복구
            for backupVisit in backupRestaurant.visits {
                let visit = Visit(
                    restaurant: restaurant,
                    visitDate: backupVisit.visitDate,
                    notes: backupVisit.notes,
                    rating: backupVisit.rating
                )
                visit.menuItem = backupVisit.menuItem ?? ""
                visit.menu = backupVisit.menuName.flatMap { menusByName[$0] }
                if let photoId = backupVisit.photoId {
                    visit.photoId = photoId
                    restoredVisits[photoId] = visit
                }

                // 일반
                visit.spicy = backupVisit.spicy
                visit.boldness = backupVisit.boldness
                visit.sweetness = backupVisit.sweetness
                visit.saltiness = backupVisit.saltiness
                visit.richness = backupVisit.richness
                visit.naturalTaste = backupVisit.naturalTaste
                visit.texture = backupVisit.texture
                visit.cooking = backupVisit.cooking
                visit.spicyAppropriate = backupVisit.spicyAppropriate
                visit.boldnessAppropriate = backupVisit.boldnessAppropriate
                visit.sweetnessAppropriate = backupVisit.sweetnessAppropriate
                visit.saltinessAppropriate = backupVisit.saltinessAppropriate
                visit.richnessAppropriate = backupVisit.richnessAppropriate
                visit.naturalTasteAppropriate = backupVisit.naturalTasteAppropriate
                visit.textureAppropriate = backupVisit.textureAppropriate
                visit.cookingAppropriate = backupVisit.cookingAppropriate

                // 스테이크
                visit.steakDoneness = backupVisit.steakDoneness
                visit.steakJuiciness = backupVisit.steakJuiciness
                visit.steakTenderness = backupVisit.steakTenderness
                visit.steakSeasoning = backupVisit.steakSeasoning
                visit.steakFlavor = backupVisit.steakFlavor
                visit.steakMarbling = backupVisit.steakMarbling
                visit.steakDonenessAppropriate = backupVisit.steakDonenessAppropriate
                visit.steakJuicinessAppropriate = backupVisit.steakJuicinessAppropriate
                visit.steakTendernessAppropriate = backupVisit.steakTendernessAppropriate
                visit.steakSeasoningAppropriate = backupVisit.steakSeasoningAppropriate
                visit.steakFlavorAppropriate = backupVisit.steakFlavorAppropriate
                visit.steakMarblingAppropriate = backupVisit.steakMarblingAppropriate

                // 초밥
                visit.sushiShari = backupVisit.sushiShari
                visit.sushiNeta = backupVisit.sushiNeta
                visit.sushiWasabi = backupVisit.sushiWasabi
                visit.sushiBalance = backupVisit.sushiBalance
                visit.sushiGrip = backupVisit.sushiGrip
                visit.sushiTemperature = backupVisit.sushiTemperature
                visit.sushiShariAppropriate = backupVisit.sushiShariAppropriate
                visit.sushiNetaAppropriate = backupVisit.sushiNetaAppropriate
                visit.sushiWasabiAppropriate = backupVisit.sushiWasabiAppropriate
                visit.sushiBalanceAppropriate = backupVisit.sushiBalanceAppropriate
                visit.sushiGripAppropriate = backupVisit.sushiGripAppropriate
                visit.sushiTemperatureAppropriate = backupVisit.sushiTemperatureAppropriate

                // 라멘
                visit.ramenBroth = backupVisit.ramenBroth
                visit.ramenNoodle = backupVisit.ramenNoodle
                visit.ramenChashu = backupVisit.ramenChashu
                visit.ramenTopping = backupVisit.ramenTopping
                visit.ramenTemperature = backupVisit.ramenTemperature
                visit.ramenBalance = backupVisit.ramenBalance
                visit.ramenBrothAppropriate = backupVisit.ramenBrothAppropriate
                visit.ramenNoodleAppropriate = backupVisit.ramenNoodleAppropriate
                visit.ramenChashuAppropriate = backupVisit.ramenChashuAppropriate
                visit.ramenToppingAppropriate = backupVisit.ramenToppingAppropriate
                visit.ramenTemperatureAppropriate = backupVisit.ramenTemperatureAppropriate
                visit.ramenBalanceAppropriate = backupVisit.ramenBalanceAppropriate

                // 피자
                visit.pizzaDough = backupVisit.pizzaDough
                visit.pizzaSauce = backupVisit.pizzaSauce
                visit.pizzaCheese = backupVisit.pizzaCheese
                visit.pizzaBaking = backupVisit.pizzaBaking
                visit.pizzaTopping = backupVisit.pizzaTopping
                visit.pizzaBalance = backupVisit.pizzaBalance
                visit.pizzaDoughAppropriate = backupVisit.pizzaDoughAppropriate
                visit.pizzaSauceAppropriate = backupVisit.pizzaSauceAppropriate
                visit.pizzaCheeseAppropriate = backupVisit.pizzaCheeseAppropriate
                visit.pizzaBakingAppropriate = backupVisit.pizzaBakingAppropriate
                visit.pizzaToppingAppropriate = backupVisit.pizzaToppingAppropriate
                visit.pizzaBalanceAppropriate = backupVisit.pizzaBalanceAppropriate

                // 와인
                visit.wineBody = backupVisit.wineBody
                visit.wineTannin = backupVisit.wineTannin
                visit.wineAcidity = backupVisit.wineAcidity
                visit.wineAroma = backupVisit.wineAroma
                visit.wineFinish = backupVisit.wineFinish
                visit.wineBalance = backupVisit.wineBalance
                visit.wineBodyAppropriate = backupVisit.wineBodyAppropriate
                visit.wineTanninAppropriate = backupVisit.wineTanninAppropriate
                visit.wineAcidityAppropriate = backupVisit.wineAcidityAppropriate
                visit.wineAromaAppropriate = backupVisit.wineAromaAppropriate
                visit.wineFinishAppropriate = backupVisit.wineFinishAppropriate
                visit.wineBalanceAppropriate = backupVisit.wineBalanceAppropriate

                // 커피
                visit.coffeeAcidity = backupVisit.coffeeAcidity
                visit.coffeeBody = backupVisit.coffeeBody
                visit.coffeeFlavor = backupVisit.coffeeFlavor
                visit.coffeeAftertaste = backupVisit.coffeeAftertaste
                visit.coffeeSweetness = backupVisit.coffeeSweetness
                visit.coffeeBalance = backupVisit.coffeeBalance
                visit.coffeeAcidityAppropriate = backupVisit.coffeeAcidityAppropriate
                visit.coffeeBodyAppropriate = backupVisit.coffeeBodyAppropriate
                visit.coffeeFlavorAppropriate = backupVisit.coffeeFlavorAppropriate
                visit.coffeeAftertasteAppropriate = backupVisit.coffeeAftertasteAppropriate
                visit.coffeeSweetnessAppropriate = backupVisit.coffeeSweetnessAppropriate
                visit.coffeeBalanceAppropriate = backupVisit.coffeeBalanceAppropriate

                context.insert(visit)
            }
        }

        // TasteProfile 복구
        for backupProfile in data.tasteProfiles {
            let profile = TasteProfile(userId: backupProfile.userId)
            profile.spicy = backupProfile.spicy
            profile.boldness = backupProfile.boldness
            profile.sweetness = backupProfile.sweetness
            profile.saltiness = backupProfile.saltiness
            profile.richness = backupProfile.richness
            profile.naturalTaste = backupProfile.naturalTaste
            profile.texture = backupProfile.texture
            profile.cooking = backupProfile.cooking
            profile.updatedAt = backupProfile.updatedAt

            context.insert(profile)
        }

        try context.save()
        logger.info("로컬 데이터 복구 완료: \(data.restaurants.count)개 식당")
        return restoredVisits
    }

    /// 받아 둔 사진 파일을 되살린 방문의 기록 안(VisitPhoto)에 붙인다. 백업에 적힌 순서를 지킨다.
    @MainActor
    private func attachPhotos(_ files: [(url: URL, filename: String, visitID: UUID)],
                              to visits: [UUID: Visit], modelContainer: ModelContainer) throws {
        guard !files.isEmpty else { return }
        let context = modelContainer.mainContext
        var order: [UUID: Int] = [:]
        for file in files {
            guard let visit = visits[file.visitID], let data = try? Data(contentsOf: file.url) else { continue }
            let photo = VisitPhoto(data: data, sortOrder: order[file.visitID, default: 0])
            order[file.visitID, default: 0] += 1
            context.insert(photo)
            photo.visit = visit
        }
        try context.save()
        logger.info("사진 \(files.count)장을 기록에 붙임")
    }

    // MARK: - UserDefaults

    private func loadLastBackupDate() {
        lastBackupDate = UserDefaults.standard.object(forKey: "lastCloudKitBackupDate") as? Date
    }

    private func saveLastBackupDate() {
        UserDefaults.standard.set(lastBackupDate, forKey: "lastCloudKitBackupDate")
    }
}

// MARK: - Backup Models

struct BackupData: Codable {
    let restaurants: [BackupRestaurant]
    let tasteProfiles: [BackupTasteProfile]
    /// 직접 추가한 음식 종류 (없던 시절의 백업은 nil)
    var customCategories: [FoodCategory]? = nil
    let backupDate: Date

    var allVisits: [BackupVisit] { restaurants.flatMap(\.visits) }

    /// 이 백업이 가리키는 사진 레코드 이름 전부.
    var photoRecordNames: [String] {
        allVisits.flatMap { visit -> [String] in
            guard let photoId = visit.photoId else { return [] }
            return (visit.photoFilenames ?? []).map { Self.photoRecordName(photoId: photoId, filename: $0) }
        }
    }

    static func photoRecordName(photoId: UUID, filename: String) -> String {
        "photo.\(photoId.uuidString).\(filename)"
    }
}

struct BackupMenu: Codable {
    let name: String
    let price: Int?
    let menuDescription: String
    let isSignature: Bool
}

struct BackupRestaurant: Codable {
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let notes: String
    let rating: Int
    let visitDate: Date
    let category: String
    let phoneNumber: String
    let isTop6: Bool
    let top6Rank: Int?
    let categoryIcon: String
    let foodCategoryId: String
    let isWishlist: Bool
    let visits: [BackupVisit]
    var menus: [BackupMenu]? = nil
}

struct BackupVisit: Codable {
    let visitDate: Date
    let notes: String
    let rating: Int
    var menuItem: String? = nil
    /// 고른 메뉴의 이름 (같은 식당의 `menus` 중 하나)
    var menuName: String? = nil
    var photoId: UUID? = nil
    var photoFilenames: [String]? = nil

    // 일반 맛 취향
    let spicy: Double?
    let boldness: Double?
    let sweetness: Double?
    let saltiness: Double?
    let richness: Double?
    let naturalTaste: Double?
    let texture: Double?
    let cooking: Double?
    let spicyAppropriate: Int?
    let boldnessAppropriate: Int?
    let sweetnessAppropriate: Int?
    let saltinessAppropriate: Int?
    let richnessAppropriate: Int?
    let naturalTasteAppropriate: Int?
    let textureAppropriate: Int?
    let cookingAppropriate: Int?

    // 스테이크
    let steakDoneness: Double?
    let steakJuiciness: Double?
    let steakTenderness: Double?
    let steakSeasoning: Double?
    let steakFlavor: Double?
    let steakMarbling: Double?
    let steakDonenessAppropriate: Int?
    let steakJuicinessAppropriate: Int?
    let steakTendernessAppropriate: Int?
    let steakSeasoningAppropriate: Int?
    let steakFlavorAppropriate: Int?
    let steakMarblingAppropriate: Int?

    // 초밥
    let sushiShari: Double?
    let sushiNeta: Double?
    let sushiWasabi: Double?
    let sushiBalance: Double?
    let sushiGrip: Double?
    let sushiTemperature: Double?
    let sushiShariAppropriate: Int?
    let sushiNetaAppropriate: Int?
    let sushiWasabiAppropriate: Int?
    let sushiBalanceAppropriate: Int?
    let sushiGripAppropriate: Int?
    let sushiTemperatureAppropriate: Int?

    // 라멘
    let ramenBroth: Double?
    let ramenNoodle: Double?
    let ramenChashu: Double?
    let ramenTopping: Double?
    let ramenTemperature: Double?
    let ramenBalance: Double?
    let ramenBrothAppropriate: Int?
    let ramenNoodleAppropriate: Int?
    let ramenChashuAppropriate: Int?
    let ramenToppingAppropriate: Int?
    let ramenTemperatureAppropriate: Int?
    let ramenBalanceAppropriate: Int?

    // 피자
    let pizzaDough: Double?
    let pizzaSauce: Double?
    let pizzaCheese: Double?
    let pizzaBaking: Double?
    let pizzaTopping: Double?
    let pizzaBalance: Double?
    let pizzaDoughAppropriate: Int?
    let pizzaSauceAppropriate: Int?
    let pizzaCheeseAppropriate: Int?
    let pizzaBakingAppropriate: Int?
    let pizzaToppingAppropriate: Int?
    let pizzaBalanceAppropriate: Int?

    // 와인
    let wineBody: Double?
    let wineTannin: Double?
    let wineAcidity: Double?
    let wineAroma: Double?
    let wineFinish: Double?
    let wineBalance: Double?
    let wineBodyAppropriate: Int?
    let wineTanninAppropriate: Int?
    let wineAcidityAppropriate: Int?
    let wineAromaAppropriate: Int?
    let wineFinishAppropriate: Int?
    let wineBalanceAppropriate: Int?

    // 커피
    let coffeeAcidity: Double?
    let coffeeBody: Double?
    let coffeeFlavor: Double?
    let coffeeAftertaste: Double?
    let coffeeSweetness: Double?
    let coffeeBalance: Double?
    let coffeeAcidityAppropriate: Int?
    let coffeeBodyAppropriate: Int?
    let coffeeFlavorAppropriate: Int?
    let coffeeAftertasteAppropriate: Int?
    let coffeeSweetnessAppropriate: Int?
    let coffeeBalanceAppropriate: Int?
}

struct BackupTasteProfile: Codable {
    let userId: String
    let spicy: Double
    let boldness: Double
    let sweetness: Double
    let saltiness: Double
    let richness: Double
    let naturalTaste: Double
    let texture: Double
    let cooking: Double
    let updatedAt: Date
}

enum BackupError: LocalizedError {
    case invalidData
    case noBackupFound
    case cloudKitNotAvailable

    var errorDescription: String? {
        switch self {
        case .invalidData:
            return String(localized: "백업 데이터가 손상되었습니다")
        case .noBackupFound:
            return String(localized: "백업 데이터를 찾을 수 없습니다")
        case .cloudKitNotAvailable:
            return String(localized: "iCloud를 사용할 수 없어요. 설정에서 iCloud에 로그인했는지 확인해 주세요.")
        }
    }
}
