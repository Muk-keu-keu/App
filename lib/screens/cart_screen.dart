import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/cart.dart';
import '../models/combo.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/credit_widgets.dart';
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
/// 다른 점은 제목과 돌아갈 곳뿐이다.
class CartScreen extends StatelessWidget {
  const CartScreen({
    super.key,
    required this.onBack,
    this.title = '장바구니',
  });

  final VoidCallback onBack;
  final String title;

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
            size: 100,
            radius: 0,
          ),
          videoTitle: cart.source!.title,
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
              // 매장 사이는 선이 아니라 **16 회색 띠**로 끊는다. 배달이 따로 가는
              // 별개의 주문이라 한 줄짜리 구분선으로는 같은 가게의 메뉴 구분과
              // 구별되지 않았다 (디자이너 피드백 2026-08-13).
              if (i > 0)
                Container(height: 16, width: double.infinity, color: AppColors.bg),
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
                // 매장마다 ✕ 가 하나씩이라 테스트가 특정 매장을 집으려면 키가 필요하다.
                key: ValueKey('remove-store-${store.restaurantId}'),
                onTap: () => _confirmRemove(context),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  // 회전 없이 그리면 + 로 보인다 (피드백 27번).
                  child: const DsCloseIcon(size: 20),
                ),
              ),
            ],
          ),
          // 최소 주문 금액은 **가게의 속성**이라 이름 바로 아래에 둔다. 담은 결과인
          // "총 음식값" 은 메뉴 목록 아래에 있다 — 조건과 결과를 같은 줄에 붙이면
          // 어느 쪽이 변하는 값인지 헷갈린다.
          if (store.restaurant.minOrderPrice > 0) ...[
            const SizedBox(height: 6),
            // **가게가 정한 값을 그대로 쓴다.** 포인트가 얼마나 쓰였는지는 아래
            // 결제 요약이 말하므로 여기서 또 손대면 같은 이야기가 두 번 나온다.
            Text('최소주문 ${wonFormat(store.restaurant.minOrderPrice)}원',
                style: AppText.caption(color: AppColors.gray600)),
          ],
          // 잔액이 0이면 위젯이 알아서 아무것도 안 그린다.
          if (store.creditBalance > 0) ...[
            const SizedBox(height: 10),
            CreditBadge(balance: store.creditBalance),
          ],
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
              // 옵션이 비어도 버튼을 남긴다. 명세가 바뀌었다 — 빈 배열은 그 메뉴에
              // 옵션이 없다는 뜻이 아니라 영상에서 언급된 게 없다는 뜻이고,
              // 전체 선택지는 GET menus 로 따로 받는다.
              onEditOption: () => MenuOptionSheet.show(
                context,
                restaurantId: store.restaurantId,
                line: line,
              ),
            ),
            const SizedBox(height: 16),
            const DsDivider(color: AppColors.gray300),
          ],
          const SizedBox(height: 16),
          DsAddMenuButton(onTap: () => flow.openStoreMenu(store.restaurantId)),
          // 지금까지 배달비는 아래 결제 요약의 합계 한 줄이 전부였다. 포인트가 가게
          // 단위로 계산되면서 **어느 가게에서 얼마가 드는지**가 카드에서 보여야 한다.
          const SizedBox(height: 14),
          _StoreCostLine(store: store),
          // 미달 처리를 **가게 자리에서** 한다. 하단 결제 바에 몰아 두면 가게가
          // 여럿일 때 어느 집이 걸렸는지 알 수 없고, 고치러 위로 올라와야 한다.
          //
          // 판정 기준은 가게가 정한 최소주문이 아니라 **포인트를 뺀 실질 최소주문**
          // ([StoreCart.effectiveMinOrder]) 이다. 잔액으로 이미 덮인 가게는 여기까지
          // 오지 않는다 — "포인트가 있는데 왜 결제가 안 되지" 가 되기 때문이다.
          //
          // 안내는 미달인 동안 **모양이 바뀌지 않는다.** 체크만 켜졌다 꺼진다 —
          // 고르고 나서 문구가 통째로 갈리면 방금 뭘 눌렀는지 되짚기 어렵다.
          if (!store.meetsMinimum) ...[
            const SizedBox(height: 12),
            const CreditNotice(
              type: CreditNoticeType.warn,
              title: '최소주문금액이 모자르다면? 미리 결제해서 포인트로 적립해요',
              body: '부족한 만큼을 포인트로 내면 지금 주문할 수 있어요.\n'
                  '그 포인트는 다음 주문에 그대로 쓰여요.',
            ),
            const SizedBox(height: 12),
            _PrepaidCheck(store: store),
          ],
        ],
      ),
    );
  }
}

/// "N원 결제하고 포인트 적립" 체크.
///
/// 버튼이 아니라 체크박스인 이유는 **되돌릴 수 있어야** 하기 때문이다. 돈을 더
/// 내는 선택이라 잘못 골랐을 때 장바구니를 비우는 것 말고 다른 길이 있어야 한다.
///
/// 켜면 그 가게의 [StoreCart.base] 가 최소 주문 금액까지 올라가고, 결제 요약에
/// "포인트 채움" 줄이 생기며, 하단 결제 버튼의 잠금이 풀린다.
class _PrepaidCheck extends StatelessWidget {
  const _PrepaidCheck({required this.store});

  final StoreCart store;

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: ValueKey('prepaid-check-${store.restaurantId}'),
        onTap: () => context.read<AppFlow>().togglePrepaid(store.restaurantId),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              DsCheckbox(isOn: store.prepaidOptIn, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${wonFormat(store.shortfall)}원 결제하고 포인트 적립',
                  style: store.prepaidOptIn
                      ? AppText.body2(color: AppColors.gray800)
                          .copyWith(fontWeight: FontWeight.w600)
                      : AppText.body2(color: AppColors.gray600),
                ),
              ),
            ],
          ),
        ),
      );
}

/// 가게 하나의 총 음식값·배달비 한 줄.
///
/// "총 음식값" 은 이 가게에 담은 메뉴 전부의 합이다(옵션값·수량 포함, 배달비 제외).
/// 최소 주문 금액을 재는 기준도 이 값이라 바로 아래 미달 문구와 같은 잣대다.
///
/// **배달비 0원은 "무료" 로 쓰고 primary500 으로 강조한다.** 시드에 0원 가게가
/// 카테고리마다 있어서 실제로 자주 뜨고, 조합에 섞이면 그게 눈에 띄어야 한다.
class _StoreCostLine extends StatelessWidget {
  const _StoreCostLine({required this.store});

  final StoreCart store;

  @override
  Widget build(BuildContext context) {
    final base = AppText.caption(color: AppColors.gray600);

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '총 음식값 ${wonFormat(store.itemsTotal)}원 · '),
          if (store.deliveryFee == 0)
            TextSpan(
              text: '배달비 무료',
              style: AppText.caption(color: AppColors.primary500)
                  .copyWith(fontWeight: FontWeight.w600),
            )
          else
            TextSpan(text: '배달비 ${wonFormat(store.deliveryFee)}원'),
        ],
      ),
      style: base,
    );
  }
}

/// 전체 결제 금액. 서버로 보내지 않는 값이고 화면에만 쓴다.
class _PaymentSummary extends StatelessWidget {
  const _PaymentSummary({required this.cart});

  final Cart cart;

  /// 미달을 채우는 가게 수. 요약 줄의 "(2곳)" 이다.
  int get _filledStores => [
        for (final s in cart.stores)
          if (s.earnedPoint > 0) s,
      ].length;

  int get _spentStores => [
        for (final s in cart.stores)
          if (s.usedPoint > 0) s,
      ].length;

  String _suffix(int count) => cart.storeCount > 1 ? ' ($count곳)' : '';

  @override
  Widget build(BuildContext context) {
    final paid = cart.payAmountTotal;
    final before = cart.stores.fold(0, (sum, s) => sum + s.creditBalance);
    final after = before + cart.pointDeltaTotal;

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('결제 금액', style: AppText.btn1()),
              // 포인트가 다 덮어 0원이 되는 순간이 이 기능의 핵심 체험이라 색으로 짚어 준다.
              Text(
                '${wonFormat(paid)}원',
                style: paid == 0
                    ? AppText.btn1(color: AppColors.primary500)
                    : AppText.btn1(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _row('주문 금액', cart.itemsTotal),
          const SizedBox(height: 8),
          _row(
            cart.storeCount > 1 ? '배달비 (${cart.storeCount}곳)' : '배달비',
            cart.deliveryFeeTotal,
          ),

          // ── 포인트 ──
          //
          // **채움(+)과 사용(−)을 절대 합치지 않는다.** 가게가 여럿이면 부호가 섞여
          // 순액이 뜻을 잃는다 — −5,000 + 12,000 = +7,000 이 되어 교촌에서 5,000원을
          // 쓴 사실이 사라지고 "7,000원 적립" 처럼 읽힌다.
          if (cart.earnedPointTotal > 0) ...[
            const SizedBox(height: 8),
            _row('포인트 채움${_suffix(_filledStores)}', cart.earnedPointTotal,
                sign: '+', color: AppColors.primary500),
          ],
          if (cart.usedPointTotal > 0) ...[
            const SizedBox(height: 8),
            _row('포인트 사용${_suffix(_spentStores)}', cart.usedPointTotal,
                sign: '−', color: AppColors.primary500),
          ],

          // 잔액이 어떻게 바뀌는지. 금액이 아니라 상태라 구분선 아래 캡션으로 둔다.
          if (before > 0 || cart.earnedPointTotal > 0) ...[
            const SizedBox(height: 12),
            const DsDivider(color: AppColors.gray300),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('포인트 잔액', style: AppText.caption(color: AppColors.gray600)),
                Text('${wonFormat(before)}P → ${wonFormat(after)}P',
                    style: AppText.caption(color: AppColors.gray600)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(String label, int amount, {String sign = '', Color? color}) {
    final style = AppText.body2(color: color ?? AppColors.gray700)
        .copyWith(letterSpacing: -0.35);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('$sign${wonFormat(amount)}원', style: style),
      ],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({
    required this.cart,
    required this.isCheckingOut,
    required this.onCheckout,
  });

  final Cart cart;
  final bool isCheckingOut;
  final VoidCallback onCheckout;

  /// 버튼은 하나뿐이다.
  ///
  /// 미달 안내와 "채우기" 선택은 **가게 카드가 자기 자리에서** 맡는다. 여기에
  /// 몰아 두면 가게가 여럿일 때 어느 집 이야기인지 알 수 없고, 결제 직전에
  /// 선택지를 두 개 던지게 된다.
  ///
  /// 못 누르는 상태일 때만 이유로 라벨을 바꾼다 — 회색 버튼이 이유 없이 회색이면
  /// 어디를 고쳐야 하는지 알 수 없다.
  String get _label {
    if (isCheckingOut) return '주문 중...';
    if (cart.isEmpty) return '담은 메뉴가 없어요';

    final blocked = cart.blockedStores;
    if (blocked.isNotEmpty) {
      return blocked.length == 1
          ? '${blocked.first.restaurant.name} 최소주문을 채워주세요'
          : '${blocked.length}곳의 최소주문을 채워주세요';
    }
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
            onPressed: cart.canCheckout && !isCheckingOut ? onCheckout : null,
          ),
        ),
      );
}
