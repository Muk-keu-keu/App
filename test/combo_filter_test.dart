import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
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

/// 추천 호출 횟수와 넘어온 취향을 기록한다.
class _RecordingRepository implements ComboRepository {
  int calls = 0;
  TastePreference? lastPreference;

  @override
  Future<List<ComboRecommendation>> recommend({
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async {
    calls++;
    lastPreference = preference;
    return [
      ComboRecommendation(
        store: const StoreSummary(
          id: 'store-1',
          name: '두찜-잠실새내점',
          rating: 4.2,
          reviewCount: 312,
          distanceKm: 3.2,
          deliveryMinutes: 40,
          imagePath: 'assets/images/store_dujjim.png',
          minimumOrderAmount: 14000,
          deliveryFee: 1500,
          similarity: 0.9,
        ),
        items: [
          ComboItem(
            id: 'item-1',
            name: '로제 닭발',
            options: '순살',
            unitPrice: 20000,
            quantity: 1,
            imagePath: 'assets/images/menu_rose_dakbal.png',
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<MenuItem>> menu(String storeId) async => const [];
}

const _extraction = ExtractionResult(
  restaurantName: '두찜',
  foodCategory: '한식',
  area: '잠실',
  confidence: 0.9,
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
    });

    test('필터로 열면 취향 설정 화면으로 간다', () {
      flow.openFilter();
      expect(flow.stage, AppStage.keyword);
    });

    test('필터에서 적용하면 AI 를 다시 부르지 않고 추천만 다시 만든다', () async {
      flow.openFilter();
      flow.updatePreference(
        TastePreference(mode: ServingMode.solo, spice: SpiceLevel.hot),
      );

      await flow.applyPreferenceAndAnalyze();

      // 추천은 한 번 다시 불렸고, 바뀐 취향이 그대로 넘어갔다.
      expect(repo.calls, 1);
      expect(repo.lastPreference?.mode, ServingMode.solo);
      expect(repo.lastPreference?.spice, SpiceLevel.hot);

      // 필터를 걸었으니 비교 목록으로 돌아온다.
      expect(flow.stage, AppStage.comboList);
      expect(flow.recommendations, hasLength(1));
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
