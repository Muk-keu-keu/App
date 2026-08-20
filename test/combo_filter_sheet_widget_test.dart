import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mukbang_ttaradamgi/api/mukbang_api.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/screens/combo_list_screen.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';
import 'package:mukbang_ttaradamgi/theme.dart';
import 'package:mukbang_ttaradamgi/widgets/common.dart';
import 'package:mukbang_ttaradamgi/widgets/ds.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

class _OneStoreRepository implements ComboRepository {
  TastePreference? lastPreference;

  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async {
    lastPreference = preference;
    return AnalysisResult(
      exactMatches: [
        ComboSuggestion(
          brandName: '엽기떡볶이',
          restaurant: const Restaurant(
            restaurantId: 101,
            name: '엽기떡볶이 성수점',
            foodCategory: FoodCategory.snack,
            area: '성수동',
            rating: 4.5,
            etaMin: 30,
            deliveryFee: 2000,
            minOrderPrice: 12000,
            distanceKm: 1.2,
          ),
          items: [
            CartLine(
              menuId: 101001,
              name: '오리지널 떡볶이',
              menuType: MenuType.main,
              price: 14000,
              quantity: 1,
            ),
          ],
        ),
      ],
    );
  }

  @override
  Future<RestaurantMenus?> menus(int restaurantId) async => null;
}

void main() {
  late _OneStoreRepository repo;
  late AppFlow flow;

  setUp(() async {
    repo = _OneStoreRepository();
    flow = AppFlow(repository: repo, locationService: const _NoLocation());
    flow.source = AnalysisSource.fromUrl(
      url: Uri.parse('https://www.instagram.com/p/xxxxx/'),
      rawText: '엽떡 먹방',
    );
    flow.extraction = const ExtractionResult(
      dishes: [ExtractedDish(name: '오리지널 떡볶이', brandName: '엽기떡볶이')],
    );
    await flow.applyFilter(flow.preference);
  });

  Future<void> pumpList(WidgetTester tester) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppFlow>.value(
        value: flow,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: const Scaffold(body: ComboListScreen()),
        ),
      ),
    );
    await tester.pump();
  }

  /// 칩을 눌러 시트를 띄운다. [index] 는 칩 줄의 순서다 (0 아이콘 · 1 맛 · 2 예상 시간).
  Future<void> tapChip(WidgetTester tester, int index) async {
    await tester.tap(find.byType(DsChipFilter).at(index));
    await tester.pumpAndSettle();
  }

  // 피드백 2026-08-13 — 칩을 누르면 목록을 떠났다. 이제 목록 위에 시트만 올라온다.
  testWidgets('아이콘 칩은 화면을 옮기지 않고 전체 필터 시트를 띄운다', (tester) async {
    await pumpList(tester);
    await tapChip(tester, 0);

    expect(tester.takeException(), isNull);
    // 시트가 떴는데도 목록 화면은 그대로 뒤에 남아 있다.
    expect(find.byType(ComboListScreen), findsOneWidget);
    expect(flow.stage, AppStage.comboList);

    // 통합 시트는 두 섹션과 두 버튼을 함께 그린다 (시안 1114:4765).
    expect(find.text('필터'), findsOneWidget);
    expect(find.text('맵기'), findsOneWidget);
    expect(find.text('예상 도착 시간'), findsOneWidget);
    expect(find.text('초기화'), findsOneWidget);
    expect(find.text('적용하기'), findsOneWidget);
  });

  testWidgets('맛 칩은 맵기만, 예상 시간 칩은 도착 시간만 띄운다', (tester) async {
    await pumpList(tester);

    await tapChip(tester, 1);
    // 헤더가 곧 섹션 이름이라 제목이 하나뿐이다 (시안 1114:4602).
    expect(find.text('맵기'), findsOneWidget);
    expect(find.text('예상 도착 시간'), findsNothing);
    expect(find.byType(DsOptionItem), findsNWidgets(SpiceLevel.values.length));

    await tester.tap(find.text('초기화'));
    await tester.pumpAndSettle();
    Navigator.of(tester.element(find.text('초기화'))).pop();
    await tester.pumpAndSettle();

    await tapChip(tester, 2);
    expect(find.text('예상 도착 시간'), findsOneWidget);
    expect(find.text('맵기'), findsNothing);
    expect(find.byType(DsOptionItem), findsNothing);
  });

  testWidgets('시트에서 고른 맵기는 적용하기 전까지 반영되지 않는다', (tester) async {
    await pumpList(tester);
    await tapChip(tester, 1);

    await tester.tap(find.text('매운맛'));
    await tester.pumpAndSettle();
    // 아직 적용 전이다. 목록의 취향은 그대로여야 한다.
    expect(flow.preference.spice, isNot(SpiceLevel.hot));

    await tester.tap(find.text('적용하기'));
    await tester.pumpAndSettle();

    expect(flow.preference.spice, SpiceLevel.hot);
    expect(repo.lastPreference?.spice, SpiceLevel.hot);
    // 시트는 닫히고 목록으로 돌아왔다.
    expect(find.text('적용하기'), findsNothing);
    expect(flow.stage, AppStage.comboList);
  });

  testWidgets('초기화는 시안 기준값으로 되돌린다', (tester) async {
    flow.updatePreference(
      TastePreference(spice: SpiceLevel.hot, maxDeliveryMinutes: 25),
    );
    await pumpList(tester);
    await tapChip(tester, 0);

    await tester.tap(find.text('초기화'));
    await tester.pumpAndSettle();
    // 초기화는 시트 안의 값만 되돌린다 — 아직 목록에 적용하지 않는다.
    expect(flow.preference.spice, SpiceLevel.hot);
    expect(find.text('${TastePreference.resetMinutes}분 이하'), findsOneWidget);

    await tester.tap(find.text('적용하기'));
    await tester.pumpAndSettle();

    expect(flow.preference.spice, TastePreference.resetSpice);
    expect(flow.preference.maxDeliveryMinutes, TastePreference.resetMinutes);
  });

  testWidgets('예상 시간 슬라이더 값이 적용 요청에 전달된다', (tester) async {
    await pumpList(tester);
    await tapChip(tester, 2);

    final slider = find.byType(DeliveryTimeSlider);
    final rect = tester.getRect(slider);
    await tester.tapAt(Offset(rect.left + rect.width * 0.25, rect.center.dy));
    await tester.pumpAndSettle();

    expect(flow.preference.maxDeliveryMinutes, isNot(30));
    await tester.tap(find.text('적용하기'));
    await tester.pumpAndSettle();

    expect(flow.preference.maxDeliveryMinutes, 30);
    expect(repo.lastPreference?.maxDeliveryMinutes, 30);
  });
}
