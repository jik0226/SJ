# SJ — Study J 🌱

> 종이 플래너의 10분 블록 그리드를 디지털로 옮기고, **수학 함수로 자라는 식물 마스코트**가 학습·운동 시간을 영양분으로 받는 iOS 학습 동반자 앱.
>
> **SJ** = **S**tudy **J** — 학습을 게이미피케이션 + 함수형 시각화로 풀어내는 개인 동반자.

<p align="center">
  <em>SwiftUI · SwiftData · ActivityKit · CoreLocation · HealthKit · WidgetKit</em>
</p>

---

## 📌 프로젝트 개요

| 항목 | 내용 |
|------|------|
| **유형** | 개인 프로젝트, iOS Native 앱 |
| **기간** | 2026.05 (진행 중) |
| **플랫폼** | iOS 17+, iPhone 17 Pro 시뮬레이터 + 실기기 검증 |
| **언어/도구** | Swift 6.3, Xcode 26.5, SwiftUI, SwiftData, Swift Package Manager |
| **개발 사이클** | 자체 리뷰·픽스 19 사이클, 외부 코드 리뷰 7회 반영, 결함 60+건 수정 |
| **코드 규모** | Swift 약 5,400줄 / 76 파일 / 49 단위 테스트 통과 |

---

## ✨ 핵심 기능

| 영역 | 구현 |
|------|------|
| **순공시간 타이머** | 과목별 색·아이콘·일일 목표·**강의 모드** 토글. TimerEngine 결정론적 상태머신 |
| **다른 앱 사용 자동 정지** | 5 종 iOS 어댑터 (scenePhase / Screen Lock / Call / Audio / Scene Geometry) 가 단일 GuardPolicy 정책표로 라우팅. 13 신호 × 강의모드 ON/OFF 매트릭스 단위 테스트 |
| **잠금화면 LiveActivity** | `Text(timerInterval:)` 로 OS-driven 카운트, 앱 wake-up 없이 정확한 active-time 표시 (pause 시 `startedAt` 재기준점) |
| **10분 블록 플래너** | 22행 × 6열 그리드 (05:00 → 02:50 wrap), 세션 종료 시 자동 색 채움 |
| **러닝 측정** | CoreLocation 적응형 정확도 (정지 20초 → 100m 다운그레이드), HealthKit Workout 저장, Always 권한 시 백그라운드 GPS |
| **운동 종류** | running / walking / cycling / gym / free — MET 별 칼로리, HK activityType 정확 매핑 |
| **함수형 식물 마스코트** | (씨앗 + 학습 분 + 운동 분) → 줄기 sin 파형, 로즈 곡선 잎, 6장 꽃 — **AI 에셋 없이 수학으로만 사람마다 다른 식물** |
| **연속 학습 streak** | UserDefaults 영속 7일 streak, 도달 시 식물 영양분 보너스 + 알림 |
| **위젯 + 위젯 자동 동기화** | 디데이 / 오늘 순공 / 식물 3종, App Group 으로 데이터 공유 |
| **그룹 채팅** (PoC) | 그룹별 thread, 기록 첨부 (오늘 순공/러닝 자동 공유), 차단·신고·미성년자 안전 정책 |
| **미성년자 안전** | 만 14세 미만 가입 시 메시지 길이 200자 cap + URL 차단 + 신고 24h SLA 표기 |
| **통계** | Apple Charts — 7/30일 일별 막대 / 과목별 파이 / 시간대 히트맵 (PlannerCalendar cutoff 03:00 적용) |

---

## 🌱 차별 포인트 — 함수형 식물 마스코트

마스코트 시스템에 AI 일러스트 대신 **`(seed, studyMinutes, workoutMinutes)` 결정론적 함수**를 사용.

```
줄기 높이 = log₁₀(총분 + 1) × 30 + 20
줄기 진폭 = 4 + √(운동 분 ÷ 30)
잎 개수  = min(20, 2 + ⌊log₁₀(총분 + 1) × 4⌋)
잎 모양  = (3 + ⌊운동 분 ÷ 60⌋ mod 5) 장 장미곡선
잎 색조  = 0.12 + (0.30 − 0.12) × 공부비율
꽃 개화  = 공부 ≥ 360분 ∧ 운동 ≥ 90분
```

같은 식이라도 **사용자별 seed 가 다르므로 식물 모양도 다르고**, 본인의 식 자체를 detail 화면에서 직접 볼 수 있음. SwiftUI Canvas 로 베지에·로즈 곡선만 그려 외부 에셋 0.

---

## 🛠️ 기술 스택

**Core**: Swift 6.3 · SwiftUI · SwiftData · Swift Package Manager
**iOS 기능**: ActivityKit · WidgetKit · CoreLocation · CoreMotion · HealthKit · CallKit · AVAudioSession · UserNotifications · Apple Charts
**아키텍처**: Pure-core (Foundation only) + iOS Adapter 분리, `@MainActor` + `@Observable` (Observation), `nonisolated` delegate
**테스트**: XCTest (StudyCore Swift Package, 49 단위 테스트)
**CI 도구**: XcodeGen (project.yml inline entitlement properties)

---

## 🏗️ 아키텍처

```
StudyCore (Swift Package, Foundation-only)
├── Models            Subject / StudySession / RunSession / PlannerBlock /
│                     DailyPage / DDay / Mascot / PausedRange
├── PlannerCalendar   cutoff 시각 + 슬롯 변환 (0..143)
├── TimerEngine       @Observable 상태머신, clock 주입 가능
├── BackgroundGuard   13 SceneSignal × Context → GuardAction 순수 결정표
├── MascotEngine      진화 룰 (legacy, plant 시스템으로 대체)
└── PlantFormula      seed + 영양분 → PlantParameters 결정론적 함수

StudyApp (iOS Application)
├── App               StudyApp @main, AppState (@Observable, MainActor)
├── Features          Home / Timer / Planner / DDay / Subject / Plant /
│                     Running / Stats / Groups / Friends / Onboarding
├── Background        4 옵저버 어댑터 + BackgroundGuardAdapter
├── Persistence       AppModelContainer (migration fallback) /
│                     SessionPersistence (transactional) /
│                     PlantProgressService / StreakService / WidgetSyncService
├── Health / CloudKit / Notifications / Social / Models / Design
└── Shared/           App + WidgetExtension 공유 ActivityKit attributes

StudyWidgets (App Extension)
├── DDayWidget · TodayStudyTimeWidget · PlantWidget · TimerLiveActivity
```

---

## 🧪 품질 검증

- **49 / 49 단위 테스트** 통과 (`swift test`)
- `xcodebuild` BUILD SUCCEEDED, 코드 경고 0
- **외부 코드 리뷰 7회** 반영 — 매 라운드 P0~P2 결함 카탈로그
- SwiftData 마이그레이션 fallback (legacy store 자동 삭제 → in-memory) 로 업그레이드 crash loop 방지
- 핵심 시간 모델 검증: pause-aware active time, cutoff 03:00, 슬롯 인덱스 132, LiveActivity rebase

---

## 📅 개발 사이클

| 단계 | 산출 |
|------|------|
| W0 | 코어 PoC + iOS 앱 셸 + 디자인 토큰 |
| W1.A | SwiftData 모델 5개 + 5탭 UI + 세션 영속화 |
| W1.B | BackgroundGuard 4 어댑터 + 세션 라이프사이클 게이팅 |
| W2 | LiveActivity + Widget Extension + App Group 동기화 |
| W3 | 친구 / 그룹 채팅 (mock) + 미성년자 안전 정책 |
| W4 | 운동 / 러닝 (HealthKit + 적응형 GPS) + 운동 종류 확장 |
| W5 | 마스코트 → **함수형 식물** 전면 재설계 (사용자 피드백 반영) |
| Polish | 통계 / 알림 / 햅틱 / 위젯 3종 / SwiftData migration / 미성년자 enforcement |

상세 변경 이력 → [`AUTONOMOUS_CYCLE_REPORT.md`](docs/AUTONOMOUS_CYCLE_REPORT.md), [`FINAL_REVIEW.md`](docs/FINAL_REVIEW.md), [`PLAN.md`](docs/PLAN.md)

---

## 🚀 빌드 & 실행

### 시뮬레이터

```bash
# XcodeGen 으로 프로젝트 생성 (한 번만)
/tmp/xcodegen_unzip/xcodegen/bin/xcodegen generate

# 빌드
xcodebuild -project StudyApp.xcodeproj \
  -scheme StudyApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build

# 단위 테스트
(cd StudyCore && swift test)
```

### 실기기 (무료 Apple ID)

[`DEVICE_RUN_GUIDE.md`](docs/DEVICE_RUN_GUIDE.md) 의 10 단계 가이드.

---

## 📚 회고

- **TDD 친화 아키텍처**: 시간 의존성을 `clock: () -> Date` 클로저로 주입해 결정론적 단위 테스트. BackgroundGuard 도 순수 결정 테이블로 분리해 iOS 어댑터 없이 13 신호 모두 검증 가능
- **함수형 마스코트**: 외부 에셋 의존도를 0 으로 만드는 procedural 접근. 사용자가 자기 식물의 식을 직접 보는 투명성 + 사람마다 다른 시드로 unique 경험
- **외부 리뷰 사이클**: 매 라운드 P0~P2 결함 카탈로그를 받아 픽스 → 빌드 → 재리뷰. "테스트만 남았다" 판정의 함정을 외부 리뷰가 두 번 잡아준 경험
- **iOS 권한·시뮬 한계**: BackgroundGuard 4 옵저버는 시뮬에서 자동화 검증 불가 → 단위 테스트로 정책 매트릭스 + 실기기 수동 회귀로 분리

---

## 📝 라이선스

본 저장소는 학습/포트폴리오 목적. 외부 배포 시 별도 라이선스 명시 필요.

---

<p align="center">
  <sub>🐙 Autopus-ADK 기반 자동 리뷰 사이클 + 외부 코드 리뷰 협업</sub>
</p>
