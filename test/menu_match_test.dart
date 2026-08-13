import 'package:flutter_test/flutter_test.dart';
import 'package:mukbang_ttaradamgi/models/combo.dart';

DishCandidate candidate(String store, String menu, double score) => DishCandidate(
      restaurant: Restaurant(
        restaurantId: store.hashCode,
        name: store,
        foodCategory: FoodCategory.korean,
        area: '역삼동',
        rating: 4.5,
        etaMin: 30,
        deliveryFee: 3000,
        minOrderPrice: 12000,
        distanceKm: 1.2,
      ),
      item: CartLine(menuId: menu.hashCode, name: menu, price: 20000, menuType: MenuType.main, quantity: 1),
      score: score,
    );

/// 첫 화면은 "먹방 속 조합" 이다. 영상에 없던 음식이 거기 뜨면 안 된다.
///
/// 서버는 반경 안에서 가장 가까운 5개를 채워 주기만 한다. 마라로제 떡볶이를
/// 요청했을 때 실제로 이렇게 왔다 — 전부 KOREAN 이라 카테고리 필터로는 하나도
/// 걸러지지 않았고, 점수도 0.44~0.54 로 평평했다.
void main() {
  group('dishHeadNoun — 핵심 음식명', () {
    test('띄어 쓴 이름은 뒤엣말이 정체다', () {
      expect(AnalysisResult.dishHeadNoun('마라로제 떡볶이'), '떡볶이');
      expect(AnalysisResult.dishHeadNoun('오리지널 떡볶이'), '떡볶이');
      expect(AnalysisResult.dishHeadNoun('간장 치킨'), '치킨');
    });

    test('붙여 쓴 이름도 표에서 찾아낸다', () {
      // 여기가 처음 규칙이 무너진 자리다. 통째로 핵심어로 쓰면
      // "럭키치즈떡볶이" 가 "치즈떡볶이" 와 다른 음식이 되어 버린다.
      expect(AnalysisResult.dishHeadNoun('럭키치즈떡볶이'), '떡볶이');
      expect(AnalysisResult.dishHeadNoun('마라로제찜닭'), '찜닭');
      expect(AnalysisResult.dishHeadNoun('동파육'), '동파육');
    });

    test('긴 이름을 먼저 잡는다', () {
      // "떡볶이" 를 "볶이" 로 자르면 라볶이까지 같은 음식이 된다.
      expect(AnalysisResult.dishHeadNoun('치즈라볶이'), '라볶이');
      expect(AnalysisResult.dishHeadNoun('매운 제육볶음'), '제육볶음');
    });

    test('뒤에 수량이 붙어도 찾는다', () {
      expect(AnalysisResult.dishHeadNoun('떡볶이 2인분'), '떡볶이');
      expect(AnalysisResult.dishHeadNoun('치킨 세트'), '치킨');
    });

    test('모르는 음식은 빈 문자열이다', () {
      // 표에 없는 이름이다. 여기서 억지로 정하면 멀쩡한 후보가 전부 떨어진다.
      expect(AnalysisResult.dishHeadNoun('인기폭탄세트'), '');
      expect(AnalysisResult.dishHeadNoun('오징어 먹물 슬러쉬'), '');
      expect(AnalysisResult.dishHeadNoun(''), '');
      expect(AnalysisResult.dishHeadNoun('   '), '');
    });
  });

  group('isSameDish — 같은 음식인지', () {
    test('실제로 잘못 떴던 조합을 걸러낸다', () {
      expect(AnalysisResult.isSameDish('마라로제 떡볶이', '마라로제찜닭'), isFalse);
      expect(AnalysisResult.isSameDish('마라로제 떡볶이', '로제찜닭'), isFalse);
      expect(AnalysisResult.isSameDish('마라로제 떡볶이', '제육볶음 도시락'), isFalse);
      expect(AnalysisResult.isSameDish('마라로제 떡볶이', '쟁반국수'), isFalse);
      expect(AnalysisResult.isSameDish('동파육', '탕수육'), isFalse);
    });

    test('같은 음식은 남긴다', () {
      expect(AnalysisResult.isSameDish('마라로제 떡볶이', '마라로제 떡볶이'), isTrue);
      // 브랜드가 앞에 붙어도 정체는 떡볶이다.
      expect(AnalysisResult.isSameDish('오리지널 떡볶이', '엽기떡볶이 오리지널'), isTrue);
      expect(AnalysisResult.isSameDish('오리지널 떡볶이', '오리지널 떡볶이(중)'), isTrue);
      expect(AnalysisResult.isSameDish('동파육', '홍콩반점 동파육'), isTrue);
    });

    test('띄어쓰기 차이는 무시한다', () {
      expect(AnalysisResult.isSameDish('마라로제 떡볶이', '마라로제떡볶이'), isTrue);
      expect(AnalysisResult.isSameDish('마라 로제 떡볶이', '마라로제 떡 볶 이'), isTrue);
    });

    test('붙여 쓴 이름도 같은 음식으로 본다', () {
      // 실제로 "럭키치즈떡볶이 를 파는 곳이 근처에 없어요" 가 떴던 건이다.
      expect(AnalysisResult.isSameDish('럭키치즈떡볶이', '치즈떡볶이'), isTrue);
      expect(AnalysisResult.isSameDish('럭키치즈떡볶이', '오리지널 떡볶이'), isTrue);
      expect(AnalysisResult.isSameDish('럭키치즈떡볶이', '마라로제찜닭'), isFalse);
    });

    test('판단할 근거가 없으면 거르지 않는다', () {
      // 추출이 요리명을 못 준 경우나 표에 없는 음식까지 빈 화면으로 만들면
      // 더 나쁘다. 실제로 인기폭탄세트·슬러쉬가 전부 빈 화면이 됐다.
      expect(AnalysisResult.isSameDish('', '아무 메뉴'), isTrue);
      expect(AnalysisResult.isSameDish('인기폭탄세트', '엽기떡볶이 세트'), isTrue);
      expect(AnalysisResult.isSameDish('오징어 먹물 슬러쉬', '아무 메뉴'), isTrue);
    });
  });

  group('withMenuFilter', () {
    test('영상에 없던 음식을 첫 화면에서 걷어낸다', () {
      final result = AnalysisResult(
        dishResults: [
          DishResult(
            dishName: '마라로제 떡볶이',
            candidates: [
              candidate('두찜 강남구청점', '마라로제찜닭', 0.54),
              candidate('홍수계찜닭 종합운동장점', '로제찜닭', 0.46),
              candidate('직구삼 봉은사점', '비빔쫄면', 0.46),
              candidate('본도시락 학동점', '제육볶음 도시락', 0.46),
              candidate('가장맛있는족발 강남역점', '쟁반국수', 0.44),
            ],
          ),
        ],
      );

      // 전체 목록("다른 결과 보기")은 그대로 다섯 곳이다.
      expect(result.all, hasLength(5));
      // 첫 화면은 비어야 한다 — 떡볶이를 파는 곳이 하나도 없다.
      expect(result.withMenuFilter().all, isEmpty);
    });

    test('같은 메뉴가 있으면 그것만 남는다', () {
      final result = AnalysisResult(
        dishResults: [
          DishResult(
            dishName: '마라로제 떡볶이',
            candidates: [
              candidate('청년다방 역삼점', '마라로제 떡볶이', 0.93),
              candidate('두찜 강남구청점', '마라로제찜닭', 0.54),
            ],
          ),
        ],
      );

      final first = result.withMenuFilter().all;
      expect(first, hasLength(1));
      expect(first.single.restaurant.name, '청년다방 역삼점');
      expect(result.all, hasLength(2));
    });

    test('영상에 나온 브랜드(exactMatches)는 손대지 않는다', () {
      // 브랜드로 직접 찾은 것이라 메뉴명으로 다시 의심할 이유가 없다.
      final combo = ComboSuggestion(
        restaurant: candidate('청년다방 역삼점', 'x', 1).restaurant,
        items: [CartLine(menuId: 1, name: '마라로제 떡볶이', price: 15000, menuType: MenuType.main, quantity: 1)],
        comboScore: 1,
      );
      final result = AnalysisResult(exactMatches: [combo], dishResults: const []);

      expect(result.withMenuFilter().exactMatches, hasLength(1));
    });
  });
}
