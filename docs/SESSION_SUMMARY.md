# 공부 어플 — 세션 종합 요약

> 작성일: 2026-05-14
> 작성자: Claude (Autopus)

## 진행 트랙

| 트랙 | 산출물 | 보고서 | 상태 |
|------|--------|--------|------|
| W0 | 코어 비즈니스 로직 Swift Package (45 단위 테스트) + iOS 앱 셸 | [W0_REPORT.md](W0_REPORT.md) | ✅ 코덱스 7차 통과 |
| W1.A | SwiftData 모델 5개 + 5탭 UI (홈/타이머/플래너/D-Day/과목) + 세션 영속화 + PlannerBlock 자동 채움 | [W1_REPORT.md](W1_REPORT.md) | ✅ 코덱스 7차 통과 |
| W1.B | BackgroundGuard iOS 어댑터 (ScreenLock / Call / Audio / Geometry) + 세션 라이프사이클 게이팅 | 위 동일 | ✅ |
| W2 | App Group + Widget Extension + LiveActivity + DDay 위젯 + 오늘 순공 위젯 | [W2_REPORT.md](W2_REPORT.md) | 🟡 빌드 OK, 잠금화면·홈위젯 자동검증 한계 |
| W4 | HealthKit 권한 + RunSessionModel + RunningManager (적응형 GPS) + RunningView | [W4_REPORT.md](W4_REPORT.md) | 🟡 빌드 OK, GPS 시뮬레이션 사용자 수동 |
| W3 | FriendProfileModel + CellogMessageModel + Social mock 서비스 + 친구·셀로그 UI + 더보기 메뉴 | [W3_REPORT.md](W3_REPORT.md) | 🟢 mock 모드. CloudKit wire 는 W3.D 트랙 분리 |
| W5 | 마스코트 종×단계 placeholder + 종/이름 설정 UI | [W5_REPORT.md](W5_REPORT.md) | 🟢 placeholder. 실제 에셋은 사용자 작업 |

## 코드 통계 (대략)

```
StudyCore/                  Swift Package, Foundation only, 45 단위 테스트
├── Sources/                6 모듈 / 11 파일 / 약 500 줄
└── Tests/                  5 파일 / 약 350 줄

StudyApp/                   iOS 메인 앱
├── App/                    StudyApp + AppState + LiveActivityController
├── Background/             5 옵저버 (ScreenLock / Call / Audio / Geometry + Adapter)
├── Design/                 토큰
├── Features/               Home / Timer / Planner / DDay / Subject / Mascot / Friends / Cellog / Running
├── Health/                 HealthService
├── Models/                 8 SwiftData @Model
├── Persistence/            AppModelContainer / SessionPersistence / WidgetSyncService
└── Social/                 FriendCode / SocialService

StudyWidgets/               Widget Extension
├── StudyWidgetsBundle      WidgetBundle
├── TimerLiveActivity       Lock Screen + Dynamic Island
├── DDayWidget              Small/Medium
└── TodayStudyTimeWidget    Small

Shared/                     양쪽 타겟에 공유
└── TimerActivityAttributes ActivityKit attributes + AppGroup id
```

총 약 30+ Swift 소스 파일, 모두 file-size-limit 300줄 이하 준수.

## 사용자 요구사항 매핑

| # | 요구사항 | 구현 위치 | 상태 |
|---|----------|-----------|------|
| 1 | 디데이 | DDayModel / DDayListView / DDayWidget | ✅ |
| 2 | 순공시간 (과목 등록) | SubjectModel / TimerEngine / TimerView | ✅ |
| 3 | 다른 앱 사용 시 즉시 정지, 강의 모드 토글 | BackgroundGuard 정책표 + GuardPolicy + 옵저버 5개 | ✅ |
| 4 | 배터리·데이터 최소화 | 옵저버 세션 라이프사이클 게이팅, GPS 적응형 정확도, LiveActivity OS 렌더 | ✅ |
| 5 | 친구와 같이 사용 | FriendsView + SocialService (mock, CloudKit wire 예정) | 🟢 PoC |
| 6 | 목표시간 달성 성취감 | Mascot 6단계 진화 + EvolutionRules | ✅ |
| 7 | 운동 + 러닝 km 측정 | RunningManager + CoreLocation + HealthService | ✅ |
| 8 | 셀로그 스타일 메시지 | CellogInboxView + CellogComposeSheet (응원/잔소리/익명) | ✅ |
| 9 | 메인화면 캐릭터 성장 (사람마다 다르게) | MascotAvatar + MascotSettingsView (5종 × 6단계) | ✅ placeholder |
| 10 | 사진 5 디자인 가중치 | DesignTokens 파랑 + 카드 + 그림자 + 마스코트 카드 | ✅ |
| 11 | 10분 블록 플래너 (사진 1) | BlockGridView 22h × 6열 wrap (05:00 → 02:50) | ✅ |

## 남은 미해결 사항

- **CloudKit wire (W3.D)**: SocialService 가 CloudKit Public/Private/Shared 로 동기화. App Store 가이드 1.2 신고/차단 처리 백오피스. 실기기 + Apple Developer Program 필요
- **미성년자 정책 (W3.E)**: 가입 연령 입력, 익명 송수신 차단, 욕설 필터
- **AI 마스코트 30컷**: 사용자가 외부 도구로 생성 후 Assets.xcassets 추가
- **LiveActivity / Widget 실기기 검증**: 시뮬레이터 자동 검증 한계
- **운동 종류 확장**: 걷기 / 자전거 / 헬스 / 자유 (현재는 러닝 한 종류)
- **백그라운드 GPS**: `allowsBackgroundLocationUpdates` + Always 권한 (러닝 화면 꺼져도 측정)
- **통계 화면**: 일/주/월 차트 (PLAN §6.6)

## 다음 권장 단계 (코덱스 토큰 복구 후)

1. 코덱스에 본 폴더 전체 (PLAN + W0~W5 보고서) 일괄 리뷰 의뢰
2. 우선순위:
   - **실기기 회귀 테스트** — 백그라운드 정지 4가지 신호 / LiveActivity / 위젯 / 러닝 GPS
   - **CloudKit wire** — 친구 기능 실사용 가능하게 만드는 결정적 단계
   - **미성년자 정책** — App Store 심사 통과를 위해 필수
   - **AI 마스코트 에셋** — 사용자 작업

---

🐙 Autopus
