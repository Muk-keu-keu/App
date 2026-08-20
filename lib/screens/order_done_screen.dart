import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/combo.dart';
import '../models/order.dart';
import '../theme.dart';
import '../widgets/credit_widgets.dart';
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

  /// 가게가 한 곳이면 이름을 붙인다. 여러 곳이면 어디에 남았는지 한 줄로 못 쓴다.
  static String _pointTitle(OrderReceipt receipt) {
    if (receipt.pointDelta <= 0) {
      return '포인트 ${wonFormat(receipt.pointDelta.abs())}원을 사용했어요';
    }
    final left = receipt.points.where((p) => p.balance > 0).toList();
    final money = '${wonFormat(receipt.pointDelta)}P';
    return left.length == 1
        ? '${left.first.restaurantName}에 $money 남았어요'
        : '$money 남았어요';
  }

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
                pointDelta: paid.pointDelta,
              ),
            ],
            // 포인트가 쌓였으면 그 액수보다 **그게 뭘 뜻하는지**가 본문이다.
            // "7,000P 남았어요" 만으로는 다음에 뭘 할 수 있는지 알 수 없다.
            if (receipt.touchedPoint) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: CreditNotice(
                  type: CreditNoticeType.ok,
                  title: _pointTitle(receipt),
                  body: receipt.pointDelta > 0
                      ? '다음 주문부터 이 가게는 최소주문금액 없이\n원하는 만큼만 담을 수 있어요.'
                      : '음식값과 배달비를 포인트로 냈어요.',
                ),
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
    this.pointDelta = 0,
  });

  final int itemsTotal;
  final int deliveryFee;
  final int total;

  /// 포인트 잔액 순변화. 양수면 채운 것, 음수면 쓴 것이다.
  /// **화면은 이 순액 하나만 쓴다** — 사용액과 적립액을 따로 보여주면 혼란스럽다.
  final int pointDelta;

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
            if (pointDelta != 0) ...[
              const SizedBox(height: 12),
              _row(
                pointDelta > 0 ? '포인트 채움' : '포인트 사용',
                pointDelta.abs(),
                color: AppColors.primary500,
                sign: pointDelta > 0 ? '+' : '−',
              ),
            ],
          ],
        ),
      );

  Widget _row(
    String label,
    int amount, {
    Color color = AppColors.gray800,
    String sign = '',
  }) =>
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SizedBox(
            width: 96,
            child: Text(label, style: AppText.body1(color: AppColors.gray600)),
          ),
          Text('$sign${wonFormat(amount)}원', style: AppText.sub2(color: color)),
        ],
      );
}
