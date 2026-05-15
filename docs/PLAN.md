# 공부 어플 (가칭) — 기획서 v2.0

> 작성일: 2026-05-13
> 최종 수정: 2026-05-13 (코덱스 리뷰 v1 반영)
> 작성자: Claude (Autopus)
> 리뷰어: Codex
> 상태: 리뷰 반영 완료 — 구현 착수 대기

## 0. 변경 이력

| 버전 | 일자 | 내용 |
|------|------|------|
| v1.0 | 2026-05-13 | 최초 기획 |
| v1.1 | 2026-05-13 | 사용자 결정 4건 반영 (iOS17+, 즉시정지, 친구 MVP, AI 마스코트) |
| v2.0 | 2026-05-13 | 코덱스 리뷰 반영. MVP 범위는 사용자 요구 우선 유지, 그 외 P0/P1/P2 모두 수용 |

## 1. 사용자 요구사항 (고정값 — 변경 금지)

다음은 사용자가 명시한 고정 요구사항입니다. 어떤 리뷰·기술 제약도 이 항목들을 축소하지 못합니다.

1. **디데이**
2. **순공시간 타이머** (과목 등록 기반)
3. **다른 앱 사용 시 타이머 즉시 정지**, 단 강의 모드 토글로 예외 가능
4. **배터리·데이터 사용량 최소화**
5. **친구와 같이 사용**
6. **목표시간 채우기 성취감**
7. **운동 카테고리 + 러닝 km 측정**
8. **셀로그 스타일 메시지**
9. **메인화면 캐릭터 성장** (사람마다 다르게)
10. **사진 5번 디자인 가중치** (참고: 사진 2~5)
11. **10분 블록 시각 플래너** (사진 1 참고)

## 2. 사용자 결정 (확정)

| 항목 | 결정 |
|------|------|
| iOS 최소 버전 | iOS 17+ |
| 앱 이탈 감지 | 즉시 정지 + 알림 (`scenePhase` 기반, ScreenTime API 미사용) |
| 친구 기능 범위 | **MVP에 포함** |
| 마스코트 시스템 | **함수형 바다 (procedural)** — 씨앗 + 영양분(공부/운동 분) → PlantFormula 결정론적 함수가 파도·물고기·배경 색을 산출. AI 에셋 폐기 |

## 3. 디자인 레퍼런스 (수치화 — P2 반영)

이미지 파일은 작업 디렉토리 루트에 위치합니다.

| 파일 | 가중치 | 추출 요소 |
|------|--------|-----------|
| `1.jpeg` | 플래너 레이아웃 100% | 좌측: 시간 그리드(05–02시, 10분×6칸), 우측: D-Day 큰 표시 / 오늘의 목표 / Key Point / Feedback / Progress 0–100 |
| `2.jpeg` (Grennify) | 톤 | 둥근 카드, 곡선 프레임 → 바다 카드 라운드 코너·그라데이션 톤에 적용 |
| `3.jpeg` (HIKING) | 톤 | 파란 그라데이션, 풍경 일러스트 → 디데이 카드 배경 |
| `4.jpeg` (Clair) | 톤 | 미니멀 원형 컨트롤 → 타이머 메인 컨트롤 |
| **`5.jpeg` (실버도그)** | **최우선** | 메인 컬러 블루, 카드형 UI, 마스코트 어시스턴트, 게이미피케이션 카피("85% 달성") |

### 컬러 토큰 (수치 확정)
```
primary       #3D7BFF
primaryDark   #2E5DC8
background    #FFFFFF  (dark: #0A0E1A)
surface       #F5F7FB  (dark: #131826)
textPrimary   #1A1D29  (dark: #F5F7FB)
textSecondary #6B7280
success       #4CAF50
warning       #FFB020
error         #FF4757
subjectPalette #FF6B6B, #FFA94D, #FFD43B, #69DB7C, #4DABF7, #748FFC, #B197FC, #F783AC, #868E96, #20C997
```

### 간격·라운드·그림자
```
spacing  4 / 8 / 12 / 16 / 24 / 32
radius   8 / 12 / 16 / 24 (cards = 16)
shadow   y=2 blur=8 opacity=0.06 (light), y=2 blur=12 opacity=0.18 (dark)
```

### 타이포
```
title-1   28 / 700
title-2   22 / 700
headline  17 / 600
body      15 / 400
caption   12 / 500
```

### 디자인 QA 기준 (수치 검증 가능)
- 플래너 그리드 셀 크기: 정사각 (1:1), 가로 6칸이 화면 너비 88%를 균등 분할
- 마스코트 영역 최소 높이: 메인 화면 상단 30% (safe area 기준)
- 카드 좌우 마진: 16pt, 카드 간 세로 간격: 12pt
- 텍스트 행간: body 1.45, headline 1.35

## 4. MVP 범위 (사용자 요구 우선 — 모두 포함)

코덱스가 권장한 축소안은 반려. 대신 W0 기술 검증 스파이크 추가 + 일정 8주로 조정.

| 영역 | MVP 포함 | 비고 |
|------|----------|------|
| 디데이 | ✅ | 위젯 포함 |
| 과목 등록 (강의 모드 토글) | ✅ | |
| 순공시간 타이머 + 즉시 정지 | ✅ | **W0에서 기술 검증 선행** |
| 10분 블록 플래너 | ✅ | |
| 오늘의 페이지 (목표/KP/FB/Progress) | ✅ | |
| 마스코트 성장 | ✅ | **함수형 바다** — `PlantFormula(seed, studyMinutes, workoutMinutes)` (함수명은 git history 호환을 위해 유지). 사람마다 다른 seed → 다른 파도·물고기 배치. 식 자체를 사용자가 PlantDetailView("내 바다의 식")에서 확인 가능 |
| 통계 (일/주/월) | ✅ | |
| LiveActivity | ✅ | **Date 기반 OS 렌더링** |
| 디데이·시간 위젯 | ✅ | |
| 운동 (HealthKit 연동) | ✅ | |
| 러닝 GPS 측정 | ✅ | 적응형 샘플링 |
| 친구 시스템 | ✅ | **Private + CKShare 구조** |
| 셀로그 메시지 | ✅ | |
| 신고·차단·미성년자 정책 | ✅ | App Store 가이드 1.2 |

## 5. 백그라운드 정지 정책 (P0 반영)

`scenePhase` 단독 의존을 버리고, 다중 신호를 조합합니다.

### 정지 트리거 화이트리스트
| 상황 | 신호 | 동작 |
|------|------|------|
| 다른 앱 전환 | `scenePhase == .background` | **즉시 정지** + 알림 + 햅틱 |
| 홈 스크린 | 동일 | **즉시 정지** |
| 화면 잠금 | `UIApplication.protectedDataWillBecomeUnavailable` | **정지** (사용자 토글로 허용 가능) |
| Picture-in-Picture | `AVPictureInPictureController` 이벤트 | **정지** |
| Split View / Stage Manager (우리 앱 < 50% 비율) | `UIScene.windowScene.effectiveGeometry` | **정지** |

### 일시정지 트리거 (false positive 방지)
| 상황 | 신호 | 동작 |
|------|------|------|
| 전화 수신 | `CallKit` / `CXCallObserver` | 일시정지, 통화 종료 시 자동 재개 옵션 |
| Siri / 다른 오디오 인터럽션 | `AVAudioSession` interruption | 일시정지, 끝나면 재개 |
| Control Center / Notification Center 슬라이드 | `scenePhase == .inactive` | **정지 안 함** (active 회복 시 무시) |
| 시스템 알림 팝업 | `.inactive` 짧은 시간 | **정지 안 함** |

### 강의 모드 정책
- 과목별 `allowPhoneUse: Bool` 토글
- ON이면 위 정지 트리거 전부 무시
- **악용 방지**: 1회 강의 모드 세션 최대 3시간, 초과 시 자동 종료 + 강제 휴식 알림

### 카운트 정의표 (Open Question 1 답)
| 상황 | 카운트 | 비고 |
|------|--------|------|
| 앱 active + 타이머 ON | ✅ 순공 | |
| 앱 background | ❌ 정지 | 핵심 |
| 화면 잠금 (기본) | ❌ 정지 | 토글 가능 |
| 전화 수신 중 | ⏸ 일시정지 | 자동 재개 |
| 강의 모드 과목 | ✅ 모든 케이스 | 3시간 캡 |
| Split View 분할 비율 < 50% | ❌ 정지 | 분할 사용은 본격 공부 아님 |
| PiP 동영상 재생 | ❌ 정지 | |

### W0 기술 검증 스파이크 산출물
- `BackgroundGuard` 모듈 단독 테스트 앱
- 위 모든 케이스 자동 + 수동 테스트 리포트
- false positive 비율 < 1% 검증
- 알림 도착 지연 측정 (목표 < 500ms)

## 6. LiveActivity 설계 (P1 반영)

매초 갱신 X. OS 자동 렌더링 사용.

```swift
struct StudyTimerAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        let startedAt: Date           // 시작 시각
        let pausedAt: Date?           // 일시정지 시각 (nil = 실행 중)
        let accumulatedSeconds: Int   // 누적 (재개 전 합)
        let subjectName: String
        let subjectColorHex: String
        let targetSeconds: Int?       // 목표 시간 (선택)
    }
    let sessionId: UUID
}

// 잠금화면 표시
Text(timerInterval: state.startedAt...Date.distantFuture,
     pauseTime: state.pausedAt,
     countsDown: false)
// OS가 자동으로 매초 렌더링, 앱 wake-up 없음
```

**앱이 update 호출하는 시점만**:
- start / pause / resume / end / 과목 변경

**업데이트 호출 금지 시점**:
- 매초 / 매분 (OS에 위임)

## 7. CloudKit 재설계 (P1 반영)

### Public DB (최소 필드만, 검색용)
| 레코드 | 필드 | 접근 |
|--------|------|------|
| `UserProfile` | `recordID`, `friendCode`(6자리), `nickname`, `mascotSpecies`, `mascotStage`, `isMinor` | 친구코드로만 조회 가능 (인덱싱) |

### Private DB (본인만)
| 레코드 | 용도 |
|--------|------|
| `FriendLink` | 친구 목록 (상대 recordID, 별명, 추가일, 프라이버시 토글) |
| `Inbox` | 받은 셀로그 메시지 |
| `BlockList` | 차단 사용자 |
| `Report` | 신고 기록 (백오피스 검토용) |

### Shared DB (CKShare)
| 레코드 | 공유 모델 |
|--------|----------|
| `DailySummary` | 친구별 1:1 공유. 오늘 총 순공만, 5분 throttle |
| `CellogMessage` | 발신자 Private → 수신자에게 CKShare로 공유. 신고 시 메타만 백오피스 접근 |

### 보안·프라이버시 룰
- 친구 검색은 친구코드 정확 일치만 (부분 검색 불가)
- 미성년자(`isMinor=true`) 프로필은 검색 결과에서 제외
- 메시지에는 발신자 닉네임만 노출, 실명·이메일 미공개
- 신고 시 메시지+발신자 24시간 SLA 검토

## 8. 데이터 모델 (P1 반영)

```swift
@Model
final class Subject {
    @Attribute(.unique) var id: UUID
    var name: String
    var colorHex: String
    var sfSymbol: String
    var allowPhoneUse: Bool
    var categoryRaw: String         // "study" | "workout"
    var dailyTargetMinutes: Int
    var createdAt: Date
}

@Model
final class StudySession {
    @Attribute(.unique) var id: UUID
    var subject: Subject?
    var startedAt: Date
    var endedAt: Date?
    var totalSeconds: Int
    var plannerDay: Int             // YYYYMMDD (귀속 일자, cutoff = 03:00)
    var pausedRanges: [PausedRange]
}

@Model
final class PlannerBlock {
    @Attribute(.unique) var compositeKey: String   // "YYYYMMDD-slotIndex" — 복합 유니크
    var plannerDay: Int             // YYYYMMDD
    var slotIndex: Int              // 0..143 (24h × 6, 10분 단위)
    var subject: Subject?
    var note: String?
}

@Model
final class DailyPage {
    @Attribute(.unique) var plannerDay: Int        // YYYYMMDD
    var todayGoal: String
    var keyPoint: String
    var feedback: String
    var progressPercent: Int
}

@Model
final class DDay {
    @Attribute(.unique) var id: UUID
    var title: String
    var targetDate: Date
    var emoji: String
    var isPinned: Bool
}

@Model
final class Mascot {
    @Attribute(.unique) var id: UUID
    var speciesRaw: String
    var exp: Int
    var stage: Int
    var name: String
}

@Model
final class RunSession {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var distanceMeters: Double
    var routePolyline: Data         // encoded
    var avgPaceSecPerKm: Int
    var caloriesKcal: Double
    var plannerDay: Int
}
```

### 자정 귀속 정책
- 학생 라이프스타일 반영: **cutoff = 03:00**
- 02:59:59까지의 세션 → 전날 `plannerDay`
- 03:00부터 → 새 `plannerDay`
- 사용자 설정에서 cutoff 조정 가능 (0~6시 범위)

### Slot 인덱스 정책
- 0 = 00:00, 143 = 23:50 (24h × 6)
- 사진 1 UI는 05:00부터 02:50까지 표시 (즉 30 → 143 → 17 순서로 wrap)
- 데이터는 항상 절대 인덱스, 표시만 wrap

## 9. 미성년자·안전 정책 (Open Question 2 답)

- 가입 시 만 나이 입력. 만 14세 미만은 `isMinor=true`
- **미성년자 제약**:
  - 친구 검색에서 본인 프로필 비노출
  - 셀로그 익명 메시지 송수신 불가
  - 친구는 친구코드 직접 입력만 가능
  - 위치/러닝 기능은 보호자 동의 후 활성화
- **메시지 필터링**:
  - 욕설·혐오 사전 (한국어 + 영어 1차)
  - 발송 전 차단 + 사용자에게 알림
  - 반복 위반 3회 시 30일 메시지 정지
- **신고·차단**:
  - 모든 메시지·프로필에 신고 버튼
  - SLA: 24시간 이내 검토
  - 차단 시 양방향 즉시 차단 + 친구 관계 자동 해제

## 10. MVP 성공 지표 (Open Question 3 답)

| 지표 | 목표 |
|------|------|
| D+1 retention | ≥ 60% |
| D+7 retention | ≥ 30% |
| 일일 기록 완료율 (DAU 중 타이머 1회 이상 시작) | ≥ 50% |
| 평균 일일 순공시간 | ≥ 60분 |
| 친구 추가율 (D+7) | ≥ 20% |
| 셀로그 메시지 / 활성 사용자 / 30일 | ≥ 5건 |
| 크래시 프리 세션 | ≥ 99.5% |
| 백그라운드 false positive 비율 | < 1% |
| 평균 배터리 사용 / 1시간 타이머 | < 3% |

베타 2주 데이터 기준 평가.

## 11. 일정 (8주, W0 추가)

| 주차 | 마일스톤 | 산출물 |
|------|----------|--------|
| **W0** | **기술 검증 스파이크** | **`BackgroundGuard` 단독 앱, LiveActivity PoC, CloudKit 권한 PoC, 마스코트 에셋 1종** |
| W1 | 기반 | Xcode 프로젝트, 디자인 토큰, Subject CRUD, TimerEngine 코어, BackgroundGuard 통합 |
| W2 | 시간 + 기록 | StudySession 저장, PlannerBlock 자동 채움, DDay |
| W3 | 메인 화면 | 마스코트 엔진, 오늘의 페이지, 통계 v1 |
| W4 | 위젯·LiveActivity | DDay 위젯, 시간 위젯, LiveActivity 통합 |
| W5 | 운동·러닝 | HealthKit 연동, RunSession, 적응형 GPS |
| W6 | 친구·셀로그 | CloudKit 셋업, 친구코드, FriendLink, CellogMessage, 신고·차단 |
| W7 | 안전·미성년자·필터 | 미성년자 정책, 메시지 필터, 신고 백오피스, 약관 |
| W8 | 폴리싱·QA | 베타 빌드, AI 마스코트 에셋 5종, 디자인 QA, TestFlight |

### 병렬화 전략
- W1~W4는 4개 executor 병렬 (Timer / Planner / Mascot / Widget)
- W5~W6도 2개 병렬 (Workout / Friends)
- 통합·QA는 단일 트랙

## 12. 아키텍처 (변경 없음, v1.0과 동일)

`Features / Core / Design / Widgets` 4계층. 자세한 트리는 v1.0 참고 (생략).

## 13. 배터리·데이터 절감 (강화)

| 항목 | 전략 |
|------|------|
| 타이머 | 로컬만, 동기화는 5분 배치 |
| LiveActivity | OS 자동 렌더링, 앱 update는 이벤트 시 |
| 친구 데이터 | CloudKit 푸시 트리거, 5분 throttle |
| 러닝 GPS | `kCLLocationAccuracyBestForNavigation` 중 정지 감지 시 `kCLLocationAccuracyHundredMeters`로 다운그레이드 |
| 비러닝 시간 | GPS 완전 off |
| BG 작업 | `BGProcessingTask` 1일 1회 (새벽) |
| 이미지 | WebP, 캐싱, lazy load |
| 위젯 | timeline `.atEnd` 최소화, 1시간 단위 갱신 |

## 14. 리스크 & 완화 (갱신)

| 리스크 | 영향 | 완화 |
|--------|------|------|
| W0 기술 검증에서 false positive 1% 초과 | 핵심 기능 신뢰 | 화이트리스트 추가, 사용자 토글로 보완 |
| CKShare 페어 동기화 복잡도 | 친구·메시지 지연 | W6에서 가장 먼저 통합 시작 |
| ~~AI 마스코트 일러스트 품질~~ | (폐기) | 사용자 지시로 함수형 바다 procedural 생성으로 전환. AI 에셋 미사용 |
| App Store 친구 기능 심사 | 출시 지연 | 신고·차단·약관·미성년자 정책 W7 완료, 심사 전 자체 점검 |
| HealthKit 권한 거부 | 운동 기능 제한 | 수동 입력 폴백 |
| CloudKit 무료 한도 | 사용자 증가 시 부담 | 모니터링, 필요 시 백엔드 이전 가능하게 추상화 |
| 강의 모드 악용 | 부정 사용 | 3시간 캡, 일일 사용 횟수 노출 |
| 미성년자 사용 → 위험 | 법적 리스크 | 가입 시 연령 게이트, 익명 제한, 메시지 필터 |
| 일정 8주 초과 | 출시 지연 | W4 종료 시점 중간 점검, 비핵심 폴리싱 일부 Phase 2로 |

## 15. 다음 단계

1. **사용자 동의** → 이 v2.0 진행 확정
2. **W0 기술 검증 시작** (2~3일):
   - BackgroundGuard PoC
   - LiveActivity PoC
   - CloudKit 권한·CKShare PoC
   - AI 마스코트 에셋 1종 생성
3. **W0 결과 코덱스 리뷰**
4. **W1 본격 구현** (executor 병렬 분배)

---

🐙 Autopus
