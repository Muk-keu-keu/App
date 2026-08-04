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
      expect(SpiceSelection.none.wire, 'NONE');
      expect(SpiceSelection.medium.wire, 'MEDIUM');
      expect(SpiceSelection.hot.wire, 'HOT');
      expect(SpiceSelection.fromWire(null), isNull);
      expect(SpiceSelection.fromWire('MEDIUM'), SpiceSelection.medium);
      // 명세에 없는 값이 와도 터지지 않는다.
      expect(SpiceSelection.fromWire('EXTREME'), isNull);
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
        orderId: 'order_5001',
        title: '제목',
        body: '본문',
      );

      expect(postId, isNotEmpty);
      // 돌려받은 id 로 상세를 받을 수 있어야 한다.
      expect(await repo.detail(postId), isNotNull);
    });

    test('작성 후 그 postId 의 상세로 이동한다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final flow = makeFlow(repo);
      flow.composeOrderId = 'order_5001';

      await flow.submitPost(title: '내 조합', body: '본문');

      expect(flow.stage, AppStage.jokboDetail);
      expect(flow.selectedPost?.title, '내 조합');
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
    test('상세의 조합을 복사해 주문 화면으로 간다', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final flow = makeFlow(repo);
      await flow.openPost('post_01H8X');

      await flow.startReorder();

      expect(flow.stage, AppStage.jokboOrder);
      expect(flow.orderCombo, isNotNull);

      // 복사본이라 주문 화면에서 수량을 바꿔도 게시글 스냅샷은 그대로다.
      final itemId = flow.orderCombo!.items.first.id;
      final snapshotBefore = flow.selectedPost!.combo.items.first.quantity;
      flow.changeOrderQuantity(itemId: itemId, delta: 1);

      expect(flow.selectedPost!.combo.items.first.quantity, snapshotBefore);
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
      final item = ComboItem(
        id: 'i1',
        name: '로제 닭발',
        options: '순살',
        unitPrice: 20000,
        quantity: 2,
        imagePath: 'assets/images/menu_rose_dakbal.png',
        optionsPrice: 3000,
      );

      expect(item.lineTotal, 46000);
    });

    test('payableTotal 은 주문 금액 + 배달비', () async {
      final repo = MockPostRepository(delay: Duration.zero);
      final post = (await repo.detail('post_01H8X'))!;

      expect(
        post.combo.payableTotal,
        post.combo.itemsTotal + post.combo.store.deliveryFee,
      );
    });
  });
}
