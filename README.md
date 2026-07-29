# 먹방 따라담기 🍜

인스타그램 릴스에서 본 먹방 조합을, **공유 버튼 한 번**으로 요기요 주문까지 이어주는 앱.
요기요 아이디어 공모전 출품작. Flutter 로 iOS·안드로이드를 함께 지원한다.

## 어떻게 동작하나

1. 인스타 릴스에서 **공유 → 먹방 따라담기**
2. 취향 설정 (1인/헬시플레저 모드, 맵기, 도착 시간)
3. 링크의 제목·설명·썸네일 수집 → **Gemini 가 음식점·음식종류·지역·메뉴 추출**
4. 추출 결과로 조합 구성 → 매장 카드와 메뉴를 보여주고 요기요로 연결

## 시작하기

```bash
# 1) 환경변수 파일 만들기 (커밋되지 않음)
cp .env.example .env
#    .env 의 GEMINI_API_KEY 에 실제 키를 넣는다. 값은 팀 채널에서 공유.

# 2) 의존성 설치
flutter pub get

# 3) 실행
flutter run
```

Gemini 키는 [aistudio.google.com/apikey](https://aistudio.google.com/apikey) 에서 무료로 발급받을 수 있다.

## 요구사항

- Flutter 3.44 이상 (Dart 3.12)
- iOS: Xcode 26 이상
- 안드로이드: compileSdk 37 (`receive_sharing_intent` 요구사항)

## 프로젝트 구조

```
lib/
  main.dart              앱 진입점. 공유 링크 수신과 화면 전환
  app_flow.dart          상태관리(ChangeNotifier). 분석 파이프라인
  env.dart               .env 접근
  models/                도메인 모델 (= 백엔드 API 스키마 초안)
  services/              Gemini 호출, 링크 메타데이터 수집
  repository/            조합 추천 데이터 소스
  screens/               화면 6개 + 시트 2개
  widgets/               공용 위젯
```

## 공유 시트 수신

플랫폼마다 경로가 다르다.

| | 방식 |
|---|---|
| **안드로이드** | `AndroidManifest.xml` 의 `ACTION_SEND` intent-filter → `MainActivity` 직접 실행 |
| **iOS** | Swift Share Extension(`ios/ShareExtension/`) → `mukbang://analyze?u=<링크>` → `app_links` 수신 |

iOS 는 익스텐션이 본체 앱을 직접 실행할 수 없어, 응답자 체인에서
`openURL:options:completionHandler:` 를 찾아 호출한다. 구형 `openURL:` 은 iOS 10 에서
폐기돼 `respondsToSelector` 는 true 를 주지만 실제로는 아무 동작도 하지 않는다.

## 백엔드 연동 지점

현재 조합 추천은 `ComboBuilder` 가 AI 추출 결과로 만들어 낸다.
**가격·평점·거리·배달시간은 실제 데이터가 아니라 추정치다.**

서버가 준비되면 `ComboRepository` 구현체만 갈아끼우면 화면 코드는 그대로다.

```dart
abstract class ComboRepository {
  Future<List<ComboRecommendation>> recommend({
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  });

  Future<List<MenuItem>> menu(String storeId);   // GET /stores/{id}/menu
}
```

`lib/models/combo.dart` 의 `StoreSummary` / `ComboItem` / `MenuItem` 이 곧 응답 스키마
초안이다. API 설계 시 이 구조를 기준으로 맞추면 클라이언트 수정이 최소화된다.

이미지 필드는 `imagePath`(번들 에셋)와 `imageUrl`(원격)이 함께 있다.
지금 `imageUrl` 에는 공유된 게시물의 `og:image` 가 들어가고, API 연동 후엔 서버가 준
URL 로 바뀐다. 화면 코드는 이미 `imageUrl` 을 우선 사용한다.

## 테스트

```bash
flutter test
```

## 알아둘 점

- `.env` 는 `flutter_dotenv` 특성상 앱 번들 에셋으로 들어간다. 배포된 앱을 뜯으면
  키가 보인다. 실제 서비스에서는 Gemini 호출을 백엔드로 옮겨야 한다.
- 폰트는 Pretendard(SIL OFL). `assets/fonts/OFL.txt` 에 라이선스 원문이 있다.
