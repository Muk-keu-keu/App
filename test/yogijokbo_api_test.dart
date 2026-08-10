/// **2026-08-09 에 서버로 직접 확인한 요기족보 계약**을 잠근다.
///
/// 노션 명세와 다른 곳이 있어 이쪽을 기준으로 한다. 특히 다음이 명세와 다르다.
/// - 인증은 `Authorization: Bearer` 다 (명세는 `X-User-Id`)
/// - 목록 응답 키는 `posts` 이고 `postId` 는 **숫자**, 작성자는 `authorNickName`
/// - 좋아요 여부는 `liked` (명세는 `likedByMe`)
/// - 댓글에 커서가 없다. 작성 응답이 갱신된 목록 전체를 준다
/// - 작성은 multipart 이고 필드는 `checkoutId` 다 (명세는 JSON 파트 + `orderId`)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mukbang_ttaradamgi/api/api_client.dart';
import 'package:mukbang_ttaradamgi/api/mukbang_api.dart';
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

/// 한글이 든 본문을 그대로 쓰려면 바이트로 만들어야 한다 —
/// `http.Response(문자열)` 은 latin1 로 인코딩한다.
http.Response _json(String body, [int status = 200]) => http.Response.bytes(
      utf8.encode(body),
      status,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );

/// 오간 요청을 붙잡아 두는 가짜 서버.
class _FakeServer {
  _FakeServer(this._respond);

  final http.Response Function(http.Request request) _respond;

  final List<http.Request> requests = [];

  http.Client get client => MockClient((request) async {
        requests.add(request);
        return _respond(request);
      });

  http.Request get last => requests.last;
}

/// 목록 응답 한 건. `postId` 가 숫자이고 작성자는 닉네임 한 줄이다.
const _listBody = '''
{
  "posts": [
    {
      "postId": 9001,
      "title": "떵개 추천 두찜 로제 닭발",
      "thumbnailUrl": "https://cdn.example.com/orders/5001/source.jpg",
      "authorNickName": "배고픈 요기요",
      "createdAt": "2026-07-07T19:12:00+09:00",
      "likeCount": 12,
      "commentCount": 4,
      "liked": true
    },
    {
      "postId": 9002,
      "title": "썸네일 없는 글",
      "thumbnailUrl": null,
      "authorNickName": "문복희팬",
      "createdAt": "2026-07-05T12:00:00+09:00",
      "likeCount": 3,
      "commentCount": 0,
      "liked": false
    }
  ],
  "nextCursor": "eyJpZCI6OTAwMX0="
}
''';

/// 상세 응답. 조합이 `order` 블록으로 오고 주문 상세와 같은 모양이다.
const _detailBody = '''
{
  "postId": 9001,
  "title": "떵개 추천 두찜 로제 닭발",
  "body": "분모자랑 치즈 꼭 추가하고 드세요",
  "imageUrls": ["https://cdn.example.com/posts/9001/1.jpg"],
  "authorId": 1,
  "authorNickName": "배고픈 요기요",
  "createdAt": "2026-07-07T19:12:00+09:00",
  "likeCount": 12,
  "commentCount": 1,
  "liked": false,
  "mine": true,
  "order": {
    "checkoutId": 5001,
    "orderedAt": "2026-07-07T18:00:00+09:00",
    "source": {
      "platform": "YOUTUBE",
      "url": "https://www.youtube.com/watch?v=abc123",
      "thumbnailUrl": "https://cdn.example.com/orders/5001/source.jpg",
      "title": "로제닭발 먹방"
    },
    "totalPrice": 23000,
    "stores": [
      {
        "restaurantId": 201,
        "restaurantName": "두찜-잠실새내점",
        "deliveryFee": 3000,
        "itemsTotal": 20000,
        "subtotal": 23000,
        "items": [
          {
            "menuId": 201001,
            "menuName": "[원조 K 로제] 로제 닭발",
            "menuImageUrl": "https://cdn.example.com/menus/201001.jpg",
            "unitPrice": 16000,
            "quantity": 1,
            "selectedOptions": [
              { "group": "토핑 추가", "name": "치즈몽땅", "price": 0 }
            ],
            "optionsPrice": 0,
            "lineTotal": 16000
          },
          {
            "menuId": 201002,
            "menuName": "[사이드] 치즈볼",
            "unitPrice": 2000,
            "quantity": 2,
            "optionsPrice": 0,
            "lineTotal": 4000
          }
        ]
      }
    ]
  }
}
''';

const _commentsBody = '''
{
  "comments": [
    {
      "commentId": 4101,
      "authorId": 2,
      "authorNickName": "닭발러버",
      "body": "분모자 진짜 필수인가요?",
      "createdAt": "2026-07-07T20:03:00+09:00",
      "mine": false
    },
    {
      "commentId": 4102,
      "authorId": 1,
      "authorNickName": "나",
      "body": "둘 다 맛있어요",
      "createdAt": "2026-07-07T20:10:00+09:00",
      "mine": true
    }
  ]
}
''';

/// `GET v1/restaurants/{id}/menus` 의 `restaurant` 블록. 2026-08-09 부터
/// 평점·리뷰 수·거리·예상 시간·최소 주문 금액이 전부 온다.
const _menusBody = '''
{
  "restaurant": {
    "restaurantId": 201,
    "name": "두찜-잠실새내점",
    "foodCategory": "KOREAN",
    "area": "잠실동",
    "rating": 4.2,
    "reviewCount": 312,
    "etaMin": 40,
    "deliveryFee": 3000,
    "minOrderPrice": 14000,
    "distanceKm": 3.2,
    "imageUrl": "https://cdn.example.com/stores/201.jpg"
  },
  "menus": []
}
''';

void main() {
  ({MukbangApi api, ApiPostRepository repo}) apiWith(
    _FakeServer server, {
    String? token = 'access-token',
  }) {
    final client = ApiClient(
      baseUrl: 'http://server.test',
      httpClient: server.client,
      accessToken: token,
    );
    final api = MukbangApi(client);
    return (api: api, repo: ApiPostRepository(api));
  }

  group('1번 목록 — GET v1/posts', () {
    test('sort·size 를 쿼리로 보내고 posts 배열을 읽는다', () async {
      final server = _FakeServer((_) => _json(_listBody));
      final page = await apiWith(server).repo.list(sort: PostSort.latest, size: 5);

      expect(server.last.method, 'GET');
      expect(server.last.url.path, '/v1/posts');
      expect(server.last.url.queryParameters['sort'], 'LATEST');
      expect(server.last.url.queryParameters['size'], '5');
      // 커서가 없는 첫 페이지는 키를 아예 보내지 않는다 — "null" 이 커서로 읽힌다.
      expect(server.last.url.queryParameters.containsKey('cursor'), isFalse);

      expect(page.items, hasLength(2));
      expect(page.nextCursor, 'eyJpZCI6OTAwMX0=');
      expect(page.hasMore, isTrue);
    });

    test('숫자 postId 를 문자열 id 로, authorNickName 을 작성자로 읽는다', () async {
      final server = _FakeServer((_) => _json(_listBody));
      final page = await apiWith(server).repo.list(sort: PostSort.popular);
      final first = page.items.first;

      expect(first.id, '9001');
      expect(first.author.nickname, '배고픈 요기요');
      expect(first.likeCount, 12);
      expect(first.commentCount, 4);
      // 서버 키는 liked 다. 앱 모델 이름은 likedByMe.
      expect(first.likedByMe, isTrue);
      expect(page.items.last.likedByMe, isFalse);
    });

    test('목록이 골라 준 썸네일을 그대로 쓰고, 없으면 null 이다', () async {
      final server = _FakeServer((_) => _json(_listBody));
      final page = await apiWith(server).repo.list(sort: PostSort.popular);

      expect(page.items.first.thumbnailUrl,
          'https://cdn.example.com/orders/5001/source.jpg');
      expect(page.items.last.thumbnailUrl, isNull);
    });

    test('목록은 조합을 내려주지 않는다', () async {
      final server = _FakeServer((_) => _json(_listBody));
      final page = await apiWith(server).repo.list(sort: PostSort.popular);

      expect(page.items.first.stores, isEmpty);
    });

    test('Bearer 토큰을 싣는다', () async {
      final server = _FakeServer((_) => _json(_listBody));
      await apiWith(server).repo.list(sort: PostSort.popular);

      expect(server.last.headers['Authorization'], 'Bearer access-token');
    });

    test('토큰이 없어도 목록을 받는다 — 서버가 무인증 200 을 준다', () async {
      final server = _FakeServer((_) => _json(_listBody));
      final page = await apiWith(server, token: null).repo.list(sort: PostSort.popular);

      expect(server.last.headers.containsKey('Authorization'), isFalse);
      expect(page.items, hasLength(2));
    });
  });

  group('2번 상세 — GET v1/posts/{postId}', () {
    test('order 블록을 장바구니 모양 조합으로 읽는다', () async {
      final server = _FakeServer((_) => _json(_detailBody));
      final post = await apiWith(server).repo.detail('9001');

      expect(server.last.url.path, '/v1/posts/9001');
      expect(post!.stores, hasLength(1));
      expect(post.stores.first.restaurant.name, '두찜-잠실새내점');
      expect(post.stores.first.deliveryFee, 3000);
      expect(post.allLines, hasLength(2));
      expect(post.allLines.first.name, '[원조 K 로제] 로제 닭발');
      // 음식값 20,000 + 배달비 3,000
      expect(post.itemsTotal, 20000);
      expect(post.payableTotal, 23000);
    });

    test('출처 영상과 사용자 사진을 구분해 읽는다', () async {
      final server = _FakeServer((_) => _json(_detailBody));
      final post = await apiWith(server).repo.detail('9001');

      expect(post!.source?.platform, PostPlatform.youtube);
      expect(post.source?.title, '로제닭발 먹방');
      expect(post.imageUrls, hasLength(1));
    });

    test('작성자와 작성일을 읽는다', () async {
      final server = _FakeServer((_) => _json(_detailBody));
      final post = await apiWith(server).repo.detail('9001');

      expect(post!.author.id, '1');
      expect(post.author.nickname, '배고픈 요기요');
      expect(post.dateText, '2026.07.07');
      // 프로필 사진은 오지 않는다. 원형 자리는 닉네임 첫 글자로 채운다.
      expect(post.author.profileImageUrl, isNull);
      expect(post.author.initial, '배');
    });

    test('작성일이 없고 eatedAt 만 오면 그것을 쓴다', () async {
      // 명세에 createdAt 이 들어오기 전(2026-08-09) 서버가 먹은 날만 주던 모양이다.
      // 날짜 줄이 1970 으로 보이지 않도록 폴백을 남겨 둔다.
      final server = _FakeServer((_) => _json(
            _detailBody
                .replaceAll('"createdAt"', '"eatedAt"')
                .replaceAll('"authorNickName": "배고픈 요기요",', ''),
          ));
      final post = await apiWith(server).repo.detail('9001');

      expect(post!.dateText, '2026.07.07');
      expect(post.author.nickname, isEmpty);
    });

    test('mine 이 true 면 내 글이다', () async {
      final server = _FakeServer((_) => _json(_detailBody));
      final post = await apiWith(server).repo.detail('9001');

      expect(post!.mine, isTrue);
    });

    test('없는 글은 404 → null', () async {
      final server = _FakeServer((_) => _json('{"status":404}', 404));
      expect(await apiWith(server).repo.detail('404'), isNull);
    });
  });

  group('3번 작성 — POST v1/posts (multipart)', () {
    test('multipart 로 checkoutId·title·body 를 보내고 postId 를 받는다', () async {
      final server = _FakeServer((_) => _json('{"postId": 9012}', 201));
      final postId = await apiWith(server).repo.create(
            checkoutId: 5001,
            title: '내 로제닭발 조합',
            body: '치즈 두 배가 정답',
          );

      expect(postId, '9012');
      expect(server.last.method, 'POST');
      expect(server.last.url.path, '/v1/posts');

      // Content-Type 은 손으로 넣지 않는다 — boundary 가 빠지면 400 이다.
      final contentType = server.last.headers['content-type'] ?? '';
      expect(contentType, contains('multipart/form-data'));
      expect(contentType, contains('boundary='));

      final body = utf8.decode(server.last.bodyBytes);
      expect(body, contains('name="checkoutId"'));
      expect(body, contains('5001'));
      expect(body, contains('name="title"'));
      expect(body, contains('내 로제닭발 조합'));
      expect(body, contains('name="body"'));
      // restaurantId 는 보내지 않는다. checkoutId 로 조합이 전부 정해진다.
      expect(body, isNot(contains('restaurantId')));
    });
  });

  group('4·5번 좋아요', () {
    test('POST 는 liked 를 읽어 likedByMe 로 준다', () async {
      final server = _FakeServer((_) => _json('{"likeCount":13,"liked":true}'));
      final result = await apiWith(server).repo.like('9001');

      expect(server.last.method, 'POST');
      expect(server.last.url.path, '/v1/posts/9001/likes');
      expect(result.likeCount, 13);
      expect(result.likedByMe, isTrue);
    });

    test('DELETE 는 liked:false 를 준다', () async {
      final server = _FakeServer((_) => _json('{"likeCount":12,"liked":false}'));
      final result = await apiWith(server).repo.unlike('9001');

      expect(server.last.method, 'DELETE');
      expect(server.last.url.path, '/v1/posts/9001/likes');
      expect(result.likeCount, 12);
      expect(result.likedByMe, isFalse);
    });
  });

  group('6·7번 댓글', () {
    test('목록은 커서 없이 comments 배열로 온다', () async {
      final server = _FakeServer((_) => _json(_commentsBody));
      final comments = await apiWith(server).repo.comments('9001');

      expect(server.last.url.path, '/v1/posts/9001/comments');
      expect(server.last.url.queryParameters, isEmpty);
      expect(comments, hasLength(2));
      expect(comments.first.id, '4101');
      expect(comments.first.author.nickname, '닭발러버');
      expect(comments.first.mine, isFalse);
      expect(comments.last.mine, isTrue);
    });

    test('작성 응답이 갱신된 목록 전체다 — 다시 받지 않는다', () async {
      final server = _FakeServer((_) => _json(_commentsBody, 201));
      final updated = await apiWith(server).repo.addComment('9001', '맛있겠다');

      expect(server.requests, hasLength(1)); // POST 한 번뿐
      expect(server.last.method, 'POST');
      expect(jsonDecode(server.last.body)['body'], '맛있겠다');
      expect(updated, hasLength(2));
    });

    test('작성 응답이 비면 목록을 다시 받는다', () async {
      final server = _FakeServer((request) =>
          request.method == 'POST' ? _json('', 201) : _json(_commentsBody));
      final updated = await apiWith(server).repo.addComment('9001', '맛있겠다');

      expect(server.requests, hasLength(2));
      expect(updated, hasLength(2));
    });
  });

  group('명세에 없지만 서버에 있는 것', () {
    test('삭제는 DELETE v1/posts/{id} 와 .../comments/{id} 다', () async {
      final server = _FakeServer((_) => _json('', 200));
      final repo = apiWith(server).repo;

      await repo.deletePost('9001');
      expect(server.last.method, 'DELETE');
      expect(server.last.url.path, '/v1/posts/9001');

      await repo.deleteComment('9001', '4101');
      expect(server.last.url.path, '/v1/posts/9001/comments/4101');
    });

  });

  group('8번 수정 — PATCH v1/posts/{postId} (multipart)', () {
    test('multipart 로 title·body 를 보내고 checkoutId 는 없다', () async {
      final server = _FakeServer((_) => _json('', 200));
      await apiWith(server).repo.updatePost('9001', title: '새 제목', body: '새 본문');

      expect(server.last.method, 'PATCH');
      expect(server.last.url.path, '/v1/posts/9001');

      final contentType = server.last.headers['content-type'] ?? '';
      expect(contentType, contains('multipart/form-data'));
      expect(contentType, contains('boundary='));

      final body = utf8.decode(server.last.bodyBytes);
      expect(body, contains('name="title"'));
      expect(body, contains('새 제목'));
      expect(body, contains('name="body"'));
      expect(body, contains('새 본문'));
      // 조합은 결제 스냅샷이라 바뀌지 않는다. 작성과 달리 checkoutId 를 보내지 않는다.
      expect(body, isNot(contains('checkoutId')));
    });

    test('남길 사진을 다시 받아 파일로 되보낸다 — 보낸 순서가 표시 순서다', () async {
      // 서버는 사진을 부분 수정하지 않는다. 보낸 목록이 사진 전체를 대체하므로
      // 제목만 고칠 때도 기존 사진을 되보내야 지워지지 않는다.
      final server = _FakeServer((request) => request.url.host == 'cdn.example.com'
          ? http.Response.bytes([1, 2, 3], 200)
          : _json('', 200));

      await apiWith(server).repo.updatePost(
            '9001',
            title: '새 제목',
            body: '새 본문',
            images: const [
              PostImage.kept('https://cdn.example.com/posts/9001/first.png'),
              PostImage.kept('https://cdn.example.com/posts/9001/second.jpg'),
            ],
          );

      // 사진 두 장을 먼저 받아 오고 그 다음 PATCH 가 나간다.
      expect(server.requests, hasLength(3));
      expect(server.requests[0].url.path, '/posts/9001/first.png');
      expect(server.requests[1].url.path, '/posts/9001/second.jpg');

      final body = utf8.decode(server.last.bodyBytes);
      // 두 파트 모두 images 라는 같은 이름으로, URL 의 파일 이름을 살려 나간다.
      expect(body, contains('filename="first.png"'));
      expect(body, contains('filename="second.jpg"'));
      // 확장자로 파트의 Content-Type 이 정해진다. octet-stream 이면 서버 검증에 걸린다.
      expect(body, contains('image/png'));
      expect(body, contains('image/jpeg'));
      // 순서가 그대로 sort_order 가 되므로 first 가 second 보다 앞이어야 한다.
      expect(body.indexOf('first.png'), lessThan(body.indexOf('second.jpg')));
    });

    test('사진을 못 받으면 요청을 보내지 않고 던진다', () async {
      // 그대로 보내면 서버가 그 사진을 지운다. 사용자가 건드리지도 않은 사진이
      // 사라지는 것보다 저장을 실패시키는 쪽이 낫다.
      final server = _FakeServer((request) => request.url.host == 'cdn.example.com'
          ? _json('', 500)
          : _json('', 200));

      await expectLater(
        apiWith(server).repo.updatePost(
              '9001',
              title: '새 제목',
              body: '새 본문',
              images: const [PostImage.kept('https://cdn.example.com/a.jpg')],
            ),
        throwsA(isA<PostImagesUnavailableException>()),
      );

      // CDN 요청 한 번뿐 — PATCH 는 나가지 않았다.
      expect(server.requests, hasLength(1));
      expect(server.requests.single.url.host, 'cdn.example.com');
    });

    test('새로 고른 사진은 파일 경로로 붙인다', () async {
      final server = _FakeServer((_) => _json('', 200));
      final picked = File(
        '${Directory.systemTemp.path}/mukbang_test_picked.jpg',
      )..writeAsBytesSync([9, 9, 9]);
      addTearDown(() => picked.deleteSync());

      await apiWith(server).repo.updatePost(
            '9001',
            title: '새 제목',
            body: '새 본문',
            images: [PostImage.picked(picked.path)],
          );

      final body = utf8.decode(server.last.bodyBytes);
      expect(body, contains('filename="mukbang_test_picked.jpg"'));
      expect(body, contains('image/jpeg'));
    });

    test('수정 화면 저장이 지금 붙어 있는 사진을 그대로 되보낸다', () async {
      final server = _FakeServer((request) => switch (request.url.host) {
            'cdn.example.com' => http.Response.bytes([1, 2, 3], 200),
            _ when request.url.path.endsWith('/comments') => _json(_commentsBody),
            _ when request.method == 'PATCH' => _json('', 200),
            _ => _json(_detailBody),
          });
      final client = ApiClient(
        baseUrl: 'http://server.test',
        httpClient: server.client,
        accessToken: 'access-token',
      );
      final flow = AppFlow(
        apiClient: client,
        locationService: const _NoLocation(),
        postRepository: ApiPostRepository(MukbangApi(client)),
      );

      await flow.openPost('9001');
      expect(flow.selectedPost!.imageUrls, hasLength(1));

      final saved = await flow.savePostEdit(title: '고친 제목', body: '고친 본문');

      expect(saved, isTrue);
      expect(flow.stage, AppStage.jokboDetail);
      expect(flow.selectedPost?.title, '고친 제목');

      final patch = server.requests.lastWhere((r) => r.method == 'PATCH');
      expect(utf8.decode(patch.bodyBytes), contains('filename="1.jpg"'));
    });

    test('사진을 못 받으면 저장하지 않고 수정 화면에 남는다', () async {
      final server = _FakeServer((request) => switch (request.url.host) {
            'cdn.example.com' => _json('', 500),
            _ when request.url.path.endsWith('/comments') => _json(_commentsBody),
            _ => _json(_detailBody),
          });
      final client = ApiClient(
        baseUrl: 'http://server.test',
        httpClient: server.client,
        accessToken: 'access-token',
      );
      final flow = AppFlow(
        apiClient: client,
        locationService: const _NoLocation(),
        postRepository: ApiPostRepository(MukbangApi(client)),
      );

      await flow.openPost('9001');
      flow.openPostEdit();

      final saved = await flow.savePostEdit(title: '고친 제목', body: '고친 본문');

      expect(saved, isFalse);
      expect(flow.stage, AppStage.jokboEdit);
      // 제목도 그대로여야 한다 — 저장되지 않았는데 화면만 바뀌면 안 된다.
      expect(flow.selectedPost?.title, '떵개 추천 두찜 로제 닭발');
      expect(server.requests.any((r) => r.method == 'PATCH'), isFalse);
    });
  });

  group('화면 흐름', () {
    test('서버 목록으로 요기족보를 열고 글을 펼친다', () async {
      final server = _FakeServer((request) => request.url.path == '/v1/posts'
          ? _json(_listBody)
          : request.url.path.endsWith('/comments')
              ? _json(_commentsBody)
              : _json(_detailBody));
      final client = ApiClient(
        baseUrl: 'http://server.test',
        httpClient: server.client,
        accessToken: 'access-token',
      );
      final flow = AppFlow(
        apiClient: client,
        locationService: const _NoLocation(),
        postRepository: ApiPostRepository(MukbangApi(client)),
      );

      await flow.openJokbo();
      expect(flow.posts, hasLength(2));
      expect(flow.postsLoadFailed, isFalse);

      await flow.openPost('9001');
      expect(flow.stage, AppStage.jokboDetail);
      expect(flow.selectedPost?.stores, hasLength(1));
      expect(flow.postComments, hasLength(2));

      // 상세 조합이 그대로 장바구니가 된다. 이 서버는 GET menus 에 매장 블록이
      // 없는 응답을 주는데, id 가 맞지 않으므로 결제 스냅샷의 배달비가 남는다.
      await flow.startReorder();
      expect(flow.cart.storeCount, 1);
      expect(flow.cart.deliveryFeeTotal, 3000);
    });

    test('나도 주문하기가 매장 정보를 GET menus 로 채운다', () async {
      // 게시글의 order 블록은 매장 정보를 세 개만 준다. 그대로 두면 최소 주문
      // 금액이 0이라 미달인데도 결제 버튼이 열린다.
      final server = _FakeServer((request) => switch (request.url.path) {
            '/v1/posts' => _json(_listBody),
            '/v1/restaurants/201/menus' => _json(_menusBody),
            final p when p.endsWith('/comments') => _json(_commentsBody),
            _ => _json(_detailBody),
          });
      final client = ApiClient(
        baseUrl: 'http://server.test',
        httpClient: server.client,
        accessToken: 'access-token',
      );
      final flow = AppFlow(
        apiClient: client,
        locationService: const _NoLocation(),
        postRepository: ApiPostRepository(MukbangApi(client)),
      );

      await flow.openPost('9001');
      // 게시글에서 온 조합은 아직 0 이다.
      expect(flow.selectedPost!.stores.first.restaurant.minOrderPrice, 0);

      await flow.startReorder();

      final store = flow.cart.stores.first.restaurant;
      expect(store.rating, 4.2);
      expect(store.reviewCount, 312);
      expect(store.etaMin, 40);
      expect(store.distanceKm, 3.2);
      expect(store.minOrderPrice, 14000);
      // 배달비는 게시글에서 이미 알던 값과 같다.
      expect(flow.cart.deliveryFeeTotal, 3000);
      // 음식값 20,000 이 최소 주문 금액을 넘어 결제할 수 있다.
      expect(flow.cart.canCheckout, isTrue);
    });

    test('매장 정보를 못 받아도 주문 화면은 열린다', () async {
      final server = _FakeServer((request) => switch (request.url.path) {
            '/v1/restaurants/201/menus' => _json('{"status":404}', 404),
            final p when p.endsWith('/comments') => _json(_commentsBody),
            _ => _json(_detailBody),
          });
      final client = ApiClient(
        baseUrl: 'http://server.test',
        httpClient: server.client,
        accessToken: 'access-token',
      );
      final flow = AppFlow(
        apiClient: client,
        locationService: const _NoLocation(),
        postRepository: ApiPostRepository(MukbangApi(client)),
      );

      await flow.openPost('9001');
      await flow.startReorder();

      expect(flow.stage, AppStage.jokboOrder);
      expect(flow.cart.stores.first.restaurant.name, '두찜-잠실새내점');
    });

    test('목록을 못 받으면 로딩을 끝내고 실패로 표시한다', () async {
      final server = _FakeServer((_) => throw http.ClientException('no route'));
      final client = ApiClient(
        baseUrl: 'http://server.test',
        httpClient: server.client,
        accessToken: 'access-token',
      );
      final flow = AppFlow(
        apiClient: client,
        locationService: const _NoLocation(),
        postRepository: ApiPostRepository(MukbangApi(client)),
      );

      await flow.openJokbo();

      expect(flow.postsLoading, isFalse);
      expect(flow.posts, isEmpty);
      expect(flow.postsLoadFailed, isTrue);
    });
  });
}
