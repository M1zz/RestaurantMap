import Foundation
import CloudKit
import SwiftData
import OSLog

/// CloudKit을 사용한 데이터 백업/복구 서비스
@Observable
class CloudKitBackupService {
    static let shared = CloudKitBackupService()

    private let logger = Logger(subsystem: "com.restaurantmap", category: "CloudKitBackup")

    private let recordType = "BackupData"

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
        // CloudKit Capability가 추가되지 않았으면 nil 반환
        // 이렇게 하면 EXC_BREAKPOINT 에러를 완전히 회피
        return nil  // 임시로 비활성화 - CloudKit Capability를 추가한 후 CKContainer.default()로 변경
    }

    // MARK: - Public Methods

    /// iCloud 계정 상태 확인
    func checkiCloudStatus() async -> Bool {
        guard let container = getContainer() else {
            errorMessage = "CloudKit을 사용할 수 없습니다.\n\nXcode에서 Signing & Capabilities 탭으로 이동하여:\n1. '+ Capability' 클릭\n2. 'iCloud' 추가\n3. 'CloudKit' 체크박스 활성화"
            logger.error("❌ CloudKit Capability가 추가되지 않음")
            return false
        }

        do {
            let status = try await container.accountStatus()
            switch status {
            case .available:
                logger.info("iCloud 계정 사용 가능")
                return true
            case .noAccount:
                errorMessage = "iCloud 계정에 로그인되어 있지 않습니다."
                return false
            case .restricted:
                errorMessage = "iCloud 접근이 제한되어 있습니다."
                return false
            case .couldNotDetermine:
                errorMessage = "iCloud 상태를 확인할 수 없습니다."
                return false
            case .temporarilyUnavailable:
                errorMessage = "iCloud가 일시적으로 사용 불가합니다."
                return false
            @unknown default:
                errorMessage = "알 수 없는 iCloud 상태입니다."
                return false
            }
        } catch {
            logger.error("iCloud 상태 확인 실패: \(error.localizedDescription)")
            errorMessage = "iCloud 상태 확인 실패: \(error.localizedDescription)"
            return false
        }
    }

    /// 데이터 백업
    func backup(modelContainer: ModelContainer) async -> Bool {
        guard await checkiCloudStatus() else { return false }

        isBackingUp = true
        errorMessage = nil
        progressMessage = "백업 준비 중..."

        defer { isBackingUp = false }

        do {
            // 1. 로컬 데이터 가져오기
            progressMessage = "데이터 수집 중..."
            let backupData = try await fetchLocalData(modelContainer: modelContainer)

            // 2. 기존 백업 삭제
            progressMessage = "기존 백업 정리 중..."
            try await deleteExistingBackups()

            // 3. 새 백업 저장
            progressMessage = "CloudKit에 저장 중..."
            try await saveToCloudKit(data: backupData)

            // 4. 마지막 백업 시간 저장
            lastBackupDate = Date()
            saveLastBackupDate()

            progressMessage = "백업 완료!"
            logger.info("백업 성공")
            return true

        } catch {
            logger.error("백업 실패: \(error.localizedDescription)")
            errorMessage = "백업 실패: \(error.localizedDescription)"
            progressMessage = nil
            return false
        }
    }

    /// 데이터 복구
    func restore(modelContainer: ModelContainer) async -> Bool {
        guard await checkiCloudStatus() else { return false }

        isRestoring = true
        errorMessage = nil
        progressMessage = "복구 준비 중..."

        defer { isRestoring = false }

        do {
            // 1. CloudKit에서 데이터 가져오기
            progressMessage = "CloudKit에서 데이터 가져오는 중..."
            guard let backupData = try await fetchFromCloudKit() else {
                errorMessage = "백업 데이터가 없습니다."
                progressMessage = nil
                return false
            }

            // 2. 로컬 데이터 삭제
            progressMessage = "기존 데이터 정리 중..."
            try await deleteLocalData(modelContainer: modelContainer)

            // 3. 복구된 데이터 저장
            progressMessage = "데이터 복구 중..."
            try await restoreLocalData(modelContainer: modelContainer, data: backupData)

            progressMessage = "복구 완료!"
            logger.info("복구 성공")
            return true

        } catch {
            logger.error("복구 실패: \(error.localizedDescription)")
            errorMessage = "복구 실패: \(error.localizedDescription)"
            progressMessage = nil
            return false
        }
    }

    /// 로컬 데이터 초기화 (모든 데이터 삭제)
    func resetLocalData(modelContainer: ModelContainer) async -> Bool {
        progressMessage = "데이터 초기화 중..."

        do {
            try await deleteLocalData(modelContainer: modelContainer)
            progressMessage = "초기화 완료!"
            logger.info("로컬 데이터 초기화 완료")
            return true
        } catch {
            logger.error("초기화 실패: \(error.localizedDescription)")
            errorMessage = "초기화 실패: \(error.localizedDescription)"
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

        for restaurant in restaurants {
            let visits = restaurant.visits?.map { visit in
                BackupVisit(
                    visitDate: visit.visitDate,
                    notes: visit.notes,
                    rating: visit.rating,
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
                foodCategoryRaw: restaurant.foodCategoryRaw,
                isWishlist: restaurant.isWishlist,
                visits: visits
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
            backupDate: Date()
        )
    }

    /// CloudKit에 데이터 저장
    private func saveToCloudKit(data: BackupData) async throws {
        guard let container = getContainer() else {
            throw BackupError.cloudKitNotAvailable
        }

        let privateDB = container.privateCloudDatabase

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let jsonData = try encoder.encode(data)

        let record = CKRecord(recordType: recordType)
        record["jsonData"] = jsonData as CKRecordValue
        record["backupDate"] = data.backupDate as CKRecordValue

        try await privateDB.save(record)
        logger.info("CloudKit에 백업 저장 완료")
    }

    /// 기존 백업 삭제
    private func deleteExistingBackups() async throws {
        guard let container = getContainer() else {
            throw BackupError.cloudKitNotAvailable
        }

        let privateDB = container.privateCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))

        let (results, _) = try await privateDB.records(matching: query)

        for (recordID, _) in results {
            try await privateDB.deleteRecord(withID: recordID)
        }

        logger.info("기존 백업 삭제 완료")
    }

    /// CloudKit에서 데이터 가져오기
    private func fetchFromCloudKit() async throws -> BackupData? {
        guard let container = getContainer() else {
            throw BackupError.cloudKitNotAvailable
        }

        let privateDB = container.privateCloudDatabase
        let query = CKQuery(recordType: recordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "backupDate", ascending: false)]

        let (results, _) = try await privateDB.records(matching: query, resultsLimit: 1)

        guard let (_, result) = results.first else {
            return nil
        }

        let record = try result.get()

        guard let jsonData = record["jsonData"] as? Data else {
            throw BackupError.invalidData
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backupData = try decoder.decode(BackupData.self, from: jsonData)

        return backupData
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

    /// 복구된 데이터를 로컬에 저장
    @MainActor
    private func restoreLocalData(modelContainer: ModelContainer, data: BackupData) throws {
        let context = modelContainer.mainContext

        // Restaurant 및 Visit 복구
        for backupRestaurant in data.restaurants {
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
                foodCategory: FoodCategory(rawValue: backupRestaurant.foodCategoryRaw) ?? .general,
                listType: backupRestaurant.isWishlist ? .wishlist : (backupRestaurant.isTop6 ? .michelin : .visited)
            )

            context.insert(restaurant)

            // Visit 복구
            for backupVisit in backupRestaurant.visits {
                let visit = Visit(
                    restaurant: restaurant,
                    visitDate: backupVisit.visitDate,
                    notes: backupVisit.notes,
                    rating: backupVisit.rating
                )

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
    let backupDate: Date
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
    let foodCategoryRaw: String
    let isWishlist: Bool
    let visits: [BackupVisit]
}

struct BackupVisit: Codable {
    let visitDate: Date
    let notes: String
    let rating: Int

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

enum BackupError: Error {
    case invalidData
    case noBackupFound
    case cloudKitNotAvailable

    var localizedDescription: String {
        switch self {
        case .invalidData:
            return "백업 데이터가 손상되었습니다"
        case .noBackupFound:
            return "백업 데이터를 찾을 수 없습니다"
        case .cloudKitNotAvailable:
            return "CloudKit을 사용할 수 없습니다. Xcode에서 iCloud Capability를 추가하세요."
        }
    }
}
