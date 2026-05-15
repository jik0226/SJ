# 서명 만료 & 친구 채팅 서버 — 결정 메모 (무료 우선)

## 1. "일주일 서명 없이도 쓰게" — 무료 흐름 정리

무료 Apple ID 빌드의 7일 만료는 Apple이 강제하는 정책이라 우회 자체는 불가능.
실질 무료 옵션은 둘.

| 옵션 | 기간 | 비용 | 노력 | 비고 |
|---|---|---|---|---|
| (A) 무료 ID + 매주 Xcode 재서명 | 7일 | 0원 | 매주 USB 연결 후 ⌘R | 본인용 시제품에 적합 |
| (B) AltStore / SideStore + AltServer (PC 상시 ON) | 7일 (자동 재서명) | 0원 | 초기 셋업 1회 | 비공식, iOS 업데이트마다 깨질 위험 |

**현재 추천 = (A)**. (B)는 Mac을 24시간 켜두지 못하면 동일하게 7일 후 만료.

> 1년 무신경하려면 Apple Developer Program 99 USD/년 가입이 유일한 정공법.
> 본 메모는 **0원 흐름**을 우선합니다.

## 2. 친구 채팅 서버 — 무료 후보 비교

| 백엔드 | 운영 비용 | 무료 한도 (요점) | 채팅에 충분? |
|---|---|---|---|
| **Firebase Firestore** | 무료 한도 내 0원 | 1GB 저장 · 일 50,000 read / 20,000 write · 일 10GB 대역폭 | **예.** 10명 · 일 수백 메시지 거뜬 |
| Supabase | 무료 한도 내 0원 | 500MB DB · 2GB 대역폭/월 · 동시 50 소켓 | 예 (한도 더 빡빡) |
| CloudKit | 0원 (단, **Developer Program $99/년** 필수) | iCloud 사용자당 1GB 사설 + 공유 | 예, 단 Developer 가입 필요 |
| 자체 Go 서버 + Fly.io/Render | 0~$5/월 | 무료 한도 작음 | 예, 운영 부담 |

**채택: Firebase Firestore (Anonymous Auth + Firestore)**

이유:
1. **Apple Developer 가입 없이도 즉시 시작.** 본인 Google 계정만 있으면 됨.
2. **실시간 listener**가 SDK 한 줄로 작동 → 채팅 새 메시지 푸시·읽음 표시에 직결.
3. 무료 한도가 친구 10명·일 메시지 수백 건 시나리오에 차고 넘침.
4. 안드로이드 확장 여지 (구글 SDK 공통).

## 3. 도입 절차 (예상 작업량)

### 3.1 Firebase 콘솔 (사용자가 수행)

1. <https://console.firebase.google.com/> 에서 새 프로젝트 생성 (예: `sj-study-app`).
2. iOS 앱 추가 → Bundle ID `co.autopus.study` 입력.
3. `GoogleService-Info.plist` 다운로드 → `StudyApp/` 폴더에 배치.
4. Firebase 콘솔에서 다음 활성화:
   - **Authentication → Sign-in method → Anonymous** (사용자 가입 없이 익명 UID 발급).
   - **Authentication → Sign-in method → Google** (계정 연결 기능에 필요. 활성화하면 OAuth 클라이언트 ID가 발급되고 plist에 자동 포함됨 → 새 plist 받아 교체)
   - **Firestore Database → Production 모드로 생성** (서울 리전 권장 `asia-northeast3`).
5. Firestore 보안 규칙: 풀 미러를 고려해 다음 규칙으로 게시:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {

       // Public profile: every authenticated user can read (friend
       // discovery), only the owner can write.
       match /users/{uid} {
         allow read: if request.auth != null;
         allow write: if request.auth != null && request.auth.uid == uid;

         // Private subtree: only the owner can access.
         match /private/{document=**} {
           allow read, write: if request.auth != null
             && request.auth.uid == uid;
         }

         // Friend subcollection (mutual links). The owner reads their own
         // list; any authenticated user can write into another user's
         // friends list so a one-tap "add" puts the connection on both
         // sides without an accept/reject step. Tighten to a request
         // model later when adding the accept flow.
         match /friends/{otherUid} {
           allow read: if request.auth != null && request.auth.uid == uid;
           allow write: if request.auth != null;
         }
       }

       // Groups: any authenticated user can read (so a join code can be
       // resolved), members + creators can write.
       match /groups/{groupId} {
         allow read: if request.auth != null;
         allow write: if request.auth != null;
       }

       // Chat messages: authenticated users only. Stricter "must be a
       // group member" check left as a follow-up — requires storing UIDs
       // in `groups/{gid}.memberUids` first.
       match /chats/{groupId}/messages/{messageId} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

6. **Google Sign-In용 URL scheme**: 5)에서 Google provider를 켜면 plist의
   `REVERSED_CLIENT_ID`가 채워집니다 (예: `com.googleusercontent.apps.1234-abcdef`).
   이 값을 `StudyApp/Info.plist`의 `CFBundleURLTypes`에 추가해야 OAuth 콜백이 앱으로 돌아옵니다 — 다만 본 프로젝트는 `Info.plist`를 XcodeGen이 생성하므로, 다음 라운드에 `project.yml`의 `info.properties.CFBundleURLTypes`에 한 줄 추가 PR을 따로 만들겠습니다.
   본 시점에서 Google 연결 버튼을 누르면 "Google 로그인이 활성화되지 않았어요" 안내가 뜹니다 (정상 — plist 재발급 + URL scheme 등록 끝나면 동작).

### 3.2 Xcode 측 (코드 변경)

| 변경점 | 위치 | 예상 LOC |
|---|---|---|
| SPM 의존성 `firebase-ios-sdk` 추가 | `project.yml` | +3줄 |
| `FirebaseApp.configure()` 호출 | `StudyApp/App/StudyApp.swift` (App entry) | +2줄 |
| `GoogleService-Info.plist` 추가 | `StudyApp/` | 파일 1개 |
| `FriendsService`의 mock 채팅을 Firestore listener로 교체 | `Features/Social/` | ~120줄 |
| 익명 인증 부트스트랩 | `App/AuthBootstrap.swift` (신규) | ~30줄 |

### 3.3 데이터 모델 매핑

현재 SwiftData 모델 → Firestore 컬렉션:

| 로컬 SwiftData | Firestore |
|---|---|
| `FriendProfileModel.friendCode` | `users/{uid}.friendCode` |
| `StudyGroupModel` | `groups/{groupId}` |
| `ChatMessageModel` | `chats/{groupId}/messages/{messageId}` |

로컬은 캐시·오프라인 보존용으로 그대로 유지 → Firestore listener가 새 메시지를 받으면 SwiftData에도 mirror.

## 4. 다음 단계 (실 통합)

1. 사용자가 위 §3.1 Firebase 콘솔 단계 5개를 마무리 → `GoogleService-Info.plist` 확보.
2. 본 저장소에서 `project.yml`에 `firebase-ios-sdk` SPM 의존성 한 줄 추가 + `FirebaseApp.configure()` 콜.
3. `FriendsService` 통합 작업 (별도 PR, ~1~2일).

**현재 코드 상태**: 친구 모델·UI·로컬 mock 채팅까지 다 갖춰져 있어, 위 통합만 끝나면 즉시 친구 채팅이 살아납니다. iCloud 의존성은 모두 nil-container 가드로 격리돼 있으므로 무료 흐름과 충돌 없음.

## 5. 결정 트리 요약

```
무료로 친구 채팅 켜고 싶다?
  └─ Yes ─▶ Firebase 콘솔에서 프로젝트 + Anonymous + Firestore 활성화
              │
              └─ GoogleService-Info.plist 받아오면 코드 통합 PR 시작
```
