# 자동 진행 사이클 종합 보고서

> 작성일: 2026-05-14
> 작성자: Claude (Autopus) — 자동 진행 + 주기적 자체 리뷰 모드
> 검토 대상: Codex (토큰 복구 후 일괄 리뷰)

## 0. 요약

자체 리뷰 → 픽스 → 빌드/테스트 → 다시 audit 의 19 사이클을 자동 진행 (외부 리뷰 6회 반영). **49건의 결함 발견·수정 + 14개 신규 트랙** (마지막은 마스코트 → 함수형 식물 전면 재설계) (Cellog 그룹 채팅 재설계 + 운동 종류 확장 + 백그라운드 GPS + CloudKit wire skeleton 추가) (W3.E 미성년자 정책 / Stats / Notifications / Mascot Evolution UX / Mascot Widget / Daily Reminder / Run Summary / Subject Icon Picker / Streak Card / Cellog Sent Mailbox / Unread Badge / Haptic). 매 사이클 끝에서 `swift test` 49/49 통과 + `xcodebuild` BUILD SUCCEEDED 확인.

엔타이틀먼트 문제(C1)는 xcodegen `properties` 명시로 영구 해결되어 더 이상 빈 plist 로 재발하지 않습니다.

## 1. 사이클별 픽스

### Cycle 1 — 초기 자체 코드 리뷰 (10 건)
| 등급 | 항목 | 처리 |
|------|------|------|
| C1 | App Group entitlement 빈 plist | xcodegen `entitlements.properties` 로 inline 명시. 재생성 시 자동 채움 |
| C2 | MascotEngine 앱 측 호출 0 — 마스코트 영원히 성장 안 함 | `MascotProgressService` 추가. `AppState.persist` 가 세션 종료 시 일일 목표 임계값 첫 도달 시 EXP 부여 |
| M1 | RunningManager 권한 거부 무피드백 | `authStatus` / `authBanner` observable 추가. UI 에 빨간 배너, 시작 버튼 disabled |
| M2 | Mascot exp / stage 정합성 위험 | `stage` 를 computed property 로 변경. exp 만 영속화 |
| M3 | SceneGeometry 2초 폴링 idle | 30초 + `UIScene.didActivateNotification` 보강 |
| M4 | ScreenLockObserver 폴백 신호 | 범위를 의도적으로 protectedData 만으로 좁히고 false positive 방지 (보강 신호는 scenePhase background 가 이미 잡음) |
| M5 | `try? context.save()` 광범위 영속화 실패 은폐 | `Persistence.log` / `Persistence.save` 헬퍼 + 핵심 CRUD 사이트 propagation |
| M6 | DDay 변경 시 WidgetSync 트리거 없음 | `DDayFormView.save` / `DDayListView.togglePin/delete` 에서 `syncPinnedDDay` 호출 |
| L1 | hex 파서 3개 중복 | `MascotAvatar` 의 `fromHexString` 제거 → `DesignTokens` 의 `init?(hexString:)` 사용 |
| L2 | AddFriendSheet 입력 sanitize 표시 불일치 | `onChange` 로 즉시 sanitize 후 set |

### Cycle 2 — 통합 결함 (4 건)
- **FriendCode.sanitize 길이 cap (6자)** — visible 입력이 isValid 와 항상 일치
- **AppState.closeSession 단일 진입점** — endSession / GuardAction.stop / GuardAction.end 모두 동일 경로
- **AudioInterruptionObserver `NotificationCenter` DI** — 향후 단위 테스트용 슬롯
- **StreakService 신설** — `MascotProgressService.handleSessionCompleted` 직후 evaluate. 연속 7일 시 weeklyStreak EXP 1회 부여

### Cycle 3 — 정확성 / UX (4 건)
- **StreakService.daysBetween Calendar 기반 정확한 일수 계산**
- **MascotSettingsView / SubjectFormView / RunningView 잔여 `try? context.save()` → Persistence.save**
- **RunningManager.resume 권한 재체크** — `canStart` 가드
- **TimerView 시작 버튼 disabled 시각화** — selectedSubject 없을 때

### Cycle 4 — 소셜 (3 건)
- **StreakService daily evaluation 가드** — 같은 day 두 번째 호출은 cheap exit
- **CellogInboxView 차단 sender 필터링** — `blockedFriends.friendCode` set 으로 cascade
- **차단 친구 목록 UI + Unblock 버튼** — `BlockedRow` 컴포넌트, 차단 해제 경로 복구

### Cycle 5 — UX 마감 (3 건)
- **HomeView NavigationStack 래핑** — navigationTitle "오늘" 가시화
- **CellogCompose 80 자 카운터** — `n/80` 표시 + 자동 cap
- **Persistence 에러 배너** — `AppState.lastPersistenceError` 를 HomeView 상단에 빨간 배너로 노출, dismiss 가능

### Cycle 6 — 데이터 위생 (1 건)
- **0 km / 60s 미만 러닝 가드** — tap-tap 세션은 RunSession / HealthKit 기록에서 제외

### Cycle 7 — 코드 청소 (1 건)
- **StreakService.lastEvaluatedDayKey 제거** — set 만 되고 read 없는 죽은 키

### Cycle 19 — 외부 리뷰 6차 (4 건)
| 등급 | 항목 | 처리 |
|------|------|------|
| P1 | 걷기/자전거가 HealthKit 에 `.running` 으로 기록 + RunSummarySheet "러닝 완료" 고정 + 칼로리 running MET 고정 | **WorkoutType end-to-end**: `WorkoutType.metValue` / `completedLabel` 추가. `WorkoutType.hkActivityType` extension (StudyApp). `HealthService.saveRunning` → `saveWorkout(workoutType:...)`, cycling 이면 `distanceCycling`, locationType 도 GPS 사용 종류만 `.outdoor`. `RunningManager.workoutType` 필드 + `estimatedCalories` 가 MET 사용. `RunSummarySheet` 아이콘·완료 문구 동적. RunningView 가 `subject.workoutType` 을 manager + sheet 양쪽에 전달 |
| P1 | Always 권한이 실행 중에 승격되어도 BG GPS 안 켜짐 | `locationManagerDidChangeAuthorization` 가 `status == .authorizedAlways && state == .running` 시 `allowsBackgroundLocationUpdates = true` 즉시 적용 |
| P2 | 그룹 row unread 가 reported 메시지를 셈 | `GroupRow.unreadCount` 가 `!isReported` 필터 추가, MoreMenu 기준과 일치 |
| P2 | ShareTodayRecordSheet 결과 무시 | `share()` 가 `SendResult` 검사, 실패 사유를 `errorMessage` Section 으로 표시 후 dismiss 보류 |

### 검증
- `swift test`: 49/49
- `xcodebuild`: BUILD SUCCEEDED, 경고 0

### Cycle 18 — 외부 리뷰 5차 (5 건)
| 등급 | 항목 | 처리 |
|------|------|------|
| P1 | RunningView 상단 "닫기" 가 세션 저장 우회 → 거리/식물 영양분 유실 | TimerView 의 toolbar 닫기 제거 + `interactiveDismissDisabled()`. RunningView 자체 toolbar 에 leading 버튼: idle/ended 면 "취소"(단순 dismiss), running/paused 면 "종료"(endRun → 저장/HK/식물 → dismiss). 어떤 경로로 닫아도 데이터 손실 없음 |
| P1 | RunningManager.resume 가 백그라운드 위치 복원 안 함 | `resume()` 에서 `authStatus == .authorizedAlways` 일 때 `allowsBackgroundLocationUpdates = true` 복원 |
| P2 | GroupListView unread badge 가 내가 보낸 메시지도 셈 | `GroupRow.unreadCount` 가 `senderFriendCode != myCode` 필터 추가, MoreMenu 와 동일 기준 |
| P2 | 채팅 send 실패/필터 차단 silent | `GroupChatView` 에 `inlineError` State + inputBar 위 빨간 banner. blockedByFilter / saveFailed / empty 모두 사유 표시. draft 변경 시 자동 클리어 |
| P2 | SubjectListView.delete 가 `context.save` 안 함 | `Persistence.save({ try context.save() }, context: "subject.delete")` 추가 |

### 검증
- `swift test`: 49/49
- `xcodebuild`: BUILD SUCCEEDED, 경고 0

### Cycle 17 — 식물 재설계 (사용자 지시) — 함수형 procedural mascot

기존 5종×6단계 마스코트 placeholder 시스템 폐기. **씨앗에서 자라는 함수형 식물**로 전면 교체. AI 일러스트 없이 베지에·로즈 곡선·sin wave 만으로 식물 모양을 procedural 생성. 사용자가 자기 식물의 실제 식을 detail 화면에서 확인 가능.

#### A. 코어 (StudyCore.PlantFormula)
- `PlantNutrients(studyMinutes, workoutMinutes)`
- `PlantParameters` (stemHeight / Amplitude / Frequency / leafCount / leafPetals / leafSize / stemHue / leafHue / hasFlower / seed)
- `PlantFormula.parameters(seed:nutrients:)` 결정론적 함수: `(seed, study, workout)` 입력 → 동일 결과
- `PlantFormula.formulaDescription(...)` → label / formula / current value 9 줄 (사용자가 보는 "내 식물의 식")
- 새 모듈 `PlantFormula` 패키지 추가 (Foundation only)

#### B. 영양분 모델 (PlantModel SwiftData)
- `seed: Int` (UUID 고비트 derive), `studyMinutes`, `workoutMinutes`, `name`, `createdAt`
- `parameters` / `formulaLines` computed property → core 위임

#### C. 시각화 (PlantCanvasView)
- SwiftUI `Canvas` + `Path` 로 줄기 sin 파동 + 로즈 곡선 잎 + (조건 충족 시) 6장 꽃 그리기
- `sway` 파라미터로 부드러운 흔들림 애니메이션 (50ms 틱)

#### D. Detail UI (PlantDetailView)
- 큰 캔버스 카드 + 이름 편집 + 영양분 pill (공부/운동 분) + 9 줄 함수식 리스트 (formula + value 동시 표시) + 씨앗 ID 노출 (textSelection enabled)

#### E. 영양분 누적 (PlantProgressService)
- `handleStudySessionCompleted` — 공부 카테고리 세션 분 추가
- `handleWorkoutSessionCompleted` — gym/free 등 GPS 미사용 운동 세션 분 추가
- `handleRunCompleted` — RunSession 의 `totalActiveSeconds / 60` 추가
- `handleWeeklyStreakBonus` — 7일 streak 시 공부+60분 / 운동+60분 보너스
- 매 호출 끝에 `WidgetSyncService.syncPlant` + `WidgetCenter.reloadAllTimelines`

#### F. 통합 (AppState / Streak / RunningView)
- `AppState.persist` 가 subject.category 판단 후 study/workout 둘 중 하나로 영양분 push
- `StreakService.evaluate` 가 streak 7일 도달 시 `PlantProgressService.handleWeeklyStreakBonus`
- `RunningView.endRun` 이 `PlantProgressService.handleRunCompleted` 호출

#### G. 위젯 + 홈 (PlantWidget / HomeView.PlantCard / MoreMenu)
- `MascotWidget` 제거, `PlantWidget` 신규. App Group 키 `plant.{name,seed,studyMinutes,workoutMinutes}` 동기화. 위젯 내부에 mini Canvas (동일 함수, 의존 X)
- `HomeView` 상단 카드 → `PlantCard` (NavigationLink → PlantDetailView, sway 애니메이션)
- `MoreMenu` "마스코트" → "내 식물"
- `StudyWidgets` 타겟에 `StudyCore` 의존성 추가 (`project.yml`)

#### H. 구 마스코트 제거
- 파일 삭제: `MascotModel.swift`, `MascotAvatar.swift`, `MascotSettingsView.swift`, `MascotEvolutionOverlay.swift`, `MascotProgressService.swift`, `MascotWidget.swift`
- AppModelContainer schema 에서 `MascotModel.self` 제거, `PlantModel.self` 추가 + `seedPlant`
- `AppState.pendingEvolution` / `PendingEvolution` 구조체 제거
- `NotificationsService.postMascotEvolved` 제거
- `FriendsView` 의 `MascotAvatar` → `Image(systemName: "leaf.circle.fill")`
- FriendProfileModel 의 `mascotSpeciesRaw` / `mascotStage` 필드는 PoC 단계에 데이터만 유지 (UI 미사용, 추후 plant seed 로 마이그)

#### 시뮬레이터 안전 (이전 사이클 fix 유지)
- `CloudKitService` / `StudyApp.task` 의 `#if !targetEnvironment(simulator)` 가드는 그대로

#### 검증
- `swift test`: 49/49 통과
- `xcodebuild`: BUILD SUCCEEDED, 우리 코드 경고 0
- 시뮬레이터: 클린 install + onboarding 정상 ([screenshot_plant_onboarding.png](screenshots/screenshot_plant_onboarding.png))

### Cycle 16 — 4 트랙 병렬 (사용자 지시: cellog 재설계 + 운동 종류 + 백그라운드 GPS + CloudKit wire)

#### A. Cellog → 스터디 그룹 채팅 재설계
| 변경 | 내용 |
|------|------|
| 모델 | `CellogMessageModel` 삭제 → `StudyGroupModel` (id, code, name, memberCodes, createdAt) + `ChatMessageModel` (groupId, sender, text, sentAt, attachedRecordSummary, attachedKind, anyoneRead, isReported) |
| SocialService | `sendCellog` 폐기. `createGroup` / `joinGroup` / `leaveGroup` / `sendChat(text:to:attachedKind:attachedRecordSummary:)` / `reportMessage` / `seedDemoGroupIfNeeded`. `GroupCode` 6자 알파벳 |
| UI | `Features/Cellog/` 삭제 → `Features/Groups/GroupListView.swift` + `GroupChatView.swift` (myGroups 필터, 채팅 버블 my/other 정렬, `+` attachment, plus.circle 으로 오늘 기록 공유, group code copy, 그룹 나가기, 자동 markRead) |
| Wiring | MoreMenu 의 "셀로그" → "그룹 채팅" (bubble 아이콘 + unread count). FriendsView 의 envelope 버튼 제거. `MascotProgressService.handleCellogSent` no-op 처리 (그룹 채팅은 EXP 무한 farming 방지). `NotificationsService.postCellogReceived` → `postGroupChatReceived(groupName:senderLabel:)` |
| Schema | `AppModelContainer` 의 schema 에서 `CellogMessageModel.self` 제거, `StudyGroupModel.self` + `ChatMessageModel.self` 추가 |

#### B. 운동 종류 확장
- `StudyCore` 에 `WorkoutType` enum (running / walking / cycling / gym / free), `usesGPS`, `defaultSFSymbol`, `label`
- `SubjectModel.workoutTypeRaw: String?` (study 면 nil)
- `SubjectFormView`: 운동 카테고리 선택 시 종류 segmented picker 표시, 변경 시 기본 아이콘 자동 매핑
- `TimerView`: 시작 시 `subject.workoutType?.usesGPS == true` 일 때만 `RunningView`, 그 외 (gym/free) 는 일반 타이머
- 시드 러닝 과목에 `workoutType: .running` 부여

#### C. 백그라운드 GPS
- `Info.plist`: `NSLocationAlwaysAndWhenInUseUsageDescription` + `UIBackgroundModes: [location]`
- `RunningManager.requestAuthorizationIfNeeded` 가 WhenInUse 부여된 상태면 Always 로 한 번 더 prompt
- `start()` 가 Always 권한일 때만 `allowsBackgroundLocationUpdates = true`
- `pause()` / `end()` 가 정지 시 `allowsBackgroundLocationUpdates = false` 로 즉시 해제

#### D. CloudKit Wire Skeleton
- `project.yml` entitlements 에 `com.apple.developer.icloud-services: [CloudKit]` + `icloud-container-identifiers: [iCloud.co.autopus.study]`
- `CloudKit/CloudKitService.swift`: `Availability` enum (ready / noAccount / restricted / temporarilyUnavailable / disabled), `probeAvailability` (CKContainer accountStatus), `RecordType` 상수, `publishProfile` / `publishChatMessage` / `fetchProfile` no-op 스텁
- `StudyApp.task` 가 첫 진입에서 probe 호출
- 실제 CKRecord 저장 / fetch 는 W3.D-2 / W3.D-3 마일스톤 (Apple Developer Program 가입 후)

### 검증
- `swift test`: 49/49 통과
- `xcodebuild`: BUILD SUCCEEDED, 우리 코드 경고 0
- 시뮬레이터: 클린 install + onboarding → 정상 ([screenshot_track4_onboarding.png](screenshots/screenshot_track4_onboarding.png))
- entitlements properties (App Group + iCloud) xcodegen 재생성 시 자동 유지

### Cycle 15 — 외부 리뷰 4차 (5 건)
| 등급 | 항목 | 처리 |
|------|------|------|
| P1 | 러닝 active seconds 가 RunSession / Summary / HealthKit 에 반영 안 됨 | `RunSession.totalActiveSeconds` 필드 추가 (StudyCore), `RunSessionModel` 미러, `RunningManager.end()` 가 banked active 를 같이 넣음, `RunSummarySheet` 가 active 우선 (fallback wall-clock), `HealthService.saveRunning(startedAt:activeSeconds:...)` 시그니처로 변경 + collection range = `startedAt ... startedAt+active` |
| P1 | 미성년자 판정이 만 나이가 아닌 출생연도 차이 | `AgeOnboardingView` 를 `DatePicker(.wheel)` 로 변경. `Calendar.dateComponents([.year], from: birthDate, to: now)` 로 정확한 만 나이 계산 |
| P2 | 셀로그 / weekly streak 의 EXP 가 진화 오버레이 안 뜸 | `SocialService.SendResult.sent(kindUsed:transition:)` 로 transition 전달 → `CellogComposeSheet` 가 `appState.surfaceEvolution(transition)`. `StreakService.evaluate` 가 transition 반환 → `AppState.persist` 가 surface. `surfaceEvolution` 을 internal 노출 |
| P2 | 마스코트 위젯 sync 일부 경로 누락 (MascotSettings / EXP 변경) | `MascotProgressService.applyEvent` 가 매 호출마다 `WidgetSyncService.syncMascot` + `WidgetCenter.reloadAllTimelines` 호출. `MascotSettingsView.save` 도 동일 |
| P2 | StatsService 의 plannerDayInt 가 cutoff 무시 | `PlannerCalendar.plannerDay(for:)` 위임 → 00:00-02:59 도 전날 plannerDay 로 일관 |

### Cycle 13–14 — 추가 폴리싱 (사용자 요구 5/6/8 강화)
- **Cellog Unread Badge** — MoreMenu 의 "셀로그" label 에 unread count Capsule, `@Query` 로 받은 안읽음 fetch
- **Cellog 받은함 자동 읽음 처리** — `.task(id: mailbox)` 가 mailbox=.received 진입 시 isRead=true, badge 즉시 갱신
- **PendingEvolution struct** — tuple → 명시 Equatable struct, SwiftUI binding 깔끔
- **HapticFeedback wrapper** — `Notifications/HapticFeedback.swift`. 진화 시 success, 타이머 시작 시 light impact
- **MoreMenu SwiftData import 추가** — `@Query` 사용 시 컴파일 통과

### Cycle 11–12 — 추가 폴리싱
- **Mascot Widget (Small)** — 위젯 갤러리에 새 카드, App Group `mascot.*` 키 동기화, EXP 바 + 다음 단계 anchor
- **Daily Reminder** — `UNCalendarNotificationTrigger` 21:00 매일. onboarding 종료 시 register
- **Run Summary Sheet** — RunningView 종료 시 거리/시간/페이스/칼로리 요약 sheet (interactive dismiss disabled, 닫기 버튼만)
- **Subject SF Symbol Picker** — `SubjectFormView` 에 study/workout 카테고리별 아이콘 그리드 (study 10종, workout 7종)
- **HomeView Streak Card** — `StreakService.currentLength` / `isStreakAliveToday` getter 노출, flame 아이콘 + 연속 일수, 미달성 시 안내
- **Cellog Sent Mailbox** — `CellogInboxView` 받은함/보낸함 segmented. 보낸함은 신고 버튼 미표시, 수신 친구 코드 표시

### Cycle 10 — 신규 트랙 추가
| 트랙 | 산출물 |
|------|--------|
| **W3.E 미성년자 정책** | `AgeOnboardingView` (첫 실행 시 만 나이 입력) / `ProfanityFilter` 키워드 V1 / `SocialService.sendCellog` 가 minor 익명 자동 demote + ProfanityFilter rejection 결과 surface / `CellogComposeSheet` minor footer + 신고 24h SLA 안내 |
| **Stats** | `StatsService` (daily / weekly / subjectBreakdown / hourlyHeatmap) + `StatsView` (Charts: BarMark / SectorMark / heatmap gradient) / MoreMenu 에 진입 |
| **Notifications** | `NotificationsService` (UNUserNotificationCenter 권한) / 일일 목표 달성 / 마스코트 진화 / 주간 streak / 셀로그 수신 알림 / onboarding 직후 권한 요청 |
| **Mascot Evolution UX** | `MascotEvolutionOverlay` 풀스크린 (spring animation + 5s auto-dismiss) / `AppState.pendingEvolution` + `MascotProgressService` 가 transition 반환 / HomeView fullScreenCover |

### Cycle 9 — 외부 리뷰 2차 (3 건)
| 등급 | 항목 | 처리 |
|------|------|------|
| P1 | 잠금화면 LiveActivity 만 여전히 2 배 표시 — Dynamic Island 만 helper 적용 | `LiveActivityElapsed` View 추출 후 LockScreen / Compact / Expanded 모두 동일 helper 공유. 잠금화면 자체 `elapsed` computed 제거 |
| P1 | HK writeTypes 가 workout 만, distance / activeEnergy quantity sample 권한 누락 → silent drop 가능 | `writeTypes` 에 `distanceWalkingRunning` + `activeEnergyBurned` 추가. 첫 권한 요청 시 함께 노출 |
| P2 | 러닝 noise filter 가 wall-clock 사용 — pause 시간 포함되어 30s 뛰고 2분 pause 시 noise 미판정 | `manager.elapsedSeconds` (active only) 를 `manager.end()` 전에 capture 해서 noise 판정에 사용 |

### Cycle 8 — W2/러닝 시간 모델 결함 (6 건, 외부 리뷰 반영)
| 등급 | 항목 | 처리 |
|------|------|------|
| P1 | LiveActivity 일시정지 표시 시간 2배 | `pause/resume` 에서 `startedAt` 을 `now - activeSeconds` 로 rebase. 위젯은 `pausedAt - startedAt` 만 표시 → 활성 시간과 정확히 일치 |
| P1 | Guard 경로 pause/resume 이 LiveActivity 미반영 | `pauseSessionInternal` / `resumeSessionInternal` 단일 chokepoint. 사용자 버튼 + `applyGuardAction(.pause/.resume)` 둘 다 통과 |
| P1 | RunningManager pause 시간 누적 차감 안 됨 | `bankedActiveSeconds` + `currentSegmentStart` 패턴. pause 시 segment 마감 → bank, resume 시 새 segment 시작. ticker 는 `banked + (now - segStart)` |
| P2 | HK 권한 요청 경로 부재 | `RunningView.task` 가 `HealthService.shared.requestAuthorization()` 도 호출 → 첫 러닝 종료 시 silent drop 없음 |
| P2 | 위젯 초기 시드 sync 없음 | `AppModelContainer.seedIfNeeded` 끝에 `WidgetSyncService.syncAll(context:)` → 설치 직후 위젯이 placeholder 대신 실제 D-Day 표시 |
| (보너스) | HKWorkout 초기화기 deprecation 경고 | `HKWorkoutBuilder` 기반 + `addSamples` (distance + activeEnergy) 로 교체 → 경고 0 |

### 검증
- `swift test`: 49/49 통과
- `xcodebuild`: BUILD SUCCEEDED, **우리 코드 경고 0** (HKWorkout deprecation 포함)
- 시뮬레이터: 클린 install + 5탭 정상 ([screenshot_cycle8_home.png](screenshots/screenshot_cycle8_home.png))

## 2. 누적 검증

| 항목 | 결과 |
|------|------|
| `swift test` | **49 / 49 통과** (Cycle 1 에서 4 개 추가) |
| `xcodebuild ... build` | **BUILD SUCCEEDED** (모든 사이클) |
| 시뮬레이터 launch + 5탭 렌더 | 정상 ([screenshot_final.png](screenshots/screenshot_final.png)) |
| 엔타이틀먼트 안정성 | xcodegen 재생성 시 자동 채움 검증 |
| Persistence error path | `Persistence.save` / `os.Logger` 통해 surface, HomeView 배너 |

## 3. 신규 산출물

```
StudyApp/Persistence/
├── MascotProgressService.swift    .dailyGoalMet 자동 부여
├── StreakService.swift            연속 7일 streak 판정 (UserDefaults 영속)
└── PersistenceLog.swift           Persistence.save / Persistence.log

StudyApp/Features/Home/HomeView.swift
└── PersistenceErrorBanner         lastPersistenceError 노출

StudyApp/Features/Friends/FriendsView.swift
└── BlockedRow + blockedSection    차단 해제 경로

StudyCore/Tests/StudyCoreTests/SceneSignalTests.swift
                                   GuardAction 라우팅 종합 검증 (4 tests)
```

## 4. 코드 베이스 현황

```
StudyCore   45 + 4 = 49 unit tests passing (cycle 1 추가분 포함)
StudyApp    35 + Swift files / file-size-limit 300 준수
StudyWidgets 5 files / WidgetBundle + LiveActivity + 2 home widgets
Shared      TimerActivityAttributes + AppGroup id (양 타겟 공유)
```

전 빌드 경고 0, 우리 코드 외 `appintentsmetadataprocessor` 무관 경고 1 (AppIntents 미사용으로 인한 정보 메시지) 만.

## 5. 잔여 미해결 / 후속 트랙

| 영역 | 사유 |
|------|------|
| **실기기 회귀 테스트** (BackgroundGuard 4 신호, LiveActivity, 위젯, 러닝 GPS) | simctl 자동화 한계 |
| **CloudKit wire (W3.D)** | Apple Developer Program + 실기기 필요. SocialService 가 swap-ready |
| **미성년자 정책 (W3.E)** | 가입 연령 입력 UX + 익명 송수신 차단 + 욕설 필터 |
| **AI 마스코트 30컷** | 사용자 작업 (외부 도구). Asset Catalog placeholder 자리는 마련됨 |
| **MoreMenuView 중첩 NavigationStack 정합성** | 동작에 영향 없지만 toolbar 중복 가능. SubViewModifier 패턴으로 추후 정리 |
| **운동 종류 확장 (걷기 / 자전거 / 헬스)** | 현재 러닝 단일. RunningManager 분기 추가 |
| **백그라운드 GPS** | `allowsBackgroundLocationUpdates` + Always 권한 |
| **통계 화면 (일/주/월)** | PLAN §6.6. 미구현 |

## 6. 코덱스 리뷰 의뢰 시 우선 봐주면 좋은 곳

1. `MascotProgressService.handleSessionCompleted` 의 임계값 첫 도달 판정 로직 — race / 동시성 / 정합성
2. `StreakService.evaluate` 호출 빈도 + UserDefaults 영속 모델
3. `AppState.closeSession` 단일 진입점 — `applyGuardAction(.stop|.end)` 와 사용자 종료 / endSession 가 동일 path 인지
4. `Persistence.save` 헬퍼의 트랜잭션 의미 (현재는 단순 try-catch + os_log)
5. `SceneGeometryObserver` 30 초 + DidActivate 보강 — 분할 화면 진입 즉시 감지 보장 여부

---

🐙 Autopus
