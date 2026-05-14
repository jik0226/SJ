# W3 진행 보고서 — 친구·셀로그 (mock 모드)

> 작성일: 2026-05-14
> 작성자: Claude (Autopus)
> 검토 대상: Codex (보류, 일괄 리뷰)

## 0. 요약

CloudKit 실통신은 entitlement·iCloud 계정 의존이 커서 PoC 단계에서는 시뮬레이터 검증이 제한적. 그래서 **로컬 SwiftData 기반 mock 모드**로 데이터 모델 / 비즈니스 로직 / UI 흐름을 먼저 완성. CloudKit wire 는 W3.D 별도 트랙으로 분리.

## 1. 신규 산출물

```
StudyApp/
├── Models/FriendProfileModel.swift     본인 + 친구 통합 (isMe flag)
├── Models/CellogMessageModel.swift     셀로그 메시지 + CellogKind enum
├── Social/
│   ├── FriendCode.swift                6자리 영숫자 (혼동 문자 제외) 생성/검증
│   └── SocialService.swift             me 시드, 친구 추가, 차단/해제, 셀로그 송신/신고
├── Features/Friends/FriendsView.swift  내 친구코드 카드 + 친구 리스트 + 추가 시트
└── Features/Cellog/
    ├── CellogInboxView.swift           받은 메시지 + 신고 버튼
    └── CellogComposeSheet.swift        종류 선택 + 80자 + 템플릿
```

`AppModelContainer` schema 에 `FriendProfileModel`, `CellogMessageModel` 추가.
`RootView` 가 5탭 (홈 / 타이머 / 플래너 / D-Day / 더보기) + 더보기 안에 과목 / 친구 / 셀로그 그루핑.

## 2. 핵심 결정

| 항목 | 결정 |
|------|------|
| **자기 자신** = 친구 테이블 한 행 (`isMe = true`) | 한 모델로 통합. 친구코드/마스코트/오늘 순공 표시 모두 동일 스키마 |
| **친구 코드** | 6자리. `A-Z` (혼동 문자 `I O` 제외) + `2-9` = 32자 알파벳. 32^6 ≈ 10억 조합 |
| **차단** | `isBlocked` 플래그. 리스트 쿼리에서 자동 제외. 다시 추가 시 unblock |
| **셀로그 종류** | `cheer / complaint / anonymous`. 익명은 발신자 표시 숨김 |
| **80자 제한** | `SocialService.sendCellog` 가 `prefix(80)` 적용 |
| **신고** | `isReported` 플래그. 리스트에서 자동 제외 (24h SLA 백오피스 검토는 추후) |
| **미성년자** | 모델에 `isMinor` 플래그만. 가입 연령 입력 UX 는 W3.E 트랙 |

## 3. 검증

- `swift test`: 45/45 통과
- `xcodebuild ... build`: **BUILD SUCCEEDED**
- 시뮬레이터: 더보기 메뉴 ([screenshot_w3_more.png](screenshots/screenshot_w3_more.png)) 에 과목 / 친구 / 셀로그 정상 표시. 친구 탭 진입 시 mock seed (민서·준호) + 내 친구코드 표시

## 4. CloudKit Wire 후속 트랙 (W3.D)

코드를 갈아끼기 좋게 `SocialService` 가 SwiftData ModelContext 만 의존. CloudKit 전환 시:

1. `FriendProfileModel` 의 일부 필드 (`friendCode`, `nickname`, `mascotSpecies`, `mascotStage`) 만 Public DB `UserProfile` 레코드로 동기화
2. `FriendProfileModel` (추가된 친구) 는 Private DB `FriendLink` 와 1:1 매핑
3. `CellogMessageModel` 은 발신자 Private + 수신자 CKShare
4. App Store 가이드 1.2 준비: 신고 처리 백오피스 (Apple 측 요구사항)

추정 작업량: 1주, 실기기 + Apple Developer Program 필수.

## 5. 미성년자 정책 후속 (W3.E)

- 첫 실행 시 연령 입력 (만 14세 미만 / 이상)
- 14세 미만: 친구 검색 노출 차단, 익명 송수신 차단, 친구코드 직접 입력만 허용
- 메시지 욕설/혐오 필터 (PLAN §9 준수)

---

🐙 Autopus
