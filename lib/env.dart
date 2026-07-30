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

  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  /// 쓸 수 있는 키가 들어왔는지.
  ///
  /// **비어 있는지만 보면 안 된다.** `.env.example` 을 그대로 복사하면
  /// `GEMINI_API_KEY=YOUR_GEMINI_API_KEY` 가 들어가는데, 비어 있지 않아서 통과해
  /// 버린다. 그 상태로 빌드하면 Gemini 가 `400 API key not valid` 를 돌려주고
  /// 분석이 매번 실패한다. 실제로 TestFlight 빌드에서 이 일이 있었다.
  static bool get hasGeminiKey => isUsableKey(geminiApiKey);

  /// 템플릿 값은 무효로 본다. `.env.example` 의 자리표시자는 `YOUR_` 로 시작한다.
  static bool isUsableKey(String key) {
    final value = key.trim();
    if (value.isEmpty) return false;
    if (value.startsWith('YOUR_')) return false;
    return true;
  }
}
