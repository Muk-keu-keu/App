import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/cart.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';
import '../widgets/overlays.dart';
import 'menu_option_sheet.dart';

/// 장바구니. **여러 매장을 한 번에 결제하는 화면**이다.
///
/// 회의(2026-08-04) 결정이 그대로 보이는 곳이다.
/// - 매장마다 섹션이 하나. 배달비도 최소 주문 금액도 매장마다 따로다.
/// - 결제는 `POST v1/orders` 한 번. 매장이 여러 곳이어도 요청은 하나다.
/// - 서버는 장바구니를 저장하지 않는다. 여기 보이는 것은 전부 앱 메모리다.
///
/// 총액은 프론트가 `subtotal` 을 더해 그린다 — 명세가 전체 합계를 받지 않는다.
/// "나도 주문하기" 도 이 화면을 쓴다. 남의 조합을 복사해 온 장바구니라 구조가 같고,
/// 다른 점은 제목과 "지금 이 위치에서는 주문할 수 없다" 안내뿐이다.
class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.onBack,
    this.title = '장바구니',
    this.unavailable = false,
  });

  final VoidCallback onBack;
  final String title;

  /// 게시글 스냅샷이 지금 위치에서 주문 불가일 때. 결제 버튼을 막는다.
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final cart = flow.cart;

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          DsHeader.detail(title: title, onBack: onBack),
          if (cart.isEmpty)
            const Expanded(child: _EmptyCart())
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (cart.source != null) _VideoSection(cart: cart),
                  if (unavailable) const _UnavailableNotice(),
                  // 매장이 여러 곳이면 배달이 따로 간다는 걸 미리 알려 준다.
                  // 배달비가 두 번 붙는 이유를 결제 단계에서 처음 보면 놀란다.
                  if (cart.storeCount > 1) _MultiStoreNotice(count: cart.storeCount),
                  const SizedBox(height: 16),
                  _StoreList(cart: cart),
                  const SizedBox(height: 16),
                  _PaymentSummary(cart: cart),
                ],
              ),
            ),
          _CheckoutBar(
            cart: cart,
            isCheckingOut: flow.isCheckingOut,
            unavailable: unavailable,
            onCheckout: () => context.read<AppFlow>().checkout(),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          '담은 메뉴가 없어요',
          style: AppText.body1(color: AppColors.gray600),
        ),
      );
}

class _VideoSection extends StatelessWidget {
  const _VideoSection({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: DsVideoSummary(
          thumbnail: RemoteOrAssetImage(
            imageUrl: cart.source!.thumbnailUrl,
            assetPath: 'assets/images/store_dujjim.png',
            size: 100,
            radius: 0,
          ),
          videoTitle: cart.source!.title,
          creatorName: '',
        ),
      );
}

/// 매장이 여러 곳일 때의 안내.
class _MultiStoreNotice extends StatelessWidget {
  const _MultiStoreNotice({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            const Icon(Icons.info_outline, size: 20, color: AppColors.primary500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$count곳에서 따로 배달돼요. 결제는 한 번이고 배달비는 가게마다 붙어요.',
                style: AppText.body2(color: AppColors.gray700),
              ),
            ),
          ],
        ),
      );
}

/// 매장들을 한 덩어리로 잇는다 (시안 838:4249 — "여러개의 매장을 동시에
/// 주문하는 경우 그냥 리스트로 쭉 이어지게").
///
/// 매장마다 카드를 띄우면 결제가 매장 수만큼 나뉘어 보인다. 실제로는 한 번의
/// 결제이므로 흰 판 하나 위에 구분선으로만 나눈다.
class _StoreList extends StatelessWidget {
  const _StoreList({required this.cart});

  final Cart cart;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        child: Column(
          children: [
            for (var i = 0; i < cart.stores.length; i++) ...[
              if (i > 0) const DsDivider(color: AppColors.gray300),
              _StoreSection(store: cart.stores[i]),
            ],
          ],
        ),
      );
}

/// 매장 하나의 섹션. 이름 → 메뉴들 → 메뉴 추가하기.
///
/// 가게별 소계는 시안에 없다. 결제는 한 번이고 합계는 아래 [_PaymentSummary]
/// 한 곳에서만 보여 준다. 최소 주문 금액을 못 넘긴 안내만 남긴다 — 그게 없으면
/// 결제 버튼이 왜 막혀 있는지 이 자리에서 알 수 없다.
class _StoreSection extends StatelessWidget {
  const _StoreSection({required this.store});

  final StoreCart store;

  Future<void> _confirmRemove(BuildContext context) async {
    final flow = context.read<AppFlow>();
    final ok = await AppConfirmDialog.show(
      context,
      title: '이 매장을 삭제할까요?',
      message: '담긴 메뉴가 모두 삭제돼요.',
    );
    if (ok) flow.removeStoreFromCart(store.restaurantId);
  }

  @override
  Widget build(BuildContext context) {
    final flow = context.read<AppFlow>();

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(store.restaurant.name, style: AppText.sub1())),
              GestureDetector(
                onTap: () => _confirmRemove(context),
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.only(left: 12),
                  child: Icon(Icons.close, size: 20, color: AppColors.gray800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const DsDivider(color: AppColors.gray300),
          for (final line in store.lines) ...[
            const SizedBox(height: 16),
            DsMenuItem(
              thumbnail: RemoteOrAssetImage(
                imageUrl: line.imageUrl,
                assetPath: line.imagePath,
                size: 80,
              ),
              name: line.name,
              options: line.optionsText,
              quantity: line.quantity,
              priceText: '${wonFormat(line.lineTotal)}원',
              onDecrease: () => flow.changeCartQuantity(
                restaurantId: store.restaurantId,
                menuId: line.menuId,
                delta: -1,
              ),
              onIncrease: () => flow.changeCartQuantity(
                restaurantId: store.restaurantId,
                menuId: line.menuId,
                delta: 1,
              ),
              // 옵션이 없는 메뉴는 버튼을 숨긴다 (명세: 빈 배열이면 숨김).
              // 맵기만 조절되는 메뉴도 고칠 게 있으니 함께 본다.
              onEditOption: line.hasOptions || line.spiceAdjustable
                  ? () => MenuOptionSheet.show(
                        context,
                        restaurantId: store.restaurantId,
                        line: line,
                      )
                  : null,
            ),
            const SizedBox(height: 16),
            const DsDivider(color: AppColors.gray300),
          ],
          const SizedBox(height: 16),
          DsAddMenuButton(onTap: () => flow.openStoreMenu(store.restaurantId)),
          if (store.shortfallText != null) ...[
            const SizedBox(height: 12),
            Text(
              store.shortfallText!,
              style: AppText.caption(color: AppColors.primary500),
            ),
          ],
        ],
      ),
    );
  }
}

/// 전체 결제 금액. 서버로 보내지 않는 값이고 화면에만 쓴다.
class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.cart});

  final Cart cart;

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
                Text('${wonFormat(cart.totalPrice)}원', style: AppText.btn1()),
              ],
            ),
            const SizedBox(height: 12),
            _row('주문 금액', cart.itemsTotal),
            const SizedBox(height: 8),
            _row(
              cart.storeCount > 1 ? '배달비 (${cart.storeCount}곳)' : '배달비',
              cart.deliveryFeeTotal,
            ),
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

/// 스냅샷이 지금은 주문할 수 없을 때. 시안에 없는 상태지만, 안내가 없으면
/// 결제 버튼이 왜 안 눌리는지 알 수 없다.
class _UnavailableNotice extends StatelessWidget {
  const _UnavailableNotice();

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 16),
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
  const _CheckoutBar({
    required this.cart,
    required this.isCheckingOut,
    required this.unavailable,
    required this.onCheckout,
  });

  final Cart cart;
  final bool isCheckingOut;
  final bool unavailable;
  final VoidCallback onCheckout;

  /// 기본 문구는 시안(681:8164)의 "결제하기" 다.
  ///
  /// 못 누르는 상태일 때만 이유로 바꿔 쓴다 — 시안에 없는 상태들이고, 비활성 버튼이
  /// 이유 없이 회색이면 어디를 고쳐야 하는지 알 수 없다.
  String get _label {
    if (isCheckingOut) return '주문 중...';
    if (unavailable) return '이 위치에서는 주문할 수 없어요';
    if (cart.isEmpty) return '담은 메뉴가 없어요';
    final below = cart.storesBelowMinimum;
    if (below.isNotEmpty) return '${below.first.restaurant.name} ${below.first.shortfallText}';
    return '결제하기';
  }

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
            label: _label,
            // 두 번 눌러 주문이 두 건 생기지 않게 진행 중에는 막는다.
            onPressed: cart.canCheckout && !isCheckingOut && !unavailable
                ? onCheckout
                : null,
          ),
        ),
      );
}
