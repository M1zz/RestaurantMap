import Foundation
import CoreLocation
import OSLog

// MARK: - Kakao API Models

struct KakaoSearchResponse: Codable {
    let documents: [KakaoPlace]
    let meta: KakaoMeta
}

struct KakaoPlace: Codable, Identifiable {
    let id: String
    let placeName: String
    let categoryName: String
    let categoryGroupCode: String
    let categoryGroupName: String
    let phone: String
    let addressName: String
    let roadAddressName: String
    let x: String  // longitude
    let y: String  // latitude
    let placeUrl: String
    let distance: String

    enum CodingKeys: String, CodingKey {
        case id
        case placeName = "place_name"
        case categoryName = "category_name"
        case categoryGroupCode = "category_group_code"
        case categoryGroupName = "category_group_name"
        case phone
        case addressName = "address_name"
        case roadAddressName = "road_address_name"
        case x
        case y
        case placeUrl = "place_url"
        case distance
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: Double(y) ?? 0,
            longitude: Double(x) ?? 0
        )
    }
}

struct KakaoMeta: Codable {
    let isEnd: Bool
    let pageableCount: Int
    let totalCount: Int

    enum CodingKeys: String, CodingKey {
        case isEnd = "is_end"
        case pageableCount = "pageable_count"
        case totalCount = "total_count"
    }
}

// MARK: - Kakao Category

enum KakaoCategory: String, CaseIterable {
    case restaurant = "FD6"  // 음식점
    case cafe = "CE7"        // 카페

    var displayName: String {
        switch self {
        case .restaurant: return "음식점"
        case .cafe: return "카페"
        }
    }
}

// MARK: - Kakao Local Search Service

class KakaoLocalSearchService: ObservableObject {
    static let shared = KakaoLocalSearchService()

    private let logger = Logger(subsystem: "com.restaurantmap", category: "KakaoSearch")

    // ⚠️ 실제 사용 시 카카오 REST API 키를 여기에 입력하세요
    // https://developers.kakao.com/console/app 에서 발급받을 수 있습니다
    private var apiKey: String {
        // Info.plist에서 읽어오거나 직접 입력
        return Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""
    }

    private let baseURL = "https://dapi.kakao.com/v2/local"

    private init() {}

    // MARK: - 키워드 검색

    /// 키워드로 장소 검색
    /// - Parameters:
    ///   - query: 검색 키워드
    ///   - coordinate: 검색 기준 좌표 (현재 위치)
    ///   - radius: 검색 반경 (미터, 최대 20000)
    ///   - page: 결과 페이지 번호 (1~45)
    ///   - size: 한 페이지에 보여질 문서 수 (1~15, 기본값 15)
    func searchByKeyword(
        query: String,
        coordinate: CLLocationCoordinate2D? = nil,
        radius: Int = 5000,
        page: Int = 1,
        size: Int = 15
    ) async throws -> KakaoSearchResponse {
        guard !apiKey.isEmpty else {
            throw KakaoSearchError.noAPIKey
        }

        var urlString = "\(baseURL)/search/keyword.json?"
        urlString += "query=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)"

        if let coord = coordinate {
            urlString += "&x=\(coord.longitude)"
            urlString += "&y=\(coord.latitude)"
            urlString += "&radius=\(radius)"
        }

        urlString += "&page=\(page)"
        urlString += "&size=\(size)"
        urlString += "&sort=accuracy"  // accuracy: 정확도순, distance: 거리순

        guard let url = URL(string: urlString) else {
            throw KakaoSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")

        logger.info("🔍 카카오 검색 요청: \(query)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KakaoSearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("❌ 카카오 API 오류: \(httpResponse.statusCode)")
            throw KakaoSearchError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(KakaoSearchResponse.self, from: data)

        logger.info("✅ 카카오 검색 성공: \(result.documents.count)개 결과")

        return result
    }

    // MARK: - 카테고리 검색

    /// 카테고리로 장소 검색
    /// - Parameters:
    ///   - category: 카테고리 코드 (FD6: 음식점, CE7: 카페)
    ///   - coordinate: 검색 기준 좌표 (필수)
    ///   - radius: 검색 반경 (미터, 최대 20000)
    ///   - page: 결과 페이지 번호 (1~45)
    ///   - size: 한 페이지에 보여질 문서 수 (1~15, 기본값 15)
    func searchByCategory(
        category: KakaoCategory,
        coordinate: CLLocationCoordinate2D,
        radius: Int = 5000,
        page: Int = 1,
        size: Int = 15
    ) async throws -> KakaoSearchResponse {
        guard !apiKey.isEmpty else {
            throw KakaoSearchError.noAPIKey
        }

        var urlString = "\(baseURL)/search/category.json?"
        urlString += "category_group_code=\(category.rawValue)"
        urlString += "&x=\(coordinate.longitude)"
        urlString += "&y=\(coordinate.latitude)"
        urlString += "&radius=\(radius)"
        urlString += "&page=\(page)"
        urlString += "&size=\(size)"
        urlString += "&sort=distance"  // distance: 거리순

        guard let url = URL(string: urlString) else {
            throw KakaoSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("KakaoAK \(apiKey)", forHTTPHeaderField: "Authorization")

        logger.info("🔍 카카오 카테고리 검색: \(category.displayName)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KakaoSearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("❌ 카카오 API 오류: \(httpResponse.statusCode)")

            // 에러 메시지 출력
            if let errorString = String(data: data, encoding: .utf8) {
                logger.error("에러 내용: \(errorString)")
            }

            throw KakaoSearchError.httpError(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(KakaoSearchResponse.self, from: data)

        logger.info("✅ 카카오 카테고리 검색 성공: \(result.documents.count)개 결과")

        return result
    }

    // MARK: - 주변 음식점/카페 검색

    /// 주변 음식점과 카페를 한 번에 검색
    /// - Parameters:
    ///   - coordinate: 검색 기준 좌표
    ///   - radius: 검색 반경 (미터)
    func searchNearbyPlaces(
        coordinate: CLLocationCoordinate2D,
        radius: Int = 5000
    ) async throws -> [KakaoPlace] {
        // 병렬로 음식점과 카페 검색
        async let restaurants = searchByCategory(
            category: .restaurant,
            coordinate: coordinate,
            radius: radius,
            size: 15
        )

        async let cafes = searchByCategory(
            category: .cafe,
            coordinate: coordinate,
            radius: radius,
            size: 15
        )

        let (restaurantResult, cafeResult) = try await (restaurants, cafes)

        // 결과 합치기
        var allPlaces = restaurantResult.documents + cafeResult.documents

        // 중복 제거 (같은 ID)
        var uniquePlaces: [KakaoPlace] = []
        var seenIDs = Set<String>()

        for place in allPlaces {
            if !seenIDs.contains(place.id) {
                seenIDs.insert(place.id)
                uniquePlaces.append(place)
            }
        }

        logger.info("✅ 주변 장소 검색 완료: \(uniquePlaces.count)개")

        return uniquePlaces
    }
}

// MARK: - Errors

enum KakaoSearchError: LocalizedError {
    case noAPIKey
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingError(Error)

    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "카카오 REST API 키가 설정되지 않았습니다"
        case .invalidURL:
            return "잘못된 URL입니다"
        case .invalidResponse:
            return "잘못된 응답입니다"
        case .httpError(let code):
            return "HTTP 오류: \(code)"
        case .decodingError(let error):
            return "디코딩 오류: \(error.localizedDescription)"
        }
    }
}
