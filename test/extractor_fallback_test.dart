import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/services/extraction.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 정해 둔 대로 성공하거나 던지는 추출기. 호출 횟수를 센다.
class _FakeExtractor implements DishExtractor {
  _FakeExtractor.ok(this.name, this.dish) : error = null;
  _FakeExtractor.fails(this.name, this.error) : dish = null;

  final String name;
  final String? dish;
  final Object? error;
  int calls = 0;

  @override
  Future<ExtractionResult> extract(String text) async {
    calls++;
    if (error != null) throw error!;
    return ExtractionResult(dishes: [ExtractedDish(name: dish!)]);
  }
}

/// 한쪽 제공자가 닫혀도 시연이 멈추지 않아야 한다.
///
/// Gemini 무료 등급은 모델·프로젝트당 하루 20건이라 준비 중에 닫힌다. 그 상태로
/// 빌드된 앱은 무엇을 해도 "오늘 AI 분석 사용량을 다 썼어요" 만 띄웠다.
void main() {
  AppFlow makeFlow() => AppFlow(locationService: const _NoLocation());

  test('앞쪽이 한도로 닫히면 다음 제공자로 넘어간다', () async {
    final first = _FakeExtractor.fails(
      'openai',
      const ExtractorQuotaException(429, 'quota', isDaily: true),
    );
    final second = _FakeExtractor.ok('gemini', '동파육');
    final flow = makeFlow()..extractorsOverride = [first, second];

    final (result, fatal) = await flow.extractWithFallback('동파육 먹방');

    expect(result?.dishes.single.name, '동파육');
    expect(fatal, isNull);
    // 한도는 재시도 대상이 아니다. 한 번 더 부르면 남은 몫만 태운다.
    expect(first.calls, 1);
    expect(second.calls, 1);
  });

  test('첫 제공자가 되면 두 번째는 부르지 않는다', () async {
    final first = _FakeExtractor.ok('openai', '마라탕');
    final second = _FakeExtractor.ok('gemini', '탕수육');
    final flow = makeFlow()..extractorsOverride = [first, second];

    final (result, _) = await flow.extractWithFallback('마라탕 먹방');

    expect(result?.dishes.single.name, '마라탕');
    expect(second.calls, 0);
  });

  test('전부 한도면 마지막 이유를 들고 나온다', () async {
    // 이유를 잃으면 화면이 "잠시 후 다시 시도" 로만 뜬다. 하루 한도는 잠시
    // 후에도 안 열리므로 계속 누르게 만든다.
    final flow = makeFlow()
      ..extractorsOverride = [
        _FakeExtractor.fails('openai',
            const ExtractorQuotaException(429, 'rate limit', isDaily: false)),
        _FakeExtractor.fails('gemini',
            const ExtractorQuotaException(429, 'daily quota', isDaily: true)),
      ];

    final (result, fatal) = await flow.extractWithFallback('떡볶이');

    expect(result, isNull);
    expect(fatal, isA<ExtractorQuotaException>());
    expect((fatal as ExtractorQuotaException).isDaily, isTrue);
  });

  test('키가 거부되면 그 제공자만 접고 다음으로 넘어간다', () async {
    final first = _FakeExtractor.fails('openai', const ExtractorAuthException(401));
    final second = _FakeExtractor.ok('gemini', '치킨');
    final flow = makeFlow()..extractorsOverride = [first, second];

    final (result, fatal) = await flow.extractWithFallback('치킨 먹방');

    expect(result?.dishes.single.name, '치킨');
    expect(fatal, isNull);
    // 키 문제는 재시도해도 같은 결과다.
    expect(first.calls, 1);
  });

  test('요청이 잘못됐으면 다음 제공자로 넘기지 않는다', () async {
    // 같은 요청을 그대로 보낼 것이라 결과가 같다. 고칠 곳은 우리 코드다.
    final first =
        _FakeExtractor.fails('openai', const ExtractorRequestException(400, '스키마 오류'));
    final second = _FakeExtractor.ok('gemini', '피자');
    final flow = makeFlow()..extractorsOverride = [first, second];

    final (result, fatal) = await flow.extractWithFallback('피자');

    expect(result, isNull);
    expect(fatal, isA<ExtractorRequestException>());
    expect(second.calls, 0);
  });

  test('네트워크 실패는 한 번 재시도하고 다음 제공자로 넘어간다', () async {
    final first = _FakeExtractor.fails('openai', Exception('timeout'));
    final second = _FakeExtractor.ok('gemini', '초밥');
    final flow = makeFlow()..extractorsOverride = [first, second];

    final (result, _) = await flow.extractWithFallback('초밥');

    expect(result?.dishes.single.name, '초밥');
    expect(first.calls, 2);
  });

  test('쓸 제공자가 없으면 이유 없이 실패한다', () async {
    final flow = makeFlow()..extractorsOverride = [];

    final (result, fatal) = await flow.extractWithFallback('떡볶이');

    expect(result, isNull);
    expect(fatal, isNull);
  });
}
