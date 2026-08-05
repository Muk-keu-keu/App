/// 메뉴 옵션 하나.
///
/// 회의(2026-08-04)에서 별도 옵션 테이블을 없애고 `menu.options` JSON 배열로
/// 단순화했다. 그래서 그룹/선택지 2단 구조가 아니라 **평평한 목록**이고,
/// `group` 은 묶어 그릴 라벨일 뿐이다 (없으면 null).
///
/// 세 자리에서 같은 모양을 쓴다 — 명세 비고 "menu.options 와 같은 모양이라
/// 프론트가 변환할 것이 없다".
/// - `menu.options` (GET menus)
/// - `items[].options` (POST analyses 응답) — `selected` 가 붙어 온다
/// - `items[].selectedOptions` (POST/GET orders) — 고른 것만, `selected` 없음
library;

class MenuOption {
  const MenuOption({
    required this.name,
    required this.price,
    this.group,
    this.selected = false,
  });

  /// 묶어 그릴 라벨. `소스 선택` 처럼. 없으면 null 이고 그때는 라벨 없이 나열한다.
  final String? group;

  final String name;

  /// 추가금. 0이면 화면에 "+0원"으로 그대로 보인다(시안 동일).
  final int price;

  /// 이미 체크된 상태인지. 분석·메뉴 응답에만 있고 주문 요청에는 담지 않는다.
  final bool selected;

  MenuOption copyWith({bool? selected}) => MenuOption(
        group: group,
        name: name,
        price: price,
        selected: selected ?? this.selected,
      );

  /// 같은 옵션인지. 서버가 id 를 주지 않아 group+name 이 사실상의 키다.
  bool isSameAs(MenuOption other) => group == other.group && name == other.name;

  factory MenuOption.fromJson(Map<String, dynamic> json) => MenuOption(
        // `group` 은 없으면 null 이고, 키 자체가 빠지지는 않는다 (명세 규칙).
        group: json['group'] as String?,
        name: (json['name'] ?? '') as String,
        price: ((json['price'] ?? 0) as num).toInt(),
        selected: (json['selected'] ?? false) as bool,
      );

  /// 주문 요청의 `selectedOptions[]` 형태. `selected` 는 담지 않는다 —
  /// 고른 것만 보내므로 전부 true 여서 실어 보낼 의미가 없다.
  Map<String, dynamic> toJson() => {
        'group': group,
        'name': name,
        'price': price,
      };

  static List<MenuOption> listFrom(Object? raw) => switch (raw) {
        final List list => [
            for (final e in list)
              if (e is Map<String, dynamic>) MenuOption.fromJson(e),
          ],
        _ => const [],
      };
}

/// 옵션 변경 시트가 `group` 으로 묶어 그리기 위한 묶음.
///
/// 라벨이 없는 옵션들(`group == null`)은 하나의 무제 묶음으로 모은다.
/// 서버가 준 순서를 유지한다 — 순서가 곧 디자이너가 정한 노출 순서다.
class MenuOptionGroup {
  const MenuOptionGroup({required this.label, required this.options});

  /// null 이면 라벨 없이 옵션만 나열한다.
  final String? label;

  final List<MenuOption> options;

  static List<MenuOptionGroup> groupBy(List<MenuOption> options) {
    final order = <String?>[];
    final buckets = <String?, List<MenuOption>>{};
    for (final o in options) {
      if (!buckets.containsKey(o.group)) {
        order.add(o.group);
        buckets[o.group] = [];
      }
      buckets[o.group]!.add(o);
    }
    return [
      for (final key in order) MenuOptionGroup(label: key, options: buckets[key]!),
    ];
  }
}
