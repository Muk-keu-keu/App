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

  /// [anchorKey] 는 점 아이콘의 키. 그 오른쪽 아래에 메뉴를 붙인다.
  static Future<String?> show(
    BuildContext context, {
    required GlobalKey anchorKey,
    required List<AppActionSheetItem> items,
  }) {
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return Future<String?>.value();

    final corner = box.localToGlobal(
      box.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );

    return showDialog<String>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) => Stack(
        children: [
          Positioned(
            // 오른쪽 끝을 아이콘에 맞추고 4px 아래로 띄운다.
            left: corner.dx - 120,
            top: corner.dy + 4,
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
                        onTap: () =>
                            Navigator.of(dialogContext).pop(item.value),
                        behavior: HitTestBehavior.opaque,
                        child: Container(
                          height: 36,
                          padding:
                              const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment:
                                MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                item.label,
                                style:
                                    AppText.body2(color: AppColors.gray800),
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
