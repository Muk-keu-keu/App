import '../models/combo.dart';
import '../models/post.dart';

/// 요기족보 데이터 소스.
///
/// 백엔드가 아직 없어 [MockPostRepository] 가 Figma 시안의 데이터를 그대로 돌려준다.
/// 서버가 붙으면 이 구현체만 갈아끼우면 화면 코드는 그대로다.
/// 메서드는 `docs/api-yogijokbo.md` 의 엔드포인트와 1:1로 대응한다.
abstract class PostRepository {
  /// 1. GET v1/posts
  Future<CursorPage<YogijokboPost>> list({
    required PostSort sort,
    String? cursor,
    int size = 20,
  });

  /// 2. GET v1/posts/{postId}
  Future<YogijokboPost?> detail(String postId);

  /// 3. POST v1/posts — multipart. 서버는 postId 만 돌려준다.
  ///
  /// 조합 내용을 보내지 않는다. [checkoutId] 만 보내면 서버가 결제 스냅샷에서
  /// 읽어 붙인다. 가게가 여러 곳인 결제였으면 글도 묶음 조합으로 만들어진다.
  ///
  /// 본문 키 이름은 `orderId` 다 — 명세 비고 "API 에 나가는 orderId 는 checkout_id 다".
  Future<String> create({
    required int checkoutId,
    required String title,
    required String body,
    List<String> imagePaths = const [],
  });

  /// 4. POST v1/posts/{postId}/likes — 멱등. 변경 후 카운트를 돌려준다.
  Future<({int likeCount, bool likedByMe})> like(String postId);

  /// 5. DELETE v1/posts/{postId}/likes — 멱등. `likedByMe` 는 항상 false.
  Future<({int likeCount, bool likedByMe})> unlike(String postId);

  /// 6. GET v1/posts/{postId}/comments — created_at 오름차순.
  ///
  /// 커서가 없다. 서버가 한 글의 댓글을 한 번에 다 준다 (`{ comments: [...] }`).
  Future<List<PostComment>> comments(String postId);

  /// 7. POST v1/posts/{postId}/comments — 201 CREATED, 본문 없음.
  Future<void> addComment(String postId, String body);

  // ── 명세에 없는 것들 ────────────────────────────────────────────────────────
  // 아래 셋은 시안(922:2734)에 화면이 있는데 `docs/api-yogijokbo.md` 에는
  // 엔드포인트가 없다. 그 문서의 확인 필요 항목 "대댓글·수정·삭제" 가 아직 열려
  // 있다. 경로가 정해지면 Api 구현만 채우면 되도록 자리를 먼저 만들어 둔다.

  /// 족보 수정. 제목과 본문만 고친다 — 조합은 결제 스냅샷이라 바뀌지 않는다.
  Future<void> updatePost(
    String postId, {
    required String title,
    required String body,
  });

  /// 게시물 삭제. 되돌릴 수 없다.
  Future<void> deletePost(String postId);

  /// 댓글 삭제. 되돌릴 수 없다.
  Future<void> deleteComment(String postId, String commentId);
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
  Future<CursorPage<YogijokboPost>> list({
    required PostSort sort,
    String? cursor,
    int size = 20,
  }) async {
    await _wait;

    final result = [..._posts];

    result.sort(switch (sort) {
      PostSort.popular => (a, b) => b.likeCount.compareTo(a.likeCount),
      PostSort.latest => (a, b) => b.createdAt.compareTo(a.createdAt),
    });

    // cursor 는 앞에서 몇 개를 건너뛸지로 흉내낸다. 서버는 불투명 문자열을 주므로
    // 화면은 값의 모양에 기대지 않고 그대로 되돌려주기만 한다.
    final start = int.tryParse(cursor ?? '') ?? 0;
    final page = result.skip(start).take(size).toList();
    final next = start + page.length;

    return CursorPage(
      items: page.map((p) => p.copy()).toList(),
      nextCursor: next < result.length ? '$next' : null,
    );
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
    return [...(_comments[postId] ??= _sampleComments(postId))];
  }

  @override
  Future<void> addComment(String postId, String body) async {
    await _wait;
    final list = _comments[postId] ??= _sampleComments(postId);
    list.add(
      PostComment(
        id: 'local_${++_commentSeq}',
        author: const PostAuthor(id: 'me', nickname: '나'),
        body: body,
        // createdAt 은 호출 시각. 목록 정렬용이라 실제 시각이 필요하다.
        createdAt: DateTime.now(),
      ),
    );
    for (final post in _posts) {
      if (post.id == postId) post.commentCount = list.length;
    }
  }

  @override
  Future<void> updatePost(
    String postId, {
    required String title,
    required String body,
  }) async {
    await _wait;
    for (final post in _posts) {
      if (post.id != postId) continue;
      post.title = title;
      post.body = body;
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    await _wait;
    _cache = [for (final p in _posts) if (p.id != postId) p];
    _comments.remove(postId);
  }

  @override
  Future<void> deleteComment(String postId, String commentId) async {
    await _wait;
    final list = _comments[postId];
    if (list == null) return;
    list.removeWhere((c) => c.id == commentId);
    for (final post in _posts) {
      if (post.id == postId) post.commentCount = list.length;
    }
  }

  @override
  Future<({int likeCount, bool likedByMe})> like(String postId) => _setLike(postId, true);

  @override
  Future<({int likeCount, bool likedByMe})> unlike(String postId) =>
      _setLike(postId, false);

  /// 두 엔드포인트 모두 멱등이다. 이미 그 상태면 카운트를 건드리지 않는다.
  Future<({int likeCount, bool likedByMe})> _setLike(String postId, bool on) async {
    for (final post in _posts) {
      if (post.id != postId) continue;
      if (post.likedByMe != on) {
        post.likedByMe = on;
        // 0 미만으로 내려가지 않게 한다 (명세 5번).
        post.likeCount = (post.likeCount + (on ? 1 : -1)).clamp(0, 1 << 30);
      }
      return (likeCount: post.likeCount, likedByMe: post.likedByMe);
    }
    return (likeCount: 0, likedByMe: false);
  }

  @override
  Future<String> create({
    required int checkoutId,
    required String title,
    required String body,
    List<String> imagePaths = const [],
  }) async {
    await _wait;

    // 서버는 checkoutId 로 결제 스냅샷을 읽어 조합을 붙인다. mock 은 그럴 결제
    // 저장소가 없어 첫 샘플의 조합을 빌려 쓴다. 서버가 붙으면 사라질 코드다.
    final template = _posts.first;
    final post = YogijokboPost(
      id: 'local_post_${_posts.length + 1}',
      title: title,
      body: body,
      author: const PostAuthor(id: 'me', nickname: '나'),
      stores: [for (final s in template.stores) s.copy()],
      createdAt: DateTime.now(),
      imagePaths: imagePaths,
      source: template.source,
      commentCount: 0,
    );
    _posts.insert(0, post);
    return post.id;
  }

  // ── 시안 데이터 ────────────────────────────────────────────────────────────
  // Figma "요기족보" 섹션의 홈 목록·조합 상세·주문하기 화면에 나오는 값 그대로다.
  // 첫 글은 매장 하나, 두 번째 글은 **매장 두 곳**이다 — 회의(2026-08-04)에서 족보를
  // 묶음 조합 단위로 바꿨으므로, 목록·상세·주문 화면이 둘 다 그려지는지 봐야 한다.

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
            platform: PostPlatform.youtube,
            title: 'Sub) 로제닭발 먹방! 두찜에서 로제닭발과 중국당면, 치즈 추가 / 닭발 먹방 asmr',
            url: 'https://www.youtube.com/watch?v=demo-rose-dakbal',
          ),
          likeCount: 12,
          commentCount: 4,
          // 로제 닭발 16,000 + 치즈볼 2,000×2 = 음식값 20,000,
          // 배달비 3,000 을 더해 결제 23,000.
          stores: [
            StoreCart(
              restaurant: const Restaurant(
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
                imagePath: 'assets/images/store_dujjim.png',
              ),
              lines: [
                CartLine(
                  menuId: 201001,
                  name: '[원조 K 로제] 로제 닭발',
                  menuType: MenuType.main,
                  price: 16000,
                  quantity: 1,
                  imagePath: 'assets/images/menu_rose_dakbal.png',
                  spiceLevel: SpiceLevel.hot,
                  spiceAdjustable: true,
                  selectedSpice: SpiceLevel.medium,
                  options: const [
                    MenuOption(group: '뼈 / 순살 선택', name: '순살', price: 0, selected: true),
                    MenuOption(group: '사리 추가', name: '분모자', price: 0, selected: true),
                    MenuOption(group: '토핑 추가', name: '치즈몽땅', price: 0, selected: true),
                    MenuOption(group: '사리 추가', name: '납작당면', price: 3000),
                  ],
                ),
                CartLine(
                  menuId: 201002,
                  name: '[사이드] 치즈볼',
                  menuType: MenuType.side,
                  price: 2000,
                  quantity: 2,
                  imagePath: 'assets/images/menu_cheese_ball.png',
                ),
              ],
            ),
          ],
        ),
        YogijokboPost(
          id: 'post_02K3M',
          title: '신상 치르르 치킨에 까르보불닭 조합',
          body: '문복희 따라서 까르보 불닭이랑 같이 먹었는데\n'
              '느끼한거 불닭이 다 잡아줘서 의외로 잘 어울림\n'
              '두 가게에서 시켜야 하는데 한 번에 결제되니까 편해요',
          author: _author2,
          createdAt: DateTime(2026, 7, 5),
          imagePaths: const ['assets/images/store_dujjim.png'],
          source: const PostSource(
            platform: PostPlatform.youtube,
            title: '겉바속촉 KFC 핫크리스피 치르르치킨에 까르보불닭볶음면 먹방! 소세지도 같이',
            url: 'https://www.youtube.com/watch?v=demo-chireureu',
          ),
          likeCount: 32,
          commentCount: 9,
          // 매장 두 곳 조합. 배달비가 2,500 + 2,000 으로 두 번 붙는다.
          stores: [
            StoreCart(
              restaurant: const Restaurant(
                restaurantId: 202,
                name: 'KFC-용산아이파크몰점',
                foodCategory: FoodCategory.chicken,
                area: '한강로동',
                rating: 4.5,
                reviewCount: 892,
                etaMin: 55,
                deliveryFee: 2500,
                minOrderPrice: 12000,
                distanceKm: 8.4,
                imagePath: 'assets/images/store_dujjim.png',
              ),
              lines: [
                CartLine(
                  menuId: 202001,
                  name: '핫크리스피 치르르치킨',
                  menuType: MenuType.main,
                  price: 12000,
                  quantity: 1,
                  imagePath: 'assets/images/menu_rose_dakbal.png',
                  options: const [
                    MenuOption(group: '조각 수', name: '2조각', price: 0, selected: true),
                  ],
                ),
              ],
            ),
            StoreCart(
              restaurant: const Restaurant(
                restaurantId: 203,
                name: '편의점 배달-용산점',
                foodCategory: FoodCategory.snack,
                area: '한강로동',
                rating: 4.1,
                reviewCount: 120,
                etaMin: 25,
                deliveryFee: 2000,
                minOrderPrice: 5000,
                distanceKm: 1.2,
                imagePath: 'assets/images/store_dujjim.png',
              ),
              lines: [
                CartLine(
                  menuId: 203001,
                  name: '까르보불닭볶음면',
                  menuType: MenuType.main,
                  price: 2500,
                  quantity: 2,
                  imagePath: 'assets/images/menu_cheese_ball.png',
                ),
              ],
            ),
          ],
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
