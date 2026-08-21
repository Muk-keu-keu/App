/// "메뉴 추가하기" 전체 화면 (시안 925:4037, 피드백 23·25번).
///
/// 목록의 + 는 옵션 없이 바로 담는 빠른 길이고, 카드를 누르면 이 화면에서 옵션을
/// 고르고 담는다. 예전에는 이 화면이 없어 눌러도 아무 일도 없었다.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mukbang_ttaradamgi/api/mukbang_api.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/repository/order_repository.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/screens/menu_detail_screen.dart';
import 'package:mukbang_ttaradamgi/screens/store_menu_screen.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';
import 'package:mukbang_ttaradamgi/theme.dart';
import 'package:mukbang_ttaradamgi/widgets/ds.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

const _restaurant = Restaurant(
  restaurantId: 201,
  name: '두찜-잠실새내점',
  foodCategory: FoodCategory.korean,
  area: '잠실동',
  rating: 4.2,
  reviewCount: 312,
  etaMin: 40,
  deliveryFee: 3000,
  minOrderPrice: 14000,
  distanceKm: 3.2,
);

final _menu = Menu(
  menuId: 201001,
  name: '불닭로제 찜닭',
  menuType: MenuType.main,
  price: 20000,
  description: '불닭과 로제가 만나 부드럽고 강렬한 중독적인 맛.',
  spiceAdjustable: true,
  options: const [
    MenuOption(group: '당면추가', name: '둥근당면 추가', price: 2500),
    MenuOption(group: '당면추가', name: '납작당면 추가', price: 3000),
  ],
);

/// 매장 하나 + 메뉴 하나를 주는 저장소.
class _OneMenuRepository implements ComboRepository {
  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async =>
      const AnalysisResult.empty();

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async =>
      RestaurantMenus(restaurant: _restaurant, menus: [_menu]);
}

void main() {
  AppFlow makeFlow() => AppFlow(
        repository: _OneMenuRepository(),
        orderRepository: MockOrderRepository(delay: Duration.zero),
        postRepository: MockPostRepository(delay: Duration.zero),
        locationService: const _NoLocation(),
      );

  Future<void> pumpScreen(WidgetTester tester, Widget screen, AppFlow flow) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppFlow>.value(
        value: flow,
        child: MaterialApp(theme: buildAppTheme(), home: Scaffold(body: screen)),
      ),
    );
    await tester.pump();
  }

  testWidgets('메뉴 카드를 누르면 메뉴 상세로 간다', (tester) async {
    final flow = makeFlow();
    await flow.openStoreMenu(201);
    await pumpScreen(tester, const StoreMenuScreen(), flow);

    expect(tester.takeException(), isNull);
    // 가게 이름이 나온다 (피드백 24번 — GET menus 의 restaurant 블록).
    expect(find.text('두찜-잠실새내점'), findsOneWidget);

    await tester.tap(find.text('불닭로제 찜닭'));
    await tester.pump();

    expect(flow.stage, AppStage.menuDetail);
    expect(flow.menuDetail?.menuId, 201001);
  });

  testWidgets('메뉴 상세가 시안대로 그려진다', (tester) async {
    final flow = makeFlow();
    await flow.openStoreMenu(201);
    flow.openMenuDetail(_menu);
    await pumpScreen(tester, const MenuDetailScreen(), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('불닭로제 찜닭'), findsOneWidget);
    expect(find.textContaining('불닭과 로제가 만나'), findsOneWidget);
    // 옵션 그룹과 가격
    expect(find.text('당면추가'), findsOneWidget);
    expect(find.text('+2,500원'), findsOneWidget);
    // 맵기를 고를 수 있는 메뉴다.
    expect(find.text('맵기 선택'), findsOneWidget);
    // 시안 문구는 "추가하기" 다 ("변경하기" 는 옵션 변경 시트 쪽).
    expect(find.text('추가하기'), findsOneWidget);
    expect(find.text('변경하기'), findsNothing);
  });

  testWidgets('옵션을 고르고 추가하면 그 옵션까지 장바구니에 담긴다', (tester) async {
    final flow = makeFlow();
    await flow.openStoreMenu(201);
    flow.openMenuDetail(_menu);
    await pumpScreen(tester, const MenuDetailScreen(), flow);

    await tester.tap(find.text('납작당면 추가'));
    await tester.pump();
    await tester.tap(find.text('추가하기'));
    await tester.pump();

    // 담고 나면 **장바구니로 간다.** 예전에는 매장 메뉴로 되돌렸는데, 담은 것이
    // 어디로 갔는지 보이지 않고 결제까지 가려면 뒤로 두 번 나가야 했다
    // (피드백 2026-08-21).
    expect(flow.stage, AppStage.cart);

    final line = flow.cart.storeOf(201)!.lines.single;
    expect(line.menuId, 201001);
    expect(line.selectedOptions.map((o) => o.name), ['납작당면 추가']);
    // 기본가 20,000 + 옵션 3,000
    expect(line.lineTotal, 23000);
  });

  testWidgets('그룹 안에서는 하나만 골라진다', (tester) async {
    final flow = makeFlow();
    await flow.openStoreMenu(201);
    flow.openMenuDetail(_menu);
    await pumpScreen(tester, const MenuDetailScreen(), flow);

    await tester.tap(find.text('둥근당면 추가'));
    await tester.pump();
    await tester.tap(find.text('납작당면 추가'));
    await tester.pump();

    // 라디오라 앞의 선택이 빠진다.
    final on = tester
        .widgetList<DsRadio>(find.byType(DsRadio))
        .where((r) => r.isOn)
        .length;
    expect(on, 1);
  });

  testWidgets('뒤로가기는 사진 위에 얹혀 있고 누르면 목록으로 돌아간다', (tester) async {
    final flow = makeFlow();
    await flow.openStoreMenu(201);
    flow.openMenuDetail(_menu);
    await pumpScreen(tester, const MenuDetailScreen(), flow);

    // 시안 925:4091 — 사진(h202) 위 왼쪽 20 에 있다.
    final back = tester.getRect(find.byType(DsChevron));
    expect(back.left, closeTo(28, 2)); // 원형 padding 8 을 더한 아이콘 왼쪽
    expect(back.top, lessThan(202));

    await tester.tap(find.byType(DsChevron));
    await tester.pump();
    expect(flow.stage, AppStage.storeMenu);
  });
}
