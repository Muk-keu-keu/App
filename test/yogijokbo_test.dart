import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/post.dart';
import 'package:mukbang_ttaradamgi/models/user_location.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

/// 위치 수집이 테스트에 끼어들지 않게 실패로 고정한다.
class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

const _gangnam = UserLocation(
  lat: 37.4979,
  lng: 127.0276,
  origin: LocationOrigin.gps,
);

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
      final combo = post!.combo;
      expect(combo.itemsTotal, 20000); // 로제닭발 16,000 + 치즈볼 2,000×2
      expect(combo.store.deliveryFee, 3000);
      expect(combo.payableTotal, 23000);
    });
  });

  group('요기족보 목록', () {
    test('인기순은 좋아요가 많은 글이 먼저다', () async {
      final posts = await MockPostRepository().list(sort: PostSort.popular);
      expect(posts.first.likeCount, greaterThanOrEqualTo(posts.last.likeCount));
    });

    test('최신순은 작성일이 늦은 글이 먼저다', () async {
      final posts = await MockPostRepository().list(sort: PostSort.latest);
      expect(posts.first.createdAt.isAfter(posts.last.createdAt), isTrue);
    });

    test('내 위치에서 가능한 조합만 켜면 배달 불가 매장이 걸러진다', () async {
      final repo = MockPostRepository();
      final all = await repo.list(sort: PostSort.latest);
      final filtered = await repo.list(
        sort: PostSort.latest,
        orderableOnly: true,
        location: _gangnam,
      );

      expect(all.length, greaterThan(filtered.length));
      expect(filtered.every((p) => p.orderableHere), isTrue);
    });

    test('위치가 없으면 필터를 무시하고 전체를 준다', () async {
      // 빈 목록을 보여주는 것보다 낫다. 화면이 위치 설정을 따로 안내한다.
      final repo = MockPostRepository();
      final all = await repo.list(sort: PostSort.latest);
      final noLocation = await repo.list(sort: PostSort.latest, orderableOnly: true);

      expect(noLocation.length, all.length);
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

    test('위치 필터를 켜면 목록을 다시 불러온다', () async {
      final flow = makeFlow();
      await flow.openJokbo();
      final before = flow.posts.length;

      await flow.toggleOrderableOnly();

      expect(flow.orderableOnly, isTrue);
      // 위치가 없어 필터가 무시되므로 개수는 그대로다.
      expect(flow.posts, hasLength(before));
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
    test('주문 화면의 수량 변경이 게시글 스냅샷을 건드리지 않는다', () async {
      // api-yogijokbo.md 2번 비고 — combo 는 작성 시점 스냅샷이라 보존돼야 한다.
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await flow.startReorder();

      final itemId = flow.orderCombo!.items.first.id;
      final snapshotQuantity = flow.selectedPost!.combo.items.first.quantity;

      flow.changeOrderQuantity(itemId: itemId, delta: 2);

      expect(flow.orderCombo!.items.first.quantity, snapshotQuantity + 2);
      expect(flow.selectedPost!.combo.items.first.quantity, snapshotQuantity);
    });

    test('수량을 0으로 내리면 항목이 빠진다', () async {
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await flow.startReorder();

      final before = flow.orderCombo!.items.length;
      final itemId = flow.orderCombo!.items.first.id;
      flow.changeOrderQuantity(itemId: itemId, delta: -1); // 1 → 0

      expect(flow.orderCombo!.items, hasLength(before - 1));
    });

    test('배달 불가 매장이면 주문 불가로 표시한다', () async {
      final flow = makeFlow();
      await flow.openPost('post_02K3M'); // orderableHere: false
      await flow.startReorder();

      expect(flow.stage, AppStage.jokboOrder);
      expect(flow.orderUnavailable, isTrue);
    });

    test('뒤로 가면 주문 상태가 정리된다', () async {
      final flow = makeFlow();
      await flow.openPost('post_01H8X');
      await flow.startReorder();

      flow.backToPostDetail();

      expect(flow.stage, AppStage.jokboDetail);
      expect(flow.orderCombo, isNull);
      expect(flow.orderUnavailable, isFalse);
    });
  });

  group('족보 작성', () {
    test('공유하면 목록 맨 앞에 오고 바로 그 글이 열린다', () async {
      final repo = MockPostRepository();
      final flow = AppFlow(locationService: const _NoLocation(), postRepository: repo);

      // 작성 화면은 분석 결과 조합을 받아 열린다.
      final seed = await repo.detail('post_01H8X');
      flow.selectedPost = seed;
      await flow.startReorder();
      flow.composeCombo = flow.orderCombo;

      await flow.submitPost(title: '내 로제닭발 조합', body: '치즈 두 배가 정답');

      expect(flow.stage, AppStage.jokboDetail);
      expect(flow.selectedPost?.title, '내 로제닭발 조합');
      expect(flow.composeCombo, isNull); // 작성 상태는 비워진다

      final posts = await repo.list(sort: PostSort.latest);
      expect(posts.first.title, '내 로제닭발 조합');
    });

    test('제목이 비면 공유하지 않는다', () async {
      final repo = MockPostRepository();
      final flow = AppFlow(locationService: const _NoLocation(), postRepository: repo);
      final seed = await repo.detail('post_01H8X');
      flow.selectedPost = seed;
      await flow.startReorder();
      flow.composeCombo = flow.orderCombo;

      await flow.submitPost(title: '   ', body: '본문만 있음');

      expect(flow.composeCombo, isNotNull); // 작성 화면에 머문다
    });
  });

  group('PostSort', () {
    test('wire 값은 대문자다', () {
      expect(PostSort.popular.wire, 'POPULAR');
      expect(PostSort.latest.wire, 'LATEST');
    });
  });
}
