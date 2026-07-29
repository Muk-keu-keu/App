/// 조합 추천 도메인 모델.
///
/// iOS 앱 ComboModels.swift 와 필드가 1:1로 같다. 두 플랫폼이 같은 백엔드 API를
/// 쓰게 되므로 이 구조가 곧 API 응답 스키마다. 한쪽을 고치면 반드시 다른 쪽도 맞춘다.
///
/// imagePath 는 지금 로컬 에셋 경로이고, API 연동 시 URL 로 바뀐다.
/// 그때 Image.asset → Image.network 로만 바꾸면 된다.

class StoreSummary {
  const StoreSummary({
    required this.id,
    required this.name,
    required this.rating,
    required this.reviewCount,
    required this.distanceKm,
    required this.deliveryMinutes,
    required this.imagePath,
    this.imageUrl,
    required this.minimumOrderAmount,
    required this.deliveryFee,
    required this.similarity,
  });

  final String id;
  final String name; // "두찜-잠실새내점"
  final double rating; // 4.2
  final int reviewCount; // 312
  final double distanceKm; // 3.2
  final int deliveryMinutes; // 40
  final String imagePath;

  /// 원격 이미지. 지금은 공유된 게시물의 og:image 이고, API 연동 후엔 서버가 준 URL.
  final String? imageUrl;
  final int minimumOrderAmount;
  final int deliveryFee;

  /// 먹방 영상 속 조합과의 유사도 0.0~1.0. 정렬 기준.
  final double similarity;

  String get ratingText => '${rating.toStringAsFixed(1)}/5 ($reviewCount)';
  String get distanceText => '${distanceKm.toStringAsFixed(1)} km';

  String get deliveryText {
    if (deliveryMinutes >= 60) {
      final h = deliveryMinutes ~/ 60;
      final m = deliveryMinutes % 60;
      return m == 0 ? '$h시간' : '$h시간 $m분';
    }
    return '$deliveryMinutes분';
  }
}

class ComboItem {
  ComboItem({
    required this.id,
    required this.name,
    required this.options,
    required this.unitPrice,
    required this.quantity,
    required this.imagePath,
    this.imageUrl,
  });

  final String id;
  final String name; // "[원조 K 로제] 로제 닭발"
  final String options; // "순살, 보통맛, 중국당면, ..."
  final int unitPrice;
  int quantity;
  final String imagePath;

  /// 원격 이미지. 릴스 썸네일이 곧 영상에서 본 그 음식이라 첫 메뉴에 쓴다.
  final String? imageUrl;

  int get lineTotal => unitPrice * quantity;

  ComboItem copy() => ComboItem(
        id: id,
        name: name,
        options: options,
        unitPrice: unitPrice,
        quantity: quantity,
        imagePath: imagePath,
        imageUrl: imageUrl,
      );
}

/// 매장이 파는 메뉴 한 종류. 조합에 담기 전이라 수량이 없다.
/// API 로는 GET /stores/{id}/menu 응답 원소.
class MenuItem {
  const MenuItem({
    required this.id,
    required this.name,
    required this.options,
    required this.price,
    required this.imagePath,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String options;
  final int price;
  final String imagePath;
  final String? imageUrl;

  ComboItem toComboItem({int quantity = 1}) => ComboItem(
        id: id,
        name: name,
        options: options,
        unitPrice: price,
        quantity: quantity,
        imagePath: imagePath,
        imageUrl: imageUrl,
      );
}

class ComboRecommendation {
  ComboRecommendation({required this.store, required this.items});

  final StoreSummary store;
  List<ComboItem> items;

  String get id => store.id;
  int get itemsTotal => items.fold(0, (sum, item) => sum + item.lineTotal);
  int get payableTotal => itemsTotal + store.deliveryFee;

  /// 최소 주문 금액을 넘겼는지
  bool get meetsMinimum => itemsTotal >= store.minimumOrderAmount;

  ComboRecommendation copy() =>
      ComboRecommendation(store: store, items: items.map((e) => e.copy()).toList());
}

/// 장바구니 화면 상단 정렬 기준
enum ComboSort {
  similarity('먹방 유사도순'),
  deliveryTime('빠른 배달순'),
  price('낮은 가격순');

  const ComboSort(this.title);
  final String title;
}

/// 1,234 형태로 끊어 표시
String wonFormat(int value) {
  final s = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buffer.write(',');
    buffer.write(s[i]);
  }
  return buffer.toString();
}
