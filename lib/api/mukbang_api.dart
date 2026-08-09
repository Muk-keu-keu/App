/// 명세의 엔드포인트를 그대로 옮긴 얇은 층.
///
/// 여기에는 분기나 계산을 넣지 않는다. 경로·쿼리·본문 모양만 담아서, 명세와
/// 대조할 때 한 눈에 보이게 한다. 판단은 repository 가 한다.
library;

import '../models/analysis_source.dart';
import '../models/combo.dart';
import '../models/order.dart';
import '../models/post.dart';
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

  // ── 요기족보 ───────────────────────────────────────────────────────────────
  // 2026-08-09 에 서버로 직접 확인한 계약이다. 노션 명세와 다른 곳이 있으면
  // 이쪽이 기준이다 (`docs/api-yogijokbo.md` 에 차이를 적어 뒀다).

  /// `GET v1/posts` — 조합 목록. **인증이 없어도 200** 이다. 토큰이 없으면
  /// `liked` 가 전부 false 로 온다.
  Future<CursorPage<YogijokboPost>> posts({
    required PostSort sort,
    String? cursor,
    int size = 20,
  }) async {
    final json = await client.get('v1/posts', query: {
      'sort': sort.wire,
      'cursor': cursor,
      'size': size,
    });
    return CursorPage(
      items: [
        for (final e in (json['posts'] ?? const []) as List)
          if (e is Map<String, dynamic>) YogijokboPost.fromListJson(e),
      ],
      // 커서는 불투명 문자열이다. 숫자로 와도 그대로 되돌려 보낼 수 있게 문자열로 받는다.
      nextCursor: json['nextCursor'] == null ? null : '${json['nextCursor']}',
    );
  }

  /// `GET v1/posts/{postId}` — 게시글 상세. 조합이 `order` 블록으로 온다.
  Future<YogijokboPost> post(String postId) async {
    final json = await client.get('v1/posts/$postId');
    return YogijokboPost.fromDetailJson(json);
  }

  /// `GET v1/posts/{postId}/comments` — `{ comments: [...] }`. 커서가 없다.
  Future<List<PostComment>> postComments(String postId) async {
    final json = await client.get('v1/posts/$postId/comments');
    return _comments(json);
  }

  /// `POST v1/posts/{postId}/comments` — 201. **갱신된 댓글 목록 전체**를 준다.
  Future<List<PostComment>> createPostComment(String postId, String body) async {
    final json = await client.post('v1/posts/$postId/comments', body: {'body': body});
    return _comments(json);
  }

  /// `POST v1/posts/{postId}/likes` — 멱등. 변경 후 카운트를 준다.
  Future<({int likeCount, bool likedByMe})> likePost(String postId) async =>
      _like(await client.post('v1/posts/$postId/likes'));

  /// `DELETE v1/posts/{postId}/likes` — 멱등. `liked` 는 항상 false.
  Future<({int likeCount, bool likedByMe})> unlikePost(String postId) async =>
      _like(await client.delete('v1/posts/$postId/likes'));

  /// `POST v1/posts` — **multipart/form-data**. JSON 이 아니다.
  ///
  /// `restaurantId` 를 받지 않는다. `checkoutId` 하나로 조합이 전부 정해진다.
  /// 한 결제로 두 번 쓰면 `UNIQUE(checkout_id)` 가 막는다.
  Future<String> createPost({
    required int checkoutId,
    required String title,
    required String body,
    List<String> imagePaths = const [],
  }) async {
    final json = await client.multipart(
      'v1/posts',
      fields: {'checkoutId': '$checkoutId', 'title': title, 'body': body},
      filePaths: imagePaths,
    );
    return '${json['postId'] ?? ''}';
  }

  /// `PATCH v1/posts/{postId}` — 제목·본문 수정.
  ///
  /// **형식 미확정.** 라우팅은 되지만 JSON 으로 보내면 415 가 온다 (2026-08-09).
  /// 사진도 함께 교체하는지, multipart 인지 백엔드 회신 대기 중이다. 형식이 오면
  /// 이 한 줄만 고친다.
  Future<void> updatePost(
    String postId, {
    required String title,
    required String body,
  }) =>
      client.patch('v1/posts/$postId', body: {'title': title, 'body': body});

  /// `DELETE v1/posts/{postId}` — 내 글만. 남의 글은 403.
  Future<void> deletePost(String postId) => client.delete('v1/posts/$postId');

  /// `DELETE v1/posts/{postId}/comments/{commentId}` — 내 댓글만. 남의 댓글은 403.
  Future<void> deletePostComment(String postId, String commentId) =>
      client.delete('v1/posts/$postId/comments/$commentId');

  static List<PostComment> _comments(Map<String, dynamic> json) => [
        for (final e in (json['comments'] ?? const []) as List)
          if (e is Map<String, dynamic>) PostComment.fromJson(e),
      ];

  /// 좋아요 응답은 `liked` 로 온다. 앱 모델의 이름은 `likedByMe` 다.
  static ({int likeCount, bool likedByMe}) _like(Map<String, dynamic> json) => (
        likeCount: ((json['likeCount'] ?? 0) as num).toInt(),
        likedByMe: json['liked'] == true,
      );
}
