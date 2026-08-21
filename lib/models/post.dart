/// 요기족보 도메인 모델.
///
/// 사용자들이 자기 먹방 조합을 공유하고, 실시간 인기 조합을 보고, 마음에 들면 그대로
/// 주문하는 커뮤니티 기능. `docs/api-yogijokbo.md` 의 응답 스키마와 1:1로 맞췄다.
/// 필드를 고치면 그 문서도 함께 고친다 — 백엔드와의 계약이다.
///
/// 회의(2026-08-04)에서 족보 등록·주문·리뷰를 **묶음 조합 단위**로 바꿨다. 그래서
/// 게시글이 매장 하나(`combo`)가 아니라 매장 목록(`stores`)을 갖는다.
///
/// 상세의 조합은 `order` 블록으로 오고 **주문 상세(`GET v1/orders/{id}`)와 같은
/// 모양**이다 (2026-08-09 서버 확인). 그래서 [OrderDetail] 로 읽고 장바구니로
/// 되돌린다 — 같은 파싱을 두 벌 두지 않는다.
library;

import '../assets.dart';
import 'combo.dart';
import 'order.dart';

/// 게시글 작성자.
///
/// 서버는 작성자를 `authorId` + `authorNickName`(대문자 N) 두 값으로 준다.
/// **프로필 사진은 오지 않아** 원형 자리는 닉네임 첫 글자로 채운다.
/// 목록은 닉네임만 주고 id 는 없다.
class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
  });

  /// 목록·상세·댓글이 모두 `authorNickName` 을 쓴다. 예전 명세의 `author` 객체가
  /// 오는 경우도 있어 둘 다 받는다.
  factory PostAuthor.fromWire(Map<String, dynamic> json) {
    final nested = json['author'];
    final nickname = json['authorNickName'] ??
        json['authorNickname'] ??
        (nested is Map<String, dynamic> ? nested['nickname'] : null);
    return PostAuthor(
      id: '${json['authorId'] ?? (nested is Map<String, dynamic> ? nested['id'] ?? '' : '')}',
      nickname: '${nickname ?? ''}',
      profileImageUrl:
          nested is Map<String, dynamic> ? nested['profileImageUrl'] as String? : null,
    );
  }

  final String id;
  final String nickname;
  final String? profileImageUrl;

  /// 프로필 사진이 없을 때 원형 자리에 넣을 한 글자.
  String get initial => nickname.isEmpty ? '?' : nickname.substring(0, 1);
}

/// 출처 영상의 플랫폼. wire 값은 대문자 (api-yogijokbo.md 2번).
enum PostPlatform {
  instagram('INSTAGRAM'),
  youtube('YOUTUBE');

  const PostPlatform(this.wire);

  final String wire;

  static PostPlatform fromWire(String value) => values.firstWhere(
        (p) => p.wire == value.toUpperCase(),
        orElse: () => PostPlatform.youtube,
      );
}

/// 조합의 출처 영상. API `source` 객체.
///
/// 분석 파이프라인의 `AnalysisSource` 와 다르다 — 그쪽은 AI 에 넣은 입력이고,
/// 이건 게시글에 붙어 사용자에게 보이는 링크다.
class PostSource {
  const PostSource({
    required this.platform,
    required this.url,
    required this.title,
    this.thumbnailUrl,
  });

  final PostPlatform platform;

  /// 영상 연결 화면으로 가는 링크.
  final String url;
  final String title;

  /// 영상 썸네일. 목록 카드가 쓰는 이미지이기도 하다.
  final String? thumbnailUrl;
}

/// cursor 페이지네이션 응답. `{ items, nextCursor }` 형태를 그대로 담는다.
class CursorPage<T> {
  const CursorPage({required this.items, this.nextCursor});

  const CursorPage.empty() : items = const [], nextCursor = null;

  final List<T> items;

  /// 다음 페이지가 없으면 null.
  final String? nextCursor;

  bool get hasMore => nextCursor != null;
}

class PostComment {
  const PostComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
    this.mine = false,
  });

  final String id;
  final PostAuthor author;
  final String body;
  final DateTime createdAt;

  /// 내가 쓴 댓글인지. 삭제는 내 댓글에만 열어 준다 — 남의 댓글을 지우려 하면
  /// 서버가 403 을 준다.
  final bool mine;

  factory PostComment.fromJson(Map<String, dynamic> json) => PostComment(
        id: '${json['commentId'] ?? json['id'] ?? ''}',
        author: PostAuthor.fromWire(json),
        body: '${json['body'] ?? ''}',
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime(2026),
        mine: json['mine'] == true,
      );
}

class YogijokboPost {
  YogijokboPost({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.stores,
    required this.createdAt,
    this.imagePaths = const [],
    this.imageUrls = const [],
    this.source,
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
    this.mine = false,
    this.listThumbnailUrl,
  });

  /// 목록 항목. `GET v1/posts` 의 `posts[]`.
  ///
  /// 조합은 내려오지 않는다 — 메뉴·옵션·금액은 상세에서 받는다.
  /// 본문은 2026-08-13 명세부터 자르지 않고 전체가 온다(카드가 2줄만 그린다).
  factory YogijokboPost.fromListJson(Map<String, dynamic> json) => YogijokboPost(
        id: '${json['postId'] ?? json['id'] ?? ''}',
        title: '${json['title'] ?? ''}',
        body: '${json['body'] ?? ''}',
        author: PostAuthor.fromWire(json),
        stores: const [],
        createdAt:
            DateTime.tryParse('${json['createdAt'] ?? ''}') ?? DateTime(2026),
        likeCount: ((json['likeCount'] ?? 0) as num).toInt(),
        likedByMe: json['liked'] == true,
        commentCount: ((json['commentCount'] ?? 0) as num).toInt(),
        mine: json['mine'] == true,
        listThumbnailUrl: json['thumbnailUrl'] as String?,
      );

  /// 게시글 상세. `GET v1/posts/{postId}`.
  ///
  /// 조합은 `order` 블록에 주문 상세와 같은 모양으로 온다. 그 파싱을 다시 쓰고,
  /// 장바구니로 되돌린 결과를 스냅샷으로 들고 있는다.
  factory YogijokboPost.fromDetailJson(Map<String, dynamic> json) {
    final order = json['order'] is Map<String, dynamic>
        ? OrderDetail.fromJson(json['order'] as Map<String, dynamic>)
        : null;
    final source = order?.source;

    return YogijokboPost(
      id: '${json['postId'] ?? json['id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      body: '${json['body'] ?? ''}',
      author: PostAuthor.fromWire(json),
      stores: order == null ? const [] : Cart.fromOrderDetail(order).stores,
      // 화면의 날짜 줄은 작성일이다. `eatedAt`(먹은 날)만 오던 시기가 있어 그쪽도
      // 받아 두지만, 둘이 다 오면 작성일을 쓴다 — 시안의 그 자리는 작성일이다.
      createdAt: DateTime.tryParse('${json['createdAt'] ?? json['eatedAt'] ?? ''}') ??
          order?.orderedAt ??
          DateTime(2026),
      imageUrls: [for (final e in (json['imageUrls'] ?? const []) as List) '$e'],
      source: source == null
          ? null
          : PostSource(
              platform: source.platform == SourceKind.instagram
                  ? PostPlatform.instagram
                  : PostPlatform.youtube,
              url: source.url,
              title: source.title,
              thumbnailUrl: source.thumbnailUrl,
            ),
      likeCount: ((json['likeCount'] ?? 0) as num).toInt(),
      likedByMe: json['liked'] == true,
      commentCount: ((json['commentCount'] ?? 0) as num).toInt(),
      mine: json['mine'] == true,
    );
  }

  final String id;

  /// 글쓴이가 고칠 수 있다 (시안 922:2734 "족보 수정"). 조합은 결제 스냅샷이라
  /// 그대로지만 제목·본문은 바뀐다.
  String title;
  String body;

  final PostAuthor author;

  /// 작성 시점 조합 스냅샷. 매장이 가격을 올려도 예전 글은 그때 모습대로 보인다.
  /// (api-yogijokbo.md 2번 비고) 현재 주문 가능 여부는 "나도 주문하기"가 다시 확인한다.
  ///
  /// 매장이 여러 곳일 수 있다 — 떡볶이+핫도그 조합을 한 글로 올린 경우다.
  final List<StoreCart> stores;

  final DateTime createdAt;

  /// 번들 에셋 경로. 서버 연동 전 시연용.
  final List<String> imagePaths;

  /// 서버가 준 이미지 URL. 있으면 이쪽을 먼저 쓴다.
  /// 수정 저장 후 화면에 떠 있는 글을 그 자리에서 맞추므로 바뀔 수 있다
  /// (제목·본문과 같은 이유다 — 다시 받지 않으면 지운 사진이 남아 보인다).
  List<String> imageUrls;

  final PostSource? source;

  int likeCount;
  bool likedByMe;
  int commentCount;

  /// 내 글인지. 수정·삭제는 내 글에만 열어 준다 — 남의 글을 고치려 하면 서버가
  /// 403 을 준다. 목록·상세가 모두 내려준다.
  final bool mine;

  /// 목록이 직접 내려주는 대표 이미지. 상세에는 없다.
  ///
  /// 서버가 영상 썸네일 → 사용자 사진 → 첫 메뉴 사진 순으로 골라 준다 (1번 비고).
  /// 그 판단을 앱이 다시 하지 않는다.
  final String? listThumbnailUrl;

  /// 목록 카드에 쓰는 대표 이미지. 목록이 골라 준 값이 있으면 그것을 쓰고,
  /// 상세에서는 영상 썸네일 → 사용자가 올린 첫 사진 순으로 고른다.
  String? get thumbnailUrl =>
      listThumbnailUrl ??
      source?.thumbnailUrl ??
      (imageUrls.isEmpty ? null : imageUrls.first);
  /// 원격 이미지가 없을 때 그릴 번들 이미지.
  ///
  /// 명세(api-yogijokbo.md 1번 비고)가 적어 둔 서버의 선택 순서 — 영상 썸네일 →
  /// 사용자 사진 → **첫 메뉴 사진** — 을 앱도 그대로 따른다. 앞의 둘은
  /// [thumbnailUrl] 이 맡으므로 여기서는 사용자 사진, 그다음 첫 메뉴 사진을 본다.
  ///
  /// 마지막 자리에 특정 매장 로고를 두면 안 된다. 두찜 간판이 이 몫이던 동안
  /// 사진 없이 쓴 글과 대표 이미지 없는 서버 글이 전부 두찜으로 보였다
  /// (피드백 2026-08-21).
  String get thumbnailPath {
    if (imagePaths.isNotEmpty) return imagePaths.first;
    for (final store in stores) {
      for (final line in store.lines) {
        if (line.imagePath.isNotEmpty) return line.imagePath;
      }
    }
    return AppImages.placeholder;
  }

  /// 2026.07.07
  String get dateText =>
      '${createdAt.year}.${_two(createdAt.month)}.${_two(createdAt.day)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  /// 목록에서 쓰는 날짜. 시안(681:8066)은 갓 올라온 글은 "2분 전"으로,
  /// 오래된 글은 날짜로 보여준다. 하루가 넘어가면 절대 날짜가 더 읽기 쉽다.
  String relativeDateTextAt(DateTime now) {
    final gap = now.difference(createdAt);
    if (gap.inMinutes < 1) return '방금 전';
    if (gap.inHours < 1) return '${gap.inMinutes}분 전';
    if (gap.inDays < 1) return '${gap.inHours}시간 전';
    return dateText;
  }

  String get relativeDateText => relativeDateTextAt(DateTime.now());

  /// 목록·상세에서 본문을 몇 줄로 줄여 보여줄 때 쓴다.
  String get bodyPreview => body.replaceAll('\n', ' ');

  /// 이 글에 담긴 매장 이름 전부.
  List<String> get restaurantNames => [for (final s in stores) s.restaurant.name];

  /// 카드 제목 옆에 붙이는 매장 표기. 여러 곳이면 "외 N곳" 으로 줄인다.
  String get storeSummary => switch (restaurantNames.length) {
        0 => '',
        1 => restaurantNames.first,
        final n => '${restaurantNames.first} 외 ${n - 1}곳',
      };

  /// 매장을 통틀어 담긴 메뉴 전부.
  List<CartLine> get allLines => [for (final s in stores) ...s.lines];

  /// 결제 예상액. 매장별 배달비가 모두 더해진다.
  int get payableTotal => stores.fold(0, (sum, s) => sum + s.subtotal);

  int get itemsTotal => stores.fold(0, (sum, s) => sum + s.itemsTotal);

  /// "나도 주문하기" 가 넘길 장바구니. 스냅샷을 건드리지 않도록 복사본이다.
  Cart toCart() => Cart(stores: [for (final s in stores) s.copy()]);

  YogijokboPost copy() => YogijokboPost(
        id: id,
        title: title,
        body: body,
        author: author,
        stores: [for (final s in stores) s.copy()],
        createdAt: createdAt,
        imagePaths: imagePaths,
        imageUrls: imageUrls,
        source: source,
        likeCount: likeCount,
        likedByMe: likedByMe,
        commentCount: commentCount,
        mine: mine,
        listThumbnailUrl: listThumbnailUrl,
      );
}

/// 목록 정렬. wire 값은 대문자 — api-yogijokbo.md 공통 규칙.
enum PostSort {
  popular('인기순', 'POPULAR'),
  latest('최신순', 'LATEST');

  const PostSort(this.title, this.wire);

  final String title;
  final String wire;
}
