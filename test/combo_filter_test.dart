import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/api/mukbang_api.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/analysis_source.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/preference.dart';
import 'package:mukbang_ttaradamgi/repository/combo_repository.dart';
import 'package:mukbang_ttaradamgi/services/gemini_extractor.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 분석 호출 횟수와 넘어온 취향을 기록한다.
class _RecordingRepository implements ComboRepository {
  int calls = 0;
  TastePreference? lastPreference;

  @override
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async {
    calls++;
    lastPreference = preference;
    return AnalysisResult(
      exactMatches: [
        ComboSuggestion(
          brandName: '두찜',
          restaurant: const Restaurant(
            restaurantId: 101,
            name: '두찜-잠실새내점',
            foodCategory: FoodCategory.korean,
            area: '잠실동',
            rating: 4.2,
            etaMin: 40,
            deliveryFee: 1500,
            minOrderPrice: 14000,
            distanceKm: 3.2,
          ),
          items: [
            CartLine(
              menuId: 101001,
              name: '로제 닭발',
              menuType: MenuType.main,
              price: 20000,
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

const _extraction = ExtractionResult(
  dishes: [
    ExtractedDish(
      name: '로제 닭발',
      brandName: '두찜',
      restaurantName: '두찜-잠실새내점',
      foodCategory: FoodCategory.korean,
    ),
  ],
);

final _source = AnalysisSource.fromUrl(
  url: Uri.parse('https://www.youtube.com/watch?v=demo'),
  rawText: '두찜 로제닭발 먹방',
);

void main() {
  group('필터 다시 적용', () {
    late _RecordingRepository repo;
    late AppFlow flow;

    setUp(() {
      repo = _RecordingRepository();
      flow = AppFlow(repository: repo, locationService: const _NoLocation());
      // 분석이 이미 끝난 상태를 만든다. 필터는 그 뒤에만 열린다.
      flow.extraction = _extraction;
      flow.source = _source;
    });

    test('필터로 열면 취향 설정 화면으로 간다', () {
      flow.openFilter();
      expect(flow.stage, AppStage.keyword);
    });

    test('필터에서 적용하면 AI 를 다시 부르지 않고 분석만 다시 요청한다', () async {
      flow.openFilter();
      flow.updatePreference(
        TastePreference(mode: ServingMode.solo, spice: SpiceLevel.hot),
      );

      await flow.applyPreferenceAndAnalyze();

      // 분석은 한 번 다시 불렸고, 바뀐 취향이 그대로 넘어갔다.
      expect(repo.calls, 1);
      expect(repo.lastPreference?.mode, ServingMode.solo);
      expect(repo.lastPreference?.spice, SpiceLevel.hot);

      // 필터를 걸었으니 비교 목록으로 돌아온다.
      expect(flow.stage, AppStage.comboList);
      expect(flow.suggestions, hasLength(1));
    });

    test('취향은 명세의 preferences 세 필드로 나간다', () async {
      flow.openFilter();
      flow.updatePreference(
        TastePreference(
          mode: ServingMode.healthy,
          spice: SpiceLevel.medium,
          maxDeliveryMinutes: 35,
        ),
      );
      await flow.applyPreferenceAndAnalyze();

      expect(repo.lastPreference?.toJson(), {
        'maxSpiceLevel': 'MEDIUM',
        'maxDeliveryMin': 35,
        // 비건모드가 excludeMeat 로 나가는 유일한 화면 값이다.
        'excludeMeat': true,
      });
    });

    test('한 번 적용하면 필터 모드가 풀린다', () async {
      flow.openFilter();
      await flow.applyPreferenceAndAnalyze();
      expect(flow.stage, AppStage.comboList);

      // 두 번째는 필터가 아니라 실제 분석 경로다. 링크가 없어 실패로 끝난다.
      await flow.applyPreferenceAndAnalyze();
      expect(flow.stage, AppStage.failed);
    });

    test('추출 결과가 없으면 목록으로만 돌아간다', () async {
      flow.extraction = null;
      flow.openFilter();
      await flow.applyPreferenceAndAnalyze();

      expect(repo.calls, 0);
      expect(flow.stage, AppStage.comboList);
    });
  });
}
