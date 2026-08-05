import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../theme.dart';
import '../widgets/ds.dart';

/// 주문 접수 완료. `POST v1/orders` 의 `201` 응답만으로 그린다.
///
/// 응답은 `restaurantNames` 하나뿐이다. 그래서 이 화면이 보여줄 수 있는 것도
/// 곳 수와 가게 이름뿐이다 (명세: 요청 내용을 되돌려주지 않고, 건수도 orderId 도
/// 주지 않는다). 금액을 다시 보여주지 않는 이유가 여기 있다 — 서버가 `menuId` 로
/// 다시 계산하므로 프론트가 들고 있던 금액을 확정액처럼 보여줄 수 없다.
///
/// `orderId` 가 없어 특정 상세로 바로 갈 수 없다. 목록으로만 보낸다
/// (`docs/api-spec.md` 확인 필요 항목).
class OrderDoneScreen extends StatelessWidget {
  const OrderDoneScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final receipt = context.watch<AppFlow>().receipt;
    if (receipt == null) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            const Icon(Icons.check_circle, size: 64, color: AppColors.primary500),
            const SizedBox(height: 20),
            Text('주문이 접수되었습니다', style: AppText.h2()),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                receipt.completionText,
                textAlign: TextAlign.center,
                style: AppText.body1(color: AppColors.gray700),
              ),
            ),
            if (receipt.storeCount > 1) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  '가게마다 따로 배달돼요. 도착 시간이 다를 수 있어요.',
                  textAlign: TextAlign.center,
                  style: AppText.body2(color: AppColors.gray600),
                ),
              ),
            ],
            const Spacer(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                children: [
                  DsButton(
                    label: '주문 내역 보기',
                    onPressed: () =>
                        context.read<AppFlow>().openOrdersFromReceipt(),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.read<AppFlow>().backToYogiyoHome(),
                    behavior: HitTestBehavior.opaque,
                    child: Text(
                      '홈으로',
                      style: AppText.btn2(color: AppColors.gray600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
