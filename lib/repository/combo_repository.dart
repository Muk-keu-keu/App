import '../models/combo.dart';
import '../models/preference.dart';
import '../services/gemini_extractor.dart';
import 'combo_builder.dart';

/// 조합 추천 데이터 소스.
///
/// 백엔드 API가 아직 없어 MockComboRepository 가 Figma 시안의 데이터를 그대로
/// 돌려준다. 서버가 붙으면 이 프로토콜의 구현체만 갈아끼우면 화면 코드는 그대로다.
/// iOS 앱의 ComboRepository 와 같은 계약이므로 API 명세는 한 벌만 쓴다.
abstract class ComboRepository {
  /// 첫 번째 원소가 가장 유사한 조합이다.
  /// thumbnailUrl 은 공유된 게시물의 og:image 로, 결과 카드 이미지에 쓴다.
  Future<List<ComboRecommendation>> recommend({
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  });

  /// 매장이 파는 메뉴 전체. "메뉴 수정하기"에서 항목 추가에 쓴다.
  /// API 로는 GET /stores/{id}/menu.
  Future<List<MenuItem>> menu(String storeId);
}

class MockComboRepository implements ComboRepository {
  const MockComboRepository();

  @override
  Future<List<ComboRecommendation>> recommend({
    required ExtractionResult extraction,
    required String? thumbnailUrl,
    required TastePreference preference,
  }) async {
    // 네트워크 지연을 흉내내 로딩 화면이 보이도록 한다.
    await Future<void>.delayed(const Duration(milliseconds: 900));

    final built = ComboBuilder.build(
      extraction: extraction,
      thumbnailUrl: thumbnailUrl,
      preference: preference,
    );
    final filtered =
        built.where((c) => c.store.deliveryMinutes <= preference.maxDeliveryMinutes).toList();

    // 도착 시간 조건에 맞는 게 없으면 전체를 유사도순으로 준다.
    final result = filtered.isEmpty ? built : filtered;
    result.sort((a, b) => b.store.similarity.compareTo(a.store.similarity));
    return result;
  }

  @override
  Future<List<MenuItem>> menu(String storeId) async => _menus[storeId] ?? const [];

  /// 매장별 판매 메뉴. Figma 시안 항목에 조합에 없는 메뉴를 몇 개 더했다.
  static const Map<String, List<MenuItem>> _menus = {
    'dujjim-jamsil': [
      MenuItem(
        id: 'rose-dakbal',
        name: '[원조 K 로제] 로제 닭발',
        options: '순살, 보통맛, 중국당면, 치즈몽땅 추가, [리뷰 이벤트] 분모자 추가',
        price: 23000,
        imagePath: 'assets/images/menu_rose_dakbal.png',
      ),
      MenuItem(
        id: 'cheese-ball',
        name: '[사이드] 치즈볼',
        options: '모짜렐라 치즈 가득한 쫀득 치즈볼',
        price: 2000,
        imagePath: 'assets/images/menu_cheese_ball.png',
      ),
      MenuItem(
        id: 'dujjim-jjim',
        name: '[대표] 두찜 국물닭발',
        options: '무뼈, 매운맛, 우동사리 추가',
        price: 21000,
        imagePath: 'assets/images/menu_rose_dakbal.png',
      ),
      MenuItem(
        id: 'egg-jjim',
        name: '[사이드] 계란찜',
        options: '부드러운 뚝배기 계란찜',
        price: 3000,
        imagePath: 'assets/images/menu_cheese_ball.png',
      ),
    ],
    'hongmanyeo-songpa': [
      MenuItem(
        id: 'rose-noodle',
        name: '로제국물닭발',
        options: '돼지 껍데기(볶음) 도련, 통뼈, 무뼈닭기반, 통마늘 소스',
        price: 21000,
        imagePath: 'assets/images/menu_rose_dakbal.png',
      ),
      MenuItem(
        id: 'hong-cheese',
        name: '[사이드] 치즈볼',
        options: '모짜렐라 치즈 가득한 쫀득 치즈볼',
        price: 2500,
        imagePath: 'assets/images/menu_cheese_ball.png',
      ),
    ],
    'dujjim-songpa': [
      MenuItem(
        id: 'rose-dakbal-2',
        name: '[원조 K 로제] 로제 닭발',
        options: '순살, 보통맛, 중국당면, 치즈몽땅 추가, [리뷰 이벤트] 분모자 추가',
        price: 16000,
        imagePath: 'assets/images/menu_rose_dakbal.png',
      ),
      MenuItem(
        id: 'songpa-cheese',
        name: '[사이드] 치즈볼',
        options: '모짜렐라 치즈 가득한 쫀득 치즈볼',
        price: 2000,
        imagePath: 'assets/images/menu_cheese_ball.png',
      ),
    ],
  };

  /// 매번 새 인스턴스를 만들어 수량 변경이 다음 분석에 남지 않게 한다.
  static List<ComboRecommendation> _samples() => [
        ComboRecommendation(
          store: const StoreSummary(
            id: 'dujjim-jamsil',
            name: '두찜-잠실새내점',
            rating: 4.2,
            reviewCount: 312,
            distanceKm: 3.2,
            deliveryMinutes: 40,
            imagePath: 'assets/images/store_dujjim.png',
            minimumOrderAmount: 14000,
            deliveryFee: 1500,
            similarity: 0.96,
          ),
          items: [
            _menus['dujjim-jamsil']![0].toComboItem(),
            _menus['dujjim-jamsil']![1].toComboItem(quantity: 2),
          ],
        ),
        ComboRecommendation(
          store: const StoreSummary(
            id: 'hongmanyeo-songpa',
            name: '홍마녀불닭발-송파점',
            rating: 3.8,
            reviewCount: 164,
            distanceKm: 2.8,
            deliveryMinutes: 70,
            imagePath: 'assets/images/store_dujjim.png',
            minimumOrderAmount: 16000,
            deliveryFee: 2000,
            similarity: 0.88,
          ),
          items: [_menus['hongmanyeo-songpa']![0].toComboItem()],
        ),
        ComboRecommendation(
          store: const StoreSummary(
            id: 'dujjim-songpa',
            name: '두찜-송파점',
            rating: 4.2,
            reviewCount: 310,
            distanceKm: 3.2,
            deliveryMinutes: 45,
            imagePath: 'assets/images/store_dujjim.png',
            minimumOrderAmount: 14000,
            deliveryFee: 1500,
            similarity: 0.81,
          ),
          items: [_menus['dujjim-songpa']![0].toComboItem()],
        ),
      ];
}
