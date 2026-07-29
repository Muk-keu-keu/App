import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'combo_filter_sheet.dart';
import 'menu_edit_sheet.dart';

/// Figma "장바구니" (node 111:1782).
/// 여러 매장의 조합을 비교해 하나를 고른다.
class ComboListScreen extends StatefulWidget {
  const ComboListScreen({super.key});

  @override
  State<ComboListScreen> createState() => _ComboListScreenState();
}

class _ComboListScreenState extends State<ComboListScreen> {
  bool _minimumOnly = false;

  List<ComboRecommendation> _visible(AppFlow flow) {
    final base = _minimumOnly
        ? flow.recommendations.where((c) => c.meetsMinimum).toList()
        : List<ComboRecommendation>.from(flow.recommendations);

    switch (flow.sort) {
      case ComboSort.similarity:
        base.sort((a, b) => b.store.similarity.compareTo(a.store.similarity));
      case ComboSort.deliveryTime:
        base.sort((a, b) => a.store.deliveryMinutes.compareTo(b.store.deliveryMinutes));
      case ComboSort.price:
        base.sort((a, b) => a.itemsTotal.compareTo(b.itemsTotal));
    }
    return base;
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final combos = _visible(flow);

    return Column(
      children: [
        _header(context, flow),
        Expanded(
          child: Container(
            color: AppColors.pageBackground,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              itemCount: combos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _comboCard(context, combos[i], flow),
            ),
          ),
        ),
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SafeArea(
            top: false,
            child: PrimaryButton(
              label: '주문하기',
              onPressed: () {
                final combo = flow.selectedCombo;
                if (combo != null) _openYogiyo(combo.store.name);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, AppFlow flow) => Container(
        width: double.infinity,
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              AppHeader(
                title: '먹방요기',
                onBack: () => context.read<AppFlow>().backToCombo(),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Text('먹방 속 조합을 담았어요', style: AppText.screenTitle),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(children: [
                  _iconChip(context),
                  const SizedBox(width: 8),
                  _chip(context, flow.preference.mode.title),
                  const SizedBox(width: 8),
                  _chip(context, flow.preference.spice.title),
                  const SizedBox(width: 8),
                  _chip(context, flow.preference.deliveryLabel),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _minimumOnly = !_minimumOnly),
                      behavior: HitTestBehavior.opaque,
                      child: Row(children: [
                        FigmaCheckbox(isOn: _minimumOnly),
                        const SizedBox(width: 8),
                        Text('최소금액 맞춤만 보기',
                            style: AppText.regular(14,
                                spacing: -0.35, color: AppColors.gray800)),
                      ]),
                    ),
                    PopupMenuButton<ComboSort>(
                      onSelected: flow.updateSort,
                      itemBuilder: (_) => [
                        for (final s in ComboSort.values)
                          PopupMenuItem(value: s, child: Text(s.title)),
                      ],
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(flow.sort.title,
                            style: AppText.semiBold(14,
                                spacing: -0.35, color: AppColors.gray800)),
                        const Icon(Icons.keyboard_arrow_down,
                            size: 18, color: AppColors.gray800),
                      ]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _iconChip(BuildContext context) => GestureDetector(
        onTap: () => showComboFilterSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gray800),
          ),
          child: const Icon(Icons.tune, size: 14, color: AppColors.gray800),
        ),
      );

  Widget _chip(BuildContext context, String title) => GestureDetector(
        onTap: () => showComboFilterSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.gray600),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(title,
                style: AppText.regular(12, spacing: -0.3, color: AppColors.gray700)),
            const Icon(Icons.keyboard_arrow_down, size: 14, color: AppColors.gray600),
          ]),
        ),
      );

  Widget _comboCard(BuildContext context, ComboRecommendation combo, AppFlow flow) {
    final selected = flow.selectedCombo?.id == combo.id;

    return FigmaCard(
      borderColor: selected ? AppColors.checkedBorder : null,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RemoteOrAssetImage(
                imageUrl: combo.store.imageUrl,
                assetPath: combo.store.imagePath,
                size: 44,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(combo.store.name, style: AppText.semiBold(16, spacing: -0.4)),
                    const SizedBox(height: 4),
                    Row(children: [
                      const Icon(Icons.star, size: 11, color: Colors.black),
                      const SizedBox(width: 2),
                      Flexible(
                        child: Text(
                          '${combo.store.ratingText} · ${combo.store.distanceText} · ${combo.store.deliveryText}',
                          style: AppText.regular(12,
                              spacing: -0.3, color: AppColors.gray600),
                        ),
                      ),
                    ]),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => flow.selectCombo(combo.id),
                child: FigmaCheckbox(isOn: selected, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(height: 1, color: AppColors.gray300),
          const SizedBox(height: 16),
          for (final item in combo.items) ...[
            ComboMenuRow(
              item: item,
              onDecrease: () =>
                  flow.changeQuantity(comboId: combo.id, itemId: item.id, delta: -1),
              onIncrease: () =>
                  flow.changeQuantity(comboId: combo.id, itemId: item.id, delta: 1),
            ),
            const SizedBox(height: 16),
          ],
          Container(height: 1, color: AppColors.gray300),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => showMenuEditSheet(context, combo),
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.edit_outlined, size: 18, color: AppColors.gray800),
                const SizedBox(width: 4),
                Text('메뉴 수정하기',
                    style: AppText.semiBold(16, spacing: -0.4, color: AppColors.gray800)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openYogiyo(String query) async {
    final scheme = Uri.parse('yogiyo://search?query=${Uri.encodeComponent(query)}');
    if (await canLaunchUrl(scheme)) {
      await launchUrl(scheme);
      return;
    }
    await launchUrl(
      Uri.parse('https://www.yogiyo.co.kr/mobile/#/search/?keyword=${Uri.encodeComponent(query)}'),
      mode: LaunchMode.externalApplication,
    );
  }
}
