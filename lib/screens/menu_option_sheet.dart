import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/ds.dart';
import 'menu_option_body.dart';

/// Figma "옵션 변경" — 개정 시안 925:4037.
///
/// **그룹마다 하나씩 고르는 라디오다.** 회의(2026-08-04)에서 평평한 체크박스
/// 목록으로 갔다가 개정 시안에서 라디오로 돌아왔다. `group` 이 곧 라디오 그룹이고,
/// 서버가 `selected` 로 내려준 값이 처음 선택으로 들어온다.
///
/// **서버로 나가는 모양은 그대로 `selectedOptions[]` 배열이다.** 그룹당 하나씩
/// 담기므로 항목 수가 그룹 수를 넘지 않을 뿐, 요청 스키마는 바뀌지 않았다.
/// 다만 "그룹당 최대 1개" 라는 제약이 화면에만 있고 명세에는 없다 — 서버가 같은
/// 그룹의 옵션을 두 개 받아도 막지 않는다는 뜻이라 백엔드와 맞춰야 한다.
///
/// 맵기는 여전히 옵션 밖이다. `spiceAdjustable` 인 메뉴만 3버튼을 그리고 고른 값은
/// `selectedSpice` 로 따로 나간다. 개정 시안의 "매운맛 5단계" 그룹은 제목만 5단계고
/// 선택지는 3개뿐이라 옛 라벨이 남은 것으로 보고 기존 결정을 유지했다.
class MenuOptionSheet extends StatefulWidget {
  const MenuOptionSheet({
    super.key,
    required this.restaurantId,
    required this.line,
    this.suggestion,
  });

  final int restaurantId;
  final CartLine line;

  /// 조합 카드에서 열었으면 그 조합. 장바구니에 담기 전이라 고친 값을 넣을 곳이
  /// 장바구니가 아니라 이 조합이다 (시안 925:4243 — 카드 안에도 "옵션 변경" 이 있다).
  final ComboSuggestion? suggestion;

  static Future<void> show(
    BuildContext context, {
    required int restaurantId,
    required CartLine line,
    ComboSuggestion? suggestion,
  }) {
    final flow = context.read<AppFlow>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider<AppFlow>.value(
        value: flow,
        child: FractionallySizedBox(
          heightFactor: 0.92,
          child: MenuOptionSheet(
            restaurantId: restaurantId,
            line: line,
            suggestion: suggestion,
          ),
        ),
      ),
    );
  }

  @override
  State<MenuOptionSheet> createState() => _MenuOptionSheetState();
}

class _MenuOptionSheetState extends State<MenuOptionSheet> {
  /// 체크된 옵션.
  late Set<String> _checked = {
    for (final o in widget.line.options)
      if (o.selected) menuOptionKey(o),
  };

  /// 고른 맵기. 조절 불가 메뉴면 쓰이지 않는다.
  late SpiceLevel? _spice = widget.line.selectedSpice;

  List<MenuOption> get _selection => [
        for (final o in widget.line.options)
          if (_checked.contains(menuOptionKey(o))) o,
      ];

  void _pick(MenuOption option) =>
      setState(() => _checked = pickInGroup(_checked, option));

  @override
  Widget build(BuildContext context) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFEFEFE),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFDCDCDC),
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 15),
          _Header(
            title: widget.line.name,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: MenuOptionList(
                options: widget.line.options,
                spiceAdjustable: widget.line.spiceAdjustable,
                spice: _spice,
                onPickSpice: (next) => setState(() => _spice = next),
                checked: _checked,
                onPickOption: _pick,
              ),
            ),
          ),
          _BottomCta(
            onApply: () {
              final flow = context.read<AppFlow>();
              final spice = widget.line.spiceAdjustable ? _spice : null;
              final suggestion = widget.suggestion;

              if (suggestion == null) {
                flow.updateLineOptions(
                  restaurantId: widget.restaurantId,
                  menuId: widget.line.menuId,
                  chosen: _selection,
                  spice: spice,
                );
              } else {
                flow.updateSuggestionLineOptions(
                  suggestion: suggestion,
                  menuId: widget.line.menuId,
                  chosen: _selection,
                  spice: spice,
                );
              }
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: SizedBox(
          height: 32,
          child: Row(
            children: [
              const SizedBox(width: 64),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.h3(),
                  ),
                ),
              ),
              SizedBox(
                width: 64,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: GestureDetector(
                    onTap: onClose,
                    behavior: HitTestBehavior.opaque,
                    child: const DsCloseIcon(size: 18.19, box: 24),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.onApply});

  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5D5D5D).withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: SafeArea(
          top: false,
          // 시안(681:6050) 문구 그대로. 금액은 시트를 닫으면 카드에서 보인다.
          child: DsButton(label: '변경하기', onPressed: onApply),
        ),
      );
}
