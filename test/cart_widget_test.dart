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
    flow.openFilter();
    await flow.applyPreferenceAndAnalyze();
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
    // 배달이 따로 간다는 안내가 매장 두 곳일 때만 나온다.
    expect(find.textContaining('2곳에서 따로 배달'), findsOneWidget);
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

  testWidgets('최소 주문을 못 넘기면 버튼이 이유를 알려주고 막힌다', (tester) async {
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

    final button = tester.widget<DsButton>(find.byType(DsButton));
    expect(button.onPressed, isNull);
    // 어느 가게가 얼마 모자라는지 버튼에 그대로 쓴다.
    expect(find.textContaining('4,000원 더 담아주세요'), findsWidgets);
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

  testWidgets('완료 화면은 곳 수와 가게 이름만 보여준다', (tester) async {
    final flow = await analyzedFlow();
    flow.openCartFromAnalysis();
    await flow.checkout();
    await pumpScreen(tester, const OrderDoneScreen(), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('주문이 접수되었습니다'), findsOneWidget);
    expect(find.text('2건 · 엽기떡볶이 성수점, 명랑핫도그 성수점'), findsOneWidget);
    expect(find.textContaining('가게마다 따로 배달'), findsOneWidget);
    expect(find.text('주문 내역 보기'), findsOneWidget);
  });
}
