# 🗺️ 카카오 맵 API 설정 가이드

RestaurantMap 앱에서 카카오 로컬 검색 API를 사용하는 방법입니다.

---

## 📋 목차

1. [카카오 개발자 계정 생성](#1-카카오-개발자-계정-생성)
2. [앱 등록 및 REST API 키 발급](#2-앱-등록-및-rest-api-키-발급)
3. [Xcode 프로젝트 설정](#3-xcode-프로젝트-설정)
4. [사용 방법](#4-사용-방법)
5. [문제 해결](#5-문제-해결)

---

## 1. 카카오 개발자 계정 생성

### Step 1: 카카오 개발자 사이트 접속

```
https://developers.kakao.com
```

### Step 2: 로그인

- 카카오 계정으로 로그인
- 없으면 카카오톡 계정으로 회원가입

---

## 2. 앱 등록 및 REST API 키 발급

### Step 1: 애플리케이션 추가

```
1. https://developers.kakao.com/console/app 접속
2. "애플리케이션 추가하기" 클릭
3. 앱 이름: "RestaurantMap" (또는 원하는 이름)
4. 사업자명: 개인 이름 입력
5. "저장" 클릭
```

### Step 2: REST API 키 확인

```
1. 생성한 앱 선택
2. "앱 키" 탭 클릭
3. "REST API 키" 복사 📋

예시:
REST API 키: 1234567890abcdef1234567890abcdef
```

⚠️ **중요**: 이 키는 절대 외부에 공개하면 안 됩니다!

---

## 3. Xcode 프로젝트 설정

### 방법 1: Info.plist에 추가 (권장)

#### Step 1: Info.plist 열기

```
Xcode에서:
1. 프로젝트 네비게이터에서 "Info.plist" 파일 찾기
2. 우클릭 → "Open As" → "Source Code"
```

#### Step 2: API 키 추가

```xml
<key>KAKAO_REST_API_KEY</key>
<string>여기에_REST_API_키_붙여넣기</string>
```

**전체 예시:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>KAKAO_REST_API_KEY</key>
    <string>1234567890abcdef1234567890abcdef</string>

    <!-- 기존 다른 설정들... -->
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    ...
</dict>
</plist>
```

#### Step 3: .gitignore 설정

```bash
# Info.plist에 민감한 정보가 있으므로 별도 파일로 관리
# Secrets.xcconfig 파일 생성 권장
*.xcconfig
```

---

### 방법 2: 코드에 직접 입력 (빠른 테스트용)

⚠️ **주의**: 이 방법은 테스트용으로만 사용하세요. GitHub에 업로드하면 안 됩니다!

```swift
// KakaoLocalSearchService.swift 파일에서

private var apiKey: String {
    // 임시로 여기에 직접 입력 (테스트용)
    return "1234567890abcdef1234567890abcdef"

    // 또는 Info.plist에서 읽어오기 (권장)
    // return Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""
}
```

---

## 4. 사용 방법

### 앱 실행

```
1. Xcode에서 앱 실행 (⌘ + R)
2. 위치 권한 허용
3. 지도 탭에서 좌측 상단 버튼 확인
```

### 카카오 검색 활성화

```
1. 좌측 상단 버튼 탭
2. "카카오" 표시 확인 (노란색)
3. 지도를 이동하면 자동으로 주변 식당/카페 검색
```

### Apple Maps 검색으로 전환

```
1. 좌측 상단 버튼 다시 탭
2. "Apple" 표시 확인 (파란색)
3. 기존 Apple Maps POI 검색 사용
```

---

## 5. 카카오 API 기능

### 자동 주변 검색

```
지도를 이동할 때마다 자동으로 검색:
✅ 주변 음식점 (FD6)
✅ 주변 카페 (CE7)
```

### 장소 정보

카카오 장소 마커를 탭하면:
```
✅ 장소 이름
✅ 카테고리
✅ 도로명 주소
✅ 지번 주소
✅ 전화번호
✅ 현재 위치에서 거리
✅ 카카오맵에서 보기 링크
✅ 내 식당 목록에 추가
```

---

## 6. 문제 해결

### 오류 1: "카카오 REST API 키가 설정되지 않았습니다"

**원인**: API 키가 입력되지 않음

**해결**:
```
1. Info.plist 확인
2. KAKAO_REST_API_KEY 항목 있는지 확인
3. 값이 올바른지 확인
4. 앱 재실행
```

### 오류 2: "HTTP 오류: 401"

**원인**: API 키가 잘못됨

**해결**:
```
1. 카카오 개발자 콘솔에서 REST API 키 재확인
2. 복사할 때 앞뒤 공백 없는지 확인
3. Info.plist에 정확히 붙여넣기
4. Clean Build (⇧ + ⌘ + K)
5. 앱 재실행
```

### 오류 3: 장소가 검색되지 않음

**원인 1**: 인터넷 연결 문제

**해결**:
```
1. Wi-Fi 또는 데이터 연결 확인
2. 설정 → Wi-Fi 확인
```

**원인 2**: 위치 권한 미허용

**해결**:
```
1. 설정 → 개인정보 보호 → 위치 서비스
2. RestaurantMap 앱 찾기
3. "앱을 사용하는 동안" 선택
```

### 오류 4: "HTTP 오류: 429"

**원인**: API 호출 한도 초과 (하루 10만 건)

**해결**:
```
1. 다음 날까지 대기
2. 또는 카카오 개발자 콘솔에서 쿼터 증설 신청
```

---

## 7. API 사용량 확인

```
1. https://developers.kakao.com/console/app 접속
2. 앱 선택
3. "통계" 탭 클릭
4. API 호출 통계 확인
```

---

## 8. 카카오 API vs Apple Maps API 비교

| 특성 | 카카오 API | Apple Maps API |
|------|-----------|----------------|
| 한국 데이터 | ⭐⭐⭐⭐⭐ 매우 정확 | ⭐⭐⭐ 보통 |
| 상세 정보 | 전화번호, 주소, 카테고리 등 | 제한적 |
| 속도 | 빠름 | 보통 |
| 무료 한도 | 10만 건/일 | 무제한 |
| 설정 | API 키 필요 | 불필요 |
| 오프라인 | 불가 | 가능 (캐싱) |

---

## 9. 추가 기능 (선택사항)

### 키워드 검색 추가

현재는 주변 검색만 지원하지만, 키워드 검색도 가능합니다:

```swift
// MapView.swift의 performSearch() 함수 수정

private func performSearch() {
    guard !searchText.isEmpty else { return }

    if isUsingKakaoSearch {
        // 카카오 키워드 검색
        Task {
            do {
                let result = try await kakaoService.searchByKeyword(
                    query: searchText,
                    coordinate: locationDelegate.userLocation,
                    radius: 5000
                )

                await MainActor.run {
                    kakaoPlaces = result.documents
                    logger.info("✅ 카카오 검색: \(kakaoPlaces.count)개")
                }
            } catch {
                logger.error("❌ 카카오 검색 실패: \(error)")
            }
        }
    } else {
        // 기존 Apple Maps 검색
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        // ...
    }
}
```

---

## 10. 보안 권장사항

### 프로덕션 환경

```
1. ✅ API 키를 Info.plist에 저장
2. ✅ .gitignore에 Info.plist 추가 (또는 별도 파일)
3. ✅ GitHub Secrets 사용
4. ❌ 코드에 직접 하드코딩 금지
```

### 환경 분리

```swift
// Configuration.swift 생성 권장

enum Configuration {
    static var kakaoAPIKey: String {
        #if DEBUG
        return "개발용_API_키"
        #else
        return Bundle.main.object(forInfoDictionaryKey: "KAKAO_REST_API_KEY") as? String ?? ""
        #endif
    }
}
```

---

## 11. 참고 링크

- 📖 [카카오 로컬 API 문서](https://developers.kakao.com/docs/latest/ko/local/dev-guide)
- 📖 [카카오 개발자 콘솔](https://developers.kakao.com/console/app)
- 📖 [REST API 키 가이드](https://developers.kakao.com/docs/latest/ko/getting-started/app)

---

## 🎉 완료!

이제 카카오 로컬 검색 API를 사용할 수 있습니다!

**다음 단계:**
1. ⌘ + R로 앱 실행
2. 좌측 상단 버튼으로 카카오 검색 활성화
3. 지도를 이동하며 주변 식당 확인
4. 마커를 탭해서 상세 정보 확인
5. "내 식당 목록에 추가" 버튼으로 저장

문제가 있으면 위 "문제 해결" 섹션을 참고하세요!
