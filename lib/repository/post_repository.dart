import '../api/api_client.dart';
import '../api/mukbang_api.dart';
import '../models/combo.dart';
import '../models/post.dart';

/// 수정 후 남을 사진 한 장.
///
/// `PATCH v1/posts/{id}` 는 남길 사진을 **전부 파일로** 받는다. 그래서 이미 올라가
/// 있던 사진과 새로 고른 사진을 한 목록에 순서대로 담아야 한다 — 보낸 순서가 그대로
/// 새 표시 순서가 된다.
sealed class PostImage {
  const PostImage();

  /// 그대로 남길 사진. 앱은 URL 로만 알고 있어서 다시 받아 올려야 한다.
  const factory PostImage.kept(String url) = KeptPostImage;

  /// 새로 고른 기기 안의 사진.
  const factory PostImage.picked(String path) = PickedPostImage;
}

class KeptPostImage extends PostImage {
  const KeptPostImage(this.url);

  final String url;
}

class PickedPostImage extends PostImage {
  const PickedPostImage(this.path);

  final String path;
}

/// 남길 사진을 다시 받아 오지 못해 수정을 멈춘 상태.
///
/// 그대로 보내면 서버가 그 사진을 지운다. 사용자가 건드리지도 않은 사진이 사라지는
/// 것보다 저장을 실패시키는 쪽이 낫다.
class PostImagesUnavailableException implements Exception {
  const PostImagesUnavailableException();

  @override
  String toString() => 'PostImagesUnavailableException — 남길 사진을 다시 받지 못했습니다';
}

/// 요기족보 데이터 소스.
///
/// `.env` 에 `API_BASE_URL` 이 있으면 [ApiPostRepository], 없으면 시안 데이터를
/// 돌려주는 [MockPostRepository] 가 꽂힌다. 화면 코드는 둘을 구분하지 않는다.
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
  /// 필드 이름은 `checkoutId` 다 (2026-08-09 서버 확인 — 명세의 `orderId` 가 아니다).
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

  /// 7. POST v1/posts/{postId}/comments — 201.
  ///
  /// **갱신된 댓글 목록 전체를 돌려준다** (2026-08-09 서버 확인). 서버가 매긴
  /// id·작성시각을 알기 위해 목록을 다시 받을 필요가 없다.
  Future<List<PostComment>> addComment(String postId, String body);

  // ── 8~10. 명세 표에 늦게 들어온 것들 ────────────────────────────────────────
  // 시안(922:2734)의 수정·삭제 화면에 필요한 세 경로다. 삭제 둘은 2026-08-09 에
  // 존재를 확인했고, 수정은 2026-08-10 에 형식(multipart)까지 받았다.

  /// 8. PATCH v1/posts/{postId} — multipart.
  ///
  /// 조합은 결제 스냅샷이라 바뀌지 않는다. 제목·본문·사진만 고친다.
  ///
  /// [images] 는 **수정 후 남을 사진 전부**다. 안 보내면 사진이 전부 지워진다.
  /// 제목만 고칠 때도 지금 붙어 있는 사진을 그대로 다시 넘겨야 한다.
  Future<void> updatePost(
    String postId, {
    required String title,
    required String body,
    List<PostImage> images = const [],
  });

  /// 게시물 삭제. 되돌릴 수 없다.
  Future<void> deletePost(String postId);

  /// 댓글 삭제. 되돌릴 수 없다.
  Future<void> deleteComment(String postId, String commentId);
}

/// 실제 서버를 쓰는 구현. 판단 없이 [MukbangApi] 로 넘긴다.
class ApiPostRepository implements PostRepository {
  const ApiPostRepository(this._api);

  final MukbangApi _api;

  @override
  Future<CursorPage<YogijokboPost>> list({
    required PostSort sort,
    String? cursor,
    int size = 20,
  }) =>
      _api.posts(sort: sort, cursor: cursor, size: size);

  /// 없는 글이면 404 다. 화면은 "글이 사라졌다" 를 null 로 다룬다.
  @override
  Future<YogijokboPost?> detail(String postId) async {
    try {
      return await _api.post(postId);
    } on ApiException catch (e) {
      if (e.isNotFound) return null;
      rethrow;
    }
  }

  @override
  Future<String> create({
    required int checkoutId,
    required String title,
    required String body,
    List<String> imagePaths = const [],
  }) =>
      _api.createPost(
        checkoutId: checkoutId,
        title: title,
        body: body,
        images: [for (final path in imagePaths) UploadImage.file(path)],
      );

  @override
  Future<({int likeCount, bool likedByMe})> like(String postId) =>
      _api.likePost(postId);

  @override
  Future<({int likeCount, bool likedByMe})> unlike(String postId) =>
      _api.unlikePost(postId);

  @override
  Future<List<PostComment>> comments(String postId) => _api.postComments(postId);

  /// 작성 응답이 갱신된 목록을 준다. 비어 있으면 응답 모양이 바뀐 것이므로
  /// 목록을 다시 받는다 — 방금 쓴 댓글이 화면에서 사라지는 것보다 낫다.
  @override
  Future<List<PostComment>> addComment(String postId, String body) async {
    final updated = await _api.createPostComment(postId, body);
    return updated.isEmpty ? _api.postComments(postId) : updated;
  }

  /// 남길 사진을 파일로 다시 보내야 해서, URL 로만 아는 사진은 먼저 받아 온다.
  ///
  /// 한 장이라도 못 받으면 요청을 보내지 않고 던진다. 그대로 보내면 서버가 그 사진을
  /// 지우기 때문이다 — 사용자가 건드리지도 않은 사진이 사라진다.
  @override
  Future<void> updatePost(
    String postId, {
    required String title,
    required String body,
    List<PostImage> images = const [],
  }) async {
    final parts = <UploadImage>[];
    for (final (index, image) in images.indexed) {
      switch (image) {
        case PickedPostImage(:final path):
          parts.add(UploadImage.file(path));
        case KeptPostImage(:final url):
          final bytes = await _api.downloadImage(url);
          if (bytes == null) throw const PostImagesUnavailableException();
          parts.add(UploadImage.bytes(bytes, filename: _keptFilename(url, index)));
      }
    }

    await _api.updatePost(postId, title: title, body: body, images: parts);
  }

  /// 되보내는 사진의 파일 이름. 확장자로 파트의 Content-Type 이 정해지므로
  /// URL 의 마지막 조각을 살린다. 쿼리스트링이 붙어 있으면 떼고, 확장자가 없으면
  /// jpg 로 둔다 — 서버가 받는 네 형식 중 가장 흔하다.
  static String _keptFilename(String url, int index) {
    final last = Uri.tryParse(url)?.pathSegments.lastOrNull ?? '';
    final clean = last.split('?').first;
    return clean.contains('.') ? clean : 'kept_$index.jpg';
  }

  @override
  Future<void> deletePost(String postId) => _api.deletePost(postId);

  @override
  Future<void> deleteComment(String postId, String commentId) =>
      _api.deletePostComment(postId, commentId);
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

  /// 서버처럼 갱신된 목록 전체를 돌려준다.
  @override
  Future<List<PostComment>> addComment(String postId, String body) async {
    await _wait;
    final list = _comments[postId] ??= _sampleComments(postId);
    list.add(
      PostComment(
        id: 'local_${++_commentSeq}',
        author: const PostAuthor(id: 'me', nickname: '나'),
        body: body,
        // createdAt 은 호출 시각. 목록 정렬용이라 실제 시각이 필요하다.
        createdAt: DateTime.now(),
        mine: true,
      ),
    );
    for (final post in _posts) {
      if (post.id == postId) post.commentCount = list.length;
    }
    return [...list];
  }

  /// [images] 는 받아만 두고 쓰지 않는다. 더미 글의 사진은 번들 에셋이라 지우거나
  /// 순서를 바꿀 대상이 없다. 서버에서는 이 목록이 사진 전체를 대체한다.
  @override
  Future<void> updatePost(
    String postId, {
    required String title,
    required String body,
    List<PostImage> images = const [],
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
      mine: true,
    );
    _posts.insert(0, post);
    return post.id;
  }

  // ── 시안 데이터 ────────────────────────────────────────────────────────────
  // 발표용 네 글을 앞에 두고, Figma 검증용 두 글을 뒤에 남긴다. 발표용 글은 카드,
  // 상세 사진, "주문한 메뉴"가 같은 음식을 가리키도록 각각 별도 이미지와 조합을 갖는다.
  // Figma 글의 첫 글은 매장 하나, 두 번째 글은 **매장 두 곳**이다 — 회의(2026-08-04)
  // 에서 족보를 묶음 조합 단위로 바꿨으므로 목록·상세·주문 화면 검증에 계속 쓴다.
  //
  // 글과 댓글을 모두 `mine: true` 로 둔다. 시연에서 수정·삭제 화면(922:2734)까지
  // 보여줘야 하기 때문이다. 서버가 붙으면 실제 소유 여부가 내려온다.

  static const _author1 = PostAuthor(id: 'user_01', nickname: '배고픈 요기요');
  static const _author2 = PostAuthor(id: 'user_02', nickname: '문복희팬');
  static const _demoAuthor = PostAuthor(id: 'demo_yunsu', nickname: '먹잘알 윤수');

  static StoreCart _demoStore({
    required int id,
    required String name,
    required FoodCategory category,
    required String area,
    required int deliveryFee,
    required String imagePath,
    required List<CartLine> lines,
  }) =>
      StoreCart(
        restaurant: Restaurant(
          restaurantId: id,
          name: name,
          foodCategory: category,
          area: area,
          rating: 4.8,
          reviewCount: 842,
          etaMin: 35,
          deliveryFee: deliveryFee,
          minOrderPrice: 12000,
          distanceKm: 1.2,
          imagePath: imagePath,
        ),
        lines: lines,
      );

  static CartLine _demoLine({
    required int id,
    required String name,
    required int price,
    required String imagePath,
    MenuType type = MenuType.main,
    SpiceLevel spice = SpiceLevel.none,
  }) =>
      CartLine(
        menuId: id,
        name: name,
        menuType: type,
        price: price,
        quantity: 1,
        imagePath: imagePath,
        spiceLevel: spice,
      );

  static List<YogijokboPost> _samples() => [
        YogijokboPost(
          id: 'demo_rose_chicken',
          title: '로제엽떡과 허니콤보 치팅 조합',
          body: '꾸덕한 로제소스에 바삭달콤한 허니콤보를 찍어 먹으면 '
              '단짠매콤 밸런스가 완벽해요.\n'
              '떡볶이에는 소시지랑 치즈를 넉넉히, 치킨은 소스 묻기 전에 한입 먹고 '
              '찍먹하면 두 가지 맛을 다 즐길 수 있어요. 친구들이랑 먹기 좋은 조합!',
          author: _demoAuthor,
          createdAt: DateTime(2026, 8, 16, 12, 30),
          imagePaths: const [
            'assets/images/jokbo_demo_rose_tteokbokki_chicken.jpg',
          ],
          source: const PostSource(
            platform: PostPlatform.instagram,
            title: '꾸덕한 로제떡볶이와 허니치킨 먹방',
            url: 'https://www.instagram.com/reel/demo-rose-chicken/',
          ),
          likeCount: 98,
          mine: true,
          stores: [
            _demoStore(
              id: 800,
              name: '동대문엽기떡볶이 삼성점',
              category: FoodCategory.snack,
              area: '삼성동',
              deliveryFee: 0,
              imagePath: 'assets/images/jokbo_demo_rose_tteokbokki_chicken.jpg',
              lines: [
                _demoLine(
                  id: 80004,
                  name: '로제떡볶이',
                  price: 16000,
                  imagePath: 'assets/images/jokbo_demo_rose_tteokbokki_chicken.jpg',
                  spice: SpiceLevel.medium,
                ),
              ],
            ),
            _demoStore(
              id: 300,
              name: '교촌치킨 신사점',
              category: FoodCategory.chicken,
              area: '신사동',
              deliveryFee: 0,
              imagePath: 'assets/images/jokbo_demo_rose_tteokbokki_chicken.jpg',
              lines: [
                _demoLine(
                  id: 30003,
                  name: '허니콤보',
                  price: 23000,
                  imagePath: 'assets/images/jokbo_demo_rose_tteokbokki_chicken.jpg',
                ),
              ],
            ),
          ],
        ),
        YogijokboPost(
          id: 'demo_udon_tonkatsu',
          title: '우삼겹 우동전골과 바삭 돈카츠',
          body: '스키야키 영상 보고 우삼겹우동전골로 따라 먹어봤어요.\n'
              '국물은 뜨끈하고 우삼겹은 부드러운데, 바삭한 돈카츠까지 곁들이니 '
              '식감 조합이 딱이에요. 전골 먼저 먹고 남은 국물에 우동까지 싹 비우는 순서 추천!',
          author: _demoAuthor,
          createdAt: DateTime(2026, 8, 16, 11, 40),
          imagePaths: const ['assets/images/jokbo_demo_udon_tonkatsu.jpg'],
          source: const PostSource(
            platform: PostPlatform.instagram,
            title: '입에서 녹는 스키야키와 바삭한 돈카츠',
            url: 'https://www.instagram.com/reel/demo-udon-tonkatsu/',
          ),
          likeCount: 84,
          mine: true,
          stores: [
            _demoStore(
              id: 902,
              name: '미소야 선릉점',
              category: FoodCategory.japanese,
              area: '선릉동',
              deliveryFee: 3000,
              imagePath: 'assets/images/jokbo_demo_udon_tonkatsu.jpg',
              lines: [
                _demoLine(
                  id: 90204,
                  name: '우삼겹우동전골',
                  price: 12000,
                  imagePath: 'assets/images/jokbo_demo_udon_tonkatsu.jpg',
                ),
                _demoLine(
                  id: 90202,
                  name: '돈카츠 정식',
                  price: 14500,
                  imagePath: 'assets/images/jokbo_demo_udon_tonkatsu.jpg',
                ),
              ],
            ),
          ],
        ),
        YogijokboPost(
          id: 'demo_tuna_porridge',
          title: '참치야채죽으로 속 편한 한 끼',
          body: '늦은 밤이라 자극적인 메뉴 대신 참치야채죽으로 골랐어요.\n'
              '참치의 고소함과 잘게 썬 채소가 어울려 심심하지 않고, 김가루와 깨를 '
              '섞으니 끝까지 맛있어요. 속 편한 야식이나 다음 날 아침 메뉴로 추천합니다.',
          author: _demoAuthor,
          createdAt: DateTime(2026, 8, 16, 10, 55),
          imagePaths: const ['assets/images/jokbo_demo_tuna_porridge.jpg'],
          source: const PostSource(
            platform: PostPlatform.instagram,
            title: '속 편하고 든든한 참치야채죽',
            url: 'https://www.instagram.com/reel/demo-tuna-porridge/',
          ),
          likeCount: 71,
          mine: true,
          stores: [
            _demoStore(
              id: 1203,
              name: '본죽 신사점',
              category: FoodCategory.korean,
              area: '신사동',
              deliveryFee: 2000,
              imagePath: 'assets/images/jokbo_demo_tuna_porridge.jpg',
              lines: [
                _demoLine(
                  id: 120305,
                  name: '참치야채죽',
                  price: 13000,
                  imagePath: 'assets/images/jokbo_demo_tuna_porridge.jpg',
                ),
              ],
            ),
          ],
        ),
        YogijokboPost(
          id: 'demo_rose_tteokbokki',
          title: '꾸덕한 로제떡볶이 치즈 필수',
          body: '맵찔이도 부담 없이 먹기 좋은 크리미한 로제떡볶이예요.\n'
              '쫀득한 떡에 소스가 잘 배고 치즈가 매운맛을 잡아줘서 계속 손이 갑니다. '
              '소시지와 어묵까지 골라 먹는 재미가 있고, 남은 소스에는 주먹밥 비벼 먹는 걸 추천해요.',
          author: _demoAuthor,
          createdAt: DateTime(2026, 8, 16, 10, 10),
          imagePaths: const ['assets/images/jokbo_demo_rose_tteokbokki.jpg'],
          source: const PostSource(
            platform: PostPlatform.instagram,
            title: '치즈 듬뿍 꾸덕한 로제떡볶이 먹방',
            url: 'https://www.instagram.com/reel/demo-rose-tteokbokki/',
          ),
          likeCount: 63,
          mine: true,
          stores: [
            _demoStore(
              id: 801,
              name: '동대문엽기떡볶이 삼성점',
              category: FoodCategory.snack,
              area: '삼성동',
              deliveryFee: 3000,
              imagePath: 'assets/images/jokbo_demo_rose_tteokbokki.jpg',
              lines: [
                _demoLine(
                  id: 80104,
                  name: '로제떡볶이',
                  price: 16000,
                  imagePath: 'assets/images/jokbo_demo_rose_tteokbokki.jpg',
                  spice: SpiceLevel.medium,
                ),
              ],
            ),
          ],
        ),
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
          mine: true,
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
          mine: true,
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
        mine: true,
      ),
      PostComment(
        id: 'c2',
        author: _author1,
        body: '둘 다 맛있는데 분모자가 소스 더 잘 배어요!',
        createdAt: DateTime(2026, 7, 7, 13, 20),
        mine: true,
      ),
      PostComment(
        id: 'c3',
        author: const PostAuthor(id: 'u4', nickname: '맵찔이탈출'),
        body: '치즈 추가 꿀팁 감사합니다 저도 시켜봤어요',
        createdAt: DateTime(2026, 7, 7, 18, 41),
        mine: true,
      ),
      PostComment(
        id: 'c4',
        author: const PostAuthor(id: 'u5', nickname: '주먹밥장인'),
        body: '주먹밥 같이 먹으니까 진짜 다르네요',
        createdAt: DateTime(2026, 7, 8, 9, 15),
        mine: true,
      ),
    ];
  }
}
