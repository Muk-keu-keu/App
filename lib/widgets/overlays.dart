import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme.dart';
import 'ds.dart';

/// 시안 04_최종화면의 alert · action sheet · overflow menu · toast.
///
/// 넷 다 화면 위에 잠깐 떠 있다가 사라지는 것들이라 한 파일에 모았다. 화면마다
/// 따로 만들면 같은 모달이 조금씩 다르게 생기고, 되돌릴 수 없는 동작(삭제)의
/// 확인 문구가 화면마다 달라진다.
///
/// 삭제 확인은 전부 [AppConfirmDialog] 하나를 지난다.

/// "AI 추천 이유" 모달 (시안 1059:5978, 350 폭).
///
/// 왜 이 조합이 먼저 나왔는지 설명한다. 결과 화면은 "가장 비슷한" 조합 하나를
/// 앞에 놓는데, 근거가 안 보이면 사용자는 그게 임의로 고른 것인지 알 수 없다.
///
/// 닫기 버튼이 [confirmLabel] 하나뿐이라 결과를 바꾸지 않는다 — 읽고 나가는 창이다.
class RecommendationModal extends StatelessWidget {
  const RecommendationModal({
    super.key,
    required this.title,
    required this.body,
    required this.hint,
  });

  final String title;
  final String body;

  /// 본문 아래 회색 한 줄. 다음에 무엇을 할 수 있는지 알려 준다.
  final String hint;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String body,
    required String hint,
  }) =>
      showDialog<void>(
        context: context,
        builder: (_) => RecommendationModal(title: title, body: body, hint: hint),
      );

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // 시안 폭 350 = 390 - 20 × 2.
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.h2().copyWith(letterSpacing: -0.48)),
              const SizedBox(height: 8),
              Text(
                body,
                style: AppText.body1(color: AppColors.gray700)
                    .copyWith(letterSpacing: -0.32),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(DsIcons.info, width: 20, height: 20),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      hint,
                      style: AppText.body2(color: AppColors.gray600)
                          .copyWith(letterSpacing: -0.28),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              DsButton(
                label: '확인',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      );
}

/// "이 매장을 추천한 이유" 팝오버 (시안 1052:8091, 280 폭).
///
/// [RecommendationModal] 과 달리 카드 한 장에 대한 설명이라 훨씬 짧고, 확인
/// 버튼 대신 X 로 닫는다. 목록에서 카드를 비교하는 중에 뜨는 창이라 누르고
/// 바로 돌아갈 수 있어야 한다.
class StoreReasonPopover extends StatelessWidget {
  const StoreReasonPopover({super.key, required this.reasons});

  final List<String> reasons;

  static Future<void> show(BuildContext context, {required List<String> reasons}) =>
      showDialog<void>(
        context: context,
        builder: (_) => StoreReasonPopover(reasons: reasons),
      );

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 55),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '이 매장을 추천한 이유',
                      style: AppText.sub2().copyWith(letterSpacing: -0.32),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: '닫기',
                    child: GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      behavior: HitTestBehavior.opaque,
                      // 에셋을 그냥 그리면 `+` 다. 돌리는 일은 [DsCloseIcon] 이 한다.
                      child: const DsCloseIcon(size: 18.19, box: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final reason in reasons)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 시안은 `list-disc` 다. Text 의 불릿 문자를 쓰면 줄바꿈된
                      // 둘째 줄이 점 아래로 흘러 들여쓰기가 무너진다.
                      Padding(
                        padding: const EdgeInsets.only(top: 8, right: 8),
                        child: Container(
                          width: 3,
                          height: 3,
                          decoration: const BoxDecoration(
                            color: AppColors.gray700,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          reason,
                          style: AppText.body2(color: AppColors.gray700)
                              .copyWith(letterSpacing: -0.28),
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

/// 되돌릴 수 없는 동작 앞에 세우는 확인 창 (시안 925:3648, 335×163).
///
/// `true` 를 돌려주면 사용자가 실행을 골랐다는 뜻이다. 바깥을 눌러 닫으면
/// `null` 이 오므로 호출부는 `== true` 로 본다 — 실수로 닫은 것을 실행으로
/// 해석하지 않기 위해서다.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = '삭제하기',
    this.cancelLabel = '취소',
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = '삭제하기',
    String cancelLabel = '취소',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        // 시안 폭 335 = 390 - 27.5 × 2.
        insetPadding: const EdgeInsets.symmetric(horizontal: 27.5),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppText.sub1()),
              const SizedBox(height: 4),
              Text(message, style: AppText.body1(color: AppColors.gray600)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _DialogButton(
                      label: cancelLabel,
                      background: AppColors.gray200,
                      style: AppText.body1(color: AppColors.gray800),
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DialogButton(
                      label: confirmLabel,
                      background: AppColors.alert,
                      style: AppText.btn1(color: Colors.white),
                      onTap: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.background,
    required this.style,
    required this.onTap,
  });

  final String label;
  final Color background;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(label, style: style),
        ),
      );
}

/// 액션시트·오버플로 메뉴의 한 줄.
class AppActionSheetItem {
  const AppActionSheetItem({
    required this.label,
    required this.value,
    this.destructive = false,
  });

  final String label;

  /// 고르면 `show` 가 돌려줄 값.
  final String value;

  /// 되돌릴 수 없는 동작이면 true. 액션시트에서만 빨갛게 그린다 —
  /// 오버플로 메뉴는 시안이 삭제도 검정으로 두었다.
  final bool destructive;
}

/// 게시물 헤더의 점 아이콘에서 올라오는 시트 (시안 922:2720, 350×181).
///
/// 취소는 [items] 와 12px 떨어진 별도 카드다. 실행 항목 바로 옆에 붙어 있으면
/// 삭제를 누르려다 취소를 누르는 일이 잦다.
class AppActionSheet {
  const AppActionSheet._();

  static Future<String?> show(
    BuildContext context, {
    required List<AppActionSheetItem> items,
    String cancelLabel = '취소',
  }) =>
      showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => SafeArea(
          child: Padding(
            // 시안 폭 350 = 390 - 20 × 2.
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          const Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.gray300,
                          ),
                        _SheetRow(
                          label: items[i].label,
                          style: AppText.body1(
                            color: items[i].destructive
                                ? AppColors.alert
                                : AppColors.gray800,
                          ),
                          onTap: () =>
                              Navigator.of(sheetContext).pop(items[i].value),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _SheetRow(
                    label: cancelLabel,
                    style: AppText.btn1(color: AppColors.gray800),
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          height: 56,
          alignment: Alignment.center,
          child: Text(label, style: style),
        ),
      );
}

/// 댓글의 점 아이콘에서 나오는 작은 메뉴 (시안 922:2734, 120×36).
///
/// 항목이 '삭제하기' 하나뿐이라 시트를 올리면 과하다. 누른 자리 아래에 붙인다.
/// 시안이 글자를 검정으로 두었다 — 알약 하나에 삭제뿐이라 빨강까지 쓰지 않는다.
///
/// `showMenu` 를 쓰지 않는 이유는 그쪽이 자체 수직 패딩을 넣어 시안의 36 높이가
/// 나오지 않아서다.
class AppOverflowMenu {
  const AppOverflowMenu._();

  /// [link] 는 점 아이콘에 걸어 둔 링크. 그 오른쪽 아래에 메뉴를 붙인다.
  ///
  /// 좌표를 직접 재서 [Positioned] 로 놓지 않는다. 아이콘이 스크롤 안에 있으면
  /// 잰 좌표와 오버레이 좌표계가 어긋나 메뉴가 아이콘에서 한참 떨어진 자리에
  /// 떴다. [CompositedTransformFollower] 는 그 계산을 프레임워크가 맡는다.
  static Future<String?> show(
    BuildContext context, {
    required LayerLink link,
    required List<AppActionSheetItem> items,
  }) {
    return showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => Stack(
        children: [
          CompositedTransformFollower(
            link: link,
            // 아이콘의 오른쪽 아래에 메뉴의 오른쪽 위를 붙이고 4px 띄운다.
            targetAnchor: Alignment.bottomRight,
            followerAnchor: Alignment.topRight,
            offset: const Offset(0, 4),
            child: SizedBox(
              width: 120,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4A4A4A).withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final item in items)
                        GestureDetector(
                          onTap: () => Navigator.of(dialogContext).pop(item.value),
                          behavior: HitTestBehavior.opaque,
                          child: Container(
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.label,
                                  style: AppText.body2(color: AppColors.gray800),
                                ),
                                SvgPicture.asset(
                                  DsIcons.delete,
                                  width: 20,
                                  height: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 화면 하단에 잠깐 떴다 사라지는 알림 (시안 952:5089, 350×40).
///
/// 조합을 공유하면 주문내역으로 돌아가고 이걸 띄운다. 방금 쓴 글로 바로
/// 넘기지 않는 이유는 시안이 그렇게 정해서다 — 대신 [actionLabel] 로 갈 수 있게 둔다.
class AppToast {
  const AppToast._();

  static void show(
    BuildContext context, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    showOn(
      messenger,
      message: message,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    );
  }

  /// 토스트를 띄운 화면이 사라진 뒤에도 보여줘야 할 때 쓴다.
  ///
  /// 조합 공유처럼 **성공하면 화면이 바뀌는** 동작은 `await` 가 끝난 시점에 그 화면이
  /// 이미 없어서 `context` 로 messenger 를 찾을 수 없다. 그래서 부르는 쪽이 await 전에
  /// [ScaffoldMessenger.of] 를 붙잡아 두고 이 메서드로 넘긴다 — messenger 자체는
  /// MaterialApp 아래에 있어 화면 전환에 살아남는다.
  static void showOn(
    ScaffoldMessengerState messenger, {
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black.withValues(alpha: 0.8),
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          content: Row(
            children: [
              Expanded(
                child: Text(
                  message,
                  style: AppText.body2(color: Colors.white),
                ),
              ),
              if (actionLabel != null && onAction != null)
                GestureDetector(
                  onTap: () {
                    messenger.hideCurrentSnackBar();
                    onAction();
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel,
                        style: AppText.btn3(color: AppColors.gray200),
                      ),
                      const DsChevron.right(color: AppColors.gray200),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
  }
}
