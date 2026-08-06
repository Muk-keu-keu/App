import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/cart.dart' show wonFormat;
import '../../models/menu.dart';
import '../../models/order.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';

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
                          if (i > 0) const SizedBox(height: 24),
                          _StoreBlock(store: detail.stores[i]),
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

class _StoreBlock extends StatelessWidget {
  const _StoreBlock({required this.store});

  final OrderStore store;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(store.restaurantName, style: AppText.sub2()),
          const SizedBox(height: 12),
          for (var i = 0; i < store.items.length; i++) ...[
            if (i > 0) const SizedBox(height: 16),
            _ItemRow(line: store.items[i]),
          ],
        ],
      );
}

/// 메뉴 한 줄. 주문이 끝난 내역이라 수량 조절도 옵션 변경도 없다.
class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.line});

  final CartLine line;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RemoteOrAssetImage(
            imageUrl: line.imageUrl,
            assetPath: line.imagePath,
            size: 72,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: AppText.btn2()),
                if (line.optionsText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    line.optionsText,
                    style: AppText.caption(color: AppColors.gray600),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${wonFormat(line.lineTotal)}원',
                      style: AppText.btn2(),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${line.quantity}개',
                      style: AppText.caption(color: AppColors.gray600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
}

class _Payment extends StatelessWidget {
  const _Payment({required this.detail});

  final OrderDetail detail;

  int get _itemsTotal =>
      detail.stores.fold(0, (sum, s) => sum + s.itemsTotal);

  int get _deliveryTotal =>
      detail.stores.fold(0, (sum, s) => sum + s.deliveryFee);

  @override
  Widget build(BuildContext context) => Column(
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
              Text('결제 금액', style: AppText.btn1()),
              Text('${wonFormat(detail.totalPrice)}원', style: AppText.btn1()),
            ],
          ),
        ],
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
