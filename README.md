# 식당 지도 앱 (RestaurantMap)

MapKit을 활용한 식당 정보 관리 iOS 앱입니다.

## 주요 기능

### 1. 지도 뷰
- MapKit을 사용한 지도 표시
- 저장된 식당 위치에 핀 표시
- 현재 위치 표시
- 플로팅 버튼으로 식당 추가
  - 현재 위치에 식당 추가
  - 수동으로 위치 선택하여 추가

### 2. 식당 목록 뷰
- 저장된 모든 식당 목록 표시
- 식당 정보 요약 (이름, 주소, 별점, 카테고리, 방문 날짜)
- 스와이프로 삭제
- 탭하여 상세 정보 보기

### 3. 식당 추가
- 식당 이름, 주소 입력
- 카테고리 및 전화번호 입력
- 방문 날짜 선택
- 별점 (1-5) 평가
- 메모 작성
- 지도에서 위치 선택

### 4. 식당 상세 정보
- 모든 식당 정보 확인
- 지도에서 위치 확인
- Apple 지도로 바로 이동
- 전화번호 탭으로 전화 걸기
- 편집 모드로 정보 수정
- 식당 삭제

## 기술 스택

- **SwiftUI**: 모던한 UI 구축
- **SwiftData**: 로컬 데이터 저장 및 관리
- **MapKit**: 지도 표시 및 위치 관리
- **iOS 17.0+**: 최신 iOS 기능 활용

## 데이터 모델

Restaurant 모델은 다음 정보를 저장합니다:
- 이름 (name)
- 주소 (address)
- 위도/경도 (latitude/longitude)
- 메모 (notes)
- 별점 (rating: 0-5)
- 방문 날짜 (visitDate)
- 카테고리 (category)
- 전화번호 (phoneNumber)

## 설치 및 실행

1. RestaurantMap.zip 압축 해제
2. Xcode 15.0 이상에서 `RestaurantMap.xcodeproj` 파일 열기
3. iOS 17.0 이상의 시뮬레이터 또는 실제 기기 선택
4. ⌘R로 빌드 및 실행

## 권한

앱은 다음 권한을 요청합니다:
- 위치 정보: 지도에서 현재 위치 표시를 위해 필요

## 사용 방법

### 식당 추가하기
1. 지도 탭에서:
   - 파란색 버튼: 현재 위치에 식당 추가
   - 초록색 버튼: 수동으로 위치 선택하여 추가

2. 목록 탭에서:
   - 우측 상단 + 버튼으로 추가

### 식당 정보 보기
- 지도의 핀을 탭하거나
- 목록에서 식당을 탭하여 상세 정보 확인

### 식당 정보 편집
- 상세 정보 화면에서 '편집' 버튼 탭

### 식당 삭제
- 목록에서 좌측으로 스와이프하거나
- 상세 정보 화면 하단의 '식당 삭제' 버튼

## 프로젝트 구조

```
RestaurantMap/
├── RestaurantMap.xcodeproj/    # Xcode 프로젝트 파일
└── RestaurantMap/
    ├── RestaurantMapApp.swift          # 앱 진입점
    ├── ContentView.swift                # 메인 탭 뷰
    ├── Models/
    │   └── Restaurant.swift            # 데이터 모델
    ├── Views/
    │   ├── MapView.swift               # 지도 뷰
    │   ├── RestaurantListView.swift    # 목록 뷰
    │   ├── AddRestaurantView.swift     # 추가 뷰
    │   └── RestaurantDetailView.swift  # 상세 뷰
    ├── Assets.xcassets/                # 이미지 리소스
    └── Preview Content/                # 프리뷰 리소스
```

## 향후 개선 사항

- [ ] 실제 GPS 위치 가져오기
- [ ] 사진 추가 기능
- [ ] 식당 검색 기능
- [ ] 카테고리별 필터링
- [ ] 방문 기록 통계
- [ ] iCloud 동기화
- [ ] 지도에서 직접 탭하여 추가

## 문제 해결

### 프로젝트가 열리지 않는 경우
1. Xcode 버전이 15.0 이상인지 확인
2. macOS 버전이 Xcode 요구사항을 충족하는지 확인
3. `.xcodeproj` 파일을 더블클릭하여 Xcode로 열기

### 빌드 오류가 발생하는 경우
1. Product > Clean Build Folder (⇧⌘K)
2. Xcode 재시작
3. iOS Deployment Target이 17.0으로 설정되어 있는지 확인

## 라이선스

MIT License
