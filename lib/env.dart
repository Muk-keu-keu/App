import 'package:flutter_dotenv/flutter_dotenv.dart';

/// .env 에서 읽는 환경변수.
///
/// .env 는 커밋되지 않는다(.gitignore). 새로 받은 사람은 .env.example 을
/// .env 로 복사한 뒤 값을 채우면 된다. 값은 팀 채널로 따로 공유한다.
///
/// 주의: flutter_dotenv 는 .env 를 앱 번들 에셋으로 넣는다. 즉 배포된 앱을
/// 뜯으면 키를 볼 수 있다. 실제 서비스에서는 키를 서버에 두고 앱은 자사
/// 백엔드만 호출하도록 바꿔야 한다. 지금은 데모 단계라 이대로 둔다.
class Env {
  const Env._();

  static Future<void> load() => dotenv.load(fileName: '.env');

  /// 값 하나를 읽는다. **`load()` 전에 불려도 던지지 않는다.**
  ///
  /// `dotenv.env` 는 초기화 전에 접근하면 `NotInitializedError` 를 던진다.
  /// 단위 테스트는 에셋을 못 읽어 `load()` 를 부르지 않는데, [AppFlow] 생성자가
  /// [hasApiBaseUrl] 로 저장소를 고르기 때문에 그 자리에서 앱이 죽었다.
  /// 값이 없는 것과 아직 안 읽은 것을 같게 다루는 편이 안전하다 — 둘 다 "설정 없음" 이다.
  static String _read(String key) {
    try {
      return dotenv.env[key] ?? '';
    } on Object {
      return '';
    }
  }

  static String get geminiApiKey => _read('GEMINI_API_KEY');

  static String get openAiApiKey => _read('OPENAI_API_KEY');

  /// 구조화 출력을 지원하는 모델이면 무엇이든 된다. 비우면 어댑터 기본값을 쓴다.
  static String get openAiModel => _read('OPENAI_MODEL').trim();

  /// 백엔드 주소. `https://host` 또는 `http://192.168.0.10:8080`.
  ///
  /// 비어 있으면 앱이 더미 데이터로 돈다. 백엔드가 아직 없는 동안 시연이 멈추지
  /// 않게 하려는 것이고, 서버가 올라오면 이 값만 채우면 실제 API 를 쓴다.
  /// 자리표시자(`YOUR_`)가 들어와도 비어 있는 것으로 본다.
  static String get apiBaseUrl {
    final value = _read('API_BASE_URL').trim();
    return isUsableKey(value) ? value : '';
  }

  /// 실제 서버를 쓸 수 있는 상태인지.
  static bool get hasApiBaseUrl => apiBaseUrl.isNotEmpty;

  /// 발표 촬영 중 요기족보만 번들 데이터를 쓰는지.
  ///
  /// 실서버의 이미지 저장소가 잠시 멈춰도 홈·목록·상세의 발표 흐름은 이어져야 한다.
  /// `true` 일 때도 로그인·주문·분석은 실서버를 그대로 쓰고, 게시글 저장소만
  /// `MockPostRepository`로 바뀐다. 환경값을 끄면 코드 변경 없이 실서버로 돌아간다.
  static bool get usesDemoJokbo => isEnabled(_read('DEMO_JOKBO'));

  static bool isEnabled(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }

  /// 쓸 수 있는 키가 들어왔는지.
  ///
  /// **비어 있는지만 보면 안 된다.** `.env.example` 을 그대로 복사하면
  /// `GEMINI_API_KEY=YOUR_GEMINI_API_KEY` 가 들어가는데, 비어 있지 않아서 통과해
  /// 버린다. 그 상태로 빌드하면 Gemini 가 `400 API key not valid` 를 돌려주고
  /// 분석이 매번 실패한다. 실제로 TestFlight 빌드에서 이 일이 있었다.
  static bool get hasGeminiKey => isUsableKey(geminiApiKey);

  static bool get hasOpenAiKey => isUsableKey(openAiApiKey);

  /// 추출에 쓸 키가 하나라도 있는지. 둘 다 없으면 네트워크를 태울 필요가 없다.
  static bool get hasAiKey => hasOpenAiKey || hasGeminiKey;

  /// OpenAI 키가 있으면 그쪽을 쓴다.
  ///
  /// Gemini 무료 등급의 하루 20건 한도가 시연 도중 닫히는 일이 반복돼 우선순위를
  /// 이렇게 뒀다. `.env` 에서 `OPENAI_API_KEY` 를 지우면 그대로 Gemini 로 돌아간다.
  static bool get prefersOpenAi => hasOpenAiKey;

  /// 템플릿 값은 무효로 본다. `.env.example` 의 자리표시자는 `YOUR_` 로 시작한다.
  static bool isUsableKey(String key) {
    final value = key.trim();
    if (value.isEmpty) return false;
    if (value.startsWith('YOUR_')) return false;
    return true;
  }
}
