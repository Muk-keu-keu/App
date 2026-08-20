import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/cart.dart' show wonFormat;
import '../../models/order.dart';
import '../../theme.dart';
import '../../widgets/ds.dart';
import '../../widgets/order_card.dart';

/// Figma "주문내역 상세" (node 857:4509).
///
/// 주문내역 카드의 "상세보기" 로 들어온다. 목록 응답에는 메뉴가 없어서
/// `GET v1/orders/{checkoutId}` 를 따로 받아 그린다.
///
/// 가게별 소계는 그리지 않는다. 시안이 결제 정보를 한 덩어리로만 보여준다 —
/// 결제가 한 번이었다는 사실이 화면에서 그대로 읽혀야 한다.
class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final detail = flow.orderDetail;

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          DsHeader.detail(
            title: '주문내역 상세',
            onBack: () => context.read<AppFlow>().closeOrderDetail(),
          ),
          if (detail == null)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  const SizedBox(height: 16),
                  _Section(
                    title: '주문 정보',
                    child: Column(
                      children: [
                        for (var i = 0; i < detail.stores.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          OrderedStoreCard(
                            storeName: detail.stores[i].restaurantName,
                            lines: detail.stores[i].items,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Section(
                    title: '결제 정보',
                    child: _Payment(detail: detail),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppText.sub1()),
            const SizedBox(height: 16),
            child,
          ],
        ),
      );
}

class _Payment extends StatelessWidget {
  const _Payment({required this.detail});

  final OrderDetail detail;

  int get _itemsTotal =>
      detail.stores.fold(0, (sum, s) => sum + s.itemsTotal);

  int get _deliveryTotal =>
      detail.stores.fold(0, (sum, s) => sum + s.deliveryFee);

  /// 시안 857:5238 — 주문 정보의 매장 카드와 같은 테두리 카드다.
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gray300),
        ),
        child: Column(
          children: [
            _row('주문 금액', _itemsTotal),
            const SizedBox(height: 8),
            _row(
              detail.stores.length > 1
                  ? '배달비 (${detail.stores.length}곳)'
                  : '배달비',
              _deliveryTotal,
            ),
            const SizedBox(height: 12),
            const DsDivider(color: AppColors.gray300),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 시안은 "총 결제 금액" 이다.
                Text('총 결제 금액', style: AppText.btn1()),
                Text('${wonFormat(detail.totalPrice)}원', style: AppText.btn1()),
              ],
            ),
          ],
        ),
      );

  Widget _row(String label, int amount) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.body2(color: AppColors.gray700)),
          Text('${wonFormat(amount)}원',
              style: AppText.body2(color: AppColors.gray700)),
        ],
      );
}
