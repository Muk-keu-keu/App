import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/post.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// `docs/api-yogijokbo.md` (확정) 의 계약을 잠근다.
///
/// 서버가 붙기 전이라 실제 HTTP 를 칠 수 없다. 대신 wire 값과 응답 모양,
/// 그리고 명세가 바꾼 흐름(좋아요 분리·전용 reorder 없음)을 검사한다.
void main() {
  AppFlow makeFlow(PostRepository repo) =>
      AppFlow(locationService: const _NoLocation(), postRepository: repo);

  group('wire 값', () {
    test('정렬은 LATEST / POPULAR', () {
      expect(PostSort.latest.wire, 'LATEST');
      expect(PostSort.popular.wire, 'POPULAR');
    });

    test('플랫폼은 INSTAGRAM / YOUTUBE', () {
      expect(PostPlatform.instagram.wire, 'INSTAGRAM');
      expect(PostPlatform.youtube.wire, 'YOUTUBE');
      expect(PostPlatform.fromWire('instagram'), PostPlatform.instagram);
    });

    test('맵기는 NONE / MEDIUM / HOT 3단계이고 null 을 허용한다', () {
      expect(SpiceLevel.none.wire, 'NONE');
      expect(SpiceLevel.medium.wire, 'MEDIUM');
      expect(SpiceLevel.hot.wire, 'HOT');
      expect(SpiceLevel.fromWire(null), isNull);
      expect(SpiceLevel.fromWire('MEDIUM'), SpiceLevel.medium);
      // 명세에 없는 값이 와도 터지지 않는다.
      expect(SpiceLevel.fromWire('EXTREME'), isNull);
    });
  });

  group('1번 목록 — cursor 페이지네이션', () {
    test('size 만큼만 주고 다음 커서를 함께 준다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final first = await repo.list(sort: PostSort.latest, size: 1);

      expect(first.items, hasLength(1));
      expect(first.nextCursor, isNotNull);
      expect(first.hasMore, isTrue);
    });

    test('마지막 페이지의 nextCursor 는 null', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final all = await repo.list(sort: PostSort.latest, size: 100);

      expect(all.nextCursor, isNull);
      expect(all.hasMore, isFalse);
    });

    test('커서로 이어 받으면 목록이 누적된다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final flow = makeFlow(repo);

      await flow.loadPosts();
      final firstCount = flow.posts.length;

      // 한 장씩 받도록 커서를 직접 이어 본다.
      final page = await repo.list(sort: flow.postSort, size: 1);
      expect(page.items, hasLength(1));
      final next = await repo.list(sort: flow.postSort, cursor: page.nextCursor, size: 1);
      expect(next.items.first.id, isNot(page.items.first.id));
      expect(firstCount, greaterThanOrEqualTo(2));
    });
  });

  group('2번 상세 — orderableHere 를 목록에서 물려받는다', () {
    test('상세 응답에 없는 값을 목록에서 채운다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final flow = makeFlow(repo);

      await flow.loadPosts();
      final blocked = flow.posts.firstWhere((p) => !p.orderableHere);

      await flow.openPost(blocked.id);
      expect(flow.selectedPost?.orderableHere, isFalse);
    });
  });

  group('3번 작성 — postId 만 돌려준다', () {
    test('조합을 보내지 않고 orderId 로 만든다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final postId = await repo.create(
        checkoutId: 7002,
        title: '제목',
        body: '본문',
      );

      expect(postId, isNotEmpty);
      // 돌려받은 id 로 상세를 받을 수 있어야 한다.
      expect(await repo.detail(postId), isNotNull);
    });

    test('작성 후 주문내역으로 돌아가고 postId 를 돌려준다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final flow = makeFlow(repo);
      flow.composeCheckoutId = 7002;

      final postId = await flow.submitPost(title: '내 조합', body: '본문');

      // 화면 이동은 시안 952:5089 대로 주문내역이다. 방금 쓴 글로는
      // 토스트의 "보러가기" 로만 가므로, 그 이동에 쓸 id 가 나와야 한다.
      expect(flow.stage, AppStage.orders);
      expect(postId, isNotNull);
      expect(await repo.detail(postId!), isNotNull);
    });
  });

  group('4·5번 좋아요 — 두 엔드포인트로 나뉘고 멱등이다', () {
    test('like 를 두 번 불러도 카운트가 한 번만 오른다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final before = (await repo.detail('post_01H8X'))!.likeCount;

      final first = await repo.like('post_01H8X');
      final again = await repo.like('post_01H8X');

      expect(first.likeCount, before + 1);
      expect(again.likeCount, before + 1);
      expect(again.likedByMe, isTrue);
    });

    test('unlike 는 likedByMe 를 항상 false 로 주고 0 미만으로 내려가지 않는다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      await repo.unlike('post_01H8X');
      final result = await repo.unlike('post_01H8X');

      expect(result.likedByMe, isFalse);
      expect(result.likeCount, greaterThanOrEqualTo(0));
    });
  });

  group('6·7번 댓글', () {
    test('작성 응답에 본문이 없어 다시 받아온다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final flow = makeFlow(repo);
      await flow.openPost('post_01H8X');
      final before = flow.postComments.length;

      await flow.submitComment('명세대로 다시 받아오는지');

      expect(flow.postComments.length, before + 1);
      expect(flow.postComments.last.body, '명세대로 다시 받아오는지');
      expect(flow.selectedPost?.commentCount, flow.postComments.length);
    });

    test('cursor 로 이어 받는다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final first = await repo.comments('post_01H8X', size: 2);

      expect(first.items, hasLength(2));
      expect(first.nextCursor, isNotNull);

      final next = await repo.comments('post_01H8X', cursor: first.nextCursor, size: 2);
      expect(next.items.first.id, isNot(first.items.first.id));
    });
  });

  group('나도 주문하기 — 전용 API 가 없다', () {
    test('게시글의 조합을 복사해 장바구니로 간다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final flow = makeFlow(repo);
      await flow.openPost('post_01H8X');

      await flow.startReorder();

      expect(flow.stage, AppStage.jokboOrder);
      expect(flow.cart.isNotEmpty, isTrue);

      // 복사본이라 장바구니에서 수량을 바꿔도 게시글 스냅샷은 그대로다.
      final store = flow.cart.stores.first;
      final snapshotBefore = flow.selectedPost!.stores.first.lines.first.quantity;
      flow.changeCartQuantity(
        restaurantId: store.restaurantId,
        menuId: store.lines.first.menuId,
        delta: 1,
      );

      expect(
        flow.selectedPost!.stores.first.lines.first.quantity,
        snapshotBefore,
      );
    });

    test('배달 불가 글은 주문 불가로 표시한다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final flow = makeFlow(repo);
      await flow.loadPosts();
      final blocked = flow.posts.firstWhere((p) => !p.orderableHere);

      await flow.openPost(blocked.id);
      await flow.startReorder();

      expect(flow.orderUnavailable, isTrue);
    });
  });

  group('금액', () {
    test('lineTotal 은 (기본가 + 옵션 추가금) × 수량', () {
      final line = CartLine(
        menuId: 1,
        name: '로제 닭발',
        menuType: MenuType.main,
        price: 20000,
        quantity: 2,
        options: const [
          MenuOption(name: '치즈몽땅', price: 3000, selected: true),
        ],
      );

      expect(line.optionsPrice, 3000);
      expect(line.lineTotal, 46000);
    });

    test('payableTotal 은 주문 금액 + 매장별 배달비', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final post = (await repo.detail('post_01H8X'))!;

      final deliveryTotal = post.stores.fold(0, (sum, s) => sum + s.deliveryFee);
      expect(post.payableTotal, post.itemsTotal + deliveryTotal);
    });

    test('매장이 여러 곳이면 배달비가 여러 번 붙는다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final post = (await repo.detail('post_02K3M'))!;

      expect(post.stores.length, 2);
      // 소계의 합이 결제 예상액이다 (명세 5번: 전체 합계는 서버로 보내지 않는다).
      expect(
        post.payableTotal,
        post.stores.fold(0, (sum, s) => sum + s.subtotal),
      );
    });
  });
}
