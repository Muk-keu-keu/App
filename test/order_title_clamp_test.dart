import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/order.dart';

/// `POST v1/orders` 의 `source.title` 길이를 서버가 받을 수 있는 만큼으로 자른다.
///
/// 인스타 `og:title` 은 캡션 전문이라 600자를 넘기기 일쑤다. 그대로 보내면 서버가
/// 500 을 내고 **결제 자체가 불가능**했다. 유튜브는 제목이 짧아 멀쩡히 되는 탓에
/// 원인이 결제가 아니라 영상 쪽에 있다는 게 드러나지 않았다.
///
/// 실측한 경계: UTF-8 300바이트 통과 · 310바이트 실패.
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
      final long = '가' * 400; // 1200바이트
      final cut = OrderSource.clampTitle(long);

      expect(bytes(cut), lessThanOrEqualTo(OrderSource.titleMaxBytes));
      expect(cut.endsWith('…'), isTrue);
    });

    test('실제로 500 을 냈던 인스타 캡션이 통과 범위로 들어온다', () {
      const caption = '쎄럽 | 맛도리모음.ZIP on Instagram: "🐷주말 돼지파티🐷 하고싶을땐? '
          '꾸덕한 엽떡로제+교촌허콤이 진리,, 진짜 갓벽한 조합이다,, 안그래도 엽떡+허콤 조합은 '
          '진리였는데 엽떡로제랑 먹는게 이김,, 기본엽떡은 오리지널도 맵지만, 로제떡볶이는 '
          '그렇게까진 맵지않은 편이라 맵찔이들도 오리지널맛 가능. 치즈,소세지 추가는 다다익선!! '
          '바싹달콤한 허니콤보를 꾸덕꾸덕한 로제쏘스에 찍먹하면 너무 맛있어서 정신 아득해진다,, '
          '#쎄럽_배달 #엽떡 #동대문엽기떡볶이 #엽떡로제 #로제떡볶이 #교촌치킨';

      expect(bytes(caption), greaterThan(OrderSource.titleMaxBytes),
          reason: '이 캡션이 한계를 넘지 않으면 이 테스트가 무의미하다');
      expect(bytes(OrderSource.clampTitle(caption)),
          lessThanOrEqualTo(OrderSource.titleMaxBytes));
    });

    test('이모지를 반쪽으로 자르지 않는다', () {
      // 코드포인트 중간에서 끊으면 깨진 바이트가 남아 서버가 또 터진다.
      final long = '🐷' * 200;
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
        title: '가' * 400,
      );

      final wire = source.toJson();

      expect(bytes(wire['title'] as String),
          lessThanOrEqualTo(OrderSource.titleMaxBytes));
      // 화면에 그리는 원본은 그대로 들고 있는다.
      expect(source.title.length, 400);
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
