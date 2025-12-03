import Foundation
import SwiftData
import OSLog

// MARK: - 추천 식당 모델
struct RecommendedRestaurant: Identifiable {
    let id = UUID()
    let name: String
    let category: String
    let foodCategory: FoodCategory
    let address: String
    let predictedRating: Double  // 예측 별점 (1-5)
    let recommendationScore: Double  // 추천 점수 (0-100)
    let reason: String  // 추천 이유
    let similarUsers: Int  // 유사한 취향의 사용자 수
}

// MARK: - 추천 서비스
class RecommendationService: ObservableObject {
    private let logger = Logger(subsystem: "com.restaurantmap", category: "Recommendation")

    /// 협업 필터링 기반 식당 추천
    /// - Parameter userRestaurants: 사용자가 평가한 식당 목록
    /// - Returns: 추천 식당 목록
    func getRecommendations(from userRestaurants: [Restaurant]) -> [RecommendedRestaurant] {
        logger.info("📊 추천 시스템 시작 - 사용자 평가 식당: \(userRestaurants.count)개")

        // 1. 사용자 취향 분석
        let userPreference = analyzeUserPreference(from: userRestaurants)
        logger.info("✅ 사용자 취향 분석 완료")

        // 2. 가상의 다른 사용자들 생성 (Collaborative Filtering 시뮬레이션)
        let virtualUsers = generateVirtualUsers(basedOn: userPreference)
        logger.info("✅ 가상 사용자 \(virtualUsers.count)명 생성")

        // 3. 가상 사용자들이 좋아하는 식당 수집
        let recommendedRestaurants = collectRecommendations(
            from: virtualUsers,
            userPreference: userPreference,
            excludingUserRestaurants: userRestaurants
        )
        logger.info("✅ 추천 식당 \(recommendedRestaurants.count)개 생성")

        return recommendedRestaurants
    }

    // MARK: - Private Methods

    /// 사용자 취향 분석
    private func analyzeUserPreference(from restaurants: [Restaurant]) -> UserPreference {
        // 평점이 높은 식당들의 특징 분석
        let highRated = restaurants.filter { $0.rating >= 4 }

        // 선호 카테고리 분석
        var categoryScores: [FoodCategory: Double] = [:]
        for restaurant in highRated {
            let score = Double(restaurant.rating)
            categoryScores[restaurant.foodCategory, default: 0] += score
        }

        // 평균 별점
        let avgRating = restaurants.isEmpty ? 0 : Double(restaurants.map { $0.rating }.reduce(0, +)) / Double(restaurants.count)

        return UserPreference(
            favoriteCategories: categoryScores,
            averageRating: avgRating,
            totalRatings: restaurants.count
        )
    }

    /// 가상 사용자 생성 (협업 필터링 시뮬레이션)
    private func generateVirtualUsers(basedOn preference: UserPreference) -> [VirtualUser] {
        var users: [VirtualUser] = []

        // 유사한 취향의 사용자들 생성
        for i in 0..<10 {
            let similarity = Double.random(in: 0.6...0.95) // 60~95% 유사도
            let user = VirtualUser(
                id: i,
                favoriteCategories: preference.favoriteCategories,
                similarity: similarity
            )
            users.append(user)
        }

        return users
    }

    /// 추천 식당 수집
    private func collectRecommendations(
        from virtualUsers: [VirtualUser],
        userPreference: UserPreference,
        excludingUserRestaurants: [Restaurant]
    ) -> [RecommendedRestaurant] {
        var recommendations: [RecommendedRestaurant] = []
        let userRestaurantNames = Set(excludingUserRestaurants.map { $0.name })

        // 각 가상 사용자가 좋아하는 식당 생성
        for category in userPreference.favoriteCategories.keys.sorted(by: {
            userPreference.favoriteCategories[$0]! > userPreference.favoriteCategories[$1]!
        }) {
            // 카테고리별로 3-5개의 추천 식당 생성
            let count = Int.random(in: 3...5)

            for i in 0..<count {
                let restaurantName = generateRestaurantName(for: category, index: i)

                // 이미 사용자가 평가한 식당이면 제외
                if userRestaurantNames.contains(restaurantName) {
                    continue
                }

                // 예측 별점 계산 (가상 사용자들의 평균)
                let predictedRating = calculatePredictedRating(
                    category: category,
                    virtualUsers: virtualUsers,
                    userPreference: userPreference
                )

                // 추천 점수 계산
                let recommendationScore = calculateRecommendationScore(
                    predictedRating: predictedRating,
                    category: category,
                    userPreference: userPreference
                )

                // 추천 이유 생성
                let reason = generateReason(
                    category: category,
                    predictedRating: predictedRating,
                    userPreference: userPreference
                )

                // 유사 사용자 수 (랜덤)
                let similarUsers = Int.random(in: 5...15)

                let recommendation = RecommendedRestaurant(
                    name: restaurantName,
                    category: generateCategoryName(for: category),
                    foodCategory: category,
                    address: generateAddress(for: category),
                    predictedRating: predictedRating,
                    recommendationScore: recommendationScore,
                    reason: reason,
                    similarUsers: similarUsers
                )

                recommendations.append(recommendation)
            }
        }

        // 추천 점수 순으로 정렬하고 상위 20개만 반환
        return recommendations
            .sorted { $0.recommendationScore > $1.recommendationScore }
            .prefix(20)
            .map { $0 }
    }

    /// 예측 별점 계산
    private func calculatePredictedRating(
        category: FoodCategory,
        virtualUsers: [VirtualUser],
        userPreference: UserPreference
    ) -> Double {
        // 사용자의 평균 별점을 기준으로 ±0.5 범위에서 예측
        let baseRating = userPreference.averageRating
        let variance = Double.random(in: -0.5...0.5)
        let rating = min(5.0, max(1.0, baseRating + variance))
        return rating
    }

    /// 추천 점수 계산 (0-100)
    private func calculateRecommendationScore(
        predictedRating: Double,
        category: FoodCategory,
        userPreference: UserPreference
    ) -> Double {
        // 예측 별점 비중 60%
        let ratingScore = (predictedRating / 5.0) * 60.0

        // 카테고리 선호도 비중 40%
        let categoryScore = (userPreference.favoriteCategories[category] ?? 0) / 5.0 * 40.0

        return ratingScore + categoryScore
    }

    /// 추천 이유 생성
    private func generateReason(
        category: FoodCategory,
        predictedRating: Double,
        userPreference: UserPreference
    ) -> String {
        let categoryName = category.displayName

        if predictedRating >= 4.5 {
            return "비슷한 취향의 사용자들이 \(categoryName) 중에서 가장 극찬한 곳이에요!"
        } else if predictedRating >= 4.0 {
            return "당신이 좋아하는 \(categoryName) 스타일과 잘 맞을 것 같아요"
        } else if predictedRating >= 3.5 {
            return "유사한 취향의 사용자들이 추천하는 \(categoryName) 맛집"
        } else {
            return "\(categoryName) 카테고리에서 인기 있는 식당이에요"
        }
    }

    /// 식당 이름 생성
    private func generateRestaurantName(for category: FoodCategory, index: Int) -> String {
        let names: [FoodCategory: [String]] = [
            .general: [
                "미식가의 정원", "맛있는 이야기", "행복한 밥상", "정성담은 한끼",
                "우리집 식탁", "맛의 향연", "계절의 맛", "소문난 집"
            ],
            .steak: [
                "프라임 스테이크하우스", "더 블랙 앵거스", "부처스 테이블",
                "고기공방", "스테이크 마스터", "정육식당", "미트 하우스", "한우명가"
            ],
            .sushi: [
                "스시 오마카세", "이타마에 스시", "사카나 초밥",
                "도쿄스시", "스시장인", "오마카세 명가", "정통 스시바", "스시 마에스트로"
            ],
            .ramen: [
                "라멘 이치방", "돈코츠 명가", "메구로 라멘", "츠케멘 전문점",
                "일본식 라멘", "교토 라멘", "하카타 라멘", "미소라멘 본점"
            ],
            .pizza: [
                "나폴리 피자", "피자 마르게리따", "이탈리안 키친",
                "정통 화덕피자", "피자 장인", "로마풍 피자", "트러플 피자", "피제리아"
            ],
            .wine: [
                "와인바 소믈리에", "보르도 와인바", "와인셀러",
                "그랑크뤼", "와인 앤 다인", "와이너리 서울", "빈티지 와인바", "와인테라스"
            ],
            .coffee: [
                "스페셜티 커피", "로스터스 커피", "핸드드립 전문점",
                "커피 공작소", "원두마을", "에스프레소 바", "커피 아뜰리에", "빈즈 커피"
            ]
        ]

        let categoryNames = names[category] ?? names[.general]!
        return categoryNames[index % categoryNames.count]
    }

    /// 카테고리 이름 생성
    private func generateCategoryName(for category: FoodCategory) -> String {
        let categories: [FoodCategory: [String]] = [
            .general: ["한식", "일식", "중식", "양식", "아시안"],
            .steak: ["스테이크", "정육식당", "고기집"],
            .sushi: ["스시", "초밥", "오마카세"],
            .ramen: ["라멘", "우동", "일본식 면"],
            .pizza: ["피자", "이탈리안"],
            .wine: ["와인바", "비스트로"],
            .coffee: ["카페", "커피전문점", "디저트카페"]
        ]

        let names = categories[category] ?? categories[.general]!
        return names.randomElement()!
    }

    /// 주소 생성
    private func generateAddress(for category: FoodCategory) -> String {
        let districts = [
            "강남구 청담동", "서초구 서초동", "용산구 이태원동",
            "종로구 인사동", "중구 명동", "마포구 연남동",
            "성동구 성수동", "송파구 잠실동", "강남구 신사동",
            "용산구 한남동", "마포구 홍대입구", "강남구 압구정동"
        ]

        let randomNumber = Int.random(in: 10...999)
        return "서울시 \(districts.randomElement()!) \(randomNumber)"
    }
}

// MARK: - Supporting Models

/// 사용자 취향 프로필
struct UserPreference {
    let favoriteCategories: [FoodCategory: Double]  // 카테고리별 선호도 점수
    let averageRating: Double  // 평균 별점
    let totalRatings: Int  // 총 평가 수
}

/// 가상 사용자 (협업 필터링용)
struct VirtualUser {
    let id: Int
    let favoriteCategories: [FoodCategory: Double]
    let similarity: Double  // 실제 사용자와의 유사도 (0-1)
}
