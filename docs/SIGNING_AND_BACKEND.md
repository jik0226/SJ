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
5. Firestore 보안 규칙 — **멤버 기반(member-based)으로 강화**. 그룹/채팅은 그룹
   `memberUids`(인증 UID)에 든 사용자만 읽고 쓸 수 있고, 그룹 목록 나열(enumeration)도
   막혀 있습니다. 코드로 가입할 때는 `groupCodes/{code}` 룩업 문서로만 그룹 id를 찾습니다
   (그룹 문서 자체는 비회원이 못 읽음). friendCode는 공개값이라 신뢰 경계로 쓸 수 없으므로
   규칙은 모두 `request.auth.uid` 기준입니다. 아래 규칙을 콘솔 → Firestore Database → 규칙
   에 붙여넣고 **게시**하세요:

   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {

       // ── Helpers ─────────────────────────────────────────────────────
       function signedIn() { return request.auth != null; }
       function oldUids() { return resource.data.get('memberUids', []); }
       function newUids() { return request.resource.data.get('memberUids', []); }
       function ownFriendCode() {
         return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.get('friendCode', '');
       }
       function isGroupMember() { return signedIn() && request.auth.uid in oldUids(); }
       // A non-member joining a ROOM may add ONLY their own uid (and ONLY their
       // own friendCode to memberCodes), must preserve everyone already there,
       // must not touch name/code/id, and must not be a DM.
       function isRoomSelfJoin() {
         return signedIn()
           && ownFriendCode() != ''
           && !(request.auth.uid in oldUids())
           && request.auth.uid in newUids()
           && newUids().toSet().hasAll(oldUids().toSet())
           && newUids().toSet().difference(oldUids().toSet()).hasOnly([request.auth.uid])
           && !resource.data.get('code', '').matches('DM:.*')
           && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['memberUids', 'memberCodes', 'updatedAt'])
           // memberCodes must be PRESERVED (can't remove other members) and may
           // only gain our own friendCode — never strip the roster.
           && request.resource.data.get('memberCodes', []).toSet().hasAll(resource.data.get('memberCodes', []).toSet())
           && request.resource.data.get('memberCodes', []).toSet()
                .difference(resource.data.get('memberCodes', []).toSet()).hasOnly([ownFriendCode()]);
       }

       // ── Public profile ──────────────────────────────────────────────
       // Any signed-in user can read (friend discovery by code needs a
       // collection query); only the owner writes their own profile.
       match /users/{userId} {
         allow read: if request.auth != null;
         allow write: if request.auth.uid == userId;

         // Private backup subtree: owner-only, never shared.
         match /private/{document=**} {
           allow read, write: if request.auth.uid == userId;
         }

         // Friend links. The owner reads their own list. A write is allowed
         // into your OWN list, or into someone else's list ONLY when the
         // entry identifies you (data.uid == your uid) — that powers the
         // one-tap mutual add without letting anyone forge arbitrary entries.
         match /friends/{otherUid} {
           allow read: if request.auth.uid == userId;
           allow write: if request.auth.uid == userId
                     || request.auth.uid == request.resource.data.uid;
         }
       }

       // ── Groups ──────────────────────────────────────────────────────
       // Member-gated. get/list are restricted to YOUR membership so no one can
       // enumerate the collection or its rosters — the inbox query MUST be
       // `where memberUids array-contains <uid>`. A non-member never reads the
       // group doc; join-by-code resolves the id via /groupCodes, then self-joins.
       //  • create — creator must include their own uid.
       //  • update — a current member may edit; a non-member may only self-join
       //    a ROOM (isRoomSelfJoin: adds only their own uid/code, never a DM).
       //  • delete — a current member only (last one out drops the doc).
       match /groups/{groupId} {
         allow get: if isGroupMember();
         allow list: if isGroupMember();
         // Shape-validated so a self-join setData(merge:) onto a MISSING doc
         // (e.g. a stale groupCode pointing at a deleted group) can't create a
         // malformed half-group — a create must carry the full, well-formed doc.
         allow create: if signedIn()
           && request.resource.data.keys().hasOnly(['id', 'code', 'name', 'memberCodes', 'memberUids', 'updatedAt'])
           && request.resource.data.id == groupId
           && request.resource.data.code is string
           && request.resource.data.name is string
           && request.resource.data.memberUids is list
           && request.auth.uid in request.resource.data.memberUids;
         allow update: if isGroupMember() || isRoomSelfJoin();
         allow delete: if isGroupMember();
       }

       // ── Group join codes ────────────────────────────────────────────
       // Maps a join code → group id. Exact-code `get` only (no list → codes
       // can't be enumerated). create-once by a member of the target group;
       // immutable after. Holds only { gid } so the room name stays hidden
       // until you actually join.
       match /groupCodes/{code} {
         allow get: if signedIn();
         allow list: if false;
         allow create: if signedIn()
           && request.resource.data.keys().hasOnly(['gid', 'createdAt'])
           && request.resource.data.gid is string
           && exists(/databases/$(database)/documents/groups/$(request.resource.data.gid))
           && get(/databases/$(database)/documents/groups/$(request.resource.data.gid)).data.code == code
           && request.auth.uid in get(/databases/$(database)/documents/groups/$(request.resource.data.gid)).data.get('memberUids', []);
         allow update, delete: if false;
       }

       // ── Chat messages (the sensitive content) ───────────────────────
       // read/create only for users whose uid is in the parent group's
       // memberUids. create additionally requires the message to carry the
       // sender's OWN uid, so a member can't forge another member's
       // senderFriendCode. Messages are immutable; moderation goes via /reports.
       match /chats/{groupId}/messages/{messageId} {
         allow read: if request.auth != null
           && request.auth.uid in
              get(/databases/$(database)/documents/groups/$(groupId)).data.get('memberUids', []);
         allow create: if request.auth != null
           && request.auth.uid in
              get(/databases/$(database)/documents/groups/$(groupId)).data.get('memberUids', [])
           && request.resource.data.senderUid == request.auth.uid;
         allow update, delete: if false;
       }

       // ── Reports (UGC moderation) ────────────────────────────────────
       // Users file content reports here; only the operator reads them in the
       // console. A reporter may only create a report that identifies itself.
       match /reports/{reportId} {
         allow create: if request.auth.uid == request.resource.data.reporterUid;
         allow read, update, delete: if false;
       }
     }
   }
   ```

   > **배포 순서 주의**: 앱이 그룹 문서에 `memberUids`(인증 UID)를 쓰도록 업데이트된
   > 뒤(또는 동시에) 이 규칙을 게시하세요. 기존 그룹 문서에는 `memberUids`가 없어,
   > 규칙 게시 직후에는 멤버가 채팅방을 한 번 열어 재게시(`memberUids`에 본인 UID가
   > arrayUnion)되기 전까지 해당 방의 메시지 읽기가 거부됩니다. DM은 열 때마다 자동
   > 재게시되고, 그룹 방도 채팅 화면 진입 시 백필됩니다.

   > **인박스/룸 마이그레이션**: 인박스가 `memberUids array-contains <uid>` 쿼리로 바뀌어,
   > `memberUids`에 본인 UID가 없는 레거시 그룹은 한 번 열기 전까지 목록에서 안 보입니다(열면
   > 백필). 또 기존 룸은 `groupCodes` 항목이 없어 새 멤버가 코드로 못 들어오므로, 멤버가 룸
   > 채팅을 한 번 열면 `groupCodes`가 자동 등록되도록 했습니다(기존 멤버 1회 진입 필요).

   > **기존 DM 1회 정리**: DM은 self-join이 금지되므로, `memberUids`가 채워지기 전에
   > 만들어진 *기존* DM 문서는 양쪽 다 재게시가 막혀 메시지를 못 읽을 수 있어요(내용
   > 유출은 없고 단순 "잠김"). 베타 테스트 데이터라면 콘솔에서 `groups` 중 `code`가
   > `DM:`로 시작하는 문서 + 해당 `chats/{id}` 를 한 번 지우면, 다음에 친구 탭에서 열 때
   > 양쪽 UID로 새로 안전하게 생성됩니다. (그룹 방은 영향 없음.)

   > **무료 한계(공개 출시 전 과제)**: Cloud Functions(유료) 없이 "코드로 가입"을
   > 유지하므로, DM id를 유추한 공격자가 *빈* DM 문서를 선점하는 DoS는 남습니다(내용
   > 유출 아님, 정상 사용자가 그 방을 못 쓰게 되는 정도). 공개 출시 시에는 친구 관계에
   > 무작위 DM 토큰을 심어 id를 유추 불가능하게 만들거나, 가입 검증 Function을
   > 도입하는 것을 권장합니다.

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
