import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/post.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 피드백 2026-08-21 — 주문내역에서 족보를 쓰고 토스트의 "보러가기" 로 상세에
/// 들어갔다가 뒤로 나오면, 요기족보 목록이 "아직 올라온 조합이 없어요" 로 비어
/// 있었다. 실시간 인기 배너는 로그인 때 받아 두므로 멀쩡히 보여서 목록만 비어
/// 보였다.
///
/// 원인은 `backToJokboHome` 이 목록을 받지 않고 화면만 바꾼 것이다. 이 경로로는
/// `openJokbo`(목록을 받는 유일한 입구)를 한 번도 지나지 않는다.
void main() {
  AppFlow makeFlow(MockPostRepository repo) => AppFlow(
        locationService: const _NoLocation(),
        postRepository: repo,
      );

  test('상세에서 뒤로 나오면 한 번도 안 받은 목록을 받아 온다', () async {
    final repo = MockPostRepository();
    final flow = makeFlow(repo);

    // 목록 화면을 거치지 않고 상세로 바로 들어간 상태.
    await flow.openPost('post_01H8X');
    expect(flow.posts, isEmpty, reason: '아직 목록을 받은 적이 없다');

    await flow.backToJokboHome();

    expect(flow.stage, AppStage.jokboHome);
    expect(flow.posts, isNotEmpty, reason: '더미 데이터가 보여야 한다');
    expect(flow.postsLoadFailed, isFalse);
  });

  test('족보를 쓰고 상세를 거쳐 뒤로 나오면 쓴 글이 목록에 있다', () async {
    final repo = MockPostRepository();
    final flow = makeFlow(repo);

    // 주문내역에서 작성 → 공유. 화면은 주문내역으로 돌아간다.
    flow.composeCheckoutId = 7002;
    final postId = await flow.submitPost(
      title: '떡볶이랑 치킨이 근본 조합이죠',
      body: '인스타 먹방보고 따라서 먹었는데 역시 근본이에요',
    );
    expect(postId, isNotNull);
    expect(flow.stage, AppStage.orders);

    // 토스트의 "보러가기" → 상세 → 뒤로.
    await flow.openPost(postId!);
    await flow.backToJokboHome();

    expect(
      flow.posts.map((p) => p.title),
      contains('떡볶이랑 치킨이 근본 조합이죠'),
    );
  });

  test('이미 받아 둔 목록은 상세를 다녀와도 다시 받지 않는다', () async {
    final repo = _CountingRepository();
    final flow = makeFlow(repo);

    await flow.openJokbo();
    final callsAfterOpen = repo.listCalls;
    expect(flow.posts, isNotEmpty);

    await flow.openPost(flow.posts.first.id);
    await flow.backToJokboHome();

    // 페이지를 이어 받아 둔 목록과 스크롤을 헛되게 버리지 않는다.
    expect(repo.listCalls, callsAfterOpen);
  });
}

/// `list` 호출 횟수를 센다. 그 외 동작은 [MockPostRepository] 그대로다.
class _CountingRepository extends MockPostRepository {
  int listCalls = 0;

  @override
  Future<CursorPage<YogijokboPost>> list({
    required PostSort sort,
    String? cursor,
    int size = 20,
  }) {
    listCalls++;
    return super.list(sort: sort, cursor: cursor, size: size);
  }
}
