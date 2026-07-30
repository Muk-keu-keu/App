import '../models/combo.dart';
import '../models/post.dart';
import '../models/user_location.dart';

/// 요기족보 데이터 소스.
///
/// 백엔드가 아직 없어 [MockPostRepository] 가 Figma 시안의 데이터를 그대로 돌려준다.
/// 서버가 붙으면 이 구현체만 갈아끼우면 화면 코드는 그대로다.
/// 메서드는 `docs/api-yogijokbo.md` 의 엔드포인트와 1:1로 대응한다.
abstract class PostRepository {
  /// GET /api/v1/posts
  /// [orderableOnly] 가 true 면 좌표가 필요하다. 좌표가 없으면 필터를 무시한다.
  Future<List<YogijokboPost>> list({
    required PostSort sort,
    bool orderableOnly = false,
    UserLocation? location,
  });

  /// GET /api/v1/posts/{postId}
  Future<YogijokboPost?> detail(String postId);

  /// GET /api/v1/posts/{postId}/comments
  Future<List<PostComment>> comments(String postId);

  /// POST /api/v1/posts/{postId}/comments
  Future<PostComment> addComment(String postId, String body);

  /// POST·DELETE /api/v1/posts/{postId}/likes — 변경 후 카운트를 돌려준다(멱등).
  Future<({int likeCount, bool likedByMe})> toggleLike(String postId);

  /// POST /api/v1/posts/{postId}/reorder
  /// 스냅샷이 지금도 주문 가능한지 현재 시점으로 재확인한다.
  Future<ReorderResult> reorder({required String postId, UserLocation? location});

  /// POST /api/v1/posts — 내 조합을 공유한다.
  Future<YogijokboPost> create({
    required String title,
    required String body,
    required List<String> imagePaths,
    required ComboRecommendation combo,
    PostSource? source,
  });
}

/// "나도 주문하기" 결과. 시안의 주문하기 화면이 이 값으로 그려진다.
class ReorderResult {
  const ReorderResult({
    required this.orderable,
    this.combo,
    this.unavailableItems = const [],
  });

  final bool orderable;

  /// 현재 가격·재고로 다시 계산한 조합.
  final ComboRecommendation? combo;

  /// 담을 수 없는 항목. reason 은 SOLD_OUT / DISCONTINUED / OUT_OF_DELIVERY_AREA.
  final List<({String name, String reason})> unavailableItems;
}

class MockPostRepository implements PostRepository {
  /// [delay] 는 네트워크 지연 흉내다. 로딩 상태가 화면에 보이도록 기본값을 둔다.
  ///
  /// 위젯 테스트는 가짜 시계에서 돌아 `Future.delayed` 가 저절로 진행되지 않는다.
  /// 그래서 테스트는 `Duration.zero` 를 넣어 지연을 끈다.
  MockPostRepository({this.delay = const Duration(milliseconds: 400)});

  final Duration delay;

  /// 지연이 0이면 타이머를 아예 만들지 않는다. `Future.delayed(Duration.zero)` 도
  /// 타이머를 걸기 때문에, 가짜 시계로 돌아가는 위젯 테스트에서는 시간을 진행시키지
  /// 않으면 완료되지 않는다.
  Future<void> get _wait =>
      delay == Duration.zero ? Future<void>.value() : Future<void>.delayed(delay);

  /// 시연 중 좋아요·댓글이 유지되도록 인스턴스에 들고 있는다.
  /// 서버가 붙으면 사라질 상태다.
  List<YogijokboPost>? _cache;
  final Map<String, List<PostComment>> _comments = {};
  int _commentSeq = 0;

  List<YogijokboPost> get _posts => _cache ??= _samples();

  @override
  Future<List<YogijokboPost>> list({
    required PostSort sort,
    bool orderableOnly = false,
    UserLocation? location,
  }) async {
    await _wait;

    var result = [..._posts];

    // 좌표가 없으면 걸러낼 근거가 없다. 필터를 무시하고 전체를 준다 —
    // 빈 목록을 보여주는 것보다 낫고, 화면이 위치 설정을 따로 안내한다.
    if (orderableOnly && location != null) {
      result = result.where((p) => p.orderableHere).toList();
    }

    result.sort(switch (sort) {
      PostSort.popular => (a, b) => b.likeCount.compareTo(a.likeCount),
      PostSort.latest => (a, b) => b.createdAt.compareTo(a.createdAt),
    });
    return result.map((p) => p.copy()).toList();
  }

  /// **복사본을 돌려준다.** 실제 HTTP API 는 매번 새 객체를 주므로 화면이 응답을
  /// 고쳐도 서버 상태가 바뀌지 않는다. mock 이 내부 객체를 그대로 넘기면 화면의
  /// 낙관적 업데이트가 저장소 상태까지 바꿔 버려 같은 변경이 두 번 적용된다.
  @override
  Future<YogijokboPost?> detail(String postId) async {
    await _wait;
    for (final post in _posts) {
      if (post.id == postId) return post.copy();
    }
    return null;
  }

  /// 같은 이유로 리스트도 새로 만들어 준다. 저장소의 리스트를 그대로 주면
  /// 화면이 항목을 더할 때 저장소에도 함께 들어간다.
  @override
  Future<List<PostComment>> comments(String postId) async {
    await _wait;
    return [..._comments[postId] ??= _sampleComments(postId)];
  }

  @override
  Future<PostComment> addComment(String postId, String body) async {
    final list = _comments[postId] ??= _sampleComments(postId);
    final comment = PostComment(
      id: 'local_${++_commentSeq}',
      author: const PostAuthor(id: 'me', nickname: '나'),
      // createdAt 은 호출 시각. 목록 정렬용이라 실제 시각이 필요하다.
      body: body,
      createdAt: DateTime.now(),
    );
    list.add(comment);
    for (final post in _posts) {
      if (post.id == postId) post.commentCount = list.length;
    }
    return comment;
  }

  @override
  Future<({int likeCount, bool likedByMe})> toggleLike(String postId) async {
    for (final post in _posts) {
      if (post.id != postId) continue;
      post.likedByMe = !post.likedByMe;
      post.likeCount += post.likedByMe ? 1 : -1;
      return (likeCount: post.likeCount, likedByMe: post.likedByMe);
    }
    return (likeCount: 0, likedByMe: false);
  }

  @override
  Future<ReorderResult> reorder({required String postId, UserLocation? location}) async {
    await _wait;
    final post = await detail(postId);
    if (post == null) return const ReorderResult(orderable: false);

    // 스냅샷을 복사해서 준다. 주문 화면에서 수량을 바꿔도 게시글은 그대로여야 한다.
    return ReorderResult(orderable: post.orderableHere, combo: post.combo.copy());
  }

  @override
  Future<YogijokboPost> create({
    required String title,
    required String body,
    required List<String> imagePaths,
    required ComboRecommendation combo,
    PostSource? source,
  }) async {
    await _wait;
    final post = YogijokboPost(
      id: 'local_post_${_posts.length + 1}',
      title: title,
      body: body,
      author: const PostAuthor(id: 'me', nickname: '나'),
      combo: combo.copy(),
      createdAt: DateTime.now(),
      imagePaths: imagePaths,
      source: source,
      commentCount: 0,
    );
    _posts.insert(0, post);
    return post.copy();
  }

  // ── 시안 데이터 ────────────────────────────────────────────────────────────
  // Figma "요기족보" 섹션의 홈 목록·조합 상세·주문하기 화면에 나오는 값 그대로다.
  // 가격은 주문하기 화면 기준: 로제 닭발 16,000 + 치즈볼 2,000×2 = 주문 20,000,
  // 배달비 3,000 을 더해 결제 23,000 이 된다.

  static const _author1 = PostAuthor(id: 'user_01', nickname: '배고픈 요기요');
  static const _author2 = PostAuthor(id: 'user_02', nickname: '문복희팬');

  static List<YogijokboPost> _samples() => [
        YogijokboPost(
          id: 'post_01H8X',
          title: '떵개 추천 두찜 로제 닭발',
          body: '분모자랑 치즈 꼭 추가하고 드세요😊\n'
              '맵찔이는 치즈 추가해서 먹어야 딱 적당히 매워서 너무 맛있어요\n'
              '집에 있는 재료로 주먹밥 만들어서 같이 먹는 거 추천',
          author: _author1,
          createdAt: DateTime(2026, 7, 7),
          imagePaths: const [
            'assets/images/menu_rose_dakbal.png',
            'assets/images/store_dujjim.png',
          ],
          source: const PostSource(
            videoTitle: 'Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가 / 닭발 먹방 asmr',
            videoUrl: 'https://www.youtube.com/watch?v=demo-rose-dakbal',
          ),
          likeCount: 12,
          commentCount: 4,
          combo: ComboRecommendation(
            store: const StoreSummary(
              id: 'dujjim-jamsil',
              name: '두찜-잠실새내점',
              rating: 4.2,
              reviewCount: 312,
              distanceKm: 3.2,
              deliveryMinutes: 40,
              imagePath: 'assets/images/store_dujjim.png',
              minimumOrderAmount: 14000,
              deliveryFee: 3000,
              similarity: 1,
            ),
            items: [
              ComboItem(
                id: 'rose-dakbal',
                name: '[원조 K 로제] 로제 닭발',
                options: '순살, 보통맛, 분모자로 변경, 치즈몽땅 추가, [리뷰 이벤트] 납작당면 추가',
                unitPrice: 16000,
                quantity: 1,
                imagePath: 'assets/images/menu_rose_dakbal.png',
              ),
              ComboItem(
                id: 'cheese-ball',
                name: '[사이드] 치즈볼',
                options: '모짜렐라 치즈 가득한 쫀득 치즈볼',
                unitPrice: 2000,
                quantity: 2,
                imagePath: 'assets/images/menu_cheese_ball.png',
              ),
            ],
          ),
        ),
        YogijokboPost(
          id: 'post_02K3M',
          title: '신상 치르르 치킨 미침',
          body: '문복희 따라서 까르보 불닭이랑 같이 먹었는데\n'
              '느끼한거 불닭이 다 잡아줘서 의외로 잘 어울림',
          author: _author2,
          createdAt: DateTime(2026, 7, 5),
          imagePaths: const ['assets/images/store_dujjim.png'],
          source: const PostSource(
            videoTitle: '겉바속촉 KFC 핫크리스피 치르르치킨에 까르보불닭볶음면 먹방! 소세지도 같이',
            videoUrl: 'https://www.youtube.com/watch?v=demo-chireureu',
          ),
          likeCount: 32,
          commentCount: 9,
          // 배달 권역 밖 매장. "내 위치에서 가능한 조합만" 필터가 동작하는지 보이려면
          // 목록에 걸러지는 항목이 하나는 있어야 한다.
          orderableHere: false,
          combo: ComboRecommendation(
            store: const StoreSummary(
              id: 'kfc-yongsan',
              name: 'KFC-용산아이파크몰점',
              rating: 4.5,
              reviewCount: 892,
              distanceKm: 8.4,
              deliveryMinutes: 55,
              imagePath: 'assets/images/store_dujjim.png',
              minimumOrderAmount: 12000,
              deliveryFee: 2500,
              similarity: 1,
            ),
            items: [
              ComboItem(
                id: 'chireureu',
                name: '핫크리스피 치르르치킨',
                options: '2조각, 콜라 변경',
                unitPrice: 12000,
                quantity: 1,
                imagePath: 'assets/images/menu_rose_dakbal.png',
              ),
              ComboItem(
                id: 'carbo',
                name: '까르보불닭볶음면',
                options: '컵라면',
                unitPrice: 2500,
                quantity: 1,
                imagePath: 'assets/images/menu_cheese_ball.png',
              ),
            ],
          ),
        ),
      ];

  static List<PostComment> _sampleComments(String postId) {
    if (postId != 'post_01H8X') return [];
    return [
      PostComment(
        id: 'c1',
        author: const PostAuthor(id: 'u3', nickname: '닭발러버'),
        body: '분모자 진짜 필수인가요? 중국당면이 더 맛있을 것 같은데',
        createdAt: DateTime(2026, 7, 7, 13, 2),
      ),
      PostComment(
        id: 'c2',
        author: _author1,
        body: '둘 다 맛있는데 분모자가 소스 더 잘 배어요!',
        createdAt: DateTime(2026, 7, 7, 13, 20),
      ),
      PostComment(
        id: 'c3',
        author: const PostAuthor(id: 'u4', nickname: '맵찔이탈출'),
        body: '치즈 추가 꿀팁 감사합니다 저도 시켜봤어요',
        createdAt: DateTime(2026, 7, 7, 18, 41),
      ),
      PostComment(
        id: 'c4',
        author: const PostAuthor(id: 'u5', nickname: '주먹밥장인'),
        body: '주먹밥 같이 먹으니까 진짜 다르네요',
        createdAt: DateTime(2026, 7, 8, 9, 15),
      ),
    ];
  }
}
