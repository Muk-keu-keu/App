import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/preference.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Figma "필터" (node 681:6194).
///
/// 조합을 담기 전에 맵기·도착시간을 고른다. 개정 시안에서 "모드"(1인/비건)
/// 섹션이 빠졌다 — 자세한 배경은 [TastePreference] 주석에 있다.
class KeywordSelectScreen extends StatelessWidget {
  const KeywordSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final pref = flow.preference;

    return Column(
      children: [
        _header(context),
        Expanded(
          child: Container(
            color: AppColors.pageBackground,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _section(
                    title: '맵기',
                    body: '원하는 매운 정도에 맞춰 메뉴를 골라드려요.',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final level in SpiceLevel.values) _spiceCard(context, level, pref),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _section(
                    title: '예상 도착 시간',
                    body: '원하는 시간 안에 받을 수 있는 매장을 찾아드려요.',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pref.deliveryLabel,
                          style: AppText.medium(16, spacing: -0.4, color: AppColors.gray600),
                        ),
                        const SizedBox(height: 9),
                        DeliveryTimeSlider(
                          minutes: pref.maxDeliveryMinutes,
                          onChanged: (v) {
                            pref.maxDeliveryMinutes = v;
                            context.read<AppFlow>().updatePreference(pref);
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: '적용하기',
              onPressed: () => context.read<AppFlow>().applyPreferenceAndAnalyze(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: SafeArea(
          bottom: false,
          child: Text('먹방 속 조합, 내 취향대로', style: AppText.screenTitle),
        ),
      );

  Widget _section({required String title, required String body, required Widget child}) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.sectionTitle),
            Text(body, style: AppText.sectionBody),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );

  Widget _spiceCard(BuildContext context, SpiceLevel level, TastePreference pref) {
    final selected = pref.spice == level;
    return GestureDetector(
      onTap: () {
        pref.spice = level;
        context.read<AppFlow>().updatePreference(pref);
      },
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.selectedFill : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: AppColors.selectedBorder, width: 2) : null,
          boxShadow: figmaCardShadow,
        ),
        child: Column(
          children: [
            Image.asset(level.imagePath, width: 36, height: 36, fit: BoxFit.contain),
            const SizedBox(height: 8),
            Text(level.title, style: AppText.semiBold(14, spacing: -0.35)),
          ],
        ),
      ),
    );
  }
}
