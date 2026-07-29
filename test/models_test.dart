import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/metadata_fetcher.dart';

void main() {
  group('wonFormat', () {
    test('세 자리마다 쉼표를 넣는다', () {
      expect(wonFormat(0), '0');
      expect(wonFormat(2000), '2,000');
      expect(wonFormat(23000), '23,000');
      expect(wonFormat(1234567), '1,234,567');
    });
  });

  group('ComboItem', () {
    test('lineTotal 은 단가 곱하기 수량이다', () {
      final item = ComboItem(
        id: 'a',
        name: '치즈볼',
        options: '',
        unitPrice: 2000,
        quantity: 2,
        imagePath: '',
      );
      expect(item.lineTotal, 4000);
    });
  });

  group('StoreSummary', () {
    StoreSummary store(int minutes) => StoreSummary(
          id: 'x',
          name: 'x',
          rating: 4.2,
          reviewCount: 312,
          distanceKm: 3.2,
          deliveryMinutes: minutes,
          imagePath: '',
          minimumOrderAmount: 0,
          deliveryFee: 0,
          similarity: 1,
        );

    test('60분 미만은 분으로 표시한다', () {
      expect(store(40).deliveryText, '40분');
    });

    test('60분 이상은 시간으로 표시한다', () {
      expect(store(60).deliveryText, '1시간');
      expect(store(70).deliveryText, '1시간 10분');
    });

    test('평점·거리 표기', () {
      expect(store(40).ratingText, '4.2/5 (312)');
      expect(store(40).distanceText, '3.2 km');
    });
  });

  group('ComboRecommendation', () {
    test('Figma 시안 금액이 맞아떨어진다 (27,000 + 배달팁 1,500 = 28,500)', () async {
      final combos = await const MockComboRepository()
          .recommend(extractedText: '', preference: TastePreference());
      final first = combos.first;

      expect(first.store.name, '두찜-잠실새내점');
      expect(first.itemsTotal, 27000);
      expect(first.payableTotal, 28500);
    });

    test('도착 시간 조건으로 걸러낸다', () async {
      final pref = TastePreference(maxDeliveryMinutes: 40);
      final combos = await const MockComboRepository()
          .recommend(extractedText: '', preference: pref);

      expect(combos.every((c) => c.store.deliveryMinutes <= 40), isTrue);
    });
  });

  group('GeminiExtractor.parseResponse', () {
    test('앞뒤 잡음이 있어도 JSON 을 뽑아낸다', () {
      final result = GeminiExtractor.parseResponse(
        '```json\n{"restaurantName":"교촌치킨 강남점","foodCategory":"치킨",'
        '"area":"강남","menu":"레드콤보","confidence":0.9}\n```',
      );
      expect(result.restaurantName, '교촌치킨 강남점');
      expect(result.foodCategory, '치킨');
      expect(result.confidence, 0.9);
    });
  });

  group('MetadataFetcher', () {
    test('og 태그를 파싱한다', () {
      const html = '<meta property="og:title" content="로제 닭발 먹방">'
          '<meta property="og:description" content="두찜 잠실새내점">';
      final meta = MetadataFetcher.parseOgTags(html);
      expect(meta.title, '로제 닭발 먹방');
      expect(meta.description, '두찜 잠실새내점');
    });

    test('인스타 og:url 에서 계정명을 뽑는다', () {
      const html = '<meta property="og:url" content="https://www.instagram.com/udtmukbang/reel/x/">';
      expect(MetadataFetcher.instagramHandle(html), 'udtmukbang');
    });

    test('예약어 경로는 계정명이 아니다', () {
      const html = '<meta property="og:url" content="https://www.instagram.com/reel/abc/">';
      expect(MetadataFetcher.instagramHandle(html), isNull);
    });

    test('HTML 엔티티를 되돌린다', () {
      expect(MetadataFetcher.decodeEntities('A&amp;B &quot;C&quot;'), 'A&B "C"');
    });
  });
}
