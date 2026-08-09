import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/post.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

/// 위치 수집이 테스트에 끼어들지 않게 실패로 고정한다.
class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

void main() {
  AppFlow makeFlow() => AppFlow(
        locationService: const _NoLocation(),
        postRepository: MockPostRepository(),
      );

  group('YogijokboPost', () {
    test('날짜를 2026.07.07 형태로 보여준다', () {
      final repo = MockPostRepository();
      return repo.detail('post_01H8X').then((post) {
        expect(post!.dateText, '2026.07.07');
      });
    });

    test('본문 미리보기는 줄바꿈을 공백으로 바꾼다', () async {
      final post = await MockPostRepository().detail('post_01H8X');
      expect(post!.body, contains('\n'));
      expect(post.bodyPreview, isNot(contains('\n')));
    });

    test('조합 금액은 주문금액 + 배달비다 — 시안의 결제 23,000원', () async {
      final post = await MockPostRepository().detail('post_01H8X');
      expect(post!.stores, hasLength(1));
      expect(post.itemsTotal, 20000); // 로제닭발 16,000 + 치즈볼 2,000×2
      expect(post.stores.first.deliveryFee, 3000);
      expect(post.payableTotal, 23000);
    });

    test('매장이 여러 곳인 글은 배달비가 가게마다 붙는다', () async {
      // 회의(2026-08-04)에서 족보를 묶음 조합 단위로 바꿨다.
      final post = await MockPostRepository().detail('post_02K3M');
      expect(post!.stores, hasLength(2));
      expect(post.restaurantNames, hasLength(2));
      expect(post.storeSummary, contains('외 1곳'));

      final deliveryTotal =
          post.stores.fold(0, (sum, s) => sum + s.deliveryFee);
      expect(post.payableTotal, post.itemsTotal + deliveryTotal);
    });
  });

  group('요기족보 목록', () {
    test('인기순은 좋아요가 많은 글이 먼저다', () async {
      final page = await MockPostRepository().list(sort: PostSort.popular);
      expect(page.items.first.likeCount,
          greaterThanOrEqualTo(page.items.last.likeCount));
    });

    test('최신순은 작성일이 늦은 글이 먼저다', () async {
      final page = await MockPostRepository().list(sort: PostSort.latest);
      expect(page.items.first.createdAt.isAfter(page.items.last.createdAt), isTrue);
    });

    test('정렬을 바꾸면 목록을 다시 불러온다', () async {
      final flow = makeFlow();
      await flow.openJokbo();
      expect(flow.postSort, PostSort.popular);
      expect(flow.stage, AppStage.jokboHome);

      await flow.updatePostSort(PostSort.latest);

      expect(flow.postSort, PostSort.latest);
      expect(flow.posts, isNotEmpty);
      expect(flow.postsLoading, isFalse);
    });
  });

  group('조합 상세', () {
    test('글을 열면 댓글까지 채워진다', () async {
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await pumpEventQueue();

      expect(flow.stage, AppStage.jokboDetail);
      expect(flow.selectedPost?.title, '떵개 추천 두찜 로제 닭발');
      expect(flow.postComments, hasLength(4));
    });

    test('좋아요를 누르면 카운트가 오르고 다시 누르면 내려간다', () async {
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      final before = flow.selectedPost!.likeCount;

      await flow.toggleLike();
      expect(flow.selectedPost!.likedByMe, isTrue);
      expect(flow.selectedPost!.likeCount, before + 1);

      await flow.toggleLike();
      expect(flow.selectedPost!.likedByMe, isFalse);
      expect(flow.selectedPost!.likeCount, before);
    });

    test('댓글을 쓰면 목록과 카운트가 함께 늘어난다', () async {
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await pumpEventQueue();
      final before = flow.postComments.length;

      await flow.submitComment('  저도 시켜봤어요  ');

      expect(flow.postComments, hasLength(before + 1));
      expect(flow.postComments.last.body, '저도 시켜봤어요'); // 앞뒤 공백 제거
      expect(flow.selectedPost!.commentCount, before + 1);
    });

    test('빈 댓글은 등록하지 않는다', () async {
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await pumpEventQueue();
      final before = flow.postComments.length;

      await flow.submitComment('   ');

      expect(flow.postComments, hasLength(before));
    });
  });

  group('나도 주문하기', () {
    test('장바구니 수량 변경이 게시글 스냅샷을 건드리지 않는다', () async {
      // api-yogijokbo.md 2번 비고 — 조합은 작성 시점 스냅샷이라 보존돼야 한다.
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await flow.startReorder();

      final store = flow.cart.stores.first;
      final menuId = store.lines.first.menuId;
      final snapshotQuantity = flow.selectedPost!.stores.first.lines.first.quantity;

      flow.changeCartQuantity(
        restaurantId: store.restaurantId,
        menuId: menuId,
        delta: 2,
      );

      expect(flow.cart.stores.first.lines.first.quantity, snapshotQuantity + 2);
      expect(
        flow.selectedPost!.stores.first.lines.first.quantity,
        snapshotQuantity,
      );
    });

    test('수량을 0으로 내리면 항목이 빠진다', () async {
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await flow.startReorder();

      final store = flow.cart.stores.first;
      final before = store.lines.length;
      flow.changeCartQuantity(
        restaurantId: store.restaurantId,
        menuId: store.lines.first.menuId,
        delta: -1, // 1 → 0
      );

      expect(flow.cart.stores.first.lines, hasLength(before - 1));
    });

    test('매장이 여러 곳인 글은 그대로 여러 가게 장바구니가 된다', () async {
      final flow = makeFlow();
      await flow.openPost('post_02K3M');
      await flow.startReorder();

      expect(flow.cart.storeCount, 2);
      expect(flow.cart.deliveryFeeTotal, 4500); // 2,500 + 2,000
    });

    test('출처 영상이 주문 요청에 실린다', () async {
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await flow.startReorder();

      final json = flow.cart.toOrderJson();
      final source = json['source'] as Map<String, dynamic>;
      expect(source['platform'], 'YOUTUBE');
      expect(source['title'], contains('로제닭발'));
    });

    test('뒤로 가면 상세로 돌아간다', () async {
      final flow = makeFlow();
      await flow.openPost('post_02K3M');
      await flow.startReorder();

      flow.backToPostDetail();

      expect(flow.stage, AppStage.jokboDetail);
    });
  });

  group('족보 작성', () {
    test('공유하면 목록 맨 앞에 오고 주문내역으로 돌아간다', () async {
      final repo = MockPostRepository();
      final flow = AppFlow(locationService: const _NoLocation(), postRepository: repo);

      // 작성 화면은 분석 결과 조합을 받아 열린다.
      final seed = await repo.detail('post_01H8X');
      flow.selectedPost = seed;
      // 명세 3번: 조합 내용을 보내지 않는다. checkoutId 하나로 서버가 붙인다.
      flow.composeCheckoutId = 7002;

      final postId =
          await flow.submitPost(title: '내 로제닭발 조합', body: '치즈 두 배가 정답');

      // 시안 952:5089 — 공유하면 방금 쓴 글이 아니라 주문내역으로 간다.
      // 그 글로 가는 길은 화면이 띄우는 토스트의 "보러가기" 뿐이라,
      // 여기서는 이동할 수 있도록 postId 를 돌려주는지까지만 본다.
      expect(flow.stage, AppStage.orders);
      expect(postId, isNotNull);
      expect(flow.composeCheckoutId, isNull); // 작성 상태는 비워진다

      final page = await repo.list(sort: PostSort.latest);
      expect(page.items.first.title, '내 로제닭발 조합');

      // "보러가기" 가 하는 일. 돌려받은 id 로 그 글이 열려야 한다.
      await flow.openPost(postId!);
      expect(flow.stage, AppStage.jokboDetail);
      expect(flow.selectedPost?.title, '내 로제닭발 조합');
    });

    test('제목이 비면 공유하지 않는다', () async {
      final repo = MockPostRepository();
      final flow = AppFlow(locationService: const _NoLocation(), postRepository: repo);
      final seed = await repo.detail('post_01H8X');
      flow.selectedPost = seed;
      flow.composeCheckoutId = 7002;

      await flow.submitPost(title: '   ', body: '본문만 있음');

      // 작성 상태가 남아 있어야 화면에 머문다. 비워지면 상세로 넘어가 버린다.
      expect(flow.composeCheckoutId, 7002);
      expect(flow.stage, isNot(AppStage.jokboDetail));
    });
  });

  // 시안 922:2734. 서버 엔드포인트가 아직 없어 저장소는 mock 뿐이지만,
  // 화면이 기대하는 상태 변화는 여기서 잠가 둔다.
  group('족보 수정·삭제', () {
    Future<AppFlow> openedPost(MockPostRepository repo) async {
      final flow = AppFlow(locationService: const _NoLocation(), postRepository: repo);
      await flow.openJokbo();
      await flow.openPost('post_01H8X');
      return flow;
    }

    test('수정하면 상세와 목록의 제목이 함께 바뀐다', () async {
      final repo = MockPostRepository();
      final flow = await openedPost(repo);

      flow.openPostEdit();
      expect(flow.stage, AppStage.jokboEdit);

      await flow.savePostEdit(title: '고친 제목', body: '고친 본문');

      // 저장하면 상세로 돌아간다.
      expect(flow.stage, AppStage.jokboDetail);
      expect(flow.selectedPost?.title, '고친 제목');
      expect(flow.selectedPost?.body, '고친 본문');

      // 목록에 떠 있던 같은 글도 맞춰져야 한다. 안 그러면 뒤로 갔을 때
      // 옛 제목이 남아 저장이 안 된 것처럼 보인다.
      final listed = flow.posts.where((p) => p.id == 'post_01H8X');
      expect(listed.first.title, '고친 제목');

      // 저장소에도 남아 다시 받아도 같은 값이어야 한다.
      expect((await repo.detail('post_01H8X'))?.title, '고친 제목');
    });

    test('제목이 비면 저장하지 않는다', () async {
      final repo = MockPostRepository();
      final flow = await openedPost(repo);
      final before = flow.selectedPost!.title;

      flow.openPostEdit();
      await flow.savePostEdit(title: '   ', body: '본문만');

      expect(flow.selectedPost?.title, before);
      expect(flow.stage, AppStage.jokboEdit); // 화면에 머문다
    });

    test('게시물을 지우면 목록에서 빠지고 목록 화면으로 나간다', () async {
      final repo = MockPostRepository();
      final flow = await openedPost(repo);

      await flow.deleteCurrentPost();

      // 돌아갈 상세가 없어졌으므로 목록으로 나간다.
      expect(flow.stage, AppStage.jokboHome);
      expect(flow.selectedPost, isNull);
      expect(flow.posts.where((p) => p.id == 'post_01H8X'), isEmpty);
      expect(await repo.detail('post_01H8X'), isNull);
    });

    test('댓글을 지우면 목록과 카운트가 함께 줄어든다', () async {
      final repo = MockPostRepository();
      final flow = await openedPost(repo);

      final before = flow.postComments.length;
      expect(before, greaterThan(0));

      await flow.deleteComment(flow.postComments.first.id);

      expect(flow.postComments.length, before - 1);
      expect(flow.selectedPost?.commentCount, before - 1);
    });
  });

  group('PostSort', () {
    test('wire 값은 대문자다', () {
      expect(PostSort.popular.wire, 'POPULAR');
      expect(PostSort.latest.wire, 'LATEST');
    });
  });
}
