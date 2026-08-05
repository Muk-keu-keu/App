/// 명세의 엔드포인트를 그대로 옮긴 얇은 층.
///
/// 여기에는 분기나 계산을 넣지 않는다. 경로·쿼리·본문 모양만 담아서, 명세와
/// 대조할 때 한 눈에 보이게 한다. 판단은 repository 가 한다.
library;

import '../models/analysis_source.dart';
import '../models/combo.dart';
import '../models/order.dart';
import '../models/preference.dart';
import '../services/gemini_extractor.dart';
import 'api_client.dart';

/// 메뉴 조회 응답. 매장과 메뉴가 함께 온다.
class RestaurantMenus {
  const RestaurantMenus({required this.restaurant, required this.menus});

  final Restaurant restaurant;

  /// `MAIN → SIDE → DRINK`, 같은 타입 안에서는 `menuId` 순으로 정렬돼 온다.
  /// 프론트는 이 순서대로 섹션을 나눠 그리면 된다.
  final List<Menu> menus;

  factory RestaurantMenus.fromJson(Map<String, dynamic> json) => RestaurantMenus(
        restaurant: Restaurant.fromJson(
          (json['restaurant'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
        ),
        menus: [
          for (final e in (json['menus'] ?? const []) as List)
            if (e is Map<String, dynamic>) Menu.fromJson(e),
        ],
      );
}

class MukbangApi {
  const MukbangApi(this.client);

  final ApiClient client;

  bool get isConfigured => client.isConfigured;

  /// `POST v1/analyses` — 영상 속 매장·메뉴 매칭 + 유사 조합 추천.
  ///
  /// 결과가 0개여도 에러가 아니라 200 + 빈 배열이다. 호출한 쪽이 빈 결과를 화면으로
  /// 다뤄야 한다.
  Future<AnalysisResult> analyze({
    required AnalysisSource source,
    required ExtractionResult extraction,
    required TastePreference preference,
  }) async {
    final json = await client.post('v1/analyses', body: {
      'source': source.toJson(),
      'extracted': extraction.toJson(),
      'preferences': preference.toJson(),
    });
    return AnalysisResult.fromJson(json);
  }

  /// `GET v1/restaurants/{restaurantId}/menus` — 식당 전체 메뉴. 읽기 전용이다.
  ///
  /// 404 는 그 `restaurantId` 가 없을 때만 온다. 배달권역 밖이라도 200 이다.
  Future<RestaurantMenus> restaurantMenus(int restaurantId) async {
    final json = await client.get('v1/restaurants/$restaurantId/menus');
    return RestaurantMenus.fromJson(json);
  }

  /// `GET v1/orders` — 내 결제 목록. 카드 하나 = 결제 하나 = 영상 하나.
  Future<OrderPage> orders({String? cursor, int size = 20}) async {
    final json = await client.get('v1/orders', query: {'cursor': cursor, 'size': size});
    return OrderPage.fromJson(json);
  }

  /// `GET v1/orders/{checkoutId}` — 결제 내역 상세.
  Future<OrderDetail> orderDetail(int checkoutId) async {
    final json = await client.get('v1/orders/$checkoutId');
    return OrderDetail.fromJson(json);
  }

  /// `POST v1/orders` — 결제하기.
  ///
  /// **가게가 여러 곳이어도 요청은 한 번이다.** 전체 합계는 보내지 않는다 —
  /// 주문이 가게 단위로 쪼개져 저장되므로 넣어둘 자리가 없다.
  ///
  /// 응답은 가게 이름만 온다. `orderId` 를 주지 않아 완료 화면은 목록으로만 갈 수 있다.
  Future<OrderReceipt> createOrder(Cart cart) async {
    final json = await client.post('v1/orders', body: cart.toOrderJson());
    return OrderReceipt.fromJson(json);
  }
}
