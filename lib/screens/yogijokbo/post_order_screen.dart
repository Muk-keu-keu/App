import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/combo.dart';
import '../../models/post.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';
import '../menu_option_sheet.dart';

/// Figma "주문하기" (node 681:8164).
///
/// 남의 조합을 내 장바구니로 복사한 뒤 수량을 조정하고 결제로 넘어가는 화면.
///
/// 여기서 고치는 조합은 게시글 스냅샷의 **복사본**이다. 수량을 바꿔도 원 게시글은
/// 그대로여야 한다 (api-yogijokbo.md 2번 비고).
class PostOrderScreen extends StatelessWidget {
  const PostOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final combo = flow.orderCombo;
    final post = flow.selectedPost;

    if (combo == null || post == null) return const SizedBox.shrink();

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          DsHeader.detail(
            title: '주문하기',
            onBack: () => context.read<AppFlow>().backToPostDetail(),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (post.source != null) _VideoSection(post: post),
                if (flow.orderUnavailable) ...[
                  const SizedBox(height: 16),
                  const _UnavailableNotice(),
                ],
                const SizedBox(height: 16),
                _CartList(combo: combo),
                const SizedBox(height: 16),
                _PaymentSummary(combo: combo),
              ],
            ),
          ),
          _CheckoutBar(combo: combo, disabled: flow.orderUnavailable),
        ],
      ),
    );
  }
}

class _VideoSection extends StatelessWidget {
  const _VideoSection({required this.post});

  final YogijokboPost post;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DsVideoSummary(
          thumbnail: RemoteOrAssetImage(
            imageUrl: post.thumbnailUrl,
            assetPath: post.thumbnailPath,
            size: 100,
            radius: 0,
          ),
          videoTitle: post.source!.videoTitle,
          creatorName: post.author.nickname,
        ),
      );
}

class _CartList extends StatelessWidget {
  const _CartList({required this.combo});

  final ComboRecommendation combo;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(combo.store.name, style: AppText.sub1()),
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
                onDecrease: () => context
                    .read<AppFlow>()
                    .changeOrderQuantity(itemId: item.id, delta: -1),
                onIncrease: () => context
                    .read<AppFlow>()
                    .changeOrderQuantity(itemId: item.id, delta: 1),
                onEditOption: () => MenuOptionSheet.show(
                  context,
                  comboId: combo.id,
                  item: item,
                ),
              ),
              const SizedBox(height: 16),
              const DsDivider(color: AppColors.gray300),
            ],
            const SizedBox(height: 16),
            DsAddMenuButton(
              onTap: () => context.read<AppFlow>().openStoreMenu(combo),
            ),
          ],
        ),
      );
}

class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.combo});

  final ComboRecommendation combo;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('결제 금액', style: AppText.btn1()),
                Text('${wonFormat(combo.payableTotal)}원', style: AppText.btn1()),
              ],
            ),
            const SizedBox(height: 12),
            _row('주문 금액', combo.itemsTotal),
            const SizedBox(height: 8),
            _row('배달비', combo.store.deliveryFee),
          ],
        ),
      );

  Widget _row(String label, int amount) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppText.body2(color: AppColors.gray700)
                  .copyWith(letterSpacing: -0.35)),
          Text('${wonFormat(amount)}원',
              style: AppText.body2(color: AppColors.gray700)
                  .copyWith(letterSpacing: -0.35)),
        ],
      );
}

/// 스냅샷이 지금은 주문할 수 없을 때. 시안에 없는 상태지만, 서버가 주문 불가를
/// 돌려줄 수 있어 이유를 알려 주지 않으면 버튼이 왜 안 눌리는지 알 수 없다.
class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 20, color: AppColors.primary500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '지금 이 위치에서는 주문할 수 없는 조합이에요',
                style: AppText.body2(color: AppColors.gray700),
              ),
            ),
          ],
        ),
      );
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.combo, required this.disabled});

  final ComboRecommendation combo;
  final bool disabled;

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
          child: DsButton(
            label: '결제하기',
            onPressed: disabled || combo.items.isEmpty
                ? null
                : () => _showCheckoutNotice(context, combo),
          ),
        ),
      );

  /// 결제는 요기요 앱이 하는 일이고 이번 범위가 아니다.
  /// 버튼이 아무 반응도 없으면 고장으로 보이므로 다음 단계를 알려 준다.
  void _showCheckoutNotice(BuildContext context, ComboRecommendation combo) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${combo.store.name}에서', style: AppText.body2(color: AppColors.gray700)),
              const SizedBox(height: 4),
              Text('${wonFormat(combo.payableTotal)}원', style: AppText.h3()),
              const SizedBox(height: 16),
              Text(
                '결제는 요기요 앱에서 이어집니다.',
                textAlign: TextAlign.center,
                style: AppText.body2(color: AppColors.gray700),
              ),
              const SizedBox(height: 20),
              DsButton(
                label: '확인',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
