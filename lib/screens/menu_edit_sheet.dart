import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showMenuEditSheet(BuildContext context, ComboRecommendation combo) {
  final flow = context.read<AppFlow>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
    ),
    builder: (_) => ChangeNotifierProvider<AppFlow>.value(
      value: flow,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: MenuEditSheet(combo: combo),
      ),
    ),
  );
}

/// "메뉴 수정하기" 시트.
/// Figma 와이어프레임에 연결 화면이 없어, 필터 시트 구조와 조합 카드의 메뉴 행을
/// 재사용해 같은 디자인 언어로 구성했다.
class MenuEditSheet extends StatefulWidget {
  const MenuEditSheet({super.key, required this.combo});

  final ComboRecommendation combo;

  @override
  State<MenuEditSheet> createState() => _MenuEditSheetState();
}

class _MenuEditSheetState extends State<MenuEditSheet> {
  late List<ComboItem> _draft = widget.combo.items.map((e) => e.copy()).toList();
  List<MenuItem> _catalog = [];

  @override
  void initState() {
    super.initState();
    context.read<AppFlow>().storeMenu(widget.combo.store.id).then((menu) {
      if (mounted) setState(() => _catalog = menu);
    });
  }

  List<MenuItem> get _addable =>
      _catalog.where((m) => !_draft.any((d) => d.id == m.id)).toList();

  int get _total => _draft.fold(0, (sum, e) => sum + e.lineTotal);

  void _change(ComboItem item, int delta) {
    final i = _draft.indexWhere((e) => e.id == item.id);
    if (i < 0) return;
    setState(() {
      final next = _draft[i].quantity + delta;
      if (next <= 0) {
        _draft.removeAt(i);
      } else {
        _draft[i].quantity = next;
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppColors.dragHandle,
              borderRadius: BorderRadius.circular(100),
            ),
          ),
          const SizedBox(height: 15),
          Text('메뉴 수정하기', style: AppText.semiBold(20, spacing: -0.5)),
          const SizedBox(height: 2),
          Text(widget.combo.store.name,
              style: AppText.regular(14, spacing: -0.35, color: AppColors.gray600)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_draft.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          '담긴 메뉴가 없어요.\n아래에서 메뉴를 추가해 주세요.',
                          textAlign: TextAlign.center,
                          style: AppText.regular(14,
                              spacing: -0.35, color: AppColors.gray600),
                        ),
                      ),
                    )
                  else
                    for (final item in _draft) ...[
                      ComboMenuRow(
                        item: item,
                        onDecrease: () => _change(item, -1),
                        onIncrease: () => _change(item, 1),
                      ),
                      const SizedBox(height: 16),
                    ],
                  if (_addable.isNotEmpty) ...[
                    Container(height: 1, color: AppColors.gray300),
                    const SizedBox(height: 20),
                    Text('메뉴 추가하기',
                        style: AppText.semiBold(16,
                            spacing: -0.4, color: AppColors.gray800)),
                    const SizedBox(height: 12),
                    for (final menu in _addable) ...[
                      _addRow(menu),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF5D5D5D).withValues(alpha: 0.12),
                  blurRadius: 5,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('합계',
                          style: AppText.regular(14,
                              spacing: -0.35, color: AppColors.gray700)),
                      Text('${wonFormat(_total)}원',
                          style: AppText.semiBold(20, spacing: -0.5)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  PrimaryButton(
                    label: '적용하기',
                    onPressed: () {
                      context
                          .read<AppFlow>()
                          .replaceItems(comboId: widget.combo.id, items: _draft);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  Widget _addRow(MenuItem menu) => GestureDetector(
        onTap: () => setState(() => _draft.add(menu.toComboItem())),
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(menu.imagePath, width: 56, height: 56, fit: BoxFit.cover),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(menu.name, style: AppText.semiBold(14, spacing: -0.35)),
                  const SizedBox(height: 4),
                  Text('${wonFormat(menu.price)}원',
                      style: AppText.regular(12,
                          spacing: -0.3, color: AppColors.gray600)),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.softPinkFill,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, size: 16, color: AppColors.primary),
            ),
          ],
        ),
      );
}
