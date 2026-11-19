//
//  KakaoLocalSearchService.swift
//  인생 맛집
//
//  카카오 로컬 검색 — 응답 모델 · 분류 · 요청.
//

import Foundation
import CoreLocation
import MapKit
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

    /// 키는 레포에 두지 않는다. Config/Secrets.xcconfig → Info.plist 로 들어온다 (→ Config/App.xcconfig).
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""
    }

    private let baseURL = "https://dapi.kakao.com/v2/local"

    private init() {}

    // MARK: - 키워드 검색

    /// 키워드로 장소 검색
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
        urlString += "&sort=accuracy"

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
        urlString += "&sort=distance"

        guard let url = URL(string: urlString) else {
            throw KakaoSearchError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let authHeader = "KakaoAK \(apiKey)"
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        logger.info("🔍 카카오 카테고리 검색: \(category.displayName)")
        logger.info("🔍 요청 URL: \(urlString)")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw KakaoSearchError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("❌ 카카오 API 오류: \(httpResponse.statusCode)")
            logger.error("❌ 요청 URL: \(urlString)")

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
    func searchNearbyPlaces(
        coordinate: CLLocationCoordinate2D,
        radius: Int = 5000
    ) async throws -> [KakaoPlace] {
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

        let allPlaces = restaurantResult.documents + cafeResult.documents

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
            return String(localized: "카카오 REST API 키가 설정되지 않았습니다")
        case .invalidURL:
            return String(localized: "잘못된 URL입니다")
        case .invalidResponse:
            return String(localized: "잘못된 응답입니다")
        case .httpError(let code):
            return String(localized: "HTTP 오류: \(code)")
        case .decodingError(let error):
            return String(localized: "디코딩 오류: \(error.localizedDescription)")
        }
    }
}
