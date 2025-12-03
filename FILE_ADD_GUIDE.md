# 📁 파일 추가 완벽 가이드

Xcode 프로젝트에 파일을 추가하는 가장 쉬운 방법입니다.

---

## 🎯 방법 1: Finder에서 드래그 (가장 쉬움!)

### Step 1: Finder와 Xcode 나란히 열기

```
1. Xcode 열기
2. ⌘ + Space → "Finder" 입력 → Enter
3. Finder에서 이동:
   /Users/hyunholee/Documents/workspace/code/RestaurantMap/RestaurantMap/
```

### Step 2: Services 폴더 파일 추가

```
Finder에서:
1. Services 폴더 열기
2. 다음 파일들 선택 (⌘ 클릭으로 다중 선택):
   ✅ FirebaseModels.swift
   ✅ FirebaseService.swift
   ✅ FirebaseRealtimeService.swift
   ✅ RecommendationEngine.swift
   ✅ RealtimeRecommendationEngine.swift

3. 선택한 파일들을 Xcode 왼쪽의 "Services" 폴더로 드래그

4. 팝업이 뜨면:
   ☐ Copy items if needed (체크 해제!)
   ☑️ Create groups
   ☑️ Add to targets: RestaurantMap

5. "Finish" 클릭
```

### Step 3: Views 폴더 파일 추가

```
Finder에서:
1. Views 폴더 열기
2. 다음 파일들 선택:
   ✅ RecommendationView.swift
   ✅ RealtimeRecommendationView.swift

3. Xcode의 "Views" 폴더로 드래그

4. 동일하게 설정 후 "Finish"
```

---

## 🎯 방법 2: Xcode 메뉴 사용

### Services 파일 추가

```
1. Xcode에서 "Services" 폴더 우클릭
2. "Add Files to RestaurantMap..." 선택
3. 파일 브라우저에서 이동:
   /Users/hyunholee/Documents/workspace/code/RestaurantMap/RestaurantMap/Services/

4. 다음 파일들 선택 (⌘ 클릭):
   - FirebaseModels.swift
   - FirebaseService.swift
   - FirebaseRealtimeService.swift
   - RecommendationEngine.swift
   - RealtimeRecommendationEngine.swift

5. 옵션 확인:
   ☐ Copy items if needed (체크 해제)
   ☑️ Add to targets: RestaurantMap

6. "Add" 클릭
```

### Views 파일 추가

```
1. "Views" 폴더 우클릭
2. "Add Files to RestaurantMap..."
3. RecommendationView.swift, RealtimeRecommendationView.swift 선택
4. "Add" 클릭
```

---

## ✅ 파일이 제대로 추가되었는지 확인

### 확인 방법 1: Project Navigator

```
Xcode 왼쪽 패널에서:
RestaurantMap/
  └─ Services/
      ├─ FirebaseModels.swift          ← 있어야 함
      ├─ FirebaseService.swift         ← 있어야 함
      ├─ FirebaseRealtimeService.swift ← 있어야 함
      ├─ RecommendationEngine.swift    ← 있어야 함
      └─ RealtimeRecommendationEngine.swift ← 있어야 함

  └─ Views/
      ├─ RecommendationView.swift      ← 있어야 함
      └─ RealtimeRecommendationView.swift ← 있어야 함
```

### 확인 방법 2: 빌드 테스트

```
⌘ + B (빌드)
→ 에러 없이 성공하면 OK!
```

---

## 🔓 추천 탭 활성화

파일 추가 완료 후, ContentView.swift 수정:

### 현재 (비활성화):
```swift
// 추천 탭은 나중에 파일 추가 후 활성화
// RecommendationView()
//     .tabItem {
//         Label("추천", systemImage: "sparkles")
//     }
//     .tag(2)
```

### 활성화:
```swift
RecommendationView()
    .tabItem {
        Label("추천", systemImage: "sparkles")
    }
    .tag(2)
```

**또는 Realtime Database 사용:**
```swift
RealtimeRecommendationView()
    .tabItem {
        Label("추천", systemImage: "bolt.fill")
    }
    .tag(2)
```

---

## 🐛 문제 해결

### 파일이 회색으로 보임

**원인**: 타겟에 추가 안 됨

**해결**:
```
1. 파일 선택
2. 오른쪽 Inspector 패널 (⌥ + ⌘ + 1)
3. "Target Membership" 섹션
4. "RestaurantMap" 체크 ✅
```

### "Copy items if needed" 체크 시

**문제**: 파일이 중복됨

**해결**:
```
1. Xcode에서 파일 삭제 (우클릭 → Delete)
2. "Remove Reference" 선택 (Delete 아님!)
3. 다시 추가 (이번엔 체크 해제)
```

### 여전히 "Cannot find ... in scope"

**확인사항**:
```
1. 파일이 Services/Views 폴더에 있는지
2. Target Membership이 체크되어 있는지
3. Clean Build (⇧ + ⌘ + K)
4. 다시 빌드 (⌘ + B)
```

---

## 📸 스크린샷 가이드

### 드래그 앤 드롭

```
[Finder]                    [Xcode]
Services/                   RestaurantMap/
├─ FirebaseService.swift    └─ Services/
└─ ...                          (여기로 드래그!)
```

### 팝업 설정

```
┌─────────────────────────────────┐
│ Add Files to "RestaurantMap"    │
├─────────────────────────────────┤
│ ☐ Copy items if needed          │  ← 체크 해제!
│ ☑️ Create groups                │  ← 선택
│                                  │
│ Add to targets:                 │
│ ☑️ RestaurantMap                │  ← 체크!
│                                  │
│         [Cancel]  [Finish]      │
└─────────────────────────────────┘
```

---

## 🎉 완료!

파일 추가 후:
1. ⌘ + B (빌드)
2. ⌘ + R (실행)
3. 추천 탭 확인!

문제 있으면 위 "문제 해결" 섹션 참고하세요.
