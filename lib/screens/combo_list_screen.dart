import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../models/preference.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';
import '../widgets/overlays.dart';
import 'menu_option_sheet.dart';

/// Figma "다른 결과보기" (node 681:6245).
///
/// 회의(2026-08-04)에서 **하나만 고르는 화면이 아니게 됐다.** 여러 매장을 체크해
/// 한 번에 결제할 수 있어야 하므로, 체크박스가 "이 카드를 고른다" 가 아니라
/// "장바구니에 담는다" 로 바뀌었다. 하단 버튼은 담은 곳 수와 총액을 보여준다.
///
/// 카드 다중 선택·복수 옵션 레이아웃 시안은 지민님 작업 대기 중이다. 지금은 기존
/// 카드 구조에 체크박스 의미만 바꿔 두고, 시안이 오면 레이아웃만 맞춘다.
class ComboListScreen extends StatefulWidget {
  const ComboListScreen({super.key});

  @override
  State<ComboListScreen> createState() => _ComboListScreenState();
}

class _ComboListScreenState extends State<ComboListScreen> {
  bool _minimumOnly = false;

  List<ComboSuggestion> _visible(AppFlow flow) {
    final sorted = flow.sortedSuggestions;
    if (!_minimumOnly) return sorted;
    return [
      for (final c in sorted)
        if (c.meetsMinimum) c,
    ];
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
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _ComboCard(
                combo: combos[i],
                inCart: flow.isInCart(combos[i].id),
              ),
            ),
          ),
          _BottomCta(
            storeCount: flow.cart.storeCount,
            onOrder: flow.cart.isEmpty ? null : () => context.read<AppFlow>().openCart(),
          ),
        ],
      ),
    );
  }
}

/// 필터 칩 줄. 시안에는 "맛 · 예상 시간" 이라는 기본 라벨로 그려져 있지만,
/// 앱에서는 필터 화면에서 이미 값이 정해져 있어 고른 값을 그대로 보여준다.
///
/// 누르면 시안의 "필터"(681:6194) 화면이 열린다.
///
/// **모드 칩은 없다.** 개정 시안(1052:7310)의 칩 줄에는 아직 남아 있지만 필터
/// 화면에서 모드를 고를 자리가 없어졌다 — 못 바꾸는 값을 열리지 않는 칩으로
/// 두면 눌러 보고 아무 일도 안 일어난다.
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
              DsChipFilter.icon(onTap: () => context.read<AppFlow>().openFilter()),
              const SizedBox(width: 8),
              DsChipFilter(
                label: preference.spice.title,
                onTap: () => context.read<AppFlow>().openFilter(),
              ),
              const SizedBox(width: 8),
              DsChipFilter(
                label: preference.deliveryLabel,
                onTap: () => context.read<AppFlow>().openFilter(),
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
  const _ComboCard({required this.combo, required this.inCart});

  final ComboSuggestion combo;

  /// 이 매장이 장바구니에 담겨 있는지. 체크박스와 테두리가 이 값을 따른다.
  final bool inCart;

  @override
  Widget build(BuildContext context) {
    final flow = context.read<AppFlow>();
    final store = combo.restaurant;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: inCart ? Border.all(color: AppColors.primary400) : null,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8D8D8D).withValues(alpha: 0.15),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 영상에 나온 그 브랜드인지 표시한다. `exactMatches` 와 `combos` 가
          // 섞여 한 목록에 나오므로 구분이 없으면 무엇이 원본인지 알 수 없다.
          if (combo.isExactMatch) ...[
            _ExactMatchBadge(brandName: combo.brandName!),
            const SizedBox(height: 12),
          ],
          DsStoreRow(
            logo: RemoteOrAssetImage(
              imageUrl: store.imageUrl,
              assetPath: store.imagePath,
              size: 44,
            ),
            name: store.name,
            // 시안 1052:7319 — 상호 뒤의 (?). 목록에서 카드끼리 비교하는 중에
            // "왜 이 집이?" 가 바로 안 풀리면 아래로 계속 내리게 된다.
            // **근거가 있는 카드에만 붙인다.** 서버는 내세울 것이 있는 카드에만
            // 태그를 달아 준다(2026-08-13 서버 확인) — 빈 카드까지 (?) 를 그리면
            // 눌렀을 때 아무것도 없는 창이 열린다.
            //
            // 글자 없는 20짜리 아이콘이라 라벨이 없으면 스크린 리더에 아무것도
            // 읽히지 않는다.
            nameTrailing: combo.reasonBullets.isEmpty
                ? null
                : Semantics(
                    button: true,
                    label: '${store.name} 추천 이유',
                    child: GestureDetector(
                      key: ValueKey('store-reason-${combo.id}'),
                      onTap: () => StoreReasonPopover.show(
                        context,
                        reasons: combo.reasonBullets,
                      ),
                      behavior: HitTestBehavior.opaque,
                      child: SvgPicture.asset(DsIcons.help, width: 20, height: 20),
                    ),
                  ),
            ratingText: store.ratingText,
            distanceText: store.distanceText,
            deliveryText: store.etaText,
            trailing: DsCheckbox(
              isOn: inCart,
              size: 24,
              onTap: () => flow.toggleSuggestionInCart(combo),
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
              options: item.optionsText,
              quantity: item.quantity,
              priceText: '${wonFormat(item.lineTotal)}원',
              // 담기 전 카드에서는 수량만 조절한다. 옵션은 장바구니에서 고친다 —
              // 담기지 않은 조합의 옵션을 바꿔 두면 어디에 반영됐는지 알 수 없다.
              onDecrease: () => flow.changeSuggestionQuantity(
                combo: combo,
                menuId: item.menuId,
                delta: -1,
              ),
              onIncrease: () => flow.changeSuggestionQuantity(
                combo: combo,
                menuId: item.menuId,
                delta: 1,
              ),
              onEditOption: inCart
                  ? () => MenuOptionSheet.show(
                        context,
                        restaurantId: combo.id,
                        line: flow.cart.storeOf(combo.id)!.lineOf(item.menuId) ?? item,
                      )
                  : null,
            ),
          ],
          const SizedBox(height: 16),
          const DsDivider(color: AppColors.gray300),
          const SizedBox(height: 16),
          // 최소 주문 금액을 못 넘긴 매장은 결제가 막히므로 미리 알려 준다.
          if (!combo.meetsMinimum) ...[
            Text(
              '${wonFormat(store.shortfallFrom(combo.itemsTotal))}원 더 담아주세요',
              style: AppText.caption(color: AppColors.primary500),
            ),
            const SizedBox(height: 12),
          ],
          DsAddMenuButton(onTap: () => flow.openStoreMenu(combo.id)),
        ],
      ),
    );
  }
}

/// "영상에 나온 곳" 뱃지.
class _ExactMatchBadge extends StatelessWidget {
  const _ExactMatchBadge({required this.brandName});

  final String brandName;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.primary500,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          '영상 속 $brandName',
          style: AppText.caption(color: Colors.white),
        ),
      );
}

class _BottomCta extends StatelessWidget {
  const _BottomCta({required this.storeCount, required this.onOrder});

  final int storeCount;

  /// null 이면 담은 게 없어 버튼이 비활성이다.
  final VoidCallback? onOrder;

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
          // 시안(681:6245) 문구는 "주문하기" 다. 아무것도 안 담긴 상태는 시안에
          // 없어서, 그때만 왜 못 누르는지로 바꿔 쓴다.
          child: DsButton(
            label: storeCount == 0 ? '매장을 골라주세요' : '주문하기',
            onPressed: onOrder,
          ),
        ),
      );
}
