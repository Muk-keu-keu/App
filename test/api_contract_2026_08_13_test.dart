import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/post.dart';

/// 2026-08-13 명세 개정분을 앱이 그대로 읽는지 지킨다.
void main() {
  group('rating — 리뷰가 없으면 null', () {
    test('null 을 0.0 으로 채우지 않는다', () {
      // 서버가 일부러 null 을 준다. 0.0 으로 받으면 평가가 없는 새 가게가
      // 최악의 평점으로 그려진다.
      final r = Restaurant.fromJson(const {
        'restaurantId': 1,
        'name': '두찜 강남구청점',
        'foodCategory': 'KOREAN',
        'rating': null,
      });

      expect(r.rating, isNull);
      expect(r.ratingText, '평가 없음');
    });

    test('값이 있으면 리뷰 수와 함께 보여준다', () {
      final r = Restaurant.fromJson(const {
        'restaurantId': 1,
        'name': '두찜 강남구청점',
        'foodCategory': 'KOREAN',
        'rating': 4.8,
        'reviewCount': 1383,
      });

      expect(r.rating, 4.8);
      expect(r.ratingText, '4.8/5 (1383)');
    });

    test('리뷰 수만 없으면 평점만 보여준다', () {
      final r = Restaurant.fromJson(const {
        'restaurantId': 1,
        'name': 'x',
        'foodCategory': 'KOREAN',
        'rating': 4.5,
      });

      expect(r.ratingText, '4.5/5');
    });
  });

  group('emptyReason — 왜 0개인지 말한다', () {
    AnalysisResult withReason(String? reason) => AnalysisResult.fromJson({
          'summary': null,
          'emptyReason': reason,
          'exactMatches': const [],
          'dishResults': const [],
        });

    test('세 값이 서로 다른 문구가 된다', () {
      final messages = {
        for (final r in ['NO_NEARBY', 'DELIVERY_TIME_FILTERED', 'NO_SIMILAR_MENU'])
          r: withReason(r).emptyMessage,
      };

      expect(messages.values.toSet(), hasLength(3));
      // 배달시간은 사용자가 직접 풀 수 있는 유일한 조건이라 방법을 알려 준다.
      expect(messages['DELIVERY_TIME_FILTERED'], contains('시간을 늘리면'));
      expect(messages['NO_NEARBY'], contains('근처에'));
    });

    test('값이 없으면 일반 문구로 떨어진다', () {
      // 앱이 카테고리·메뉴명으로 더 걸러서 0이 된 경우다. 서버는 이유를 주지 않는다.
      expect(withReason(null).emptyMessage, '조건에 맞는 조합을 찾지 못했어요.');
    });

    test('모르는 값이 와도 터지지 않는다', () {
      expect(withReason('SOMETHING_NEW').emptyMessage, isNotEmpty);
    });
  });

  group('요기족보 목록 — body·thumbnailUrl', () {
    test('목록 카드가 본문과 썸네일을 함께 읽는다', () {
      final post = YogijokboPost.fromListJson(const {
        'postId': 9064,
        'title': '엽떡에 교촌 곁들이니 미쳤음',
        'body': '영상 보고 그대로 시켰는데 분모자가 신의 한 수였음.',
        'thumbnailUrl': 'https://cdn.example.com/a.jpg',
        'authorNickName': '윤수',
        'likeCount': 3,
        'commentCount': 2,
        'liked': true,
      });

      expect(post.id, '9064');
      expect(post.body, '영상 보고 그대로 시켰는데 분모자가 신의 한 수였음.');
      expect(post.listThumbnailUrl, 'https://cdn.example.com/a.jpg');
      expect(post.likedByMe, isTrue);
      expect(post.commentCount, 2);
    });

    test('사진 없이 쓴 글은 썸네일이 null 이다', () {
      final post = YogijokboPost.fromListJson(const {
        'postId': 1,
        'title': 't',
        'body': 'b',
        'thumbnailUrl': null,
      });

      expect(post.listThumbnailUrl, isNull);
    });
  });
}
