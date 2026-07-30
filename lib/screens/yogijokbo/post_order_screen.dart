import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/combo.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'jokbo_widgets.dart';

/// 주문하기 (Figma "주문하기").
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
      color: AppColors.pageBackground,
      child: Column(
        children: [
          AppHeader(title: '주문하기', onBack: () => context.read<AppFlow>().backToPostDetail()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (post.source != null)
                  SourceVideoCard(
                    title: post.source!.videoTitle,
                    author: post.author,
                    imagePath: post.thumbnailPath,
                    imageUrl: post.thumbnailUrl,
                  ),
                if (flow.orderUnavailable) const _UnavailableNotice(),
                const SizedBox(height: 8),
                _storeBlock(context, combo),
                const SizedBox(height: 8),
                _paymentBlock(combo),
              ],
            ),
          ),
          _checkoutBar(context, combo, flow.orderUnavailable),
        ],
      ),
    );
  }

  Widget _storeBlock(BuildContext context, ComboRecommendation combo) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(combo.store.name, style: AppText.semiBold(16, spacing: -0.4)),
            const SizedBox(height: 8),
            Container(height: 1, color: AppColors.gray200),
            for (final item in combo.items) _orderRow(context, combo, item),
            const SizedBox(height: 4),
            Center(
              child: GestureDetector(
                // 메뉴 수정 시트는 분석 결과 화면의 것을 재사용해야 하지만,
                // 그쪽은 recommendations 를 대상으로 동작한다. 요기족보 조합까지
                // 다루도록 넓히는 건 이번 범위를 넘어서므로 수량 조절만 남겼다.
                onTap: null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit_outlined, size: 16, color: AppColors.gray400),
                    const SizedBox(width: 4),
                    Text('메뉴 수정하기',
                        style: AppText.medium(14, spacing: -0.35, color: AppColors.gray400)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );

  Widget _orderRow(BuildContext context, ComboRecommendation combo, ComboItem item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RemoteOrAssetImage(
                  imageUrl: item.imageUrl,
                  assetPath: item.imagePath,
                  size: 56,
                  radius: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.name, style: AppText.semiBold(14, spacing: -0.35)),
                      const SizedBox(height: 4),
                      Text(
                        item.options,
                        style: AppText.regular(12, spacing: -0.3, color: AppColors.gray600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                QuantityStepper(
                  quantity: item.quantity,
                  onDecrease: () => context
                      .read<AppFlow>()
                      .changeOrderQuantity(itemId: item.id, delta: -1),
                  onIncrease: () => context
                      .read<AppFlow>()
                      .changeOrderQuantity(itemId: item.id, delta: 1),
                ),
                Text('${wonFormat(item.lineTotal)}원',
                    style: AppText.semiBold(16, spacing: -0.4)),
              ],
            ),
          ],
        ),
      );

  Widget _paymentBlock(ComboRecommendation combo) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          children: [
            _amountRow('결제 금액', combo.payableTotal, emphasize: true),
            const SizedBox(height: 10),
            _amountRow('주문 금액', combo.itemsTotal),
            const SizedBox(height: 10),
            _amountRow('배달비', combo.store.deliveryFee),
          ],
        ),
      );

  Widget _amountRow(String label, int amount, {bool emphasize = false}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: emphasize
                ? AppText.semiBold(16, spacing: -0.4)
                : AppText.regular(14, spacing: -0.35, color: AppColors.gray700),
          ),
          Text(
            '${wonFormat(amount)}원',
            style: emphasize
                ? AppText.semiBold(16, spacing: -0.4)
                : AppText.regular(14, spacing: -0.35, color: AppColors.gray700),
          ),
        ],
      );

  Widget _checkoutBar(BuildContext context, ComboRecommendation combo, bool unavailable) =>
      Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        child: SafeArea(
          top: false,
          child: unavailable
              // 주문 불가인데 결제 버튼을 눌리게 두면 시연에서 사고가 난다.
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.gray300,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text('이 위치에서는 주문할 수 없어요',
                      style: AppText.semiBold(16, spacing: -0.4, color: AppColors.gray600)),
                )
              : PrimaryButton(
                  label: '결제하기',
                  onPressed: () => _showCheckoutNotice(context, combo),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${wonFormat(combo.payableTotal)}원 결제',
                  style: AppText.semiBold(20, spacing: -0.5)),
              const SizedBox(height: 8),
              Text(
                '실제 결제는 요기요 앱에서 이어집니다.\n백엔드 연동 후 주문 API 로 연결할 자리예요.',
                textAlign: TextAlign.center,
                style: AppText.regular(14, spacing: -0.35, color: AppColors.gray700),
              ),
              const SizedBox(height: 20),
              PrimaryButton(label: '확인', onPressed: () => Navigator.of(context).pop()),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: AppColors.selectedFill,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '지금 위치에서는 이 매장이 배달하지 않아요',
                style: AppText.medium(13, spacing: -0.3, color: AppColors.primary),
              ),
            ),
          ],
        ),
      );
}
