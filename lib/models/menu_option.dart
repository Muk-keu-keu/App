/// 메뉴 옵션. Figma "옵션 변경" (node 681:6050) 이 쓰는 구조다.
///
/// 요기요 실제 주문서와 같은 모양이다 — 메뉴 하나에 옵션 그룹이 여러 개 있고,
/// 그룹마다 필수/선택이 갈리며 선택지마다 추가금이 붙는다.
/// API 로는 GET /stores/{storeId}/menu 응답의 `optionGroups`.
library;

class MenuOptionChoice {
  const MenuOptionChoice({
    required this.id,
    required this.name,
    this.extraPrice = 0,
  });

  final String id;
  final String name;

  /// 추가금. 0이면 화면에 "+0원"으로 그대로 보인다(시안 동일).
  final int extraPrice;
}

class MenuOptionGroup {
  const MenuOptionGroup({
    required this.id,
    required this.name,
    required this.choices,
    this.isRequired = true,
  });

  final String id;
  final String name;
  final List<MenuOptionChoice> choices;

  /// 필수면 분홍 "필수" 배지, 아니면 회색 "선택" 배지가 붙는다.
  final bool isRequired;

  /// 시안은 그룹마다 라디오 버튼이라 항상 하나만 고른다.
  /// 선택 그룹도 마찬가지여서 기본값으로 첫 선택지를 쓴다.
  MenuOptionChoice get defaultChoice => choices.first;
}
