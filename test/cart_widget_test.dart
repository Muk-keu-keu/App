import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mukbang_ttaradamgi/api/mukbang_api.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/repository/order_repository.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/screens/cart_screen.dart';
import 'package:mukbang_ttaradamgi/screens/combo_list_screen.dart';
import 'package:mukbang_ttaradamgi/screens/combo_result_screen.dart';
import 'package:mukbang_ttaradamgi/screens/order_done_screen.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';
import 'package:mukbang_ttaradamgi/theme.dart';
import 'package:mukbang_ttaradamgi/widgets/ds.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 가게 두 곳이 나오는 분석 결과를 돌려준다.
class _TwoStoreRepository implements ComboRepository {
  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async =>
      AnalysisResult(
        exactMatches: [
          _suggestion('엽기떡볶이', 101, '엽기떡볶이 성수점', 2000, 12000, 101001, '오리지널 떡볶이', 14000),
          _suggestion('명랑핫도그', 301, '명랑핫도그 성수점', 2500, 4000, 301001, '핫도그', 4000),
        ],
        combos: [
          ComboSuggestion(
            comboScore: 0.82,
            restaurant: const Restaurant(
              restaurantId: 102,
              name: '신전떡볶이 성수점',
              foodCategory: FoodCategory.snack,
              area: '성수동',
              rating: 4.1,
              etaMin: 25,
              deliveryFee: 2000,
              minOrderPrice: 10000,
              distanceKm: 0.8,
            ),
            items: [
              CartLine(
                menuId: 102001,
                name: '신전떡볶이',
                menuType: MenuType.main,
                price: 10000,
                quantity: 1,
              ),
            ],
          ),
        ],
      );

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async => null;

  static ComboSuggestion _suggestion(
    String brand,
    int id,
    String name,
    int deliveryFee,
    int minOrderPrice,
    int menuId,
    String menuName,
    int price,
  ) =>
      ComboSuggestion(
        brandName: brand,
        restaurant: Restaurant(
          restaurantId: id,
          name: name,
          foodCategory: FoodCategory.snack,
          area: '성수동',
          rating: 4.5,
          etaMin: 30,
          deliveryFee: deliveryFee,
          minOrderPrice: minOrderPrice,
          distanceKm: 1.2,
        ),
        items: [
          CartLine(
            menuId: menuId,
            name: menuName,
            menuType: MenuType.main,
            price: price,
            quantity: 1,
            spiceAdjustable: true,
            selectedSpice: SpiceLevel.medium,
            options: const [MenuOption(group: '사리 추가', name: '분모자', price: 2000)],
          ),
        ],
      );
}

void main() {
  Future<AppFlow> analyzedFlow() async {
    final flow = AppFlow(
      repository: _TwoStoreRepository(),
      orderRepository: MockOrderRepository(delay: Duration.zero),
      postRepository: MockPostRepository(delay: Duration.zero),
      locationService: const _NoLocation(),
    );
    flow.source = AnalysisSource.fromUrl(
      url: Uri.parse('https://www.instagram.com/p/xxxxx/'),
      rawText: '엽떡에 명랑핫도그',
    );
    flow.extraction = const ExtractionResult(
      dishes: [
        ExtractedDish(name: '오리지널 떡볶이', brandName: '엽기떡볶이'),
        ExtractedDish(name: '핫도그', brandName: '명랑핫도그'),
      ],
    );
    await flow.applyFilter(flow.preference);
    return flow;
  }

  Future<void> pumpScreen(WidgetTester tester, Widget screen, AppFlow flow) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppFlow>.value(
        value: flow,
        child: MaterialApp(theme: buildAppTheme(), home: Scaffold(body: screen)),
      ),
    );
    await tester.pump();
  }

  testWidgets('장바구니가 매장별 섹션으로 그려진다', (tester) async {
    final flow = await analyzedFlow();
    flow.openCartFromAnalysis();
    await pumpScreen(tester, CartScreen(onBack: () {}), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('장바구니'), findsOneWidget);
    expect(find.text('엽기떡볶이 성수점'), findsOneWidget);
    // 버튼 문구는 시안(681:8164)의 "결제하기" 다.
    expect(find.text('결제하기'), findsOneWidget);

    // 결제 금액 행은 화면 밖이라 스크롤해서 확인한다.
    await tester.scrollUntilVisible(
      find.text('결제 금액'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // 총액 = (14,000 + 2,000) + (4,000 + 2,500)
    expect(find.text('22,500원'), findsWidgets);
  });

  // 시안 868:5757 — 매장 헤더의 ✕ 는 바로 지우지 않고 먼저 물어본다.
  // 담긴 메뉴가 통째로 사라지는 동작이라 되돌릴 수 없다.
  testWidgets('매장 ✕ 는 확인을 받고 나서 지운다', (tester) async {
    final flow = await analyzedFlow();
    flow.openCartFromAnalysis();
    await pumpScreen(tester, CartScreen(onBack: () {}), flow);

    expect(flow.cart.storeCount, 2);

    // 엽기떡볶이(101) 의 ✕.
    const removeFirst = ValueKey('remove-store-101');

    await tester.tap(find.byKey(removeFirst));
    await tester.pumpAndSettle();

    expect(find.text('이 매장을 삭제할까요?'), findsOneWidget);
    expect(find.text('담긴 메뉴가 모두 삭제돼요.'), findsOneWidget);

    // 취소하면 그대로 남아 있어야 한다.
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(flow.cart.storeCount, 2);

    await tester.tap(find.byKey(removeFirst));
    await tester.pumpAndSettle();
    await tester.tap(find.text('삭제하기'));
    await tester.pumpAndSettle();

    expect(flow.cart.storeCount, 1);
    expect(find.byKey(removeFirst), findsNothing);
  });

  testWidgets('최소 주문을 못 넘기면 채우기를 고르기 전까지 버튼이 막힌다', (tester) async {
    final flow = await analyzedFlow();
    flow.openCartFromAnalysis();

    // 명랑핫도그의 최소 주문 금액만 8,000 으로 올려 미달 상태를 만든다.
    final store = flow.cart.storeOf(301)!;
    store.restaurant = Restaurant(
      restaurantId: 301,
      name: store.restaurant.name,
      foodCategory: FoodCategory.snack,
      area: '성수동',
      rating: 4.5,
      etaMin: 30,
      deliveryFee: 2500,
      minOrderPrice: 8000,
      distanceKm: 1.2,
    );
    await pumpScreen(tester, CartScreen(onBack: () {}), flow);

    // 어느 가게가 걸렸는지는 버튼이, 얼마가 모자라는지는 그 가게 카드가 말한다.
    expect(tester.widget<DsButton>(find.byType(DsButton)).onPressed, isNull);
    expect(find.textContaining('명랑핫도그 성수점 최소주문을 채워주세요'), findsWidgets);
    expect(find.textContaining('4,000원 결제하고 포인트 적립'), findsWidgets);

    // 미달분을 포인트로 채우기로 하면 잠금이 풀린다. 되돌릴 수 있어야 해서 토글이다.
    // 체크는 두 번째 매장 카드 안이라 화면 밖이다 — 스크롤해서 누른다.
    const check = ValueKey('prepaid-check-301');
    await tester.ensureVisible(find.byKey(check));
    await tester.pump();
    await tester.tap(find.byKey(check));
    await tester.pump();

    expect(flow.cart.storeOf(301)!.prepaidOptIn, isTrue);
    expect(tester.widget<DsButton>(find.byType(DsButton)).onPressed, isNotNull);
    expect(find.text('결제하기'), findsOneWidget);
  });

  testWidgets('비교 목록은 담긴 매장을 체크로 보여준다', (tester) async {
    final flow = await analyzedFlow();
    flow.openCartFromAnalysis();
    await pumpScreen(tester, const ComboListScreen(), flow);

    expect(tester.takeException(), isNull);
    // 영상에 나온 브랜드에 뱃지가 붙는다.
    expect(find.text('영상 속 엽기떡볶이'), findsOneWidget);
    // 하단 버튼은 시안(681:6245) 문구 그대로다.
    expect(find.text('주문하기'), findsOneWidget);
    // 두 매장이 모두 담긴 상태다.
    expect(flow.cart.storeCount, 2);
  });

  testWidgets('빈 장바구니는 버튼이 막힌다', (tester) async {
    final flow = await analyzedFlow();
    await pumpScreen(tester, CartScreen(onBack: () {}), flow);

    expect(find.text('담은 메뉴가 없어요'), findsWidgets);
    final button = tester.widget<DsButton>(find.byType(DsButton));
    expect(button.onPressed, isNull);
  });

  // ── 먹방 조합 카드 선택 (피드백 16·17·18 / 시안 925:4220) ────────────────────
  // 체크박스는 "지금 보고 있는 카드" 가 아니라 담기다. 그래서 해제도 되고,
  // 카드마다 따로 켜진다.

  testWidgets('선택 개수를 "N개 중 M개 선택" 으로 보여준다', (tester) async {
    final flow = await analyzedFlow();
    await pumpScreen(tester, const ComboResultScreen(), flow);

    expect(tester.takeException(), isNull);
    // 분석 결과는 영상 브랜드 2곳 + 비슷한 곳 1곳인데, 첫 화면은 영상에 나온
    // 브랜드만 세운다. 비슷한 곳은 "다른 결과 보기" 의 몫이다.
    expect(flow.suggestions, hasLength(2));
    expect(flow.sortedSuggestions, hasLength(3));
    // 개수만 색·크기가 달라 Text.rich 다. 이어붙인 문자열로 찾는다.
    expect(find.text('2개 중 0개 선택', findRichText: true), findsOneWidget);
  });

  testWidgets('체크로 담고 다시 눌러 뺀다', (tester) async {
    final flow = await analyzedFlow();
    await pumpScreen(tester, const ComboResultScreen(), flow);

    final first = flow.suggestions.first;
    expect(flow.isInCart(first.id), isFalse);

    await tester.tap(find.byType(DsCheckbox).first);
    await tester.pump();
    expect(flow.isInCart(first.id), isTrue);
    expect(find.text('2개 중 1개 선택', findRichText: true), findsOneWidget);

    // 해제가 되어야 한다 — 피드백 17번이 지적한 지점이다.
    await tester.tap(find.byType(DsCheckbox).first);
    await tester.pump();
    expect(flow.isInCart(first.id), isFalse);
    expect(find.text('2개 중 0개 선택', findRichText: true), findsOneWidget);
  });

  testWidgets('체크한 조합만 장바구니로 넘어간다', (tester) async {
    final flow = await analyzedFlow();
    await pumpScreen(tester, const ComboResultScreen(), flow);

    await tester.tap(find.byType(DsCheckbox).first);
    await tester.pump();
    await tester.tap(find.text('이대로 주문하기'));
    await tester.pump();

    // 영상 브랜드가 2곳이지만 고른 것은 하나다. 예전에는 CTA 가 장바구니를
    // 덮어써서 안 고른 가게까지 담겼다.
    expect(flow.stage, AppStage.cart);
    expect(flow.cart.storeCount, 1);
    expect(flow.cart.stores.single.restaurantId, flow.suggestions.first.id);
  });

  testWidgets('아무것도 안 고르면 영상 브랜드를 기본으로 담는다', (tester) async {
    final flow = await analyzedFlow();
    await pumpScreen(tester, const ComboResultScreen(), flow);

    await tester.tap(find.text('이대로 주문하기'));
    await tester.pump();

    expect(flow.cart.storeCount, 2);
  });

  // 피드백 29번 — 시안 949:4470 대로 금액 카드가 있고 버튼은 하나다.
  testWidgets('완료 화면은 금액 카드와 홈으로 이동하기를 보여준다', (tester) async {
    final flow = await analyzedFlow();
    flow.openCartFromAnalysis();
    await flow.checkout();
    await pumpScreen(tester, const OrderDoneScreen(), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('결제가 완료되었습니다'), findsOneWidget);
    expect(find.text('이제 먹방 속 조합을 직접 즐겨보세요!'), findsOneWidget);

    // 주문 18,000 + 배달비 4,500 = 22,500
    expect(find.text('결제 금액'), findsOneWidget);
    expect(find.text('22,500원'), findsOneWidget);
    expect(find.text('18,000원'), findsOneWidget);
    expect(find.text('4,500원'), findsOneWidget);

    expect(find.text('홈으로 이동하기'), findsOneWidget);
    // 시안에는 버튼이 하나다. 주문내역은 홈의 탭에서 간다.
    expect(find.text('주문 내역 보기'), findsNothing);
  });

  // 시안 1059:5972 / 1059:5978 — 결과가 왜 이 순서인지 묻는 자리.
  testWidgets('AI 추천 이유를 누르면 무엇을 찾았는지 알려준다', (tester) async {
    final flow = await analyzedFlow();
    await pumpScreen(tester, const ComboResultScreen(), flow);

    await tester.tap(find.text('AI 추천 이유'));
    await tester.pumpAndSettle();

    expect(find.text('영상과 가장 비슷한 결과예요'), findsOneWidget);
    // 영상에 나온 두 브랜드를 그대로 시킬 수 있다는 사실이 본문에 실린다.
    expect(
      find.textContaining('엽기떡볶이, 명랑핫도그는 근처 지점에서'),
      findsOneWidget,
    );
    expect(find.textContaining('다른 결과 보기'), findsWidgets);

    // 읽고 나가는 창이라 결과를 건드리지 않는다.
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(find.text('영상과 가장 비슷한 결과예요'), findsNothing);
    expect(flow.suggestions, hasLength(2));
  });

  // 시안 1052:8091 — 목록에서 카드끼리 비교하는 중에 뜨는 짧은 창.
  testWidgets('매장 이름 옆 물음표는 그 매장을 고른 이유를 알려준다', (tester) async {
    final flow = await analyzedFlow();
    flow.showComboList();
    await pumpScreen(tester, const ComboListScreen(), flow);

    await tester.tap(find.byKey(const ValueKey('store-reason-101')));
    await tester.pumpAndSettle();

    expect(find.text('이 매장을 추천한 이유'), findsOneWidget);
    // 이 저장소는 tags·reason 을 안 주므로 카드가 가진 사실로 만든 문구가 나온다.
    expect(find.text('영상에 나온 그 지점이에요'), findsOneWidget);
  });

  testWidgets('완료 화면의 금액은 장바구니를 비운 뒤에도 남는다', (tester) async {
    final flow = await analyzedFlow();
    flow.openCartFromAnalysis();
    await flow.checkout();

    // checkout 이 장바구니를 비우므로 화면이 읽을 값이 따로 있어야 한다.
    expect(flow.cart.isEmpty, isTrue);
    expect(flow.paidAmounts?.total, 22500);

    await pumpScreen(tester, const OrderDoneScreen(), flow);
    await tester.tap(find.text('홈으로 이동하기'));
    await tester.pump();

    expect(flow.stage, AppStage.yogiyoHome);
    expect(flow.paidAmounts, isNull);
  });
}
