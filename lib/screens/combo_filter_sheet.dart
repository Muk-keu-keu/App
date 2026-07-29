import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/preference.dart';
import '../theme.dart';
import '../widgets/common.dart';

Future<void> showComboFilterSheet(BuildContext context) {
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
      child: const ComboFilterSheet(),
    ),
  );
}

/// Figma "필터" 바텀시트 (node 150:812).
class ComboFilterSheet extends StatefulWidget {
  const ComboFilterSheet({super.key});

  @override
  State<ComboFilterSheet> createState() => _ComboFilterSheetState();
}

class _ComboFilterSheetState extends State<ComboFilterSheet> {
  late TastePreference _draft = context.read<AppFlow>().preference.copy();

  @override
  Widget build(BuildContext context) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Text('필터', style: AppText.semiBold(20, spacing: -0.5)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _section('모드', Wrap(spacing: 8, children: [
                    for (final m in ServingMode.values)
                      _chip(m.title, _draft.mode == m, () => setState(() => _draft.mode = m)),
                  ])),
                  const SizedBox(height: 20),
                  Container(height: 1, color: AppColors.gray300),
                  const SizedBox(height: 20),
                  _section('맵기', Wrap(spacing: 8, children: [
                    for (final s in SpiceLevel.values)
                      _chip(s.title, _draft.spice == s, () => setState(() => _draft.spice = s)),
                  ])),
                  const SizedBox(height: 20),
                  Container(height: 1, color: AppColors.gray300),
                  const SizedBox(height: 20),
                  _section(
                    '예상 도착 시간',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_draft.deliveryLabel,
                            style: AppText.medium(16,
                                spacing: -0.4, color: AppColors.gray600)),
                        const SizedBox(height: 9),
                        DeliveryTimeSlider(
                          minutes: _draft.maxDeliveryMinutes,
                          onChanged: (v) => setState(() => _draft.maxDeliveryMinutes = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(children: [
                GestureDetector(
                  onTap: () => setState(() => _draft = TastePreference()),
                  child: Container(
                    width: 92,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.gray200,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text('초기화',
                        style: AppText.regular(16,
                            spacing: -0.4, color: AppColors.gray800)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: PrimaryButton(
                    label: '적용하기',
                    onPressed: () {
                      context.read<AppFlow>().updatePreference(_draft);
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ]),
            ),
          ],
        ),
      );

  Widget _section(String title, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: AppText.semiBold(16, spacing: -0.4, color: AppColors.gray800)),
          const SizedBox(height: 12),
          child,
        ],
      );

  Widget _chip(String title, bool selected, VoidCallback onTap) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.softPinkFill : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppColors.checkedBorder : AppColors.gray400,
            ),
          ),
          child: Text(
            title,
            style: AppText.regular(14,
                spacing: -0.35, color: selected ? AppColors.primary : AppColors.gray800),
          ),
        ),
      );
}
