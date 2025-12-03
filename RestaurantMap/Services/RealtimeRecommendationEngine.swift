import Foundation
import CoreLocation
import OSLog

/// Realtime Database 기반 추천 엔진
@MainActor
class RealtimeRecommendationEngine: ObservableObject {
    static let shared = RealtimeRecommendationEngine()

    private let firebaseService = FirebaseRealtimeService.shared
    private let logger = Logger(subsystem: "com.restaurantmap", category: "Recommendation")

    @Published var isLoading = false
    @Published var recommendations: [Recommendation] = []

    private init() {}

    // MARK: - 유사도 계산

    func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0, magnitudeB > 0 else { return 0.0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }

    // MARK: - 추천 메서드

    /// 협업 필터링 추천: 나와 입맛이 비슷한 사람들이 좋아하는 식당
    func recommendByCollaborativeFiltering(
        myTasteProfile: TasteProfile,
        myVisitedRestaurantIds: Set<String> = [],
        limit: Int = 10
    ) async throws -> [Recommendation] {
        logger.info("🔍 Finding recommendations from similar users...")

        // 1. 모든 사용자의 취향 프로필 가져오기
        let allProfiles = try await firebaseService.fetchAllTasteProfiles()

        // 2. 내 취향과 유사한 사용자 찾기
        let myVector = [
            myTasteProfile.spicy,
            myTasteProfile.boldness,
            myTasteProfile.sweetness,
            myTasteProfile.saltiness,
            myTasteProfile.richness,
            myTasteProfile.naturalTaste,
            myTasteProfile.texture,
            myTasteProfile.cooking
        ]

        var similarUsers: [(userId: String, similarity: Double)] = []

        for profile in allProfiles {
            // 자신 제외
            guard profile.userId != firebaseService.currentUserId else { continue }

            let similarity = cosineSimilarity(myVector, profile.asVector)

            // 유사도 0.6 이상인 사용자 (Realtime DB는 더 많은 데이터 처리 가능)
            if similarity > 0.6 {
                similarUsers.append((userId: profile.userId, similarity: similarity))
            }
        }

        // 유사도 순으로 정렬
        similarUsers.sort { $0.similarity > $1.similarity }

        logger.info("👥 Found \(similarUsers.count) similar users")

        guard !similarUsers.isEmpty else {
            logger.warning("No similar users found")
            return []
        }

        // 3. 모든 공개 식당 미리 가져오기
        let allRestaurants = try await firebaseService.fetchAllRestaurants()
        let restaurantDict = Dictionary(uniqueKeysWithValues: allRestaurants.map { ($0.id, $0) })

        logger.info("📥 Fetched \(allRestaurants.count) restaurants for matching")

        // 4. 유사한 사용자들의 고평점 식당 가져오기
        var restaurantScores: [String: (restaurant: FirebaseRestaurant, score: Double, count: Int)] = [:]

        for (userId, userSimilarity) in similarUsers.prefix(10) {
            let visits = try await firebaseService.fetchVisits(for: userId, limit: 50)

            for visit in visits {
                // 내가 이미 간 곳은 제외
                guard !myVisitedRestaurantIds.contains(visit.restaurantId) else { continue }

                // 평점이 4점 이상인 것만
                guard visit.rating >= 4 else { continue }

                // 식당 정보가 있는지 확인
                guard let restaurant = restaurantDict[visit.restaurantId] else { continue }

                // 점수 계산
                let score = userSimilarity * Double(visit.rating) / 5.0

                if let existing = restaurantScores[visit.restaurantId] {
                    restaurantScores[visit.restaurantId] = (
                        existing.restaurant,
                        existing.score + score,
                        existing.count + 1
                    )
                } else {
                    restaurantScores[visit.restaurantId] = (restaurant, score, 1)
                }
            }
        }

        // 5. 추천 리스트 생성
        var recommendations: [Recommendation] = []

        for (_, value) in restaurantScores {
            let avgScore = value.score / Double(value.count)
            let finalScore = avgScore * 100.0

            let recommendation = Recommendation(
                restaurant: value.restaurant,
                score: finalScore,
                reason: "비슷한 입맛을 가진 \(value.count)명이 좋아합니다",
                similarityDetails: SimilarityDetails(
                    shapeSimilarity: 0,
                    tasteSimilarity: avgScore,
                    ratingScore: value.restaurant.averageRating / 5.0,
                    proximityScore: 0
                )
            )
            recommendations.append(recommendation)
        }

        // 점수 순으로 정렬
        recommendations.sort { $0.score > $1.score }

        logger.info("✅ Generated \(recommendations.count) collaborative recommendations")
        return Array(recommendations.prefix(limit))
    }

    /// 하이브리드 추천
    func recommendHybrid(
        myTasteProfile: TasteProfile,
        currentLocation: CLLocation?,
        category: FoodCategory? = nil,
        limit: Int = 20
    ) async throws -> [Recommendation] {
        logger.info("🔍 Generating hybrid recommendations...")

        // 1. 모든 공개 식당 가져오기
        var allRestaurants: [FirebaseRestaurant]
        if let category = category {
            allRestaurants = try await firebaseService.fetchRestaurants(category: category)
        } else {
            allRestaurants = try await firebaseService.fetchAllRestaurants()
        }

        // 2. 각 식당에 대해 점수 계산
        var recommendations: [Recommendation] = []

        for restaurant in allRestaurants {
            // 평점 점수 (40%)
            let ratingScore = restaurant.averageRating / 5.0

            // 만족도 점수 (40%)
            let satisfactionScore = restaurant.satisfactionScore / 100.0

            // 거리 점수 (20%)
            var proximityScore = 0.5
            if let currentLocation = currentLocation {
                let restaurantLocation = CLLocation(
                    latitude: restaurant.latitude,
                    longitude: restaurant.longitude
                )
                let distance = currentLocation.distance(from: restaurantLocation) / 1000.0
                proximityScore = max(0, 1 - (distance / 20.0))
            }

            // 최종 점수
            let finalScore = (
                ratingScore * 0.4 +
                satisfactionScore * 0.4 +
                proximityScore * 0.2
            ) * 100.0

            if finalScore > 50.0 {
                let recommendation = Recommendation(
                    restaurant: restaurant,
                    score: finalScore,
                    reason: generateRecommendationReason(
                        ratingScore: ratingScore,
                        satisfactionScore: satisfactionScore,
                        proximityScore: proximityScore
                    ),
                    similarityDetails: SimilarityDetails(
                        shapeSimilarity: 0,
                        tasteSimilarity: 0,
                        ratingScore: ratingScore,
                        proximityScore: proximityScore
                    )
                )
                recommendations.append(recommendation)
            }
        }

        recommendations.sort { $0.score > $1.score }

        logger.info("✅ Generated \(recommendations.count) hybrid recommendations")
        return Array(recommendations.prefix(limit))
    }

    // MARK: - Helper Methods

    private func generateRecommendationReason(
        ratingScore: Double,
        satisfactionScore: Double,
        proximityScore: Double
    ) -> String {
        var reasons: [String] = []

        if ratingScore > 0.8 {
            reasons.append("높은 평점 (\(String(format: "%.1f", ratingScore * 5))점)")
        }

        if satisfactionScore > 0.8 {
            reasons.append("높은 만족도")
        }

        if proximityScore > 0.7 {
            reasons.append("가까운 거리")
        }

        return reasons.isEmpty ? "추천 식당" : reasons.joined(separator: " • ")
    }

    func getVisitedRestaurantIds(from restaurants: [Restaurant]) -> Set<String> {
        Set(restaurants.map {
            $0.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0.name
        })
    }
}
