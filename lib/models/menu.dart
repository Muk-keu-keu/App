/// 메뉴와 장바구니 한 칸.
///
/// 명세는 같은 메뉴를 두 모양으로 내려준다.
/// - [Menu] — `GET v1/restaurants/{id}/menus` 의 `menus[]`. 사용자가 직접 고르는
///   화면용이라 `description` 이 있고 `quantity`·`selectedSpice` 가 없다.
/// - [CartLine] — `POST v1/analyses` 의 `items[]`. "한 줄이 장바구니 한 칸" 이다.
///
/// 주문 요청(`POST v1/orders`)은 필드명이 다르다 — `name` → `menuName`,
/// `price` → `unitPrice`. [CartLine.toOrderJson] 이 그 변환을 맡는다.
library;

import 'enums.dart';
import 'menu_option.dart';

/// 매장이 파는 메뉴 한 종류. 담기 전이라 수량이 없다.
class Menu {
  const Menu({
    required this.menuId,
    required this.name,
    required this.menuType,
    required this.price,
    this.description = '',
    this.imageUrl = '',
    this.spiceLevel = SpiceLevel.none,
    this.spiceAdjustable = false,
    this.options = const [],
    this.imagePath = 'assets/images/menu_rose_dakbal.png',
  });

  final int menuId;
  final String name;

  /// 섹션 구분. 응답이 MAIN → SIDE → DRINK 순으로 정렬돼 온다.
  final MenuType menuType;

  /// 메뉴 정가.
  final int price;

  /// 맛·식감 한 줄. 처음 보는 메뉴를 고르는 화면이라 "이게 뭐지" 를 알려준다.
  final String description;

  final String imageUrl;

  /// 그 메뉴가 원래 얼마나 매운지. MEDIUM/HOT 이면 고추 뱃지를 붙인다.
  final SpiceLevel spiceLevel;

  /// true 면 순한맛/기본/매운맛 3버튼을 그린다.
  final bool spiceAdjustable;

  /// 사리·토핑·소스. 빈 배열이면 "옵션 변경" 버튼을 숨긴다.
  final List<MenuOption> options;

  /// 원격 이미지를 못 받았을 때 쓰는 번들 에셋. 서버 필드가 아니다.
  final String imagePath;

  bool get isSpicy => spiceLevel != SpiceLevel.none;

  /// 장바구니에 담는다. 미리 체크된 옵션(`selected: true`)만 담아 간다.
  ///
  /// 메뉴 조회 응답의 옵션에는 `selected` 가 없어 전부 false 다. 즉 이 화면에서
  /// 담은 메뉴는 옵션 없이 시작하고, 사용자가 "옵션 변경" 에서 고른다.
  CartLine toCartLine({int quantity = 1}) => CartLine(
        menuId: menuId,
        name: name,
        menuType: menuType,
        price: price,
        imageUrl: imageUrl,
        imagePath: imagePath,
        quantity: quantity,
        spiceLevel: spiceLevel,
        spiceAdjustable: spiceAdjustable,
        // 맵기 조절이 되는 메뉴는 원래 맵기로 시작한다. 안 되는 메뉴는 고를 게 없어 null.
        selectedSpice: spiceAdjustable ? spiceLevel : null,
        options: options,
      );

  factory Menu.fromJson(Map<String, dynamic> json) => Menu(
        menuId: ((json['menuId'] ?? 0) as num).toInt(),
        name: (json['name'] ?? '') as String,
        menuType: MenuType.fromWire(json['menuType'] as String?),
        price: ((json['price'] ?? 0) as num).toInt(),
        description: (json['description'] ?? '') as String,
        imageUrl: (json['imageUrl'] ?? '') as String,
        spiceLevel: SpiceLevel.fromWireOrNone(json['spiceLevel'] as String?),
        spiceAdjustable: (json['spiceAdjustable'] ?? false) as bool,
        options: MenuOption.listFrom(json['options']),
      );
}

/// 장바구니 한 칸. 수량과 고른 옵션을 들고 있어 변경 가능하다.
class CartLine {
  CartLine({
    required this.menuId,
    required this.name,
    required this.menuType,
    required this.price,
    required this.quantity,
    this.imageUrl = '',
    this.imagePath = 'assets/images/menu_rose_dakbal.png',
    this.spiceLevel = SpiceLevel.none,
    this.spiceAdjustable = false,
    this.selectedSpice,
    this.options = const [],
  });

  final int menuId;
  final String name;
  final MenuType menuType;

  /// 메뉴 정가. 옵션 추가금과 합치지 않는다 — 명세가 두 값을 나눠 내려주고,
  /// 합쳐 두면 나중에 옵션만 바꿀 때 기본가를 되찾을 수 없다.
  final int price;

  int quantity;

  final String imageUrl;
  final String imagePath;

  final SpiceLevel spiceLevel;
  final bool spiceAdjustable;

  /// 고른 맵기. 조절 불가 메뉴는 null 이다.
  SpiceLevel? selectedSpice;

  /// 고를 수 있는 옵션 전부. 고른 것은 `selected == true` 로 표시된다.
  /// 주문 요청에는 [selectedOptions] 만 나간다.
  List<MenuOption> options;

  bool get isSpicy => spiceLevel != SpiceLevel.none;

  /// 옵션 변경 버튼을 그릴지. 빈 배열이면 고칠 게 없어 숨긴다.
  bool get hasOptions => options.isNotEmpty;

  List<MenuOption> get selectedOptions => [
        for (final o in options)
          if (o.selected) o,
      ];

  /// 체크된 옵션 합계.
  int get optionsPrice => selectedOptions.fold(0, (sum, o) => sum + o.price);

  /// `(price + optionsPrice) × quantity`
  int get lineTotal => (price + optionsPrice) * quantity;

  /// 카드 두 번째 줄에 쓰는 요약. 고른 옵션이 없으면 맵기만이라도 보여준다.
  String get optionsText {
    final parts = [
      if (selectedSpice != null && spiceAdjustable) selectedSpice!.title,
      for (final o in selectedOptions) o.name,
    ];
    return parts.join(', ');
  }

  /// 고른 옵션을 갈아끼운다. 화면이 넘겨준 목록에 있는 것만 체크로 남긴다.
  void applySelection(List<MenuOption> chosen) {
    options = [
      for (final o in options)
        o.copyWith(selected: chosen.any((c) => c.isSameAs(o))),
    ];
  }

  CartLine copy() => CartLine(
        menuId: menuId,
        name: name,
        menuType: menuType,
        price: price,
        quantity: quantity,
        imageUrl: imageUrl,
        imagePath: imagePath,
        spiceLevel: spiceLevel,
        spiceAdjustable: spiceAdjustable,
        selectedSpice: selectedSpice,
        options: [...options],
      );

  /// 분석 응답의 `items[]`.
  factory CartLine.fromJson(Map<String, dynamic> json) => CartLine(
        menuId: ((json['menuId'] ?? 0) as num).toInt(),
        name: (json['name'] ?? '') as String,
        menuType: MenuType.fromWire(json['menuType'] as String?),
        price: ((json['price'] ?? 0) as num).toInt(),
        // 서버가 안 주면 1개로 본다. 0으로 두면 장바구니에서 바로 사라진다.
        quantity: ((json['quantity'] ?? 1) as num).toInt(),
        imageUrl: (json['imageUrl'] ?? '') as String,
        spiceLevel: SpiceLevel.fromWireOrNone(json['spiceLevel'] as String?),
        spiceAdjustable: (json['spiceAdjustable'] ?? false) as bool,
        selectedSpice: SpiceLevel.fromWire(json['selectedSpice'] as String?),
        options: MenuOption.listFrom(json['options']),
      );

  /// 주문 상세 응답의 `items[]`. 필드명이 다르고, 옵션은 고른 것만 온다.
  ///
  /// 그래서 여기서 만든 [CartLine] 의 `options` 는 "고른 옵션" 뿐이다 —
  /// 안 고른 선택지를 알 수 없어 옵션 변경 시트를 열면 후보가 부족하다.
  /// 다시 주문은 GET menus 로 후보를 다시 받아 채운다.
  factory CartLine.fromOrderJson(Map<String, dynamic> json) => CartLine(
        menuId: ((json['menuId'] ?? 0) as num).toInt(),
        name: (json['menuName'] ?? '') as String,
        menuType: MenuType.fromWire(json['menuType'] as String?),
        price: ((json['unitPrice'] ?? 0) as num).toInt(),
        quantity: ((json['quantity'] ?? 1) as num).toInt(),
        selectedSpice: SpiceLevel.fromWire(json['selectedSpice'] as String?),
        // 조절 가능 여부를 주지 않는다. 맵기가 담겨 있으면 조절되는 메뉴였다는 뜻이다.
        spiceAdjustable: json['selectedSpice'] != null,
        options: [
          for (final o in MenuOption.listFrom(json['selectedOptions']))
            o.copyWith(selected: true),
        ],
      );

  /// `POST v1/orders` 의 `items[]`.
  ///
  /// `optionsPrice`·`lineTotal` 은 계산해 넣는다. 서버가 `menuId` 로 전부 다시
  /// 계산하므로 이 값들은 검증용이다 (명세: 프론트 금액은 안 믿는다).
  Map<String, dynamic> toOrderJson() => {
        'menuId': menuId,
        'menuName': name,
        'unitPrice': price,
        'quantity': quantity,
        'selectedSpice': selectedSpice?.wire,
        'selectedOptions': [for (final o in selectedOptions) o.toJson()],
        'optionsPrice': optionsPrice,
        'lineTotal': lineTotal,
      };
}
