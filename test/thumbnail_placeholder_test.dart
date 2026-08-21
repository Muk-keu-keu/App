import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/assets.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';
import 'package:mukbang_ttaradamgi/models/post.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';

/// 피드백 2026-08-21 — 두찜 간판(`store_dujjim.png`)이 앱 전체의 "이미지 없음"
/// 대역이었다. 사진 없이 쓴 글·대표 이미지 없는 서버 글·로고 없는 매장·영상
/// 썸네일을 못 받은 주문까지 전부 두찜 브랜드를 달고 나왔다.
void main() {
  const dujjim = 'assets/images/store_dujjim.png';

  YogijokboPost bare({
    List<String> imagePaths = const [],
    List<StoreCart> stores = const [],
  }) =>
      YogijokboPost(
        id: 'p1',
        title: '제목',
        body: '본문',
        author: const PostAuthor(id: 'u1', nickname: '나'),
        stores: stores,
        createdAt: DateTime(2026, 8, 21),
        imagePaths: imagePaths,
      );

  group('대표 이미지 폴백', () {
    test('사진도 조합도 없으면 중립 자리를 쓴다', () {
      expect(bare().thumbnailPath, AppImages.placeholder);
      expect(bare().thumbnailPath, isNot(dujjim));
    });

    test('사용자 사진이 있으면 그것을 먼저 쓴다', () {
      expect(
        bare(imagePaths: const ['assets/images/jokbo_demo_tuna_porridge.jpg'])
            .thumbnailPath,
        'assets/images/jokbo_demo_tuna_porridge.jpg',
      );
    });

    test('사진이 없으면 조합의 첫 메뉴 사진을 쓴다', () {
      // 명세(api-yogijokbo.md 1번)가 적어 둔 서버의 선택 순서와 같다.
      final post = bare(
        stores: [
          StoreCart(
            restaurant: const Restaurant(
              restaurantId: 101,
              name: 'KFC-용산아이파크몰점',
              foodCategory: FoodCategory.chicken,
              area: '한강로동',
              rating: 4.4,
              etaMin: 30,
              deliveryFee: 2000,
              minOrderPrice: 12000,
              distanceKm: 1.1,
            ),
            lines: [
              CartLine(
                menuId: 101001,
                name: '핫크리스피 치르르치킨',
                menuType: MenuType.main,
                price: 18000,
                quantity: 1,
                imagePath: 'assets/images/menu_cheese_ball.png',
              ),
            ],
          ),
        ],
      );

      expect(post.thumbnailPath, 'assets/images/menu_cheese_ball.png');
    });
  });

  group('두찜은 두찜 글에만 남는다', () {
    test('매장 기본 로고가 두찜이 아니다', () {
      const store = Restaurant(
        restaurantId: 999,
        name: '로고 없는 가게',
        foodCategory: FoodCategory.korean,
        area: '성수동',
        rating: 4.0,
        etaMin: 25,
        deliveryFee: 2000,
        minOrderPrice: 10000,
        distanceKm: 1.0,
      );

      expect(store.imagePath, AppImages.placeholder);
      expect(store.imagePath, isNot(dujjim));
    });

    test('시드에서 두찜 이미지는 두찜 글만 갖는다', () async {
      final page = await MockPostRepository().list(sort: PostSort.latest, size: 50);

      for (final post in page.items) {
        final usesDujjim = post.imagePaths.contains(dujjim);
        if (!usesDujjim) continue;
        expect(
          post.title,
          contains('두찜'),
          reason: '두찜과 무관한 글이 두찜 간판을 대표 이미지로 쓰고 있다',
        );
      }
    });

    test('실시간 인기 Best 5 에 두찜으로 고정된 카드가 없다', () async {
      final page = await MockPostRepository().list(sort: PostSort.popular, size: 5);

      final stuck = [
        for (final post in page.items)
          if (post.thumbnailUrl == null && post.thumbnailPath == dujjim) post.title,
      ];
      expect(stuck, isEmpty);
    });
  });
}
