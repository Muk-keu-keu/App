import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/ds.dart';

/// Figma "옵션 변경" (node 681:6050).
///
/// 조합에 담긴 메뉴 하나의 옵션을 다시 고른다. 그룹마다 라디오라 하나씩만 고르고,
/// 고른 것들의 추가금이 단가에 더해진다.
class MenuOptionSheet extends StatefulWidget {
  const MenuOptionSheet({super.key, required this.comboId, required this.item});

  final String comboId;
  final ComboItem item;

  static Future<void> show(
    BuildContext context, {
    required String comboId,
    required ComboItem item,
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
          child: MenuOptionSheet(comboId: comboId, item: item),
        ),
      ),
    );
  }

  @override
  State<MenuOptionSheet> createState() => _MenuOptionSheetState();
}

class _MenuOptionSheetState extends State<MenuOptionSheet> {
  /// 그룹 id → 고른 선택지 id.
  late final Map<String, String> _picked = {
    for (final g in widget.item.optionGroups) g.id: _initial(g),
  };

  /// 이미 담긴 메뉴의 옵션 문자열에서 이름이 일치하는 선택지를 되살린다.
  /// 못 찾으면 시안처럼 첫 선택지가 켜진 상태로 연다.
  String _initial(MenuOptionGroup group) {
    final chosen = widget.item.options.split(',').map((e) => e.trim()).toSet();
    final match = group.choices.where((c) => chosen.contains(c.name));
    return match.isEmpty ? group.defaultChoice.id : match.first.id;
  }

  List<MenuOptionChoice> get _selection => [
        for (final g in widget.item.optionGroups)
          g.choices.firstWhere((c) => c.id == _picked[g.id]),
      ];

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
              title: widget.item.name,
              onClose: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (var i = 0; i < widget.item.optionGroups.length; i++) ...[
                    if (i > 0) const DsDivider(color: AppColors.gray300),
                    _Group(
                      group: widget.item.optionGroups[i],
                      pickedId: _picked[widget.item.optionGroups[i].id]!,
                      onPick: (id) => setState(
                        () => _picked[widget.item.optionGroups[i].id] = id,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _BottomCta(
              onApply: () {
                context.read<AppFlow>().updateItemOptions(
                      comboId: widget.comboId,
                      itemId: widget.item.id,
                      choices: _selection,
                    );
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
                    // 시안은 플러스 벡터를 135° 돌려 X 를 만든다. 같은 에셋을 쓴다.
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: Center(
                        child: Transform.rotate(
                          angle: 3 * 3.1415926535 / 4,
                          child: SvgPicture.asset(
                            DsIcons.close,
                            width: 18.19,
                            height: 18.19,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _Group extends StatelessWidget {
  const _Group({
    required this.group,
    required this.pickedId,
    required this.onPick,
  });

  final MenuOptionGroup group;
  final String pickedId;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(group.name, style: AppText.sub2(color: AppColors.gray800)),
                const SizedBox(width: 4),
                DsRequirementBadge(isRequired: group.isRequired),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < group.choices.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _Row(
                choice: group.choices[i],
                isOn: group.choices[i].id == pickedId,
                onTap: () => onPick(group.choices[i].id),
              ),
            ],
          ],
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.choice, required this.isOn, required this.onTap});

  final MenuOptionChoice choice;
  final bool isOn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  DsRadio(isOn: isOn),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      choice.name,
                      style: AppText.body2(color: AppColors.gray800),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '+${wonFormat(choice.extraPrice)}원',
              style: AppText.body2(color: AppColors.gray600),
            ),
          ],
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
          child: DsButton(label: '변경하기', onPressed: onApply),
        ),
      );
}
