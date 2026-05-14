# W5 진행 보고서 — 마스코트 시스템 폴리싱

> 작성일: 2026-05-14
> 작성자: Claude (Autopus)
> 검토 대상: Codex (보류, 일괄 리뷰)

## 0. 요약

AI 일러스트 30컷은 외부 도구 의존이라 PoC 단계에서는 **SF Symbol 기반 placeholder 시스템을 정돈**하고, **종 / 이름 변경 설정 UI** 를 추가. AI 에셋 통합 시 `Image(systemName:)` 분기 한 곳만 `Image("Mascot/<species>/<stage>")` 로 교체하면 됨.

## 신규 / 변경 산출물

```
StudyApp/Features/Mascot/
├── MascotAvatar.swift           종 × 단계 (6단계) placeholder 매핑 + 종별 액센트 컬러
└── MascotSettingsView.swift     종 선택 그리드 + 이름 변경 + EXP/다음 단계 카드

StudyApp/Features/Home/
├── HomeView.swift               MascotAvatar 중복 제거 (Features/Mascot 로 이동)
└── RootView.swift               더보기 메뉴에 "마스코트" NavigationLink 추가
```

## 핵심 결정

| 항목 | 결정 |
|------|------|
| placeholder 매핑 | 5종 × 6단계 = 30개 SF Symbol 매핑 테이블. egg 단계 (`circle.dashed`) 와 final 단계 (`star.fill`) 공통, 중간 단계는 종별 분기 |
| 종별 액센트 | rabbit 파랑 / fox 주황 / bear 회색 / cat 보라 / dragon 빨강 |
| EXP 표시 | 현재 단계 + 다음 단계까지 남은 EXP. 최종 진화 시 "최종 진화 완료" |
| 종 변경 UX | 그리드 5개. 탭 시 draft 변경, 저장 버튼으로 commit. 진화 단계는 EXP 기반이라 종 변경해도 stage 유지 |
| Asset Catalog 구조 | 실제 30컷 추가 시 `Assets.xcassets/Mascot/<species>/stage<N>.imageset` 패턴 (실제 에셋은 사용자 작업 — MidJourney·DALL-E 등) |

## 검증

- `swift test`: 45/45 통과
- `xcodebuild`: BUILD SUCCEEDED
- 시뮬레이터: 홈 화면 마스코트 placeholder 정상 ([screenshot_w5_home.png](screenshots/screenshot_w5_home.png)). 더보기 → 마스코트에서 5종 그리드 + EXP 카드 확인 가능

## 후속 (사용자 작업)

1. AI 도구 (MidJourney / DALL-E / Stable Diffusion) 로 30컷 일러스트 생성
   - 종 5개 × 단계 6개 (egg → sprout → child → teen → adult → final)
   - 일관된 화풍, 정사각 1:1, 투명 배경, 1024px+
2. `StudyApp/Assets.xcassets` 에 `Mascot/<species>/stage<N>` 폴더 구조로 import
3. `MascotAvatar` 의 `Image(systemName:)` 분기를 `Image("Mascot/\(species.rawValue)/stage\(stage)")` 로 교체

---

🐙 Autopus
