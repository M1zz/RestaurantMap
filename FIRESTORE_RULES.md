# 🔒 Firestore 보안 규칙 설정

Firebase Anonymous Auth를 사용한 보안 규칙입니다.

---

## 📋 필수 설정

### 1. Firebase Console에서 Anonymous Auth 활성화

```
1. Firebase Console 접속
2. Authentication 메뉴 클릭
3. "Sign-in method" 탭
4. "익명" (Anonymous) 찾기
5. "사용 설정" 클릭
6. 저장
```

⚠️ **중요**: 이 단계를 건너뛰면 앱에서 로그인이 실패합니다!

---

## 🔐 보안 규칙 (프로덕션용)

Firebase Console → Firestore Database → 규칙

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // 사용자 프로필 컬렉션
    match /users/{userId} {
      // 자신의 데이터만 읽기/쓰기
      allow read, write: if request.auth != null && request.auth.uid == userId;

      // 취향 프로필 서브컬렉션
      match /tasteProfile/{profileId} {
        // 모든 인증된 사용자가 읽기 가능 (추천용)
        allow read: if request.auth != null;
        // 자신의 프로필만 쓰기
        allow write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // 식당 컬렉션
    match /restaurants/{restaurantId} {
      // 공개된 식당은 모든 인증된 사용자가 읽기 가능
      allow read: if request.auth != null && resource.data.isPublic == true;
      // 자신이 등록한 식당만 쓰기
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && resource.data.userId == request.auth.uid;
    }

    // 방문 기록 컬렉션
    match /visits/{visitId} {
      // 공개된 방문 기록은 모든 인증된 사용자가 읽기 가능
      allow read: if request.auth != null && resource.data.isPublic == true;
      // 자신의 방문 기록만 쓰기
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow update, delete: if request.auth != null && resource.data.userId == request.auth.uid;
    }
  }
}
```

---

## 🧪 테스트용 보안 규칙 (개발 중)

**경고**: 30일 후 자동 만료됨

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      // 모든 읽기/쓰기 허용 (테스트용만!)
      allow read, write: if request.time < timestamp.date(2025, 1, 15);
    }
  }
}
```

---

## ✅ 보안 규칙 작동 방식

### 익명 인증 플로우

```
1. 앱 시작
   ↓
2. FirebaseService.signInAnonymously() 자동 실행
   ↓
3. Firebase가 고유 UID 생성
   예: "abc123xyz456"
   ↓
4. 이후 모든 요청에 UID 포함
   request.auth.uid = "abc123xyz456"
   ↓
5. Firestore 규칙이 UID 확인
   ✅ 본인 데이터: 읽기/쓰기 허용
   ✅ 공개 데이터: 읽기만 허용
   ❌ 타인 비공개 데이터: 차단
```

---

## 🔍 보안 규칙 테스트

### Firebase Console에서 테스트

```
1. Firestore Database → 규칙 → "규칙 시뮬레이터"
2. 시뮬레이션 유형: get
3. 위치: /restaurants/test123
4. 인증 여부: ✅ 인증됨
5. Provider: custom
6. UID: test_user_1
7. "시뮬레이션 실행"
```

**예상 결과**:
- ✅ 공개 식당 읽기: 허용
- ❌ 비공개 식당 읽기: 거부
- ✅ 본인 식당 쓰기: 허용
- ❌ 타인 식당 쓰기: 거부

---

## 📊 데이터 접근 권한 요약

| 데이터 | 읽기 | 쓰기 | 조건 |
|-------|------|------|------|
| 내 취향 프로필 | ✅ 본인 | ✅ 본인 | 인증 필요 |
| 타인 취향 프로필 | ✅ 모두 | ❌ 불가 | 인증 필요 (추천용) |
| 내 식당 | ✅ 본인 | ✅ 본인 | 인증 필요 |
| 공개 식당 | ✅ 모두 | ❌ 소유자만 | 인증 필요 |
| 비공개 식당 | ❌ 불가 | ❌ 소유자만 | 인증 필요 |
| 내 방문 기록 | ✅ 본인 | ✅ 본인 | 인증 필요 |
| 공개 방문 기록 | ✅ 모두 | ❌ 소유자만 | 인증 필요 |

---

## 🐛 문제 해결

### 문제 1: "Missing or insufficient permissions"

**원인**: Anonymous Auth가 활성화되지 않음

**해결**:
```
Firebase Console → Authentication → Sign-in method
→ "익명" 사용 설정
```

### 문제 2: "User is not authenticated"

**원인**: 자동 로그인 실패

**확인**:
```swift
// Xcode 콘솔에서 확인
✅ "Firebase 익명 로그인 완료" 로그가 있어야 함
❌ "Firebase 로그인 실패" 로그가 있으면 문제
```

**해결**:
1. GoogleService-Info.plist 확인
2. Firebase SDK (FirebaseAuth) 설치 확인
3. 앱 재시작

### 문제 3: "PERMISSION_DENIED: Missing or insufficient permissions"

**원인**: Firestore 보안 규칙이 너무 엄격

**임시 해결** (테스트용):
```javascript
// 모든 접근 허용 (30일 제한)
allow read, write: if request.time < timestamp.date(2025, 1, 31);
```

---

## 🔄 익명 사용자 → 실제 사용자 전환 (추후)

나중에 소셜 로그인을 추가하려면:

```swift
// 1. 익명으로 시작
try await FirebaseService.shared.signInAnonymously()

// 2. 나중에 Google/Apple 로그인으로 연결
let credential = GoogleAuthProvider.credential(...)
try await Auth.auth().currentUser?.link(with: credential)
```

**장점**: 익명 사용자의 모든 데이터가 실제 계정으로 이전됨!

---

## 📱 앱에서 인증 상태 확인

```swift
// FirebaseService에서
if FirebaseService.shared.isAuthenticated {
    print("✅ 로그인됨: \(FirebaseService.shared.currentUserId)")
} else {
    print("❌ 로그인 필요")
}
```

---

## 🎯 보안 규칙 장점

1. **자동 인증**: 사용자가 로그인할 필요 없음
2. **데이터 보호**: 각 사용자의 데이터가 보호됨
3. **추천 가능**: 공개 데이터로 추천 시스템 작동
4. **확장 가능**: 나중에 실제 로그인 추가 가능

---

## ✅ 최종 체크리스트

- [ ] Firebase Console에서 Anonymous Auth 활성화
- [ ] Firestore 보안 규칙 업데이트
- [ ] 앱 실행 시 "Firebase 익명 로그인 완료" 로그 확인
- [ ] 데이터 업로드 테스트
- [ ] 더미 데이터 생성 테스트
- [ ] 추천 기능 테스트

---

**이제 보안이 강화된 추천 시스템이 준비되었습니다!** 🔒✨
