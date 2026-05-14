# 실기기 테스트 가이드 (무료 Apple ID)

> 작성일: 2026-05-14
> 대상: iPhone 본체에 앱을 직접 설치해 테스트하는 단계

---

## 0. 준비물

- macOS + Xcode 26.5 이상 (이미 설치됨)
- 본인 Apple ID (App Store 로 로그인되어 있는 일반 계정이면 충분)
- iPhone (iOS 17 이상)
- USB-C → iPhone 케이블

**무료 계정으로 가능 / 불가능**

| 기능 | 무료 Apple ID | 비고 |
|------|--------------|------|
| 디데이·순공·플래너·식물·운동·러닝·통계 | ✅ | 단일 기기에서 전부 동작 |
| LiveActivity (잠금화면 타이머) | ✅ | |
| 홈스크린 위젯 (디데이·오늘·식물) | ✅ | App Group 자동 등록 |
| BackgroundGuard 4 옵저버 | ✅ | 실기기에서 실제 잠금/통화/Siri 검증 가능 |
| 백그라운드 GPS (러닝 잠금) | ✅ | Always 권한 받으면 동작 |
| HealthKit (러닝 → 건강 앱 저장) | ✅ | |
| 로컬 알림 (일일 reminder / 목표 달성) | ✅ | |
| 친구 / 그룹 채팅 다중 기기 동기화 | ❌ | CloudKit 필요 → Apple Developer Program ($99/년) 가입 후 |
| TestFlight 배포 | ❌ | 동일, 유료 가입 필요 |
| 무료 인증서 만료 | ⚠️ | **7일** 마다 재서명 필요 (Xcode 에서 다시 Run 누르면 자동) |

---

## 1. Xcode 에서 본인 Apple ID 추가

이미 했다면 건너뛰기.

1. Xcode 메뉴 → **Settings** → **Accounts** 탭
2. 왼쪽 하단 `+` → **Apple ID** 선택
3. 본인 Apple ID 로그인
4. 로그인 후 화면 우측에 본인 이름이 **Personal Team** 으로 나타나면 성공
5. 그 Team 클릭하면 우측에 **Team ID** (10자 영숫자) 가 보임. 메모해두기

---

## 2. 프로젝트 열기

```bash
open "/Users/j/Downloads/공부 어플/StudyApp.xcodeproj"
```

또는 Finder 에서 `StudyApp.xcodeproj` 더블클릭.

---

## 3. 두 타겟에 Team 선택

Xcode 좌측 Project navigator 에서 `StudyApp` (파란 아이콘) 클릭.

**StudyApp 타겟**:
1. 가운데 패널 위쪽에서 **Targets → StudyApp** 선택
2. 상단 탭 중 **Signing & Capabilities** 클릭
3. **Automatically manage signing** 체크 (이미 켜져 있으면 그대로)
4. **Team** 드롭다운에서 본인 Personal Team 선택
5. 잠시 후 "Signing for StudyApp requires a development team" 같은 빨간 줄이 사라지면 성공

**StudyWidgets 타겟** (동일 절차):
1. **Targets → StudyWidgets** 선택
2. **Signing & Capabilities** 탭
3. **Team** 드롭다운에서 본인 Personal Team 선택 (App 과 동일)

### 번들 ID 충돌이 뜨면

무료 계정은 같은 Bundle ID 를 한 번만 등록할 수 있습니다. 다음 중 하나로 회피:

- **권장**: 각 타겟 Bundle Identifier 를 본인만의 이름으로 변경
  - StudyApp: `co.<본인>.study`
  - StudyWidgets: `co.<본인>.study.widgets`
- 또는 `project.yml` 에서 `PRODUCT_BUNDLE_IDENTIFIER` 를 미리 본인 이름으로 변경 후 `xcodegen generate` 재실행

---

## 4. App Group 확인 (자동)

`StudyApp.entitlements` 에 `group.co.autopus.study` 가 들어있습니다. Xcode 자동 사이닝이 해당 App Group 을 본인 계정에 자동 등록합니다.

만약 빨간 줄이 뜨면:
1. StudyApp 타겟 → Signing & Capabilities → App Groups 섹션
2. `group.co.autopus.study` 가 비활성이면 옆 새로고침 아이콘 클릭
3. 그래도 안 되면 Group ID 를 `group.<본인-bundleID>` 형태로 변경

StudyWidgets 도 동일 그룹 ID 가 양쪽에 같이 체크되어 있어야 함.

---

## 5. iPhone 연결

1. USB 케이블로 iPhone 을 Mac 에 연결
2. iPhone 에서 "이 컴퓨터를 신뢰" 묻는 다이얼로그 → **신뢰** 탭
3. Xcode 상단 device 선택기 (Run 버튼 옆 시뮬레이터 이름) 클릭 → **연결된 본인 iPhone** 선택

---

## 6. 실행

1. Xcode 상단 ▶️ (Run) 클릭 또는 `⌘R`
2. 첫 실행 시 iPhone 에 "신뢰되지 않은 개발자" 알림이 뜨면:
   - iPhone 설정 → **일반** → **VPN 및 기기 관리** → 본인 Apple ID 선택 → **신뢰** 탭
3. 다시 Xcode 에서 Run

---

## 7. 권한 다이얼로그

앱이 실행되면 순서대로 다이얼로그가 뜸:

1. **위치 사용 (앱 사용 중)** — 운동 과목 선택 + 시작 시. **허용**
2. **위치 사용 (항상)** — 첫 권한 직후 또 묻기. **허용** 해야 백그라운드 GPS 동작
3. **건강 데이터 읽기/쓰기** — RunningView 진입 시. **모두 허용**
4. **알림** — onboarding 종료 후. **허용**

---

## 8. 시나리오 확인 체크리스트

기기에서 직접 만져볼 항목:

- [ ] 첫 실행 → 생년월일 입력 → 시작
- [ ] 홈 → 식물 카드에 줄기 1개 (영양분 0)
- [ ] 타이머 → 수학 선택 → 시작 → 잠금 (전원 버튼) → 5초 후 깨움 → 배너 "정지됨: 화면 잠금" 확인
- [ ] 타이머 시작 → Cmd+H 같은 동작 (홈 누름) → 다른 앱 → 돌아옴 → 배너 "정지됨: 다른 앱 사용 감지" 확인
- [ ] 강의 모드 켠 과목으로 시작 → 다른 앱 가도 정지 안 됨 확인
- [ ] 러닝 과목 선택 → 시작 → 야외에서 직접 1~2분 걷기 → 종료 → SummarySheet 에 거리 / 페이스 / 칼로리
- [ ] 건강 앱 열어서 운동 기록이 들어왔는지 확인
- [ ] 잠금화면에서 타이머 LiveActivity 노출 확인
- [ ] 홈스크린 길게 누름 → 위젯 추가 → "공부어플" 검색 → 디데이/오늘 순공/식물 위젯 추가
- [ ] 8시간 학습 → 플래너 탭에서 색 채워진 칸 확인
- [ ] 일일 목표 채운 후 → 식물 영양분 증가 + 알림 "오늘 목표 달성!"

---

## 9. 자주 막히는 곳

| 증상 | 해결 |
|------|------|
| "No code signing certificates found" | Xcode Settings → Accounts 에 본인 Apple ID 추가 여부 확인 |
| "Failed to register bundle identifier" | Bundle ID 가 다른 사용자에게 이미 등록됨. §3 의 "번들 ID 충돌" 절차로 ID 변경 |
| "Provisioning profile expired" | 7일 만료. Xcode 다시 Run 누르면 자동 재서명 |
| App Group 빨간 줄 | StudyApp + StudyWidgets 둘 다 같은 그룹 ID 가 체크되어 있어야 함 |
| LiveActivity 안 뜸 | iPhone 설정 → 공부어플 → Live Activities 켜져 있는지 |
| 위젯 데이터 안 보임 | 앱을 한 번 더 실행 → 학습 세션 종료 → 위젯이 동기화 받음 |

---

## 10. 7일 후 재서명

무료 인증서는 7일 후 만료. 다시 사용하려면:
1. iPhone 을 Mac 에 연결
2. Xcode 에서 Run 한 번 더
3. 자동으로 새 인증서 발급 + 앱 덮어쓰기

---

🐙 Autopus
