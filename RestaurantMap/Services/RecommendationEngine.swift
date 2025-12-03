import Foundation
import CoreLocation
import OSLog

/// 추천 결과 모델
struct Recommendation: Identifiable {
    let id = UUID()
    let restaurant: FirebaseRestaurant
    let score: Double // 0.0 ~ 100.0
    let reason: String
    let similarityDetails: SimilarityDetails?
}

/// 유사도 상세 정보
struct SimilarityDetails {
    let shapeSimilarity: Double // 도형 유사도
    let tasteSimilarity: Double // 취향 유사도
    let ratingScore: Double // 평점 점수
    let proximityScore: Double // 거리 점수
}

/// 식당 추천 엔진
@MainActor
class RecommendationEngine: ObservableObject {
    static let shared = RecommendationEngine()

    private let firebaseService = FirebaseService.shared
    private let logger = Logger(subsystem: "com.restaurantmap", category: "Recommendation")

    @Published var isLoading = false
    @Published var recommendations: [Recommendation] = []

    private init() {}

    // MARK: - 유사도 계산 함수들

    /// 코사인 유사도 계산 (0.0 ~ 1.0, 1에 가까울수록 유사)
    func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }

        let dotProduct = zip(a, b).map(*).reduce(0, +)
        let magnitudeA = sqrt(a.map { $0 * $0 }.reduce(0, +))
        let magnitudeB = sqrt(b.map { $0 * $0 }.reduce(0, +))

        guard magnitudeA > 0, magnitudeB > 0 else { return 0.0 }
        return dotProduct / (magnitudeA * magnitudeB)
    }

    /// 유클리디안 거리 계산 (0에 가까울수록 유사)
    func euclideanDistance(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count else { return Double.infinity }
        let sumSquares = zip(a, b).map { pow($0 - $1, 2) }.reduce(0, +)
        return sqrt(sumSquares)
    }

    /// 유클리디안 거리를 0-1 유사도로 변환
    func euclideanToSimilarity(_ distance: Double, maxDistance: Double = 50.0) -> Double {
        return max(0, 1 - (distance / maxDistance))
    }

    // MARK: - 추천 메서드들

    /// 1. 도형 유사도 기반 추천
    /// 내 방문 기록 중 하나와 비슷한 맛의 다른 식당 찾기
    func recommendBySimilarShape(
        myVisit: Visit,
        category: FoodCategory,
        limit: Int = 10
    ) async throws -> [Recommendation] {
        logger.info("🔍 Finding restaurants with similar shape...")

        // Firebase에서 같은 카테고리 식당들 가져오기
        let allRestaurants = try await firebaseService.fetchRestaurants(category: category)

        // 내 방문 기록을 Firebase 형식으로 변환
        let myFirebaseVisit = myVisit.toFirebase(
            restaurantId: "",
            userId: firebaseService.currentUserId,
            isPublic: false
        )
        let myVector = myFirebaseVisit.intensityVector(for: category)

        var recommendations: [Recommendation] = []

        for restaurant in allRestaurants {
            // 각 식당의 방문 기록들 가져오기
            let visits = try await firebaseService.fetchVisits(for: restaurant.id)

            guard !visits.isEmpty else { continue }

            // 모든 방문의 평균 벡터 계산
            var avgVector = [Double](repeating: 0.0, count: myVector.count)
            for visit in visits {
                let vector = visit.intensityVector(for: category)
                for i in 0..<avgVector.count {
                    avgVector[i] += vector[i]
                }
            }
            avgVector = avgVector.map { $0 / Double(visits.count) }

            // 코사인 유사도 계산
            let similarity = cosineSimilarity(myVector, avgVector)

            // 유사도가 높은 것만 추천
            if similarity > 0.7 {
                let score = similarity * 100.0
                let recommendation = Recommendation(
                    restaurant: restaurant,
                    score: score,
                    reason: "맛의 형태가 \(Int(similarity * 100))% 유사합니다",
                    similarityDetails: SimilarityDetails(
                        shapeSimilarity: similarity,
                        tasteSimilarity: 0,
                        ratingScore: restaurant.averageRating / 5.0,
                        proximityScore: 0
                    )
                )
                recommendations.append(recommendation)
            }
        }

        // 점수 순으로 정렬
        recommendations.sort { $0.score > $1.score }

        logger.info("✅ Found \(recommendations.count) similar restaurants")
        return Array(recommendations.prefix(limit))
    }

    /// 2. 취향 유사 사용자 기반 추천 (협업 필터링)
    /// 나와 입맛이 비슷한 사람들이 좋아하는 식당 추천
    func recommendByCollaborativeFiltering(
        myTasteProfile: TasteProfile,
        myVisitedRestaurantIds: Set<String> = [],
        limit: Int = 10
    ) async throws -> [Recommendation] {
        logger.info("🔍 Finding recommendations from similar users...")

        // 1. 모든 사용자의 취향 프로필 가져오기
        let allProfiles = try await firebaseService.fetchAllTasteProfiles()

        // 2. 내 취향과 유사한 사용자 찾기
        let myVector = myTasteProfile.toFirebase(userId: "").asVector
        var similarUsers: [(userId: String, similarity: Double)] = []

        for profile in allProfiles {
            // 자신 제외
            guard profile.userId != firebaseService.currentUserId else { continue }

            let similarity = cosineSimilarity(myVector, profile.asVector)

            // 유사도 0.7 이상인 사용자만
            if similarity > 0.7 {
                similarUsers.append((userId: profile.userId, similarity: similarity))
            }
        }

        // 유사도 순으로 정렬
        similarUsers.sort { $0.similarity > $1.similarity }

        logger.info("👥 Found \(similarUsers.count) similar users")

        // 유사한 사용자가 없으면 빈 배열 반환
        guard !similarUsers.isEmpty else {
            logger.warning("No similar users found")
            return []
        }

        // 3. 모든 공개 식당 미리 가져오기 (효율성)
        let allRestaurants = try await firebaseService.fetchAllRestaurants()
        let restaurantDict = Dictionary(uniqueKeysWithValues: allRestaurants.map { ($0.id, $0) })

        logger.info("📥 Fetched \(allRestaurants.count) restaurants for matching")

        // 4. 유사한 사용자들의 고평점 식당 가져오기
        var restaurantScores: [String: (restaurant: FirebaseRestaurant, score: Double, count: Int)] = [:]

        for (userId, userSimilarity) in similarUsers.prefix(10) { // 상위 10명만
            let visits = try await firebaseService.fetchVisits(for: userId, limit: 50)

            for visit in visits {
                // 내가 이미 간 곳은 제외
                guard !myVisitedRestaurantIds.contains(visit.restaurantId) else { continue }

                // 평점이 4점 이상인 것만
                guard visit.rating >= 4 else { continue }

                // 식당 정보가 있는지 확인
                guard let restaurant = restaurantDict[visit.restaurantId] else { continue }

                // 점수 계산: 유사도 * 평점
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

        // 4. 추천 리스트 생성
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

    /// 3. 하이브리드 추천 (종합)
    /// 도형 유사도 + 취향 유사도 + 평점 + 거리를 모두 고려
    func recommendHybrid(
        myTasteProfile: TasteProfile,
        myRecentVisits: [Visit],
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

        // 2. 내 취향 벡터
        let myTasteVector = myTasteProfile.toFirebase(userId: "").asVector

        // 3. 내 최근 방문들의 평균 도형 (카테고리별)
        var myShapeVectors: [FoodCategory: [Double]] = [:]
        for visit in myRecentVisits.suffix(10) {
            guard let restaurant = visit.restaurant else { continue }
            let category = restaurant.foodCategory
            let fbVisit = visit.toFirebase(restaurantId: "", userId: "", isPublic: false)
            let vector = fbVisit.intensityVector(for: category)

            if var existing = myShapeVectors[category] {
                for i in 0..<existing.count {
                    existing[i] += vector[i]
                }
                myShapeVectors[category] = existing
            } else {
                myShapeVectors[category] = vector
            }
        }

        // 평균 계산
        for (category, vector) in myShapeVectors {
            let count = Double(myRecentVisits.filter { $0.restaurant?.foodCategory == category }.count)
            myShapeVectors[category] = vector.map { $0 / count }
        }

        // 4. 각 식당에 대해 점수 계산
        var recommendations: [Recommendation] = []

        for restaurant in allRestaurants {
            // 4-1. 맛 도형 유사도 (40%)
            var shapeSimilarity = 0.0
            let restaurantCategory = FoodCategory(rawValue: restaurant.foodCategory) ?? .general

            if let myShapeVector = myShapeVectors[restaurantCategory] {
                // 식당의 평균 방문 기록 벡터 (간단히 만족도 점수 사용)
                // 실제로는 방문 기록들을 가져와서 평균 계산
                shapeSimilarity = restaurant.satisfactionScore / 100.0
            } else {
                shapeSimilarity = 0.5 // 해당 카테고리 경험 없으면 중립
            }

            // 4-2. 평점 점수 (30%)
            let ratingScore = restaurant.averageRating / 5.0

            // 4-3. 만족도 점수 (20%)
            let satisfactionScore = restaurant.satisfactionScore / 100.0

            // 4-4. 거리 점수 (10%)
            var proximityScore = 0.5 // 기본값
            if let currentLocation = currentLocation {
                let restaurantLocation = CLLocation(
                    latitude: restaurant.latitude,
                    longitude: restaurant.longitude
                )
                let distance = currentLocation.distance(from: restaurantLocation) / 1000.0 // km
                proximityScore = max(0, 1 - (distance / 20.0)) // 20km 이내가 기준
            }

            // 4-5. 최종 점수 계산
            let finalScore = (
                shapeSimilarity * 0.4 +
                ratingScore * 0.3 +
                satisfactionScore * 0.2 +
                proximityScore * 0.1
            ) * 100.0

            // 일정 점수 이상만 추천
            if finalScore > 50.0 {
                let recommendation = Recommendation(
                    restaurant: restaurant,
                    score: finalScore,
                    reason: generateRecommendationReason(
                        shapeSimilarity: shapeSimilarity,
                        ratingScore: ratingScore,
                        proximityScore: proximityScore,
                        distance: currentLocation != nil ?
                            currentLocation!.distance(from: CLLocation(
                                latitude: restaurant.latitude,
                                longitude: restaurant.longitude
                            )) / 1000.0 : nil
                    ),
                    similarityDetails: SimilarityDetails(
                        shapeSimilarity: shapeSimilarity,
                        tasteSimilarity: 0,
                        ratingScore: ratingScore,
                        proximityScore: proximityScore
                    )
                )
                recommendations.append(recommendation)
            }
        }

        // 점수 순으로 정렬
        recommendations.sort { $0.score > $1.score }

        logger.info("✅ Generated \(recommendations.count) hybrid recommendations")
        return Array(recommendations.prefix(limit))
    }

    // MARK: - Helper Methods

    /// 추천 이유 텍스트 생성
    private func generateRecommendationReason(
        shapeSimilarity: Double,
        ratingScore: Double,
        proximityScore: Double,
        distance: Double?
    ) -> String {
        var reasons: [String] = []

        if shapeSimilarity > 0.8 {
            reasons.append("당신의 입맛과 잘 맞아요")
        }

        if ratingScore > 0.8 {
            reasons.append("높은 평점")
        }

        if let distance = distance, distance < 2.0 {
            reasons.append("가까운 거리 (\(String(format: "%.1f", distance))km)")
        } else if let distance = distance, distance < 5.0 {
            reasons.append("\(String(format: "%.1f", distance))km 거리")
        }

        return reasons.isEmpty ? "추천 식당" : reasons.joined(separator: " • ")
    }

    /// 내가 방문한 식당 ID 세트 생성 (중복 추천 방지)
    func getVisitedRestaurantIds(from restaurants: [Restaurant]) -> Set<String> {
        Set(restaurants.map { $0.name }) // 실제로는 Firebase ID 매핑 필요
    }
}
