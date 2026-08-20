import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';

/// 백엔드가 2026-08-13 에 보내 준 실제 응답. 계약이 바뀌면 여기서 먼저 깨진다.
const _real = r'''
{
  "summary": "영상 속 엽기떡볶이는 동대문엽기떡볶이 삼성점에서 그대로 시킬 수 있어요. 후라이드도 5곳에서 배달 가능해요.",
  "emptyReason": null,
  "exactMatches": [
    {
      "brandName": "엽기떡볶이",
      "restaurant": {
        "restaurantId": 800, "name": "동대문엽기떡볶이 삼성점", "foodCategory": "SNACK",
        "area": "잠실동", "address": "서울특별시 송파구 올림픽로 23", "rating": 4.8,
        "reviewCount": 1344, "etaMin": 21, "deliveryFee": 0, "minOrderPrice": 14000,
        "distanceKm": 1.29, "imageUrl": "https://example.com/a.png"
      },
      "items": [
        {
          "menuId": 80001, "name": "엽기떡볶이", "menuType": "MAIN", "price": 16000,
          "imageUrl": "https://example.com/b.png", "quantity": 1, "spiceLevel": "NONE",
          "spiceAdjustable": true, "selectedSpice": "MEDIUM", "options": [],
          "optionsPrice": 0, "lineTotal": 16000
        }
      ],
      "totalPrice": 16000,
      "tags": ["EXACT_MATCH"],
      "reason": "영상에 나온 그 지점이에요"
    }
  ],
  "dishResults": [
    {
      "dishName": "떡볶이",
      "candidates": [
        {
          "restaurant": {
            "restaurantId": 804, "name": "아딸 잠실점", "foodCategory": "SNACK",
            "area": "논현동", "address": "서울특별시 강남구 학동로 180", "rating": 4.7,
            "reviewCount": 824, "etaMin": 27, "deliveryFee": 2500, "minOrderPrice": 14000,
            "distanceKm": 2.41, "imageUrl": "https://example.com/a.png"
          },
          "item": {
            "menuId": 80402, "name": "밀떡볶이", "menuType": "MAIN", "price": 5000,
            "imageUrl": "https://example.com/b.png", "quantity": 1, "spiceLevel": "NONE",
            "spiceAdjustable": true, "selectedSpice": "MEDIUM", "options": [],
            "optionsPrice": 0, "lineTotal": 5000
          },
          "score": 0.62,
          "tags": ["TASTE_SIMILAR"],
          "reason": "영상 속 떡볶이와 가장 비슷해요"
        },
        {
          "restaurant": {
            "restaurantId": 801, "name": "신전떡볶이 코엑스점", "foodCategory": "SNACK",
            "area": "신천동", "address": "서울특별시 송파구 올림픽로 300", "rating": 4.7,
            "reviewCount": 964, "etaMin": 30, "deliveryFee": 1000, "minOrderPrice": 14000,
            "distanceKm": 3.84, "imageUrl": "https://example.com/a.png"
          },
          "item": {
            "menuId": 80101, "name": "신전떡볶이", "menuType": "MAIN", "price": 5000,
            "imageUrl": "https://example.com/b.png", "quantity": 1, "spiceLevel": "NONE",
            "spiceAdjustable": true, "selectedSpice": "MEDIUM", "options": [],
            "optionsPrice": 0, "lineTotal": 5000
          },
          "score": 0.62,
          "tags": [],
          "reason": null
        }
      ]
    }
  ]
}
''';

void main() {
  final result = AnalysisResult.fromJson(
    jsonDecode(_real) as Map<String, dynamic>,
  );

  test('summary 를 AI 추천 이유 본문으로 그대로 쓴다', () {
    expect(result.summary, startsWith('영상 속 엽기떡볶이는'));
    expect(result.reasonText(maxDeliveryMinutes: 40), result.summary);
    expect(result.emptyReason, isNull);
  });

  test('exactMatch 카드가 태그와 문구를 함께 받는다', () {
    final card = result.exactMatches.single;
    expect(card.brandName, '엽기떡볶이');
    expect(card.restaurant.name, '동대문엽기떡볶이 삼성점');
    expect(card.tags, ['EXACT_MATCH']);
    expect(card.reasonBullets, ['영상에 나온 그 지점이에요']);
    expect(card.items.single.lineTotal, 16000);
  });

  test('태그가 붙은 후보만 근거를 갖는다', () {
    final combos = result.combos;
    expect(combos, hasLength(2));

    final withTag = combos.firstWhere((c) => c.restaurant.restaurantId == 804);
    expect(withTag.reasonBullets, ['영상 속 떡볶이와 가장 비슷해요']);

    // 태그가 없는 후보다. 없는 근거를 지어내지 않는다.
    // 화면은 reasonBullets 가 비면 (?) 자체를 안 그린다 — 빈 창이 열리면 안 된다.
    final withoutTag = combos.firstWhere((c) => c.restaurant.restaurantId == 801);
    expect(withoutTag.tags, isEmpty);
    expect(withoutTag.reasonBullets, isEmpty);
  });
}
