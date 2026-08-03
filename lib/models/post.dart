/// 요기족보 도메인 모델.
///
/// 사용자들이 자기 먹방 조합을 공유하고, 실시간 인기 조합을 보고, 마음에 들면 그대로
/// 주문하는 커뮤니티 기능. `docs/api-yogijokbo.md` 의 응답 스키마와 1:1로 맞췄다.
/// 필드를 고치면 그 문서도 함께 고친다 — 백엔드와의 계약이다.
library;

import 'combo.dart';

/// 게시글 작성자. API `author` 객체.
class PostAuthor {
  const PostAuthor({
    required this.id,
    required this.nickname,
    this.profileImageUrl,
  });

  final String id;
  final String nickname;
  final String? profileImageUrl;

  /// 프로필 사진이 없을 때 원형 자리에 넣을 한 글자.
  String get initial => nickname.isEmpty ? '?' : nickname.substring(0, 1);
}

/// 조합의 출처 영상. Figma 의 유튜브 배지에 해당한다.
///
/// 분석 파이프라인의 `AnalysisSource` 와 다르다 — 그쪽은 AI 에 넣은 입력이고,
/// 이건 게시글에 붙어 사용자에게 보이는 링크다.
class PostSource {
  const PostSource({required this.videoTitle, required this.videoUrl});

  final String videoTitle;
  final String videoUrl;
}

class PostComment {
  const PostComment({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final PostAuthor author;
  final String body;
  final DateTime createdAt;
}

class YogijokboPost {
  YogijokboPost({
    required this.id,
    required this.title,
    required this.body,
    required this.author,
    required this.combo,
    required this.createdAt,
    this.imagePaths = const [],
    this.imageUrls = const [],
    this.source,
    this.likeCount = 0,
    this.likedByMe = false,
    this.commentCount = 0,
    this.orderableHere = true,
  });

  final String id;
  final String title;
  final String body;
  final PostAuthor author;

  /// 작성 시점 조합 스냅샷. 매장이 가격을 올려도 예전 글은 그때 모습대로 보인다.
  /// (api-yogijokbo.md 2번 비고) 현재 주문 가능 여부는 "나도 주문하기"가 다시 확인한다.
  final ComboRecommendation combo;

  final DateTime createdAt;

  /// 번들 에셋 경로. 서버 연동 전 시연용.
  final List<String> imagePaths;

  /// 서버가 준 이미지 URL. 있으면 이쪽을 먼저 쓴다.
  final List<String> imageUrls;

  final PostSource? source;

  int likeCount;
  bool likedByMe;
  int commentCount;

  /// 내 위치에서 주문 가능한지. 목록의 "내 위치에서 가능한 조합만" 필터에 쓴다.
  final bool orderableHere;

  /// 대표 이미지. 목록 썸네일.
  String? get thumbnailUrl => imageUrls.isEmpty ? null : imageUrls.first;
  String get thumbnailPath =>
      imagePaths.isEmpty ? 'assets/images/store_dujjim.png' : imagePaths.first;

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

  YogijokboPost copy() => YogijokboPost(
        id: id,
        title: title,
        body: body,
        author: author,
        combo: combo.copy(),
        createdAt: createdAt,
        imagePaths: imagePaths,
        imageUrls: imageUrls,
        source: source,
        likeCount: likeCount,
        likedByMe: likedByMe,
        commentCount: commentCount,
        orderableHere: orderableHere,
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
