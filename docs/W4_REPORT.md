# W4 진행 보고서 — 운동 / 러닝

> 작성일: 2026-05-14
> 작성자: Claude (Autopus)
> 검토 대상: Codex (보류, 일괄 리뷰)

## 산출물

```
StudyApp/
├── Health/HealthService.swift            HKHealthStore wrapper (auth + saveRunning)
├── Models/RunSessionModel.swift          SwiftData @Model + RunSession adapter
├── Features/Running/
│   ├── RunningManager.swift              @Observable, CLLocationManager + 적응형 정확도
│   └── RunningView.swift                 거리·경과·페이스 카드 + start/pause/end
└── Features/Timer/TimerView.swift        workout 카테고리 과목 선택 시 fullScreenCover로 RunningView
```

Schema 갱신: `AppModelContainer` 에 `RunSessionModel.self` 추가.
`Info.plist`: NSHealthShareUsageDescription, NSHealthUpdateUsageDescription, NSLocationWhenInUseUsageDescription, NSMotionUsageDescription 추가.

## 핵심 설계

| 항목 | 결정 |
|------|------|
| 카테고리 분기 | `Subject.category == .workout` 인 과목 선택 시 TimerView 가 `RunningView` 모달로 분기 (study 흐름과 완전 분리). 운동 시간은 RunSession 으로만 영속화 |
| 정확도 적응 | 시작 시 `kCLLocationAccuracyBestForNavigation`, 20초 이상 위치 변화 없으면 `kCLLocationAccuracyHundredMeters` 로 다운그레이드 (PLAN §13 배터리 절감) |
| 칼로리 추정 | MET 9.8 × 65kg × 시간(시) (PoC 근사. W5 폴리싱에서 사용자 몸무게 입력 옵션) |
| 폴리라인 | JSON `[lat, lon]` 배열 (PoC). Google polyline encoding 은 V2 |
| 백그라운드 | `allowsBackgroundLocationUpdates = false`. 러닝 화면 보이는 동안만 GPS. iPhone Lock 후 백그라운드 위치 기록은 W5 옵션 |

## 검증

- `swift test`: 45/45 통과 (코어 변경 없음)
- `xcodebuild ... build`: **BUILD SUCCEEDED**
- 시뮬레이터: 과목 리스트에서 운동 카테고리 시각 분리 확인 ([screenshot_w4_subjects.png](screenshots/screenshot_w4_subjects.png))

### 자동 검증 불가
- HealthKit 권한 다이얼로그 (`simctl io tap` 차단)
- 시뮬레이터 GPS — `Features → Location → Custom Location` 으로 위치 시뮬레이션 가능. 사용자 수동 검증 단계

## W5 / 후속 트랙으로 미룬 항목
- 운동 종류 분기 (걷기 / 자전거 / 헬스 / 자유) — 현재는 러닝 한 종류
- 백그라운드 GPS (`allowsBackgroundLocationUpdates`) + Always 권한
- 지도 폴리라인 (MapKit) — 현재는 숫자 카드만
- HealthKit 걸음수·칼로리 read fetch 후 홈 카드 표시
- 사용자 몸무게 프로필 → 정확한 칼로리

---

🐙 Autopus
