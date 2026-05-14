# W1 진행 보고서 — BackgroundGuard 풀 어댑터 + 모델·UI

> 작성일: 2026-05-14
> 작성자: Claude (Autopus)
> 검토 대상: Codex
> 관련 문서: [PLAN.md](PLAN.md) v2.0 / [W0_REPORT.md](W0_REPORT.md)

## 0. 요약

PLAN v2.0 W1 첫 트랙 (사용자 결정: "BackgroundGuard 풀 어댑터 + 디데이·플래너·마스코트 모델·UI") 1라운드 완료.

- 새 SwiftData 모델 5개, 새 SwiftUI 화면 5개, 새 BackgroundGuard iOS 어댑터 5개
- xcodegen 재생성, `xcodebuild` BUILD SUCCEEDED, `swift test` 45/45 통과
- 시뮬레이터에서 5탭 (홈/타이머/플래너/D-Day/과목) 모두 렌더링 검증
- 세션 영속화 + PlannerBlock 자동 채움 코드 경로 연결

## 1. W1.A — 모델·UI 트랙

### 1.1 SwiftData 모델 (StudyApp/Models)
| 파일 | 책임 |
|------|------|
| `DDayModel.swift` | DDay CRUD, `coreValue` 로 core struct 변환 |
| `PlannerBlockModel.swift` | 10분 슬롯 1개. `compositeKey = "YYYYMMDD-slotIndex"` 헬퍼 |
| `DailyPageModel.swift` | 사진1 우측 페이지. `plannerDay` unique |
| `MascotModel.swift` | 마스코트 1개 (단일 프로필). species enum raw string 변환 |
| `StudySessionModel.swift` | 완료된 세션 영속화. `from session: StudySession` convenience init |

### 1.2 ModelContainer + Seed
- `AppModelContainer` schema 6개 모델 (`SubjectModel` 추가)
- 시드: 과목 4개 + 수능 D-Day (2026-11-19, 핀 고정) + 마스코트 1개 (모치, rabbit, stage 0)
- `seedIfNeeded` 가 각 도메인별로 멱등 보장 (이미 있으면 skip)

### 1.3 세션 영속화 (`SessionPersistence`)
- 타이머 종료 시 `StudySessionModel` insert
- `PlannerCalendar.slots(for:)` 결과를 순회하면서 `(plannerDay, slotIndex)` 업서트
- 기존 슬롯이 있으면 subjectID 덮어쓰기, 없으면 insert
- `AppState.modelContext` 는 `RootView.onAppear` 에서 SwiftUI 환경 컨텍스트 주입
- `endSession()` / `applyGuardAction(.stop|.end)` 둘 다 `persistTerminatedSession()` 경유

### 1.4 SwiftUI 화면

| 화면 | 위치 | 내용 |
|------|------|------|
| HomeView | `Features/Home/HomeView.swift` | 마스코트 카드 (실 데이터 + EXP 바 + 다음 단계 EXP 힌트), 핀 D-Day 카드, 오늘 순공시간 카드 (영속 합산 + 라이브 elapsed) |
| MascotAvatar | 동일 파일 | 종/단계별 SF Symbol placeholder. 진짜 에셋 대체용 |
| DDayListView / DDayFormView | `Features/DDay/` | CRUD, 핀 토글 (한 번에 1개만 핀), 이모지 팔레트 10개 |
| BlockGridView | `Features/Planner/` | 사진1 좌측. 22h × 6열 = 132 슬롯 (05:00 → 02:50 wrap). slotIndex 자체는 0..143 절대값 유지 |
| DailyPageView | `Features/Planner/` | 사진1 우측. 오늘의 목표 / Key Point / Feedback / Progress 슬라이더 |
| PlannerView | `Features/Planner/` | 위 두 컴포넌트를 스크롤 결합 |

### 1.5 RootView 5탭
- Home / Timer / Planner / D-Day / Subject
- launch arg `--start-tab=<home|timer|planner|dday|subject>` 그대로 유지

## 2. W1.B — BackgroundGuard 풀 어댑터 (`StudyApp/Background`)

| 어댑터 | 신호 | 매커니즘 |
|--------|------|----------|
| `ScreenLockObserver` | `.screenLocked / .screenUnlocked` | `UIApplication.protectedDataWillBecomeUnavailable` / `…DidBecomeAvailable` NotificationCenter |
| `CallObserver` | `.phoneCallStarted / .phoneCallEnded` | `CXCallObserver` 델리게이트, 활성 통화 UUID set 추적 |
| `AudioInterruptionObserver` | `.audioInterruptionBegan / .audioInterruptionEnded` | `AVAudioSession.interruptionNotification` (Siri·알람 등 비통화 인터럽션) |
| `SceneGeometryObserver` | `.splitViewShrunk / .splitViewRestored` | 2초 폴링. 활성 `UIWindowScene` width < screen × 50% 이면 shrunk |
| `BackgroundGuardAdapter` | (집계) | 위 4개를 묶어 `BackgroundGuard.ingest()` 로 전달, `start()` / `stop()` 일원화 |

- `AppState` 에 `guardAdapter: BackgroundGuardAdapter` lazy 추가
- 옵저버는 `AppState.startSession()` 에서 `.start()`, `endSession()` / `persistTerminatedSession()` 에서 `.stop()` (PLAN §13 배터리 정책)
- 모든 옵저버 클로저는 `Task { @MainActor in … }` 로 isolation hop → Swift 6 동시성 경고 0

## 3. 검증

```bash
cd "/Users/j/Downloads/공부 어플/StudyCore"
swift test     # 45/45 passed (0.005s)

cd "/Users/j/Downloads/공부 어플"
xcodegen generate
xcodebuild -project StudyApp.xcodeproj -scheme StudyApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
              # BUILD SUCCEEDED (warnings: 0 from our code)
```

### 시뮬레이터 검증
- iPhone 17 Pro / iOS 26.5 정상 launch (PID 41019)
- 크래시 없음, 로그상 RunningBoardServices/UIKit 정상 시퀀스
- 5탭 스크린샷:
  - [screenshot_w1_home.png](screenshots/screenshot_w1_home.png) — 마스코트(Lv.0 + EXP 바) / 수능 D-189 / 오늘 순공시간
  - [screenshot_w1_planner.png](screenshots/screenshot_w1_planner.png) — 22×6 그리드 (05:00 → 02:50 wrap) + 시간 라벨
  - [screenshot_w1_dday.png](screenshots/screenshot_w1_dday.png) — 핀된 수능 D-Day 리스트 + 우측 상단 추가 버튼

### 시뮬레이터에서 검증 불가 (실기기 필요)
- ScreenLockObserver: 시뮬레이터엔 lock 버튼이 없음 (Cmd+L 으로 trigger 가능하나 protectedData 알림은 시뮬에서 발화 안 함)
- CallObserver: 시뮬레이터엔 CallKit 통화 시뮬레이션 한계
- AudioInterruptionObserver: 시뮬레이터 Siri 비활성
- 모두 코드 경로는 unit test 가능 (`BackgroundGuardTests` 가 정책 테이블 검증). 실기기 시 W2 폴리싱에서 회귀 확인 예정

## 4. (이력) 초기 리뷰 요청 — 모두 해결됨

W1 첫 라운드 (v1) 시점에 코덱스에 던졌던 질문들. §6 / §7 / §8 에서 모두 처리되었고 현재 미해결 항목 없음. 인수인계 시 참고용으로만 유지.

1. ~~`SessionPersistence` 슬롯 업서트의 race~~ → §6 P1.2, §8 P1.2 에서 `slotKey` unique + 트랜잭션화로 해결
2. ~~`SceneGeometryObserver` 2초 폴링 idle 배터리~~ → §6 P2.1 에서 세션 라이프사이클 게이팅으로 해결
3. `CallObserver` activeCallUUIDs Set — 의도된 단순화. 현재 정책 유지
4. ~~`persistTerminatedSession()` 멱등성~~ → 코덱스 6차 확인 (timer.end() 한 번 성공 후 ended 상태라 안전)
5. `MascotAvatar` placeholder — AI 에셋 통합 (W5) 까지 fallback 유지
6. DDay 핀 정책 — 현재 단일 트랜잭션 (`forEach` + `save`) 으로 OK
7. ~~DailyPageView ensuredPage side-effect~~ → §6 P1.1 에서 `.task(id:)` seeding 으로 해결

## 6. 코덱스 5차 리뷰 반영 (W1 → W1.1)

| # | 항목 | 진단 | 수정 |
|---|------|------|------|
| P1.1 | DailyPageView body 평가 중 SwiftData mutation | `Binding.get` 안에서 `ensuredPage()` 가 insert/save | `.task(id: plannerDay)` 로 seeding 이동. `pages.first` nil 이면 `ProgressView` placeholder. binding getter 는 순수 조회만 |
| P1.2 | PlannerBlock unique 미보장 (id 만) | 동시/재시도 시 같은 슬롯 중복 가능 | `@Attribute(.unique) var slotKey: String` 추가 (`"YYYYMMDD-slotIndex"`). `PlannerBlockModel.makeSlotKey()` 헬퍼. SessionPersistence 가 `slotKey` 로 fetch + save 에러를 `SessionPersistenceError` 로 수집 |
| P1.3 | 그리드 표시 순서가 사진1과 다름 | 0..23 으로 렌더링, PLAN §8 wrap 위배 | `displayedHours = [5..23] + [0..2]` 로 22행 wrap. 시뮬레이터 [screenshot_w1_planner_v2.png](screenshots/screenshot_w1_planner_v2.png) 에 05 → ... 순서 확인 |
| P2.1 | SceneGeometry 2초 폴링이 idle 에서도 계속 | PLAN §13 배터리 정책 위배 | `BackgroundGuardAdapter.start()` 를 `AppState.startSession()` 으로 이동, `endSession()` / `persistTerminatedSession()` 에서 `stop()`. `StudyApp.onAppear` 의 자동 시작 제거 |
| P2.2 | StudySessionModel 이 pausedRanges 누락 | 통계/CloudKit/감사에서 원본 복구 불가 | `pausedRangesData: Data?` 필드 추가, JSONEncoder/Decoder 로 round-trip. `from: StudySession` convenience init 에서 자동 인코딩 |

### 추가 보강
- `SessionPersistence.save()` 가 `[SessionPersistenceError]` 반환. 호출자가 로깅 가능. `try?` 로 에러를 묵살하던 패턴 제거
- `SessionPersistenceError` 케이스: `slotSaveFailed` / `sessionSaveFailed` (underlying Swift Error)

### 검증
- `swift test`: 45/45 통과
- `xcodebuild`: BUILD SUCCEEDED, 우리 코드 경고 0
- 시뮬레이터: 클린 install → planner 탭 05:00 시작 wrap 렌더링 확인

## 7. 코덱스 6차 리뷰 반영 (W1.1 → W1.2)

| # | 항목 | 진단 | 수정 |
|---|------|------|------|
| P1.1 | AppState 가 SwiftUI 환경과 다른 ModelContext 보유 | `StudyApp.onAppear` 가 `ModelContext(container)` 새로 만들어 주입 → `@Query` 들과 다른 context → 세션 종료 후 홈/플래너 즉시 갱신 안 됨 | `StudyApp.onAppear` 의 context 주입 라인 제거. `RootView.onAppear` 가 환경 context 단일 소스. 결과적으로 `AppState.modelContext == RootView` 의 `@Environment(\.modelContext)` |
| P1.2 | SessionPersistence 가 부분 실패 후 dirty context 로 계속 진행 | session save 실패 → 그대로 slot 저장 → 연쇄 실패. 호출자도 errors 버림 | `save(...)` 를 `throws` 로 변경 + 한 번의 `context.save()` 로 트랜잭션화. 실패 시 `context.rollback()` 후 `SessionPersistenceError.saveFailed` throw. `AppState.lastPersistenceError` 에 surface 하여 추후 UI 노출 가능 |
| P2.1 | W1_REPORT 본문이 §6 addendum 과 충돌 | `24h × 6열 = 144 슬롯`, `StudyApp.onAppear` 옵저버 시작 표현이 낡음 | `§1.4` 를 `22h × 6열 = 132 슬롯 (05:00 → 02:50 wrap)` 로, `§2` 를 `AppState.startSession()` 에서 옵저버 시작으로 갱신 |

### 검증
- `swift test`: 45/45 통과
- `xcodebuild`: BUILD SUCCEEDED, 우리 코드 경고 0
- 시뮬레이터 클린 install + launch 정상 ([screenshot_w1_round6_home.png](screenshots/screenshot_w1_round6_home.png))

### 사용자 수동 확인 요청
시뮬레이터에서:
1. 타이머 탭 → 과목 선택 (예: 수학) → 시작
2. 1–2분 대기 (또는 즉시 종료)
3. 종료 버튼
4. 홈 탭에서 "오늘 순공시간" 카드 — **숫자 즉시 증가**해야 함 (이전엔 다른 context 라 안 보였음)
5. 플래너 탭에서 시작/종료 시각대 슬롯이 과목 색으로 채워졌는지 확인

## 8. 코덱스 7차 리뷰 — 통과 + 잔여 노트 (W1 종결)

| # | 항목 | 처리 |
|---|------|------|
| - | **W1.2 통과 판정** | P0 / P1 발견 없음. 기능 면 W1 종결 |
| P2.1 | 본문 낡은 문구 (`24×6`, 이전 리뷰 요청을 현재처럼 남김) | §3 24×6 → 22×6 wrap 으로 정정. §4 를 "(이력) 모두 해결됨" 으로 표시하고 항목별로 처리 위치 명시 |
| P2.2 | 공유 ModelContext `rollback()` 반경 | **노트로 기록**. 현재 UX 는 SessionPersistence 만 dirty 상태를 만들고 즉시 save 하므로 실질 위험 낮음. W2 이후 폼/위젯 동기화가 같은 context 에 미저장 변경을 남기면 실패 시 같이 되돌아갈 수 있음 → W2 진입 시 별도 child `ModelContext` 분리 또는 명시적 save 경계 정의 검토 |

## 5. 다음 단계 후보

- **W1.C**: 실기기 회귀 테스트 (BackgroundGuard 네 가지 신호 실제 발화 확인)
- **W2**: LiveActivity + Widget Extension (App Group / entitlement 추가, xcodegen 익스텐션 타겟)
- **W3**: CloudKit Service (Public 프로필 + Private inbox + Shared 활동 피드)
- **W4**: 운동 / 러닝 (HealthKit + CoreLocation 적응형 샘플링)
- **W5**: AI 마스코트 30컷 통합 + 디자인 폴리싱

---

🐙 Autopus
