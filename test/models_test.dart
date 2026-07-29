import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_builder.dart';
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

  group('ComboBuilder — 추출 결과가 화면에 반영된다', () {
    ExtractionResult chicken() => const ExtractionResult(
          restaurantName: '교촌치킨 강남점',
          foodCategory: '치킨',
          area: '강남',
          menu: '레드콤보, 허니콤보',
          confidence: 0.9,
        );

    List<ComboRecommendation> build({
      ExtractionResult? extraction,
      String? thumbnailUrl,
      TastePreference? preference,
    }) =>
        ComboBuilder.build(
          extraction: extraction ?? chicken(),
          thumbnailUrl: thumbnailUrl,
          preference: preference ?? TastePreference(),
        );

    test('추출한 매장 이름이 그대로 나온다', () {
      expect(build().first.store.name, '교촌치킨 강남점');
    });

    test('추출한 메뉴가 조합에 담긴다', () {
      final names = build().first.items.map((e) => e.name).toList();
      expect(names, contains('레드콤보'));
      expect(names, contains('허니콤보'));
    });

    test('음식 종류별 사이드가 붙는다', () {
      final names = build().first.items.map((e) => e.name).toList();
      expect(names.any((n) => n.contains('감자튀김')), isTrue);
    });

    test('다른 영상이면 다른 매장이 나온다', () {
      final chinese = build(
        extraction: const ExtractionResult(
          restaurantName: '홍콩반점 성수점',
          foodCategory: '중식',
          area: '성수동',
          menu: '짜장면, 탕수육',
          confidence: 0.9,
        ),
      );
      expect(chinese.first.store.name, isNot(build().first.store.name));
      expect(chinese.first.items.first.name, '짜장면');
    });

    test('썸네일이 매장과 첫 메뉴에 쓰인다', () {
      const url = 'https://example.com/reel.jpg';
      final combos = build(thumbnailUrl: url);
      expect(combos.first.store.imageUrl, url);
      expect(combos.first.items.first.imageUrl, url);
    });

    test('1인 모드는 메인 메뉴를 하나로 줄인다', () {
      final combos = build(preference: TastePreference(mode: ServingMode.solo));
      expect(combos.first.items.length, 2); // 메인 1 + 사이드 1
      expect(combos.first.items.first.name, '레드콤보');
    });

    test('상호명을 못 찾으면 지역과 종류로 이름을 만든다', () {
      final combos = build(
        extraction: const ExtractionResult(
          restaurantName: '',
          foodCategory: '치킨',
          area: '강남',
          menu: '',
          confidence: 0.4,
        ),
      );
      expect(combos.first.store.name, '강남 치킨 맛집');
    });

    test('가격은 500원 단위로 끊긴다', () {
      for (final item in build().first.items) {
        expect(item.unitPrice % 500, 0, reason: '\${item.name} = \${item.unitPrice}');
      }
    });

    test('같은 입력이면 항상 같은 결과가 나온다', () {
      final a = build().first;
      final b = build().first;
      expect(a.store.rating, b.store.rating);
      expect(a.store.deliveryMinutes, b.store.deliveryMinutes);
      expect(a.itemsTotal, b.itemsTotal);
    });

    test('첫 결과의 유사도가 가장 높다', () {
      final combos = build();
      expect(combos.length, greaterThan(1));
      for (var i = 1; i < combos.length; i++) {
        expect(combos[i].store.similarity, lessThan(combos.first.store.similarity));
      }
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
