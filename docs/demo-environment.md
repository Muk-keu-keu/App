# 기기 시연 및 테스트 환경

iOS·Android 실기기와 에뮬레이터에서 앱을 빌드·설치·시연하는 절차.

---

## 대상 환경

| 구분 | 기기 | 비고 |
|---|---|---|
| iOS 실기기 | iPhone 13 Pro Max (iOS 26.2.1) | UDID `00008110-000259A2367A801E`. 개발자 계정에 등록됨 |
| iOS 시뮬레이터 | iPhone 17 Pro (iOS 26.5) | 공유 익스텐션·위치 동작 확인 가능 |
| Android 에뮬레이터 | Pixel7_API34 (Android 14) | 공유 인텐트 주입으로 분석 플로우 테스트 가능 |
| Android 실기기 | 미정 | USB 디버깅 켜고 연결하면 APK 바로 설치 |

Apple 팀 ID `GB6X5JBK3Q` · iOS 번들 `com.yunsu.mukbang` · 공유 익스텐션 `com.yunsu.mukbang.share`
Android 패키지 `com.yunsu.mukbang_ttaradamgi`

---

## 사전 준비 (최초 1회)

**1. 저장소 클론 후 `.env` 생성**

```bash
cp .env.example .env
```

`OPENAI_API_KEY` 에 실제 키를 채운다. 값은 팀 채널에서 공유한다.
**자리표시자(`YOUR_OPENAI_API_KEY`)를 그대로 두면 AI 분석이 매번 실패한다.**
앱이 이 상태를 감지해 안내하지만 빌드 전에 확인하는 편이 빠르다.

`GEMINI_API_KEY` 도 그대로 쓸 수 있다. 둘 다 있으면 OpenAI 를 쓰고,
`OPENAI_API_KEY` 를 비우면 Gemini 로 돌아간다. Gemini 무료 등급은 모델·프로젝트당
**하루 20건**이라 시연 준비 중에 닫히므로 기본을 OpenAI 로 둔다.

모델은 `OPENAI_MODEL` 로 바꾼다. 비우면 `gpt-4.1-mini` 를 쓰고, 구조화
출력(`response_format: json_schema`)을 지원하는 모델이어야 한다.

**2. 의존성 설치**

```bash
flutter pub get
```

**3. Xcode 로그인** (iOS 배포·TestFlight 에만 필요)

Xcode → Settings → Accounts → 팀 `GB6X5JBK3Q` Apple ID 추가.
로그인하지 않으면 배포용 인증서가 없어 TestFlight 업로드가 실패한다.

**4. 새 iOS 실기기를 추가할 경우**

Apple Developer 계정에 해당 기기 UDID 를 등록해야 개발 빌드가 설치된다.

---

## 배포 경로 3가지

### A. Android — APK 직접 설치 (가장 빠름)

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

`adb` 가 PATH 에 없으면 전체 경로를 쓴다.

```bash
~/Library/Android/sdk/platform-tools/adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### B. iOS — 개발 빌드 직접 설치 (로그인 불필요)

등록된 기기에만 설치된다. TestFlight 심사·업로드 없이 즉시 확인할 때 쓴다.

```bash
flutter build ipa
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Runner.xcarchive \
  -exportOptionsPlist scripts/ExportOptions-dev.plist \
  -exportPath build/ios/ipa-dev \
  -allowProvisioningUpdates

xcrun devicectl device install app \
  --device 00008110-000259A2367A801E \
  build/ios/ipa-dev/mukbang_ttaradamgi.ipa
```

`flutter build ipa` 는 archive 생성 후 App Store 용 IPA 내보내기를 시도하다 실패하는데,
archive 자체는 정상 생성되므로 위 `-exportArchive` 로 개발용 IPA 를 따로 만든다.

### C. iOS — TestFlight (팀 전체 배포)

Xcode 로그인이 되어 있어야 한다.

```bash
flutter build ipa
open build/ios/archive/Runner.xcarchive
```

Organizer → `Distribute App` → `App Store Connect` → `Upload`

**업로드 전 `pubspec.yaml` 의 빌드 번호를 올린다.** 같은 번호는 중복으로 거절된다.

```yaml
version: 1.1.0+3   # 업로드할 때마다 +1
```

본체와 공유 익스텐션의 빌드 번호가 일치해야 한다(Flutter 가 자동으로 맞춘다).

---

## 시연 전 점검

```bash
flutter analyze   # 에러 0
flutter test      # 전부 통과
```

**양 플랫폼에 모두 다시 설치한다.** 한쪽만 설치하면 다른 쪽에 이전 빌드가 남아
시연 중 다른 동작을 보인다.

설치 후 확인할 항목

| 항목 | 확인 방법 |
|---|---|
| 앱 표시 이름 | 홈 화면 아이콘이 `먹방요기` |
| 공유 시트 노출 | 인스타·유튜브에서 공유 → 목록에 `먹방요기` |
| 위치 수집 | 로그인 직후 권한 팝업 → 허용 시 상단 바에 동네 이름(`강남구 역삼동`) |
| AI 분석 | 릴스 공유 → 조합 결과 화면 도달 |
| 요기족보 | 홈 → 요기족보 → 목록·상세·주문하기 |

---

## 시연 위치 조정

시연용 매장 데이터가 강남·용산 기준이라 다른 장소에서 리허설하면 결과가 비어 보인다.
디버그 빌드에서 좌표를 강제로 지정할 수 있다.

상단 위치 바 → 주소 입력 시트 → `DEBUG · 위치 지정` → `강남역` / `용산역` / `잠실새내역`

릴리즈 빌드에서는 이 UI 가 컴파일 단계에서 제외된다.

---

## 에뮬레이터에서 공유 플로우 테스트

실기기 없이 공유 → 분석 흐름을 확인할 때 사용한다.

```bash
adb shell am start -a android.intent.action.SEND -t text/plain \
  --es android.intent.extra.TEXT "https://www.youtube.com/watch?v=..." \
  -n com.yunsu.mukbang_ttaradamgi/.MainActivity
```

---

## 알려진 제약

| 제약 | 영향 | 대응 |
|---|---|---|
| Android 에뮬레이터의 가상 GPS 가 앱에 좌표를 전달하지 못함 | 에뮬레이터에서 위치 수집 실패 | 실기기 또는 디버그 위치 지정 사용 |
| iOS 시뮬레이터는 권한 팝업을 CLI 로 조작 불가 | 자동화된 위치 테스트 불가 | 수동 확인 |
| iOS 개발 빌드는 등록된 UDID 기기에만 설치 | 미등록 기기 설치 불가 | 개발자 계정에 UDID 등록 또는 TestFlight |
| 런치 이미지가 Flutter 기본값 | 앱 시작 시 흰 화면이 잠깐 노출 | 디자인 에셋 반영 필요 |
