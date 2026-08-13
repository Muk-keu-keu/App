import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

/// 위치를 묻지 않는다. 이 테스트는 공유 원문 처리만 본다.
class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 공유로 들어온 원문을 버리지 않는지 지킨다.
///
/// 인스타는 로그인 없이 캡션을 주지 않는다. 링크로 다시 요청하면 og 태그가
/// `Instagram / null` 뿐이라 추출이 0건이 되고, 그러면 카테고리 필터까지
/// 무력화돼(`withCategoryFilter` 는 기준이 없으면 통과시킨다) 서버가 추측한
/// 결과가 영상에서 읽은 것처럼 화면에 뜬다. 동파육 릴스에 탕수육이 뜬 게 그거다.
///
/// 공유 시점의 텍스트가 그 캡션을 얻을 수 있는 유일한 창이라 반드시 살려야 한다.
void main() {
  AppFlow makeFlow() => AppFlow(locationService: const _NoLocation());

  group('AppFlow.sharedCaption', () {
    test('링크를 걷어내고 캡션만 남긴다', () {
      final flow = makeFlow()
        ..start(
          'https://www.instagram.com/reels/DZwzHAeMfhi/',
          sharedText: '중국집에서 동파육 시켜먹었는데 껍질이 부들부들해요\n'
              'https://www.instagram.com/reels/DZwzHAeMfhi/',
        );

      expect(flow.sharedCaption, '중국집에서 동파육 시켜먹었는데 껍질이 부들부들해요');
    });

    test('링크만 공유되면 캡션은 없는 것으로 본다', () {
      // 여기서 부스러기라도 남기면 rawText 가 그럴듯해져, 서버에 "재수집이
      // 필요하다" 고 알리는 신호(AnalysisSource.isThin)까지 가려 버린다.
      final flow = makeFlow()
        ..start(
          'https://www.instagram.com/reels/DZwzHAeMfhi/',
          sharedText: 'https://www.instagram.com/reels/DZwzHAeMfhi/',
        );

      expect(flow.sharedCaption, isEmpty);
    });

    test('링크가 여러 개여도 전부 걷어낸다', () {
      final flow = makeFlow()
        ..start(
          'https://www.instagram.com/reels/abc/',
          sharedText: 'https://www.instagram.com/reels/abc/ 엽떡 먹방 '
              'https://link.example.com/x',
        );

      expect(flow.sharedCaption, '엽떡 먹방');
    });

    test('공유가 아니면 캡션이 비어 있다', () {
      final flow = makeFlow()..start('https://www.instagram.com/reels/abc/');

      expect(flow.sharedCaption, isEmpty);
    });

    test('새 링크를 시작하면 이전 캡션이 따라오지 않는다', () {
      // 앞 분석의 캡션이 남으면 다음 영상의 결과가 엉뚱해진다.
      final flow = makeFlow()
        ..start('https://www.instagram.com/reels/a/', sharedText: '동파육 먹었어요 링크')
        ..start('https://www.instagram.com/reels/b/');

      expect(flow.sharedCaption, isEmpty);
    });
  });

  group('AnalysisSource.isThin — 서버 재수집 신호', () {
    test('캡션이 붙으면 더 이상 빈약하지 않다', () {
      const thin = AnalysisSource(
        url: 'https://www.instagram.com/reels/x/',
        platform: SourcePlatform.instagram,
        rawText: 'Instagram\nInstagram',
        title: '',
      );
      expect(thin.isThin, isTrue);

      const withCaption = AnalysisSource(
        url: 'https://www.instagram.com/reels/x/',
        platform: SourcePlatform.instagram,
        rawText: 'Instagram\nInstagram\n중국집에서 동파육 시켜먹었는데 껍질이 부들부들해요',
        title: '',
      );
      expect(withCaption.isThin, isFalse);
    });
  });
}
