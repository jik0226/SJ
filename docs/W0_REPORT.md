# W0 기술 검증 스파이크 — 리포트

> 작성일: 2026-05-13
> 작성자: Claude (Autopus)
> 검토 대상: Codex
> 관련 문서: [PLAN.md](PLAN.md) v2.0

## 0. 요약

PLAN.md v2.0 §5(백그라운드 정지 정책), §6(LiveActivity), §8(데이터 모델), §11 W0 항목 중 **순수 비즈니스 로직 4개 영역**을 Swift Package `StudyCore`로 구현·검증 완료.

- 6개 모듈 / 11개 소스 파일 / 모두 파일 크기 제한(300줄) 통과
- **단위 테스트 45개 전부 통과** (0.006초)
- Foundation 만 의존 (UIKit/SwiftUI/SwiftData/ActivityKit 의존성 0)
- macOS에서 단위 테스트 실행 가능 → CI 통합 용이

미완료(W0 잔여): iOS 시뮬레이터 다운로드 진행 중 → 완료 후 Xcode 프로젝트 + LiveActivity / CloudKit / SwiftData / BackgroundGuard iOS 어댑터 PoC, AI 마스코트 에셋 1종(6단계).

## 1. 모듈 구조

```
StudyCore/
├── Package.swift                              swift-tools 6.3, iOS 17 / macOS 14
├── Sources/
│   ├── Models/                                7개 값 타입
│   │   ├── Subject.swift                      (lectureModeMaxSeconds = 3h)
│   │   ├── StudySession.swift                 (+ PausedRange, PauseReason)
│   │   ├── PlannerBlock.swift                 (compositeKey = "day-slot")
│   │   ├── DailyPage.swift                    (사진1 우측 페이지)
│   │   ├── DDay.swift                         (calendar-day diff)
│   │   ├── Mascot.swift                       (+ MascotSpecies)
│   │   └── RunSession.swift
│   ├── PlannerCalendar/PlannerCalendar.swift  cutoff/slot 변환
│   ├── BackgroundGuard/
│   │   ├── SceneSignal.swift                  멀티 신호 enum
│   │   ├── GuardPolicy.swift                  순수 결정 테이블
│   │   └── BackgroundGuard.swift              런타임 디스패처
│   ├── TimerEngine/
│   │   ├── TimerState.swift
│   │   └── TimerEngine.swift                  @MainActor 상태머신
│   ├── MascotEngine/
│   │   ├── EvolutionRules.swift               (100/300/700/1500/3000)
│   │   └── MascotEngine.swift
│   └── StudyCore/StudyCore.swift              umbrella + version
└── Tests/StudyCoreTests/
    ├── ModelsTests.swift                      8 tests
    ├── PlannerCalendarTests.swift             8 tests
    ├── BackgroundGuardTests.swift             12 tests
    ├── TimerEngineTests.swift                 10 tests
    └── MascotEngineTests.swift                6 tests + 1 misc = 45 total
```

## 2. 핵심 설계 결정

### 2.1 BackgroundGuard: 정책과 런타임 분리
`GuardPolicy.decide(signal:context:)` 는 순수 함수. `BackgroundGuard` 는 컨텍스트 프로바이더와 콜백만 보유.
→ 정책은 SDK·기기 없이 테스트 가능, iOS 어댑터는 신호 변환만 책임.

### 2.2 강의 모드 정책
`subjectAllowsPhoneUse=true` 이면 distraction 신호(`background / screenLock / pip / splitView`)는 `.ignore`. 반면 `phoneCall / audioInterruption` 은 강의 모드에서도 `.pause`. `lectureCapReached` 는 항상 `.stop`.
- 검증: `testLectureModeIgnoresDistractions`, `testLectureModeStillPausesOnPhoneCall`, `testLectureCapAlwaysStops`.

### 2.3 TimerEngine 시간 계산
clock 주입(`() -> Date`). `totalSeconds = gross - sum(pausedRanges.seconds)`. `end()` 시 dangling pause 자동 close.
- 검증: `testPauseResumeFlow` (60+60 활성, 30 일시정지 → 120s), `testEndWhilePausedClosesDanglingPause`, `testCanStartFreshSessionAfterEnd`.

### 2.4 PlannerCalendar cutoff
`plannerDay(for: 2026-05-14 02:30) == 20260513` (cutoff=03:00 적용).
슬롯 0..143 절대 인덱스, UI 표시 wrap은 호출자 책임.
세션 슬롯 채움은 일시정지 구간을 **완전 포함**할 때만 스킵 (부분 겹침은 채움).
- 검증: `testPlannerDayBeforeCutoff`, `testSlotsForSessionCovers30MinuteRun`, `testSlotsCoverPartialSlotAtEnd`, `testSlotsSkipFullPause`.

### 2.5 MascotEngine
임계값 `[0, 100, 300, 700, 1500, 3000]` 누적, `stage(for:)` 는 `cap = Mascot.maxStage = 5` (6단계: egg → sprout → child → teen → adult → final).
이벤트 = `dailyGoalMet (+50) | cellogSent (+5) | weeklyStreak7 (+200) | rawExp(Int)`.
- 검증: `testStageThresholds`, `testStageUpDetected`, `testExpToNextStage`, `testWeeklyStreakBumps`.

## 3. PLAN v2.0 요구와의 대응표

| PLAN 항목 | 구현 위치 | 테스트 |
|-----------|-----------|--------|
| §5 정지 트리거 화이트리스트 | `GuardPolicy` | 5개 |
| §5 일시정지 트리거 (false-positive) | `GuardPolicy` | 4개 |
| §5 강의 모드 3시간 캡 | `Subject.lectureModeMaxSeconds`, `TimerEngine.lectureCapReached` | 2개 |
| §5 카운트 정의표 | `GuardPolicy.decide` 분기 | 12개 종합 |
| §8 PlannerBlock 복합 유니크 | `compositeKey` 속성 | 1개 |
| §8 cutoff = 03:00 | `PlannerCalendar(cutoffHour: 3)` | 3개 |
| §8 슬롯 0..143 | `PlannerBlock.slotsPerDay`, `slotIndex` | 1개 |
| §3 디자인 토큰 | 다음 단계 (Xcode 프로젝트) | — |

## 4. 의도적 비범위 (다음 단계로 이연)

| 영역 | 사유 |
|------|------|
| SwiftData `@Model` 어댑터 | Xcode 프로젝트 필요, 코어 struct → Model 매핑은 결정론적이라 PoC 단계에서 분리 |
| LiveActivity Attribute / Widget | iOS 시뮬레이터 다운로드 후 Xcode 프로젝트 단계 |
| CloudKit Service (Public / Private / Shared) | 동일 |
| BackgroundGuard iOS 어댑터 (scenePhase / CallObserver / AVAudioSession / PiP / Scene geometry) | 동일. 단 신호 매핑 표는 `SceneSignal` 에 사전 정의 완료 |
| AI 마스코트 에셋 6단계 × 5종 = 30컷 | W1 폴리싱과 병행. PoC 단계엔 placeholder SF Symbol 사용 |
| 디자인 토큰 SwiftUI Color/Spacing 매크로 | 동일 |

## 5. 리뷰 요청 포인트 (코덱스 시선)

1. **GuardPolicy 결정 테이블이 누락한 케이스**가 있는지. 특히 잠금화면 → 잠금해제 시 자동 재개를 코어에서 처리하지 않고 iOS 어댑터에 위임 (잠금=stop, 즉 새 세션 시작 필요). 의도된 설계지만 UX 확인 필요.
2. **TimerEngine.computeActiveSeconds** 가 일시정지 구간을 단순 합산. 겹치는 pause 가 생기지 않도록 상태 전이가 직렬화되어 있는지 (현재 `.paused → .paused` 차단).
3. **PlannerCalendar.slots(for:)** 가 부분 슬롯도 채움 (`testSlotsCoverPartialSlotAtEnd`). 시각적 강도 표현(예: 슬롯 내 활동 비율)을 UI 단에서 다룰지, 코어가 비율도 반환할지.
4. **cutoff** 가 사용자 설정으로 0~6h. cutoff 변경 시 기존 PlannerBlock 의 plannerDay 가 변하지 않음 (의도). 마이그레이션 정책 필요한지.
5. **EvolutionRules** 임계값이 하드코딩. 사후 튜닝 자유도를 위해 외부 주입 가능하게 할지 (현재 정적).
6. **Codable 호환성**: 모든 모델이 Codable. SwiftData `@Model` 변환 시 enum raw string 유지 OK 확인 필요.
7. **Sendable**: 모든 값 타입 Sendable, `BackgroundGuard` 는 `@MainActor`. 다른 액터 경계 충돌 우려 있는지.

## 6. 빌드 / 테스트 실행

```bash
cd "/Users/j/Downloads/공부 어플/StudyCore"
swift build         # Build complete! (3.71s)
swift test          # Executed 45 tests, with 0 failures (0.006s)

cd "/Users/j/Downloads/공부 어플"
xcodebuild -project StudyApp.xcodeproj -scheme StudyApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
                    # ** BUILD SUCCEEDED **
```

## 7. iOS 앱 셸 — 추가 산출물 (W0 후반)

XcodeGen 으로 `StudyApp.xcodeproj` 생성 후 다음을 통합 완료. iPhone 17 Pro (iOS 26.5) 시뮬레이터에서 정상 부팅 확인.

| 파일 | 책임 |
|------|------|
| `StudyApp/App/StudyApp.swift` | `@main App`, ModelContainer 주입, scenePhase 라우팅 |
| `StudyApp/App/AppState.swift` | `@Observable` 단일 상태. TimerEngine + BackgroundGuard 통합, GuardAction → TimerEngine 메서드 매핑 |
| `StudyApp/Design/DesignTokens.swift` | PLAN §3 컬러·스페이싱·라운드·타이포 토큰 |
| `StudyApp/Models/SubjectModel.swift` | SwiftData `@Model` 클래스, `coreValue` 로 core struct 변환 |
| `StudyApp/Persistence/AppModelContainer.swift` | 싱글 ModelContainer + 시드 데이터 (수학·영어·강의·러닝) |
| `StudyApp/Features/Home/RootView.swift` | TabView (홈·타이머·과목) |
| `StudyApp/Features/Home/HomeView.swift` | 사진5 톤 카드 UI: 마스코트 카드, 디데이 카드, 오늘 순공시간 카드 |
| `StudyApp/Features/Timer/TimerView.swift` | 원형 타이머 + 과목 칩, start/pause/resume/end, GuardAction 배너 |
| `StudyApp/Features/Subject/SubjectListView.swift` | 과목 CRUD + 색상 팔레트 + 강의 모드 토글 |

### 검증
- iOS 26.5 (23F77) 시뮬레이터 부팅 OK
- 앱 PID 37667 정상 실행
- 홈 탭 렌더링 확인 (screenshot_home.png)
- 디자인 토큰 (primary 파랑, 카드 라운드 16pt, 그림자) 적용

### 의도적 미완 (W1 진입 항목)
- BackgroundGuard 풀 어댑터 (CallObserver / AVAudioSession / PiP / Scene geometry — 현재는 `scenePhase` 만)
- LiveActivity Attribute + Widget Extension
- CloudKit Service (Public + Private + CKShare)
- 디데이 / 플래너 블록 / 마스코트 / 데일리 페이지 SwiftData 모델
- AI 마스코트 일러스트 (현재 SF Symbol `leaf.fill` placeholder)

## 8. 코덱스 2차 리뷰 반영 (v2 → v3)

코덱스가 5건의 결함을 짚었고 사용자 요구사항과 충돌하지 않는 항목으로 전부 수용.

| 항목 | 진단 | 수정 |
|------|------|------|
| **P0** AppState BackgroundGuard contextProvider 가 지역 변수 `lectureAllowed` 를 캡처 → 강의 모드가 실제로 전달되지 않음 | [AppState.swift:23](StudyApp/App/AppState.swift) | `contextProvider` 가 `[weak self]` 로 `self.currentSubjectAllowsPhone` 을 동적 참조하도록 변경. `@ObservationIgnored lazy var guard_` 로 self 완전 초기화 후 생성 |
| **P0** `TimerEngine.state` 변경이 `AppState` 의 `@Observable` 추적 밖이라 SwiftUI 가 리렌더링되지 않음 | [TimerEngine.swift:10](StudyCore/Sources/TimerEngine/TimerEngine.swift) | `TimerEngine` 자체에 `@Observable` 추가 (Observation import). state·session·subject 가 SwiftUI 로 자동 전파 |
| **P1** `GuardAction.stop` 이 `timer.pause` 로 매핑됨 → 정책 의도(stop = 새 세션 시작 필요)와 충돌 | [AppState.swift:55](StudyApp/App/AppState.swift) | `.stop → timer.end()` 로 변경. 동시에 `stopLectureCapWatch()` 호출. 사용자는 명시적으로 다시 시작해야 함 |
| **P1** 강의 모드 3시간 cap 이 신호로 발화되지 않음 | TimerEngine.lectureCapReached 만 존재 | `AppState.startLectureCapWatch()` 가 30s 주기로 `lectureCapReached` 체크 후 `guard_.ingest(.lectureCapReached)`. TimerView 의 시작/종료에서 강의 모드일 때만 켜고 끔 |
| **P1** `Mascot.maxStage = 4` 인데 thresholds 6개 (3000 EXP unreachable) | Mascot.swift / EvolutionRules.swift | `Mascot.maxStage = 5` 로 변경. 5단계 진화 → 6단계 (egg → sprout → child → teen → adult → final). 테스트 `testStageThresholds` / `testExpToNextStage` 갱신 |
| **P2** `screenshot_timer.png` 가 홈 화면과 동일 | simctl io tap 미지원 | RootView 에 launch arg `--start-tab=<home|timer|subject>` 추가. `simctl launch ... --start-tab=timer` 로 진짜 타이머 화면 캡처 |

### 검증
- `swift test` 45/45 통과 (테스트 보강 후에도)
- `xcodebuild ... build` **BUILD SUCCEEDED**
- 시뮬레이터 재실행: 홈 + 타이머 두 화면 모두 정상 렌더링 (screenshot_home.png, screenshot_timer.png)

### 잔존 / 의도적 미완 (W1 진입 시 처리)
- `AppState.handleScenePhase` 가 `.background / .inactive / .active` 만 SceneSignal 로 매핑. 잠금 / CallKit / AVAudioSession / PiP / Scene geometry 어댑터는 W1
- BackgroundGuard 의 false-positive 통계·로그
- LiveActivity / Widget / CloudKit
- **Lecture cap watcher 복원**: 현재 watcher 는 `TimerView` 시작 버튼에서만 켜짐. W0 셸엔 세션 영속화가 없어 즉시 결함은 아니지만, W1 에서 StudySession 영속화 또는 LiveActivity 복원이 들어오면 앱 재실행 후 active lecture-mode 세션을 발견 시 watcher 를 재기동하는 경로 (예: `AppState.init` 마지막에 `if isTimerActive && currentSubjectAllowsPhone { startLectureCapWatch() }`) 가 필요. (코덱스 3차 P2 항목)

## 11. 코덱스 4차 리뷰 (자체 발견) 반영 (v4 → v5)

코덱스 4차 리뷰가 검증 도중 흘린 두 가지 단서를 사용자가 전달. 코덱스 응답 대기 없이 독자 진행 후 다음 라운드에서 일괄 리뷰 예정.

| 항목 | 진단 | 수정 |
|------|------|------|
| **P1** `lastGuardAction` 이 새 세션 시작 후에도 `.stop` 으로 굳어 "정지됨" 배너가 다음 세션까지 잔류 | TimerView 시작 버튼이 `timer.start` 만 호출하고 `lastGuardAction` 은 초기화 안 함 | `AppState.startSession(subject:)` / `endSession()` 단일 진입점 추가. start 시 `lastGuardAction = .ignore` 로 reset, lecture 모드면 watcher 자동 wire. TimerView 시작/종료 버튼 두 메서드로 일원화 |
| **P1** W0_REPORT §2.5 의 `cap=4` 가 maxStage 변경 누락된 낡은 문구 | `stage(for:) 는 cap=4` 표기 | `cap = Mascot.maxStage = 5 (6단계: egg → sprout → child → teen → adult → final)` 로 갱신 |

### 검증
- `swift test`: 45/45 통과
- `xcodebuild ... build`: **BUILD SUCCEEDED**
- 시뮬레이터: [screenshot_timer_v3.png](screenshots/screenshot_timer_v3.png) 정상

### 시나리오 코드 보장
- start → background → `.stop` 발화 → `timer.end()` → 배너 "정지됨"
- 사용자가 다시 시작 → `startSession()` → `lastGuardAction = .ignore` → 배너 사라짐
- idle 에서 background: `handleScenePhase` `guard isTimerActive` 가 즉시 return → 변화 없음

## 10. 코덱스 3차 리뷰 반영 (v3 → v4)

| 항목 | 진단 | 수정 |
|------|------|------|
| **P1** 타이머가 idle 인데 백그라운드 진입 시 "정지됨" 배너 잔류 | [AppState.swift](StudyApp/App/AppState.swift) handleScenePhase·applyGuardAction | `handleScenePhase` 에 `guard isTimerActive` 추가. `applyGuardAction` 은 각 case 마다 적용 가능 상태인지 확인 후 `applied=true` 일 때만 `lastGuardAction` 갱신 |
| **P1** 마스코트 단계 수 문서 분열 (코드=6단계, 문서=5단계) | PLAN.md §4·§11, W0_REPORT §4·§9 | PLAN MVP 표 `5종 × 6단계`, 위험표 `6단계 × 5종 = 30컷`, W0 리포트 §4 / §9 동일 통일 |
| **P2** Lecture cap watcher 세션 복원 경로 부재 | TimerView 시작 버튼에서만 watcher 활성화 | W1 진입 시 처리 (위 §9 "잔존/의도적 미완" 에 명시) |

### 검증
- `swift test`: 45/45 통과 (no test churn)
- `xcodebuild ... build`: **BUILD SUCCEEDED**
- 시뮬레이터 재실행 후 시나리오 검증
  - idle 상태에서 앱 백그라운드 → 복귀: 배너 미표시 (이전엔 "정지됨" 노출)
  - running 상태에서 백그라운드: `.stop` 발화 → `timer.end()` 정상 동작 → 배너 "정지됨: 다른 앱 사용 감지" 표시

## 9. 다음 단계
4. BackgroundGuard iOS 어댑터 + SwiftUI 통합
5. LiveActivity Attribute + Widget Extension
6. CloudKit Service (Public + Private + CKShare) skeleton
7. 디자인 토큰 SwiftUI 매크로
8. AI 마스코트 에셋 placeholder (W1에서 6단계 × 5종 = 30컷 확장)
9. 통합 빌드 → 시뮬레이터에서 타이머·플래너 기본 플로우 동작 확인
10. W1 본격 진입

---

🐙 Autopus
