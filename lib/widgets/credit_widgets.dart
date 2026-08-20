import 'package:flutter/material.dart';

import '../models/cart.dart' show wonFormat;
import '../theme.dart';

/// 포인트 안내 박스. 결제 바 맨 위에 한 개.
///
/// 처음 보는 개념이라 버튼 라벨만으로는 뜻이 전달되지 않는다. "7,000P 채우고
/// 결제" 가 무슨 말인지 아는 사람은 없다.
///
/// 두 변형은 **배경색만** 다르다 — 주의는 흰 배경(테두리로 주목), 해결은 분홍 배경.
/// 색은 전부 기존 토큰이고 새로 만든 값이 없다.
enum CreditNoticeType {
  /// 잔액으로 못 덮어 새로 선불해야 하는 상태.
  warn,

  /// 잔액이 미달을 덮어 그냥 결제되는 상태.
  ok,
}

class CreditNotice extends StatelessWidget {
  const CreditNotice({
    super.key,
    required this.type,
    required this.title,
    required this.body,
  });

  final CreditNoticeType type;
  final String title;
  final String body;

  bool get _ok => type == CreditNoticeType.ok;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _ok ? AppColors.primary100 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _ok ? AppColors.primary300 : AppColors.primary400),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary500,
                shape: BoxShape.circle,
              ),
              child: Text(
                _ok ? '✓' : '!',
                style: AppText.btn3(color: Colors.white)
                    .copyWith(fontWeight: FontWeight.w700, height: 1.0),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.btn2(color: _ok ? AppColors.primary500 : Colors.black),
                  ),
                  const SizedBox(height: 6),
                  Text(body, style: AppText.caption(color: AppColors.gray700)),
                ],
              ),
            ),
          ],
        ),
      );
}

/// 잔액 배지.
///
/// **잔액이 0 이하면 위젯 자체를 그리지 않는다.** 호출하는 쪽에서 조건 분기를
/// 하지 않게 하려는 것이다 — 배지를 붙일 자리가 네 곳이라 각자 `if` 를 두면
/// 한 곳을 빠뜨리기 쉽다.
///
/// 색 규칙은 [DsRequirementBadge] 와 같다(primary300 배경 + primary500 글자).
/// 새 디자인 언어가 아니라 이미 쓰던 것을 그대로 쓴다.
enum CreditBadgeSize {
  /// 장바구니 가게 카드. 자리가 좁아 작게.
  s,

  /// 가게 메뉴판 헤더. 한 줄을 통째로 차지한다.
  l,
}

class CreditBadge extends StatelessWidget {
  const CreditBadge({
    super.key,
    required this.balance,
    this.size = CreditBadgeSize.s,
    this.label,
  });

  /// null 이거나 0 이하면 아무것도 그리지 않는다.
  final int? balance;
  final CreditBadgeSize size;

  /// 기본 문구를 바꾸고 싶을 때. `{}` 자리에 금액이 들어간다.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final value = balance ?? 0;
    if (value <= 0) return const SizedBox.shrink();

    final money = '${wonFormat(value)}P';
    final small = size == CreditBadgeSize.s;
    final text = label == null
        ? (small ? '보유 포인트 $money' : '이 가게에 $money 있어요')
        : label!.replaceAll('{}', money);

    return Container(
      padding: small
          ? const EdgeInsets.symmetric(horizontal: 7, vertical: 3)
          : const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: small ? AppColors.primary300 : AppColors.primary100,
        borderRadius: BorderRadius.circular(small ? 4 : AppRadius.pill),
        border: small ? null : Border.all(color: AppColors.primary300),
      ),
      child: Text(
        text,
        style: small
            ? AppText.btn3(color: AppColors.primary500)
            : AppText.btn2(color: AppColors.primary500),
      ),
    );
  }
}
