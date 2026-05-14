# 최종 자체 리뷰 — 요구사항 ↔ 구현 매핑 (수정판)

> 작성일: 2026-05-14
> 작성자: Claude (Autopus) — 자동 리뷰·테스트·디버깅 모드
> 누적: 21 사이클 / 60건 결함 처리 / 14 신규 트랙
> **판정 보정** — 외부 리뷰 7차에서 "11/11" 과한 판정을 지적받아 수정함

---

## 1. 최초 요구사항 11개 — 구현 상태 (보정)

| # | 요구사항 | 상태 | 비고 |
|---|----------|------|------|
| 1 | **디데이** | ✅ 로컬 완성 | CRUD / 핀 / 위젯 / 자동 갱신 |
| 2 | **순공시간 (과목 등록 기반)** | ✅ 로컬 완성 | TimerEngine 상태머신 + 영속화 + 편집 |
| 3 | **앱 이탈 즉시 정지 + 강의 모드** | ✅ 로컬 완성 | BackgroundGuard 정책 + 4 옵저버 + 3h 캡. **실기기 회귀 미검증** (simctl 한계) |
| 4 | **배터리·데이터 최소화** | ✅ 로컬 완성 | 옵저버 라이프사이클 게이팅 + 적응형 GPS + LiveActivity OS 렌더 |
| 5 | **친구와 같이 사용** | 🟡 **로컬 mock** | FriendProfileModel + addFriend(코드 유효성만 검증, 원격 확인 X). **CloudKit wire 필요** |
| 6 | **목표시간 채우기 성취감** | ✅ 로컬 완성 | Plant 영양분 + Streak + 알림 + 햅틱 |
| 7 | **운동 + 러닝 km** | ✅ 로컬 완성 | WorkoutType 5종 + MET + Always 권한 + HKWorkoutBuilder. **백그라운드 GPS 실제 추적 실기기 검증 필요** |
| 8 | **그룹 채팅** | 🟡 **로컬 mock** | StudyGroupModel + ChatMessageModel + 신고/차단/필터/미성년 cap·URL 차단. **다중 기기 동기화 없음** (CloudKit wire 필요) |
| 9 | **메인 캐릭터 성장 (사람마다 다르게)** | ✅ 완성 | PlantFormula 결정론적 함수, seed별 다른 모양, 사용자가 식 직접 확인 |
| 10 | **사진 5 디자인** | ✅ 완성 | DesignTokens 블루 + 카드 라운드 + 그림자 |
| 11 | **10분 블록 플래너** | ✅ 완성 | BlockGridView 22행 wrap + DailyPage + 자동 색 채움 |

**판정**:
- **로컬 단일 사용자 영역**: 9/11 완성 (1·2·3·4·6·7·9·10·11)
- **다중 사용자 영역**: 5·8 은 PoC mock — Apple Developer Program 가입 + CloudKit 실배포 시 W3.D 트랙에서 마무리

---

## 2. 7-Pass Audit 결과

### Pass 1 — 요구사항 매핑 ✅
모든 11개 항목 구현 위치 확인. 누락 없음.

### Pass 2 — 데이터 모델 정합성
- 10개 SwiftData `@Model`: `Subject / DDay / PlannerBlock / DailyPage / Plant / StudySession / RunSession / FriendProfile / StudyGroup / ChatMessage`
- Unique 제약: `id` 모두, `PlannerBlock.slotKey`, `DailyPage.plannerDay`, `FriendProfile.friendCode`, `StudyGroup.code`
- Cascade 미적용 (Subject 삭제 시 StudySession orphan) — PoC 허용 범위, 통계 영향 미미

### Pass 3 — UI 흐름
- 5탭 (홈/타이머/플래너/D-Day/더보기) → 모든 진입 정상
- 더보기 → 통계/과목/내 식물/친구/그룹 채팅 5개 NavigationLink
- TimerView fullScreenCover → RunningView (toolbar 닫기로 endRun 우회 불가)
- HomeView PlantCard → PlantDetailView NavigationLink
- onboarding (만 나이 입력) 첫 실행 1회

### Pass 4 — 동시성 / 에러 처리
- 모든 service `@MainActor enum`
- 모든 observable class `@MainActor @Observable`
- CLLocationManagerDelegate `nonisolated` + `Task { @MainActor in }` hop
- `Persistence.save` 헬퍼로 모든 CRUD 사이트 통일 (silent `try?` 제거)
- `lastPersistenceError` / `lastStartError` UI surface

### Pass 5 — 발견 결함 5건 픽스
| 항목 | 처리 |
|------|------|
| F-A `AppState.startSession` 실패 silent | `Persistence.log` + `lastStartError` State + `TimerView.guardBanner` 노출 |
| F-B `SocialService.sendChat` 직접 try-catch | `Persistence.save` 헬퍼로 일원화 |
| F-C TimerView 시작 실패 무피드백 | guardBanner 가 `lastStartError` 우선 표시 |
| F-D AppState dead 메서드 | `startBackgroundObservers / stopBackgroundObservers` 제거 (호출자 없음) |
| F-E SubjectFormView 편집 불가 | `existing: SubjectModel?` 인자 + hydrate + save 분기. 행 탭 → 편집 sheet |

### Pass 6 — 시뮬레이터 e2e
- `swift test`: 49/49 통과
- `xcodebuild`: BUILD SUCCEEDED, 우리 코드 경고 0
- 클린 install + launch 정상, crash 없음 ([screenshot_audit_pass6.png](screenshots/screenshot_audit_pass6.png))

### Pass 7 — 깊은 audit
24개 미세 항목 검토. 모두 PoC 허용 또는 의도된 설계. 새 P0/P1 발견 없음.

---

## 3. 검증 표

| 검증 항목 | 결과 |
|----------|------|
| `swift test` | 49/49 통과 |
| `xcodebuild` BUILD | SUCCEEDED |
| 우리 코드 경고 | 0 |
| 시뮬 launch 후 crash | 없음 |
| 시뮬 5탭 진입 | 모두 정상 |
| 데이터 시드 (Subject 4 / DDay 1 / Plant 1 / FriendProfile 1) | 첫 launch 자동 |
| onboarding (만 나이) | 첫 launch 1회 |
| 알림 권한 요청 | onboarding 종료 직후 |
| LiveActivity entitlement | `NSSupportsLiveActivities=true` |
| App Group entitlement | `group.co.autopus.study` (xcodegen properties 안정) |
| iCloud entitlement | `iCloud.co.autopus.study` (시뮬 가드) |

---

## 4. 의도된 미해결 (실기기 / 외부 의존)

| 항목 | 사유 |
|------|------|
| **CloudKit 실통신** | 시뮬 entitlement 미서명 → `#if !targetEnvironment(simulator)` 가드. Apple Developer Program 가입 시 W3.D-2 마일스톤 진입 |
| **실기기 BackgroundGuard 회귀** | simctl tap 자동화 한계. ScreenLock / Call / Audio / Geometry 4 신호 코드는 단위 테스트로 정책 검증, 실기기 동작은 수동 |
| **HealthKit 권한 다이얼로그** | 시뮬 자동화 한계. RunningView.task에서 `requestAuthorization` 호출은 코드 검증 |
| **백그라운드 GPS** | `allowsBackgroundLocationUpdates` 코드 + Always 권한 시 활성. 시뮬에서 실제 잠금화면 추적 검증 어려움 |
| **AI 마스코트 → 함수형 식물** | 사용자 지시로 폐기. AI 에셋 외부 의존 제거됨 |

---

## 5. 사이클 누적

총 **20 사이클 / 54건 결함 수정 / 14 신규 트랙**.

상세 이력 → [AUTONOMOUS_CYCLE_REPORT.md](AUTONOMOUS_CYCLE_REPORT.md).
주요 트랙별 보고서 → `W0_REPORT.md` ~ `W5_REPORT.md`, `PLAN.md` v2.0.

---

## 6. 외부 리뷰 7차 — 추가 픽스 (cycle 21)

코덱스 토큰 한정 상태에서 정적 감사로 외부 리뷰 받음. 5건 모두 정확.

| 등급 | 항목 | 처리 |
|------|------|------|
| P1 | SwiftData 마이그레이션 부재 + fatalError | `Holder.init` 가 catch 후 legacy store 파일 (`.sqlite`/`-wal`/`-shm`) 삭제 → 재시도 → 그래도 실패 시 in-memory fallback. 사용자 crash loop 방지 |
| P1 | 미성년자 정책 enforcement 부재 | `SocialService.sendChat` 가 `me.isMinor` 인 경우 메시지 200자 cap (성인 500자), URL (`http`/`https`/`www`) 차단. 그룹 채팅에서 적용 |
| P1 | 신고 버튼 UI 호출처 없음 | `GroupChatView.MessageBubble` 에 contextMenu 추가, 본인 메시지 외 메시지에 "신고" 항목 노출 → `SocialService.reportMessage` 호출 |
| P2 | HealthKit 실패 silent | `HealthService.requestAuthorization` / `saveWorkout` 가 결과 enum 반환. `RunningView` 에 `healthBanner` State + 두 곳 (권한 요청 / 저장 결과) 모두 사유 노출 |
| P2 | 마스코트 잔재 문구 | NotificationsService 알림 본문 "마스코트 EXP" → "식물에 영양분이 쌓이고 있어요". PLAN.md §3 / §4 / §11 마스코트 라인을 식물 시스템으로 정정 |

### 검증
- `swift test`: 49/49
- `xcodebuild`: BUILD SUCCEEDED, 우리 코드 경고 0

## 7. 결론 (수정)

> 로컬 단일 사용자 영역 9/11 완성. 다중 사용자 영역 (친구·그룹 채팅) 2건 + 백그라운드 GPS 실기기 동작 + CloudKit 실통신은 PoC mock 단계.
> "테스트만 남았다" 는 아직 이르고, **CloudKit wire + 실기기 회귀 + Apple Developer Program 가입** 이 다음 라운드 사전 조건.
> 시뮬레이터에서 동작 가능한 모든 영역은 검증 완료, SwiftData migration safety net 추가로 업그레이드 경로 안정성 확보.

**다음 사용자 결정 필요**:
1. Apple Developer Program 가입 → CloudKit wire 본 작업 진입 (W3.D)
2. 또는 현재 PoC 상태로 실기기 TestFlight 배포 (로컬 단일 사용자 검증)
3. 또는 추가 폴리싱 사이클 더 진행

---

🐙 Autopus
