import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../models/preference.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';
import 'combo_filter_sheet.dart';
import 'menu_option_sheet.dart';

/// Figma "다른 결과보기" (node 681:6245).
///
/// 먹방 조합 화면에서 넘어와 여러 매장의 조합을 나란히 비교하고 하나를 고른다.
/// 고른 카드는 primary400 테두리와 우측 상단 체크로 표시된다.
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

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          DsHeader.detail(
            title: '먹방요기',
            onBack: () => context.read<AppFlow>().backToCombo(),
          ),
          _ChipRow(preference: flow.preference),
          _FilterRow(
            minimumOnly: _minimumOnly,
            onToggleMinimum: () => setState(() => _minimumOnly = !_minimumOnly),
            sort: flow.sort,
            onSort: flow.updateSort,
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: combos.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ComboCard(
                combo: combos[i],
                selected: flow.selectedCombo?.id == combos[i].id,
              ),
            ),
          ),
          _BottomCta(
            onOrder: () {
              final combo = flow.selectedCombo;
              if (combo != null) _openYogiyo(combo.store.name);
            },
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

/// 필터 칩 줄. 시안에는 "모드 · 맛 · 예상 시간" 이라는 기본 라벨로 그려져 있지만,
/// 앱에서는 키워드 선택 화면에서 이미 값이 정해져 있어 고른 값을 그대로 보여준다.
class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.preference});

  final TastePreference preference;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              DsChipFilter.icon(onTap: () => showComboFilterSheet(context)),
              const SizedBox(width: 8),
              DsChipFilter(
                label: preference.mode.title,
                onTap: () => showComboFilterSheet(context),
              ),
              const SizedBox(width: 8),
              DsChipFilter(
                label: preference.spice.title,
                onTap: () => showComboFilterSheet(context),
              ),
              const SizedBox(width: 8),
              DsChipFilter(
                label: preference.deliveryLabel,
                onTap: () => showComboFilterSheet(context),
              ),
            ],
          ),
        ),
      );
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.minimumOnly,
    required this.onToggleMinimum,
    required this.sort,
    required this.onSort,
  });

  final bool minimumOnly;
  final VoidCallback onToggleMinimum;
  final ComboSort sort;
  final ValueChanged<ComboSort> onSort;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: onToggleMinimum,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  DsCheckbox(isOn: minimumOnly),
                  const SizedBox(width: 8),
                  Text(
                    '최소금액 맞춤만 보기',
                    style: AppText.body2(color: AppColors.gray800)
                        .copyWith(letterSpacing: -0.35),
                  ),
                ],
              ),
            ),
            PopupMenuButton<ComboSort>(
              onSelected: onSort,
              itemBuilder: (_) => [
                for (final s in ComboSort.values)
                  PopupMenuItem(value: s, child: Text(s.title)),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(sort.title, style: AppText.btn2(color: AppColors.gray800)),
                  const SizedBox(width: 2),
                  const DsChevron.down(),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ComboCard extends StatelessWidget {
  const _ComboCard({required this.combo, required this.selected});

  final ComboRecommendation combo;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final flow = context.read<AppFlow>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: selected ? Border.all(color: AppColors.primary400) : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D8D8D).withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: [
          DsStoreRow(
            logo: RemoteOrAssetImage(
              imageUrl: combo.store.imageUrl,
              assetPath: combo.store.imagePath,
              size: 44,
            ),
            name: combo.store.name,
            ratingText: combo.store.ratingText,
            distanceText: combo.store.distanceText,
            deliveryText: combo.store.deliveryText,
            trailing: DsCheckbox(
              isOn: selected,
              size: 24,
              onTap: () => flow.selectCombo(combo.id),
            ),
          ),
          const SizedBox(height: 16),
          const DsDivider(color: AppColors.gray300),
          for (final item in combo.items) ...[
            const SizedBox(height: 16),
            DsMenuItem(
              thumbnail: RemoteOrAssetImage(
                imageUrl: item.imageUrl,
                assetPath: item.imagePath,
                size: 80,
              ),
              name: item.name,
              options: item.options,
              quantity: item.quantity,
              priceText: '${wonFormat(item.lineTotal)}원',
              onDecrease: () =>
                  flow.changeQuantity(comboId: combo.id, itemId: item.id, delta: -1),
              onIncrease: () =>
                  flow.changeQuantity(comboId: combo.id, itemId: item.id, delta: 1),
              onEditOption: () => MenuOptionSheet.show(context,
                  comboId: combo.id, item: item),
            ),
          ],
          const SizedBox(height: 16),
          const DsDivider(color: AppColors.gray300),
          const SizedBox(height: 16),
          DsAddMenuButton(onTap: () => flow.openStoreMenu(combo)),
        ],
      ),
    );
  }
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.onOrder});

  final VoidCallback onOrder;

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
          child: DsButton(label: '주문하기', onPressed: onOrder),
        ),
      );
}
