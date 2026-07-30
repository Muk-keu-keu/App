import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/env.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';

/// TestFlight 빌드에서 AI 분석이 매번 실패한 일이 있었다. 원인은 `.env.example` 을
/// 그대로 복사해 `GEMINI_API_KEY=YOUR_GEMINI_API_KEY` 가 앱에 번들된 것이었다.
/// 비어 있지 않아서 기존 검사(`isNotEmpty`)를 통과해 버렸다.
void main() {
  group('Env.isUsableKey — 템플릿 값을 걸러낸다', () {
    test('.env.example 의 자리표시자는 무효다', () {
      // 실제로 앱에 들어갔던 값
      expect(Env.isUsableKey('YOUR_GEMINI_API_KEY'), isFalse);
    });

    test('YOUR_ 로 시작하는 다른 자리표시자도 무효다', () {
      expect(Env.isUsableKey('YOUR_API_KEY_HERE'), isFalse);
      expect(Env.isUsableKey('YOUR_KEY'), isFalse);
    });

    test('비어 있거나 공백뿐이면 무효다', () {
      expect(Env.isUsableKey(''), isFalse);
      expect(Env.isUsableKey('   '), isFalse);
      expect(Env.isUsableKey('\n'), isFalse);
    });

    test('실제 키 형태는 유효하다', () {
      // Gemini 키는 AIza 로 시작하는 39자 문자열이다
      expect(Env.isUsableKey('AIzaSyD-1234567890abcdefghijklmnopqrstuv'), isTrue);
    });

    test('앞뒤 공백이 있어도 값이 있으면 유효하다', () {
      expect(Env.isUsableKey('  AIzaSyD-abc  '), isTrue);
    });

    test('키 안에 YOUR_ 가 들어 있는 건 막지 않는다', () {
      // 시작 위치만 본다. 정상 키를 실수로 막으면 더 나쁘다.
      expect(Env.isUsableKey('AIzaYOUR_KEY123'), isTrue);
    });
  });

  group('GeminiAuthException', () {
    test('상태코드를 들고 있고 원인이 메시지에 드러난다', () {
      const e = GeminiAuthException(400);
      expect(e.statusCode, 400);
      expect(e.toString(), contains('API 키'));
    });
  });
}
