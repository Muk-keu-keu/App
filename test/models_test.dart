import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
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

  group('CartLine — 명세의 금액 계산', () {
    CartLine line({
      int price = 2000,
      int quantity = 2,
      List<MenuOption> options = const [],
    }) =>
        CartLine(
          menuId: 1,
          name: '치즈볼',
          menuType: MenuType.side,
          price: price,
          quantity: quantity,
          options: options,
        );

    test('옵션이 없으면 lineTotal 은 정가 × 수량', () {
      expect(line().lineTotal, 4000);
    });

    test('optionsPrice 는 체크된 옵션만 더한다', () {
      final l = line(options: const [
        MenuOption(name: '분모자', price: 2000, selected: true),
        MenuOption(name: '납작당면', price: 3000),
      ]);
      expect(l.optionsPrice, 2000);
      // (2000 + 2000) × 2
      expect(l.lineTotal, 8000);
    });

    test('applySelection 이 체크 상태를 갈아끼운다', () {
      final l = line(options: const [
        MenuOption(name: '분모자', price: 2000, selected: true),
        MenuOption(name: '치즈 추가', price: 1000),
      ]);
      l.applySelection([l.options[1]]);

      expect(l.selectedOptions.map((o) => o.name), ['치즈 추가']);
      expect(l.optionsPrice, 1000);
    });

    test('주문 요청은 menuName·unitPrice 로 이름이 바뀐다', () {
      final json = line(
        options: const [MenuOption(group: '사리 추가', name: '분모자', price: 2000, selected: true)],
      ).toOrderJson();

      expect(json['menuName'], '치즈볼');
      expect(json['unitPrice'], 2000);
      expect(json['optionsPrice'], 2000);
      expect(json['lineTotal'], 8000);
      // 고른 것만 담고, group 은 없으면 null 로 키를 남긴다.
      expect(json['selectedOptions'], [
        {'group': '사리 추가', 'name': '분모자', 'price': 2000},
      ]);
    });
  });

  group('Restaurant', () {
    Restaurant store(int eta, {int? reviewCount}) => Restaurant(
          restaurantId: 1,
          name: 'x',
          foodCategory: FoodCategory.korean,
          area: '성수동',
          rating: 4.2,
          reviewCount: reviewCount,
          etaMin: eta,
          deliveryFee: 0,
          minOrderPrice: 0,
          distanceKm: 3.2,
        );

    test('60분 미만은 분으로 표시한다', () {
      expect(store(40).etaText, '40분');
    });

    test('60분 이상은 시간으로 표시한다', () {
      expect(store(60).etaText, '1시간');
      expect(store(70).etaText, '1시간 10분');
    });

    test('리뷰 수가 없으면 평점만 보여준다', () {
      // API 응답에 reviewCount 가 없다. (0) 으로 그리면 "리뷰 0개" 로 읽힌다.
      expect(store(40).ratingText, '4.2/5');
      expect(store(40, reviewCount: 312).ratingText, '4.2/5 (312)');
    });

    test('거리 표기', () {
      expect(store(40).distanceText, '3.2 km');
    });

    test('최소 주문까지 남은 금액', () {
      final s = Restaurant(
        restaurantId: 1,
        name: 'x',
        foodCategory: FoodCategory.korean,
        area: '',
        rating: 0,
        etaMin: 0,
        deliveryFee: 0,
        minOrderPrice: 14000,
        distanceKm: 0,
      );
      expect(s.shortfallFrom(11000), 3000);
      expect(s.shortfallFrom(14000), 0);
    });
  });

  group('Cart — 다중 매장 묶음', () {
    StoreCart storeCart({
      required int id,
      required String name,
      required int deliveryFee,
      required int minOrderPrice,
      required List<CartLine> lines,
    }) =>
        StoreCart(
          restaurant: Restaurant(
            restaurantId: id,
            name: name,
            foodCategory: FoodCategory.snack,
            area: '성수동',
            rating: 4.0,
            etaMin: 30,
            deliveryFee: deliveryFee,
            minOrderPrice: minOrderPrice,
            distanceKm: 1.0,
          ),
          lines: lines,
        );

    CartLine line(int menuId, int price, {int quantity = 1}) => CartLine(
          menuId: menuId,
          name: '메뉴 $menuId',
          menuType: MenuType.main,
          price: price,
          quantity: quantity,
        );

    Cart twoStores() => Cart(
          stores: [
            storeCart(
              id: 101,
              name: '엽기떡볶이 성수점',
              deliveryFee: 2000,
              minOrderPrice: 12000,
              lines: [line(101001, 14000)],
            ),
            storeCart(
              id: 1,
              name: '교촌치킨 성수점',
              deliveryFee: 3000,
              minOrderPrice: 15000,
              lines: [line(1001, 23000)],
            ),
          ],
        );

    test('배달비는 가게마다 한 번씩 붙는다', () {
      final cart = twoStores();
      expect(cart.itemsTotal, 37000);
      expect(cart.deliveryFeeTotal, 5000);
      expect(cart.totalPrice, 42000);
    });

    test('subtotal 은 그 가게의 결제액이다', () {
      final cart = twoStores();
      expect(cart.stores[0].subtotal, 16000);
      expect(cart.stores[1].subtotal, 26000);
      // 전체 합계는 소계의 합이다.
      expect(cart.totalPrice, cart.stores.fold(0, (s, e) => s + e.subtotal));
    });

    test('한 가게라도 최소 주문을 못 넘기면 결제를 막는다', () {
      final cart = Cart(
        stores: [
          storeCart(
            id: 101,
            name: '엽기떡볶이 성수점',
            deliveryFee: 2000,
            minOrderPrice: 20000,
            lines: [line(101001, 14000)],
          ),
        ],
      );
      expect(cart.storesBelowMinimum, hasLength(1));
      expect(cart.canCheckout, isFalse);
      expect(cart.stores.first.shortfallText, '6,000원 더 담아주세요');
    });

    test('빈 장바구니는 결제할 수 없다', () {
      expect(Cart().canCheckout, isFalse);
    });

    test('마지막 메뉴를 빼면 그 가게도 사라진다', () {
      // 이름만 남으면 배달비가 총액에 계속 붙어 금액이 틀린다.
      final cart = twoStores();
      cart.stores.first.changeQuantity(menuId: 101001, delta: -1);
      cart.pruneEmptyStores();

      expect(cart.storeCount, 1);
      expect(cart.deliveryFeeTotal, 3000);
    });

    test('같은 메뉴를 다시 담으면 수량만 오른다', () {
      final cart = twoStores();
      final menu = Menu(
        menuId: 101001,
        name: '메뉴 101001',
        menuType: MenuType.main,
        price: 14000,
      );
      cart.stores.first.add(menu);

      expect(cart.stores.first.lines, hasLength(1));
      expect(cart.stores.first.lines.first.quantity, 2);
    });

    test('요청 본문에 전체 합계는 담지 않는다', () {
      // 주문이 가게 단위로 쪼개져 저장되므로 넣어둘 자리가 없다 (명세 5번).
      final json = twoStores().toOrderJson();

      expect(json.containsKey('totalPrice'), isFalse);
      expect(json['stores'], hasLength(2));

      final first = (json['stores'] as List).first as Map<String, dynamic>;
      expect(first['restaurantId'], 101);
      expect(first['itemsTotal'], 14000);
      expect(first['subtotal'], 16000);
    });
  });

  group('AnalysisResult — 두 블록으로 나뉜다', () {
    test('결과가 0개면 빈 배열이고 에러가 아니다', () {
      final result = AnalysisResult.fromJson({'exactMatches': [], 'combos': []});
      expect(result.isEmpty, isTrue);
      expect(result.all, isEmpty);
    });

    test('brandName 이 있으면 exactMatch, comboScore 가 있으면 combo', () {
      final result = AnalysisResult.fromJson({
        'exactMatches': [
          {
            'brandName': '엽기떡볶이',
            'restaurant': {'restaurantId': 101, 'name': '엽기떡볶이 성수점'},
            'items': [],
            'totalPrice': 16000,
          },
        ],
        // 서버는 가게 단위로 묶어 주지 않는다. 요리별 후보만 오고,
        // 가게로 묶는 것은 AnalysisResult.combos 가 한다.
        'dishResults': [
          {
            'dishName': '떡볶이',
            'candidates': [
              {
                'restaurant': {'restaurantId': 102, 'name': '신전떡볶이 성수점'},
                'item': {'menuId': 102001, 'name': '신전떡볶이', 'price': 12000},
                'score': 0.82,
              },
            ],
          },
        ],
      });

      expect(result.exactMatches.first.isExactMatch, isTrue);
      expect(result.exactMatches.first.brandName, '엽기떡볶이');
      expect(result.combos.first.isExactMatch, isFalse);
      expect(result.combos.first.comboScore, 0.82);
      // 영상에 나온 것이 앞, 비슷한 곳이 뒤다.
      expect(result.all.map((c) => c.id), [101, 102]);
    });

    test('exactMatches 가 여러 개면 장바구니도 여러 가게로 시작한다', () {
      final result = AnalysisResult.fromJson({
        'exactMatches': [
          {
            'brandName': '엽기떡볶이',
            'restaurant': {'restaurantId': 101, 'name': '엽기떡볶이 성수점'},
            'items': [
              {'menuId': 101001, 'name': '오리지널 떡볶이', 'price': 14000, 'quantity': 1},
            ],
          },
          {
            'brandName': '명랑핫도그',
            'restaurant': {'restaurantId': 301, 'name': '명랑핫도그 성수점'},
            'items': [
              {'menuId': 301001, 'name': '핫도그', 'price': 2000, 'quantity': 2},
            ],
          },
        ],
      });

      final carts = result.exactStoreCarts;
      expect(carts, hasLength(2));
      expect(carts[0].itemsTotal, 14000);
      expect(carts[1].itemsTotal, 4000);
    });
  });

  // 서버가 가게 단위로 묶어 주지 않으므로, 같은 가게가 여러 요리의 후보에
  // 나오는지 보고 묶는 것은 앱의 몫이다 (명세: "한 집에서 다 시킬 수 있는지는
  // 프론트가 판단한다"). 배달비가 한 번만 드는 조합이라 앞에 와야 한다.
  group('dishResults 를 가게 단위로 묶는다', () {
    Map<String, dynamic> candidate(int storeId, int menuId, double score) => {
          'restaurant': {'restaurantId': storeId, 'name': '가게$storeId'},
          'item': {'menuId': menuId, 'name': '메뉴$menuId', 'price': 10000},
          'score': score,
        };

    test('두 요리에 다 나오는 가게가 한 조합으로 묶이고 맨 앞에 온다', () {
      final result = AnalysisResult.fromJson({
        'exactMatches': [],
        'dishResults': [
          {
            'dishName': '떡볶이',
            'candidates': [candidate(1, 11, 0.9), candidate(2, 21, 0.8)],
          },
          {
            'dishName': '핫도그',
            'candidates': [candidate(2, 22, 0.7)],
          },
        ],
      });

      // 2번 가게가 떡볶이·핫도그를 다 판다 -> 메뉴 2개짜리 조합.
      final first = result.combos.first;
      expect(first.id, 2);
      expect(first.items.map((i) => i.menuId), [21, 22]);
      // 점수는 후보 점수의 평균이다.
      expect(first.comboScore, closeTo(0.75, 0.0001));

      // 한 요리만 되는 가게는 뒤로.
      expect(result.combos.map((c) => c.id), [2, 1]);
    });

    test('같은 가게에 같은 메뉴가 두 번 오면 한 줄만 담는다', () {
      final result = AnalysisResult.fromJson({
        'dishResults': [
          {'dishName': 'a', 'candidates': [candidate(1, 11, 0.9)]},
          {'dishName': 'b', 'candidates': [candidate(1, 11, 0.5)]},
        ],
      });

      expect(result.combos.single.items, hasLength(1));
    });

    test('후보가 없으면 조합도 없다', () {
      final result = AnalysisResult.fromJson({
        'exactMatches': [],
        'dishResults': [
          {'dishName': '떡볶이', 'candidates': []},
        ],
      });

      expect(result.combos, isEmpty);
      expect(result.isEmpty, isTrue);
    });
  });

  group('ComboSort', () {
    ComboSuggestion suggestion({
      String? brandName,
      double? comboScore,
      required int eta,
      required int price,
    }) =>
        ComboSuggestion(
          brandName: brandName,
          comboScore: comboScore,
          restaurant: Restaurant(
            restaurantId: eta,
            name: 'x',
            foodCategory: FoodCategory.korean,
            area: '',
            rating: 0,
            etaMin: eta,
            deliveryFee: 0,
            minOrderPrice: 0,
            distanceKm: 0,
          ),
          items: [
            CartLine(
              menuId: 1,
              name: 'm',
              menuType: MenuType.main,
              price: price,
              quantity: 1,
            ),
          ],
        );

    test('유사도순은 영상에 나온 곳을 먼저 둔다', () {
      final input = [
        suggestion(comboScore: 0.9, eta: 20, price: 1000),
        suggestion(brandName: '엽떡', eta: 50, price: 9000),
      ];
      final sorted = ComboSort.similarity.apply(input);
      expect(sorted.first.isExactMatch, isTrue);
    });

    test('빠른 배달순·낮은 가격순', () {
      final input = [
        suggestion(comboScore: 0.9, eta: 50, price: 9000),
        suggestion(comboScore: 0.5, eta: 20, price: 1000),
      ];
      expect(ComboSort.deliveryTime.apply(input).first.restaurant.etaMin, 20);
      expect(ComboSort.price.apply(input).first.payableTotal, 1000);
    });

    test('정렬은 원본을 건드리지 않는다', () {
      final input = [
        suggestion(comboScore: 0.5, eta: 50, price: 9000),
        suggestion(comboScore: 0.9, eta: 20, price: 1000),
      ];
      ComboSort.similarity.apply(input);
      expect(input.first.comboScore, 0.5);
    });
  });

  group('ComboBuilder — 추출 결과가 화면에 반영된다', () {
    ExtractionResult chicken() => const ExtractionResult(
          dishes: [
            ExtractedDish(
              name: '레드콤보',
              brandName: '교촌치킨',
              restaurantName: '교촌치킨 강남점',
              foodCategory: FoodCategory.chicken,
              description: '매콤한 홍고추 소스를 입힌 순살과 윙 콤보',
              options: ['치즈 추가'],
            ),
            ExtractedDish(
              name: '허니콤보',
              brandName: '교촌치킨',
              restaurantName: '교촌치킨 강남점',
              foodCategory: FoodCategory.chicken,
              description: '달콤한 허니 소스',
            ),
          ],
          keywords: ['치킨', '순살', '야식'],
        );

    AnalysisResult build({
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
      expect(build().exactMatches.first.restaurant.name, '교촌치킨 강남점');
    });

    test('브랜드마다 exactMatch 하나가 생긴다', () {
      // 같은 브랜드 메뉴 두 개는 한 카드로 묶인다.
      expect(build().exactMatches, hasLength(1));
      expect(build().exactMatches.first.brandName, '교촌치킨');
    });

    test('가게가 두 곳 나오는 영상이면 카드도 두 장이다', () {
      final result = build(
        extraction: const ExtractionResult(
          dishes: [
            ExtractedDish(
              name: '오리지널 떡볶이',
              brandName: '엽기떡볶이',
              restaurantName: '엽기떡볶이 강남점',
              foodCategory: FoodCategory.snack,
              options: ['분모자 넣어서'],
            ),
            ExtractedDish(
              name: '핫도그',
              brandName: '명랑핫도그',
              restaurantName: '명랑핫도그 강남점',
              foodCategory: FoodCategory.snack,
            ),
          ],
        ),
      );

      expect(result.exactMatches, hasLength(2));
      expect(
        result.exactMatches.map((m) => m.brandName),
        ['엽기떡볶이', '명랑핫도그'],
      );
      // 그대로 다중 매장 장바구니가 된다.
      expect(result.exactStoreCarts, hasLength(2));
    });

    test('추출한 메뉴가 조합에 담긴다', () {
      final names = build().exactMatches.first.items.map((e) => e.name).toList();
      expect(names, contains('레드콤보'));
      expect(names, contains('허니콤보'));
    });

    test('영상에서 말한 옵션이 체크된 상태로 담긴다', () {
      final first = build().exactMatches.first.items.first;
      expect(first.selectedOptions.map((o) => o.name), contains('치즈 추가'));
    });

    test('말하지 않은 옵션은 후보로만 남는다', () {
      final first = build().exactMatches.first.items.first;
      final names = first.options.map((o) => o.name).toList();
      expect(names, contains('분모자'));
      expect(first.selectedOptions.map((o) => o.name), isNot(contains('분모자')));
    });

    test('옵션에 맵기가 들어가지 않는다', () {
      // 맵기는 spiceLevel + spiceAdjustable 로 따로 다룬다. 회의에서 3단계로 통일.
      final first = build().exactMatches.first.items.first;
      expect(first.options.any((o) => o.name.contains('단계')), isFalse);
      expect(first.spiceAdjustable, isTrue);
    });

    test('카테고리별 사이드가 붙는다', () {
      final names = build().exactMatches.first.items.map((e) => e.name).toList();
      expect(names.any((n) => n.contains('감자튀김')), isTrue);
    });

    test('다른 영상이면 다른 매장이 나온다', () {
      final chinese = build(
        extraction: const ExtractionResult(
          dishes: [
            ExtractedDish(
              name: '짜장면',
              brandName: '홍콩반점',
              restaurantName: '홍콩반점 성수점',
              foodCategory: FoodCategory.chinese,
            ),
            ExtractedDish(name: '탕수육', brandName: '홍콩반점'),
          ],
        ),
      );
      expect(
        chinese.exactMatches.first.restaurant.name,
        isNot(build().exactMatches.first.restaurant.name),
      );
      expect(chinese.exactMatches.first.items.first.name, '짜장면');
    });

    test('썸네일이 매장과 첫 메뉴에 쓰인다', () {
      const url = 'https://example.com/reel.jpg';
      final result = build(thumbnailUrl: url);
      expect(result.exactMatches.first.restaurant.imageUrl, url);
      expect(result.exactMatches.first.items.first.imageUrl, url);
    });

    test('1인 모드는 메인 메뉴를 하나로 줄인다', () {
      final result = build(preference: TastePreference(mode: ServingMode.solo));
      // 메인 1 + 사이드 1
      expect(result.exactMatches.first.items, hasLength(2));
      expect(result.exactMatches.first.items.first.name, '레드콤보');
    });

    test('브랜드를 못 찾으면 exactMatches 가 비고 combos 만 남는다', () {
      final result = build(
        extraction: const ExtractionResult(
          dishes: [ExtractedDish(name: '치킨', foodCategory: FoodCategory.chicken)],
        ),
      );
      // 브랜드가 없어도 카드는 만들어진다 — 이름을 카테고리로 지어낸다.
      expect(result.exactMatches.first.brandName, isNull);
      expect(result.exactMatches.first.restaurant.name, '치킨 맛집');
      expect(result.combos, isNotEmpty);
    });

    test('메뉴를 하나도 못 뽑으면 combos 만 남는다', () {
      final result = build(extraction: const ExtractionResult.empty());
      expect(result.exactMatches, isEmpty);
      expect(result.combos, isNotEmpty);
    });

    test('가격은 500원 단위로 끊긴다', () {
      for (final item in build().exactMatches.first.items) {
        expect(item.price % 500, 0, reason: '${item.name} = ${item.price}');
      }
    });

    test('같은 입력이면 항상 같은 결과가 나온다', () {
      final a = build().exactMatches.first;
      final b = build().exactMatches.first;
      expect(a.restaurant.rating, b.restaurant.rating);
      expect(a.restaurant.etaMin, b.restaurant.etaMin);
      expect(a.itemsTotal, b.itemsTotal);
    });

    test('combos 는 comboScore 내림차순으로 온다', () {
      final combos = build().combos;
      expect(combos.length, greaterThan(1));
      for (var i = 1; i < combos.length; i++) {
        expect(combos[i].comboScore!, lessThan(combos[i - 1].comboScore!));
      }
    });
  });

  group('명세 enum', () {
    test('food_category 는 9개다', () {
      expect(FoodCategory.values, hasLength(9));
      expect(FoodCategory.cafeDessert.wire, 'CAFE_DESSERT');
      expect(FoodCategory.fromWire('chicken'), FoodCategory.chicken);
      // 9개 밖의 값은 null 이다.
      expect(FoodCategory.fromWire('BURGER'), isNull);
    });

    test('menu_type 은 모르는 값이 와도 MAIN 으로 떨어진다', () {
      // DB 기본값이 MAIN 이다. 모르는 값에 메뉴가 사라지면 안 된다.
      expect(MenuType.fromWire('SIDE'), MenuType.side);
      expect(MenuType.fromWire('COMBO'), MenuType.main);
      expect(MenuType.fromWire(null), MenuType.main);
    });

    test('맵기는 3단계이고 null 을 허용한다', () {
      expect(SpiceLevel.none.wire, 'NONE');
      expect(SpiceLevel.medium.wire, 'MEDIUM');
      expect(SpiceLevel.hot.wire, 'HOT');
      expect(SpiceLevel.values, hasLength(3));

      expect(SpiceLevel.fromWire(null), isNull);
      expect(SpiceLevel.fromWire('MEDIUM'), SpiceLevel.medium);
      // 예전 5단계의 EXTREME 이 와도 터지지 않는다.
      expect(SpiceLevel.fromWire('EXTREME'), isNull);
      // spice_level 은 NULL 을 허용하지 않아 파싱 폴백이 NONE 이다.
      expect(SpiceLevel.fromWireOrNone('EXTREME'), SpiceLevel.none);
    });

    test('spice_rank 는 NONE=0, MEDIUM=1, HOT=2', () {
      expect(SpiceLevel.none.rank, 0);
      expect(SpiceLevel.medium.rank, 1);
      expect(SpiceLevel.hot.rank, 2);
    });
  });

  group('MenuOption', () {
    test('group 은 없으면 null 이고 키 자체를 빼지 않는다', () {
      const option = MenuOption(name: '분모자', price: 2000);
      expect(option.toJson(), {'group': null, 'name': '분모자', 'price': 2000});
    });

    test('group 으로 묶어 그린다. 서버가 준 순서를 지킨다', () {
      final groups = MenuOptionGroup.groupBy(const [
        MenuOption(group: '사리 추가', name: '분모자', price: 2000),
        MenuOption(name: '곱빼기', price: 1500),
        MenuOption(group: '사리 추가', name: '납작당면', price: 3000),
      ]);

      expect(groups, hasLength(2));
      expect(groups.first.label, '사리 추가');
      expect(groups.first.options.map((o) => o.name), ['분모자', '납작당면']);
      expect(groups.last.label, isNull);
    });
  });

  group('GeminiExtractor.parseResponse', () {
    test('앞뒤 잡음이 있어도 JSON 을 뽑아낸다', () {
      final result = GeminiExtractor.parseResponse(
        '```json\n{"dishes":[{"name":"레드콤보","brandName":"교촌치킨",'
        '"restaurantName":"교촌치킨 강남점","foodCategory":"CHICKEN",'
        '"description":"매콤한 순살","options":["치즈 추가"]}],'
        '"keywords":["치킨"]}\n```',
      );
      expect(result.dishes, hasLength(1));
      expect(result.dishes.first.name, '레드콤보');
      expect(result.dishes.first.brandName, '교촌치킨');
      expect(result.dishes.first.foodCategory, FoodCategory.chicken);
      expect(result.keywords, ['치킨']);
    });

    test('빈 문자열 nullable 필드는 null 이 된다', () {
      // 빈 문자열을 그대로 보내면 서버가 브랜드 '' 로 검색한다.
      final result = GeminiExtractor.parseResponse(
        '{"dishes":[{"name":"떡볶이","brandName":"","restaurantName":"",'
        '"foodCategory":"","options":[]}],"keywords":[]}',
      );
      final dish = result.dishes.first;
      expect(dish.brandName, isNull);
      expect(dish.restaurantName, isNull);
      expect(dish.foodCategory, isNull);
    });

    test('AI 가 한글 카테고리로 답해도 되돌린다', () {
      final result = GeminiExtractor.parseResponse(
        '{"dishes":[{"name":"짜장면","foodCategory":"중식"}],"keywords":[]}',
      );
      expect(result.dishes.first.foodCategory, FoodCategory.chinese);
    });

    test('extracted 계약 형태로 다시 직렬화된다', () {
      const result = ExtractionResult(
        dishes: [
          ExtractedDish(
            name: '오리지널 떡볶이',
            brandName: '엽기떡볶이',
            restaurantName: '엽기떡볶이 강남점',
            foodCategory: FoodCategory.snack,
            description: '쫄깃한 밀떡에 매운 양념',
            options: ['분모자 넣어서'],
          ),
        ],
        keywords: ['떡볶이'],
      );

      expect(result.toJson(), {
        'dishes': [
          {
            'name': '오리지널 떡볶이',
            'brandName': '엽기떡볶이',
            'restaurantName': '엽기떡볶이 강남점',
            'foodCategory': 'SNACK',
            'description': '쫄깃한 밀떡에 매운 양념',
            'options': ['분모자 넣어서'],
          },
        ],
        'keywords': ['떡볶이'],
      });
    });

    test('브랜드가 여러 개면 순서를 지켜 중복 없이 모은다', () {
      const result = ExtractionResult(
        dishes: [
          ExtractedDish(name: '떡볶이', brandName: '엽기떡볶이'),
          ExtractedDish(name: '핫도그', brandName: '명랑핫도그'),
          ExtractedDish(name: '주먹밥', brandName: '엽기떡볶이'),
        ],
      );
      expect(result.brandNames, ['엽기떡볶이', '명랑핫도그']);
    });
  });

  group('AnalysisSource — 원문을 서버로 넘기기 위해 보관한다', () {
    AnalysisSource source(String url, {String rawText = 'Instagram\n교촌치킨 강남점 먹방'}) =>
        AnalysisSource.fromUrl(url: Uri.parse(url), rawText: rawText);

    test('Gemini 에 넣은 원문을 그대로 들고 있는다', () {
      expect(source('https://www.instagram.com/reel/abc/').rawText,
          'Instagram\n교촌치킨 강남점 먹방');
    });

    test('호스트로 플랫폼을 판별한다', () {
      expect(source('https://www.instagram.com/reel/abc/').platform,
          SourcePlatform.instagram);
      expect(source('https://www.youtube.com/shorts/abc').platform,
          SourcePlatform.youtube);
      expect(source('https://youtu.be/abc').platform, SourcePlatform.youtube);
      expect(source('https://www.tiktok.com/@x/video/1').platform, SourcePlatform.other);
    });

    test('명세는 두 플랫폼만 받는다', () {
      // 그 밖의 링크는 분석을 시작하기 전에 막는다.
      expect(SourcePlatform.instagram.isSupported, isTrue);
      expect(SourcePlatform.youtube.isSupported, isTrue);
      expect(SourcePlatform.other.isSupported, isFalse);
    });

    test('서버로 보내는 enum 값은 대문자다', () {
      expect(SourcePlatform.instagram.wire, 'INSTAGRAM');
      expect(SourcePlatform.youtube.wire, 'YOUTUBE');
    });

    test('toJson 이 source 계약 형태를 만든다', () {
      expect(source('https://youtu.be/abc', rawText: '두찜 로제 닭발').toJson(), {
        'platform': 'YOUTUBE',
        'url': 'https://youtu.be/abc',
        'rawText': '두찜 로제 닭발',
      });
    });

    test('텍스트가 빈약하면 서버 재수집 신호를 준다', () {
      // 인스타 캡션이 막혀 계정명 한 줄만 남은 상황
      expect(source('https://www.instagram.com/reel/abc/', rawText: '인스타그램 @x').isThin,
          isTrue);
      expect(source('https://www.instagram.com/reel/abc/').isThin, isFalse);
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
