# 🎯 식당 추천 시스템 설정 가이드

Firebase 기반 식당 추천 기능을 사용하기 위한 완벽한 설정 가이드입니다.

---

## 📦 1. Firebase SDK 설치

### 방법 1: Swift Package Manager (권장)

1. **Xcode 프로젝트 열기**
2. **File** → **Add Package Dependencies...**
3. URL 입력:
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. **Version**: `11.0.0` 이상 선택
5. **다음 패키지 선택**:
   - ✅ FirebaseFirestore
   - ✅ FirebaseFirestoreSwift
   - ✅ FirebaseAuth (옵션)

---

## 🔥 2. Firebase 프로젝트 생성

### Firebase Console 설정

1. **Firebase Console 접속**: https://console.firebase.google.com
2. **프로젝트 추가** 클릭
3. 프로젝트 이름 입력: `RestaurantMap` (원하는 이름)
4. Google Analytics 설정 (선택사항)
5. **프로젝트 만들기** 클릭

### iOS 앱 추가

1. Firebase 프로젝트 대시보드에서 **iOS 아이콘** 클릭
2. **번들 ID 입력**:
   - Xcode에서 확인: Target → General → Bundle Identifier
   - 예: `com.yourname.RestaurantMap`
3. **앱 등록** 클릭
4. **GoogleService-Info.plist 다운로드**
5. Xcode에서:
   - 다운로드한 `GoogleService-Info.plist` 파일을 프로젝트 루트에 드래그
   - ✅ "Copy items if needed" 체크
   - Target: RestaurantMap 선택

---

## 🗄️ 3. Firestore Database 설정

### 데이터베이스 생성

1. Firebase Console → **Firestore Database** 메뉴
2. **데이터베이스 만들기** 클릭
3. **모드 선택**:
   - 🧪 테스트용: **테스트 모드에서 시작**
   - 🔒 프로덕션: **프로덕션 모드에서 시작**
4. **위치 선택**: `asia-northeast3 (Seoul)` 권장
5. **사용 설정** 클릭

### 보안 규칙 설정

Firebase Console → Firestore → **규칙** 탭에서 다음 규칙 추가:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 사용자 컬렉션 (자신의 데이터만 읽기/쓰기)
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /tasteProfile/{profileId} {
        allow read: if true; // 모든 사용자가 취향 프로필 읽기 가능 (추천용)
        allow write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // 식당 컬렉션 (공개된 것만 모두 읽기 가능)
    match /restaurants/{restaurantId} {
      allow read: if resource.data.isPublic == true;
      allow write: if request.auth != null && request.auth.uid == resource.data.userId;
    }

    // 방문 기록 컬렉션
    match /visits/{visitId} {
      allow read: if resource.data.isPublic == true;
      allow write: if request.auth != null && request.auth.uid == resource.data.userId;
    }
  }
}
```

**테스트 모드 (임시):**
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true; // 모든 읽기/쓰기 허용 (개발용만!)
    }
  }
}
```

⚠️ **주의**: 테스트 모드는 30일 후 자동으로 만료됩니다!

---

## 🏗️ 4. Firestore 데이터 구조

### 컬렉션 구조

```
firestore/
├── users/
│   └── {userId}/
│       └── tasteProfile/
│           └── current (FirebaseTasteProfile)
│
├── restaurants/
│   └── {restaurantId} (FirebaseRestaurant)
│
└── visits/
    └── {visitId} (FirebaseVisit)
```

### 인덱스 생성 (성능 최적화)

Firebase Console → Firestore → **색인** 탭에서 다음 복합 색인 추가:

**1. 식당 검색용:**
- 컬렉션: `restaurants`
- 필드:
  - `isPublic` (오름차순)
  - `foodCategory` (오름차순)
  - `satisfactionScore` (내림차순)

**2. 지역 검색용:**
- 컬렉션: `restaurants`
- 필드:
  - `isPublic` (오름차순)
  - `latitude` (오름차순)

**3. 사용자 방문 기록:**
- 컬렉션: `visits`
- 필드:
  - `userId` (오름차순)
  - `isPublic` (오름차순)
  - `visitDate` (내림차순)

---

## 🚀 5. 앱에서 사용하기

### 데이터 동기화

1. **앱 실행**
2. **추천 탭** (✨ 아이콘) 클릭
3. 오른쪽 상단 **⋯** 메뉴 → **데이터 동기화**
4. **동기화 시작** 버튼 클릭

이제 내 데이터가 Firebase에 업로드됩니다!

### 추천 받기

**3가지 추천 모드:**

1. **✨ 종합 추천** (기본값)
   - 맛, 평점, 거리를 모두 고려한 최적 추천
   - 알고리즘: 하이브리드 (40% 도형유사도 + 30% 평점 + 20% 만족도 + 10% 거리)

2. **👥 비슷한 입맛**
   - 나와 취향이 비슷한 사람들이 좋아하는 식당
   - 알고리즘: 협업 필터링 (코사인 유사도 기반)

3. **🍕 맛 유사도**
   - 내가 좋아했던 맛과 비슷한 다른 식당
   - 알고리즘: 도형 유사도 (레이더 차트 벡터 비교)

### 카테고리 필터

- 전체 / 일반 / 스테이크 / 초밥 / 라멘 / 피자 / 와인 / 커피

---

## 🔍 6. 추천 알고리즘 상세

### 코사인 유사도 (Cosine Similarity)

```swift
similarity = (A · B) / (||A|| × ||B||)
```

- **범위**: 0.0 ~ 1.0
- **의미**: 1에 가까울수록 유사
- **사용처**: 취향 프로필 비교, 도형 패턴 비교

### 유클리디안 거리 (Euclidean Distance)

```swift
distance = √Σ(Ai - Bi)²
```

- **범위**: 0 ~ ∞
- **의미**: 0에 가까울수록 유사
- **사용처**: 정확한 맛 차이 계산

### 하이브리드 점수

```swift
score =
  shapeSimilarity × 0.4 +    // 도형 유사도
  ratingScore × 0.3 +         // 평점
  satisfactionScore × 0.2 +   // 만족도
  proximityScore × 0.1        // 거리
```

---

## 🐛 7. 트러블슈팅

### 문제 1: "No Firebase App '[DEFAULT]' has been created"

**원인**: Firebase가 초기화되지 않음

**해결**:
1. `GoogleService-Info.plist`가 프로젝트에 있는지 확인
2. `FirebaseApp.swift`의 `FirebaseApp.configure()` 호출 확인
3. 앱 재시작

### 문제 2: "Permission denied" 에러

**원인**: Firestore 보안 규칙

**해결**:
1. Firebase Console → Firestore → 규칙
2. 테스트 모드로 변경 (임시):
   ```javascript
   allow read, write: if true;
   ```

### 문제 3: 추천이 비어있음

**원인**: 데이터 부족

**해결**:
1. 다른 사용자 데이터가 Firebase에 있는지 확인
2. 내 데이터를 동기화했는지 확인
3. 카테고리 필터를 "전체"로 변경

### 문제 4: 느린 성능

**원인**: 인덱스 미생성

**해결**:
1. Firebase Console → Firestore → 색인
2. 필요한 복합 색인 추가 (위 4단계 참고)

---

## 📊 8. 데이터 구조 예시

### FirebaseTasteProfile

```json
{
  "userId": "abc123",
  "spicy": 7.5,
  "boldness": 6.0,
  "sweetness": 5.5,
  "saltiness": 6.5,
  "richness": 7.0,
  "naturalTaste": 8.0,
  "texture": 6.0,
  "cooking": 7.0
}
```

### FirebaseRestaurant

```json
{
  "id": "rest123",
  "userId": "abc123",
  "name": "스테이크 하우스",
  "address": "서울시 강남구",
  "latitude": 37.5,
  "longitude": 127.0,
  "category": "레스토랑",
  "foodCategory": "스테이크",
  "averageRating": 4.5,
  "visitCount": 3,
  "satisfactionScore": 92.5,
  "isPublic": true,
  "createdAt": "2024-01-01T00:00:00Z"
}
```

### FirebaseVisit

```json
{
  "id": "visit123",
  "restaurantId": "rest123",
  "userId": "abc123",
  "visitDate": "2024-01-01T12:00:00Z",
  "rating": 5,
  "notes": "완벽한 미디엄 레어!",
  "steakDoneness": 8.0,
  "steakJuiciness": 9.0,
  "steakTenderness": 8.5,
  "steakSeasoning": 7.0,
  "steakFlavor": 9.0,
  "steakMarbling": 8.0,
  "steakDonenessAppropriate": 5,
  "steakJuicinessAppropriate": 5,
  "steakTendernessAppropriate": 4,
  "isPublic": true
}
```

---

## 🎉 9. 테스트용 더미 데이터 생성

개발/테스트용으로 Firebase에 더미 데이터를 추가하려면:

### Firebase Console에서 직접 추가

1. Firestore → **컬렉션 시작** 클릭
2. 컬렉션 ID: `restaurants`
3. 문서 ID: 자동 생성
4. 위 JSON 구조대로 필드 추가

### 코드로 추가 (개발용)

```swift
// FirebaseService.swift에 추가
func createDummyData() async throws {
    // 더미 사용자 10명 생성
    for i in 1...10 {
        let profile = FirebaseTasteProfile(
            userId: "dummy_user_\(i)",
            spicy: Double.random(in: 3...9),
            boldness: Double.random(in: 3...9),
            // ... 나머지 속성
        )

        let data = try Firestore.Encoder().encode(profile)
        try await db.collection("users")
            .document("dummy_user_\(i)")
            .collection("tasteProfile")
            .document("current")
            .setData(data)
    }

    // 더미 식당 50개 생성
    // ... (생략)
}
```

---

## 📱 10. 위치 권한 설정

거리 기반 추천을 위해 위치 권한 필요:

**Info.plist에 추가:**

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>근처 맛집을 추천하기 위해 위치 정보가 필요합니다</string>
```

Xcode에서:
1. Info.plist 열기
2. `+` 버튼 → "Privacy - Location When In Use Usage Description"
3. Value: "근처 맛집을 추천하기 위해 위치 정보가 필요합니다"

---

## ✅ 완료!

이제 Firebase 기반 식당 추천 시스템이 완벽하게 설정되었습니다!

**다음 단계:**
1. ✅ Firebase 프로젝트 생성 완료
2. ✅ GoogleService-Info.plist 추가 완료
3. ✅ Firestore Database 생성 완료
4. ✅ 앱에서 데이터 동기화
5. ✅ 추천 기능 사용 시작!

**문제가 있나요?**
- Xcode 콘솔에서 에러 메시지 확인
- Firebase Console에서 데이터 확인
- 위 트러블슈팅 섹션 참고

**Happy Coding! 🚀**
