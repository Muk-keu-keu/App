import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/ds.dart';

/// 결제 완료 (시안 949:4470).
///
/// 성공 아이콘 60 · 제목 · 부제 · 금액 카드 · "홈으로 이동하기" 순이다.
///
/// **금액은 앱이 계산한 값이다.** `POST v1/orders` 의 201 응답은 `restaurantNames`
/// 뿐이라 서버 확정액을 알 수 없다 (`docs/api-spec.md` 확인 필요 항목). 결제 직전
/// 화면에서 사용자가 본 숫자를 그대로 보여주고, 서버가 다시 계산해 달라진다면
/// 주문내역에서 드러난다.
class OrderDoneScreen extends StatelessWidget {
  const OrderDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final receipt = flow.receipt;
    if (receipt == null) return const SizedBox.shrink();

    final paid = flow.paidAmounts;

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // success icon 60 (952:4591)
            SvgPicture.asset(DsIcons.success, width: 60, height: 60),
            const SizedBox(height: 20),
            // 952:4546 — 제목 H1 + 부제 gray600, 가운데 정렬 (gap 8)
            Text(
              '결제가 완료되었습니다',
              textAlign: TextAlign.center,
              style: AppText.h1().copyWith(letterSpacing: -0.56),
            ),
            const SizedBox(height: 8),
            Text(
              '이제 먹방 속 조합을 직접 즐겨보세요!',
              textAlign: TextAlign.center,
              style: AppText.body1(color: AppColors.gray600),
            ),
            if (paid != null) ...[
              const SizedBox(height: 40),
              _AmountCard(
                itemsTotal: paid.itemsTotal,
                deliveryFee: paid.deliveryFee,
                total: paid.total,
              ),
            ],
            const Spacer(),
            // Bottom CTA (952:4595) — 시안에는 버튼 하나뿐이다.
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: DsButton(
                label: '홈으로 이동하기',
                onPressed: () => context.read<AppFlow>().backToYogiyoHomeFromReceipt(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 금액 카드 (952:4609). gray100 배경, radius 16, padding 20, 줄 간격 12.
///
/// 결제 금액만 primary500 이다 — 실제로 빠져나간 돈이라 나머지와 구분한다.
class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.itemsTotal,
    required this.deliveryFee,
    required this.total,
  });

  final int itemsTotal;
  final int deliveryFee;
  final int total;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.gray100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _row('결제 금액', total, color: AppColors.primary500),
            const SizedBox(height: 12),
            _row('주문 금액', itemsTotal),
            const SizedBox(height: 12),
            _row('배달비', deliveryFee),
          ],
        ),
      );

  Widget _row(String label, int amount, {Color color = AppColors.gray800}) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: AppText.body1(color: AppColors.gray600)),
          ),
          Text('${wonFormat(amount)}원', style: AppText.sub2(color: color)),
        ],
      );
}
