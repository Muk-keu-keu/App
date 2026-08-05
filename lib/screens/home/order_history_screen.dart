import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_flow.dart';
import '../../models/cart.dart';
import '../../models/order.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/ds.dart';

/// Figma "주문내역" (node 731:5325).
///
/// 회의록의 요기족보 작성 진입점이다. 주문 카드마다 "족보 작성" 버튼이 있고,
/// 그 주문의 조합을 그대로 들고 작성 화면으로 넘어간다.
class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          const DsHeader.main(title: '주문내역'),
          const _TabBar(),
          Expanded(
            child: flow.orders.isEmpty
                ? const _Empty()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 15, 20, 120),
                    itemCount: flow.orders.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _OrderCard(
                      order: flow.orders[i],
                      posted: flow.isPostedToJokbo(flow.orders[i].checkoutId),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: DsBottomNavigation(
              current: DsTab.orders,
              onChanged: (tab) => _onTab(context, tab),
            ),
          ),
        ],
      ),
    );
  }

  void _onTab(BuildContext context, DsTab tab) {
    final flow = context.read<AppFlow>();
    switch (tab) {
      case DsTab.home:
        flow.backToYogiyoHome();
      case DsTab.jokbo:
        flow.openJokbo();
      case DsTab.orders:
      case DsTab.my:
        break;
    }
  }
}

/// 먹방요기 / 배달·포장 / 요마트·요편의점.
/// 첫 탭만 내용이 있다. 나머지는 요기요 앱 구조를 따라 자리만 둔다.
class _TabBar extends StatelessWidget {
  const _TabBar();

  static const _labels = ['먹방요기', '배달/포장', '요마트/요편의점'];

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < _labels.length; i++) _tab(_labels[i], selected: i == 0),
          ],
        ),
      );

  Widget _tab(String label, {required bool selected}) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: selected ? AppColors.gray800 : AppColors.gray300,
              width: selected ? 2 : 1,
            ),
          ),
        ),
        child: Text(
          label,
          style: selected
              ? AppText.btn2(color: AppColors.gray800)
              : AppText.body2(color: AppColors.gray500),
        ),
      );
}

/// 결제 카드 하나. **카드 하나 = 결제 하나 = 영상 하나**다 (명세 3번 비고).
///
/// 목록 응답은 조합 전체를 내려주지 않는다 — 가게 이름과 총액만 온다. 메뉴·옵션은
/// 상세에서 받으므로 "족보 작성"·"다시 주문" 을 누를 때 `GET v1/orders/{id}` 를 탄다.
class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, required this.posted});

  final OrderSummary order;

  /// 이미 족보에 공유했는지. 서버가 알려주지 않아 앱이 기억한 값이다
  /// (`GET v1/orders` 에 `isPostedToJokbo` 가 없다).
  final bool posted;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(order.dateText, style: AppText.caption(color: AppColors.gray500)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RemoteOrAssetImage(
                  imageUrl: order.thumbnailUrl,
                  assetPath: 'assets/images/store_dujjim.png',
                  size: 80,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 가게가 여러 곳인 결제는 이름을 모두 보여준다.
                        // 한 영상 보고 한 번에 시킨 것이라는 사실이 여기서 드러난다.
                        for (final name in order.restaurantNames)
                          Text(name, style: AppText.sub2()),
                        const SizedBox(height: 4),
                        if (order.sourceVideoTitle.isNotEmpty)
                          Text(
                            order.sourceVideoTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body2(color: AppColors.gray700),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${wonFormat(order.totalPrice)}원',
                          style: AppText.btn2(color: AppColors.gray800),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _jokboButton(context)),
                const SizedBox(width: 8),
                Expanded(
                  child: DsButton(
                    label: '다시 주문',
                    size: DsButtonSize.xs,
                    onPressed: () => context.read<AppFlow>().reorderFromHistory(order),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

  /// 이미 공유한 결제면 작성 대신 그 글을 열어준다.
  Widget _jokboButton(BuildContext context) {
    final done = posted;
    return GestureDetector(
      onTap: () => context.read<AppFlow>().composeFromOrder(order),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: done ? AppColors.gray300 : AppColors.gray500),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Text(
          done ? '작성한 족보' : '족보 작성',
          style: AppText.btn2(color: done ? AppColors.gray500 : AppColors.gray800),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/platter.png', width: 100, height: 100),
            const SizedBox(height: 16),
            Text('아직 주문한 내역이 없어요',
                style: AppText.body1(color: AppColors.gray700)),
          ],
        ),
      );
}
