/// 조합 추천 도메인 모델.
///
/// iOS 앱 ComboModels.swift 와 필드가 1:1로 같다. 두 플랫폼이 같은 백엔드 API를
/// 쓰게 되므로 이 구조가 곧 API 응답 스키마다. 한쪽을 고치면 반드시 다른 쪽도 맞춘다.
///
/// imagePath 는 지금 로컬 에셋 경로이고, API 연동 시 URL 로 바뀐다.
/// 그때 Image.asset → Image.network 로만 바꾸면 된다.
library;

import 'menu_option.dart';

export 'menu_option.dart';

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
    this.heroImagePath = '',
    this.deliveryRangeText,
    this.pickupMinutes = 0,
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

  /// 매장 상세 상단에 깔리는 큰 사진. 비면 [imagePath] 를 쓴다.
  final String heroImagePath;

  /// "26~42분" 처럼 폭이 있는 배달 예상. 서버가 구간으로 주는 값이라
  /// 정렬용 숫자([deliveryMinutes])와 따로 둔다. 없으면 숫자로 표시한다.
  final String? deliveryRangeText;

  /// 포장 예상 시간(분). 0이면 포장 탭을 비활성으로 그린다.
  final int pickupMinutes;

  String get ratingText => '${rating.toStringAsFixed(1)}/5 ($reviewCount)';

  String get heroPath => heroImagePath.isEmpty ? imagePath : heroImagePath;
  String get deliveryTabText => '배달 ${deliveryRangeText ?? deliveryText}';
  String get pickupTabText => pickupMinutes == 0 ? '포장' : '포장 $pickupMinutes분';
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
    this.optionGroups = const [],
    this.selectedOptions = const [],
    this.selectedSpice,
    this.optionsPrice = 0,
  });

  final String id;
  final String name; // "[원조 K 로제] 로제 닭발"

  /// API `description` — "순살, 보통맛, 중국당면, ..." 주문 시점 스냅샷 문자열.
  /// 옵션 변경 시트에서 다시 만들어 넣기 때문에 final 이 아니다.
  String options;

  /// 메뉴 기본가. 옵션 추가금은 [optionsPrice] 로 따로 둔다 — 명세가 두 값을
  /// 나눠 내려주고, 합쳐 두면 나중에 옵션만 바꿀 때 기본가를 되찾을 수 없다.
  int unitPrice;
  int quantity;
  final String imagePath;

  /// 고른 옵션들. API `selectedOptions`.
  List<SelectedOption> selectedOptions;

  /// 고른 맵기. API `selectedSpice` (nullable).
  SpiceSelection? selectedSpice;

  /// 옵션 추가금 합. API `optionsPrice`.
  int optionsPrice;

  /// 이 메뉴가 고를 수 있는 옵션 그룹. 조합에 담길 때 메뉴에서 그대로 물려받는다.
  final List<MenuOptionGroup> optionGroups;

  /// 원격 이미지. 릴스 썸네일이 곧 영상에서 본 그 음식이라 첫 메뉴에 쓴다.
  final String? imageUrl;

  /// API `lineTotal` — (기본가 + 옵션 추가금) × 수량.
  int get lineTotal => (unitPrice + optionsPrice) * quantity;

  ComboItem copy() => ComboItem(
        id: id,
        name: name,
        options: options,
        unitPrice: unitPrice,
        quantity: quantity,
        imagePath: imagePath,
        imageUrl: imageUrl,
        optionGroups: optionGroups,
        selectedOptions: [...selectedOptions],
        selectedSpice: selectedSpice,
        optionsPrice: optionsPrice,
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
    this.category = '대표메뉴',
    this.optionGroups = const [],
  });

  final String id;
  final String name;
  final String options;
  final int price;
  final String imagePath;
  final String? imageUrl;

  /// 매장 메뉴 화면의 카테고리 칩(대표메뉴·신메뉴·사이드…) 구분.
  final String category;

  /// 옵션 그룹. 비어 있으면 "옵션 변경"에서 고칠 게 없다.
  final List<MenuOptionGroup> optionGroups;

  ComboItem toComboItem({int quantity = 1}) => ComboItem(
        id: id,
        name: name,
        options: options,
        unitPrice: price,
        quantity: quantity,
        imagePath: imagePath,
        imageUrl: imageUrl,
        optionGroups: optionGroups,
      );

  /// 필수 그룹의 첫 선택지를 미리 골라 담는다. 요기요처럼 필수 옵션이 있는
  /// 메뉴는 아무것도 안 고른 상태로 장바구니에 들어갈 수 없다.
  ComboItem toComboItemWithDefaults({int quantity = 1}) {
    final chosen = [
      for (final g in optionGroups)
        SelectedOption(name: g.defaultChoice.name, price: g.defaultChoice.extraPrice),
    ];
    return ComboItem(
      id: id,
      name: name,
      options: chosen.isEmpty ? options : chosen.map((c) => c.name).join(', '),
      unitPrice: price,
      quantity: quantity,
      imagePath: imagePath,
      imageUrl: imageUrl,
      optionGroups: optionGroups,
      selectedOptions: chosen,
      optionsPrice: chosen.fold(0, (sum, c) => sum + c.price),
    );
  }
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
