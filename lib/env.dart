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

  /// 키가 비어 있으면 분석이 실패한다. 실행 초기에 확인해 원인을 빨리 알 수 있게 한다.
  static bool get hasGeminiKey => geminiApiKey.isNotEmpty;
}
