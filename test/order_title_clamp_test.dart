import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/order.dart';

/// `POST v1/orders` 의 `source.title` 길이를 서버가 받을 수 있는 만큼으로 자른다.
///
/// 인스타 `og:title` 은 캡션 전문이라 1000바이트를 넘기기 일쑤다. 서버 컬럼이
/// 300바이트뿐이던 때는 그대로 보내면 500 이 나 **결제 자체가 불가능**했다.
/// 유튜브는 제목이 짧아 멀쩡히 되는 탓에 원인이 결제가 아니라 영상 쪽에 있다는 게
/// 드러나지 않았다.
///
/// 2026-08-13 서버가 컬럼을 늘려 실제 캡션(978바이트)이 그대로 통과한다.
/// 자르는 것은 상한을 모르는 채 넘기지 않기 위해 넉넉한 값으로 남겨 뒀다.
void main() {
  int bytes(String s) => utf8.encode(s).length;

  group('clampTitle', () {
    test('짧은 제목은 그대로 둔다', () {
      const short = '소스 잔뜩 두찜 로제찜닭 #두찜 #로제찜닭';
      expect(OrderSource.clampTitle(short), short);
    });

    test('한계까지는 손대지 않는다', () {
      final exact = 'a' * OrderSource.titleMaxBytes;
      expect(OrderSource.clampTitle(exact), exact);
      expect(bytes(OrderSource.clampTitle(exact)), OrderSource.titleMaxBytes);
    });

    test('넘치면 한계 안으로 자르고 말줄임표를 붙인다', () {
      final long = '가' * 1000; // 3000바이트
      final cut = OrderSource.clampTitle(long);

      expect(bytes(cut), lessThanOrEqualTo(OrderSource.titleMaxBytes));
      expect(cut.endsWith('…'), isTrue);
    });

    test('실제 인스타 캡션은 이제 자르지 않는다', () {
      // 서버가 컬럼을 늘린 뒤(2026-08-13) 978바이트 캡션이 그대로 201 로 통과한다.
      // 자르면 주문내역·족보의 출처 제목이 근거 없이 뭉텅 잘린다.
      const caption = '쎄럽 | 맛도리모음.ZIP on Instagram: "🐷주말 돼지파티🐷 하고싶을땐? '
          '꾸덕한 엽떡로제+교촌허콤이 진리,, 진짜 갓벽한 조합이다,, 안그래도 엽떡+허콤 조합은 '
          '진리였는데 엽떡로제랑 먹는게 이김,, 기본엽떡은 오리지널도 맵지만, 로제떡볶이는 '
          '그렇게까진 맵지않은 편이라 맵찔이들도 오리지널맛 가능. 치즈,소세지 추가는 다다익선!! '
          '#쎄럽_배달 #엽떡 #동대문엽기떡볶이 #엽떡로제 #로제떡볶이 #교촌치킨';

      expect(bytes(caption), lessThanOrEqualTo(OrderSource.titleMaxBytes));
      expect(OrderSource.clampTitle(caption), caption);
    });

    test('한계를 넘는 제목은 여전히 자른다', () {
      // 상한이 어디인지 모르는 채로 넘기면, 더 긴 캡션이 나타나는 날 다시 500 을
      // 맞는다. 그때도 서버는 사유를 주지 않는다.
      final tooLong = '가' * 1000; // 3000바이트

      expect(bytes(tooLong), greaterThan(OrderSource.titleMaxBytes));
      expect(bytes(OrderSource.clampTitle(tooLong)),
          lessThanOrEqualTo(OrderSource.titleMaxBytes));
    });

    test('이모지를 반쪽으로 자르지 않는다', () {
      // 코드포인트 중간에서 끊으면 깨진 바이트가 남아 서버가 또 터진다.
      final long = '🐷' * 1000;
      final cut = OrderSource.clampTitle(long);

      expect(bytes(cut), lessThanOrEqualTo(OrderSource.titleMaxBytes));
      // 다시 인코딩·디코딩해도 같아야 한다 = 깨진 바이트가 없다.
      expect(utf8.decode(utf8.encode(cut)), cut);
    });
  });

  group('toJson', () {
    test('전송할 때 잘린 제목이 실린다', () {
      final source = OrderSource(
        platform: SourceKind.instagram,
        url: 'https://www.instagram.com/reel/DIBHSZrSkZe/',
        title: '가' * 1000,
      );

      final wire = source.toJson();

      expect(bytes(wire['title'] as String),
          lessThanOrEqualTo(OrderSource.titleMaxBytes));
      // 화면에 그리는 원본은 그대로 들고 있는다.
      expect(source.title.length, 1000);
    });

    test('긴 thumbnailUrl 은 자르지 않는다', () {
      // 396자 썸네일로도 서버가 201 을 줬다. 자르면 이미지가 깨진다.
      final thumb = 'https://scontent.cdninstagram.com/v/${'x' * 380}.jpg';
      final source = OrderSource(
        platform: SourceKind.instagram,
        url: 'https://x.com/a',
        thumbnailUrl: thumb,
        title: '짧은 제목',
      );

      expect(source.toJson()['thumbnailUrl'], thumb);
    });
  });
}
