import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/cart.dart' show wonFormat;
import '../models/credit.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/ds.dart';
import '../widgets/overlays.dart';

/// 마이요기요.
///
/// 예전에는 화면이 없어서 하단 네비를 누르면 로그아웃 액션시트만 떴다
/// (`my_menu.dart`). 백엔드에는 `GET/PATCH /v1/users/me` 와 `DELETE /v1/users/delete`
/// 가 처음부터 있었고 부를 자리만 없었다.
///
/// **포인트를 여기에 둔 것이 이 화면의 이유다.** 잔액을 볼 수 있는 곳이 장바구니와
/// 가게 메뉴판뿐이었는데 둘 다 주문하려고 들어가야만 보인다. "내가 어디에 얼마
/// 갖고 있지" 를 확인할 자리가 없었다.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final flow = context.watch<AppFlow>();
    final user = flow.currentUser;
    final credits = flow.credits;

    return Container(
      color: AppColors.bg,
      child: Column(
        children: [
          const DsHeader.main(title: '마이요기요'),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 40),
              children: [
                _ProfileCard(
                  name: user?.displayName ?? '',
                  email: user?.email ?? '',
                  onEdit: () => _editNickName(context, user?.nickName ?? ''),
                ),
                const SizedBox(height: 10),
                // 주소는 읽기 전용이다. 서버에 주소를 바꾸는 엔드포인트가 없다 —
                // 값은 가입 때 정해지고 반경 5km 검색의 기준점으로만 쓰인다.
                if ((user?.address ?? '').isNotEmpty) ...[
                  _AddressCard(address: user!.address),
                  const SizedBox(height: 10),
                ],
                _CreditCard(credits: credits),
                const SizedBox(height: 10),
                _MenuCard(children: [
                  _MenuRow(
                    label: '내가 쓴 요기족보',
                    onTap: () => context.read<AppFlow>().openJokbo(),
                  ),
                ]),
                const SizedBox(height: 10),
                _MenuCard(children: [
                  _MenuRow(
                    label: '로그아웃',
                    onTap: () => context.read<AppFlow>().logout(),
                  ),
                  const DsDivider(color: AppColors.gray300),
                  _MenuRow(
                    label: '회원 탈퇴',
                    // 되돌릴 수 없는 동작이라 alert 색을 쓴다. 결제·주문 같은 정상
                    // 동작(primary500)과 같은 색이면 실수로 누르기 쉽다.
                    color: AppColors.alert,
                    onTap: () => _deleteAccount(context),
                  ),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editNickName(BuildContext context, String current) async {
    final flow = context.read<AppFlow>();
    final next = await _NickNameSheet.show(context, current: current);
    if (next == null || !context.mounted) return;

    final error = await flow.updateNickName(next);
    if (!context.mounted) return;
    AppToast.show(context, message: error ?? '닉네임을 바꿨어요');
  }

  /// 회원 탈퇴는 **비밀번호를 받는다.** 서버가 이메일과 비밀번호를 함께 요구하고
  /// (`DeleteUserRequest`), 되돌릴 수 없는 동작이라 "정말요?" 한 번으로는 약하다.
  Future<void> _deleteAccount(BuildContext context) async {
    final flow = context.read<AppFlow>();
    final password = await _PasswordSheet.show(context);
    if (password == null || !context.mounted) return;

    final error = await flow.deleteAccount(password);
    if (error != null && context.mounted) {
      AppToast.show(context, message: error);
    }
    // 성공하면 flow 가 로그아웃까지 끝내고 로그인 화면으로 보낸다.
  }
}

// ── 프로필 ───────────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.name,
    required this.email,
    required this.onEdit,
  });

  final String name;
  final String email;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primary100,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary300),
              ),
              child: Text(
                name.isEmpty ? '·' : name.characters.first,
                style: AppText.h3(color: AppColors.primary500),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppText.sub1()),
                  const SizedBox(height: 4),
                  Text(email, style: AppText.caption(color: AppColors.gray600)),
                ],
              ),
            ),
            _GhostButton(label: '수정', onTap: onEdit),
          ],
        ),
      );
}

class _AddressCard extends StatelessWidget {
  const _AddressCard({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('배달 주소', style: AppText.sub2()),
            const SizedBox(height: 10),
            Text(address, style: AppText.body2(color: AppColors.gray700)),
            const SizedBox(height: 6),
            Text('이 주소를 기준으로 5km 안의 가게를 찾아요',
                style: AppText.caption(color: AppColors.gray600)),
          ],
        ),
      );
}

// ── 포인트 ───────────────────────────────────────────────────────────────────

class _CreditCard extends StatelessWidget {
  const _CreditCard({required this.credits});

  final List<StoreCredit> credits;

  @override
  Widget build(BuildContext context) {
    final total = StoreCredit.totalOf(credits);

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('포인트', style: AppText.sub2()),
              // 합계를 앞세우지 않는다. 가게 전용이라 여러 가게 잔액을 더한 숫자로는
              // 아무것도 할 수 없다. 규모만 알려주는 보조 정보다.
              if (credits.isNotEmpty)
                Text('${credits.length}곳 · ${wonFormat(total)}P',
                    style: AppText.btn2(color: AppColors.primary500)),
            ],
          ),
          if (credits.isEmpty) const _CreditEmpty() else ..._filled(),
        ],
      ),
    );
  }

  List<Widget> _filled() => [
        const SizedBox(height: 14),
        const DsDivider(color: AppColors.gray300),
        for (final c in credits) ...[
          const SizedBox(height: 14),
          _CreditRow(credit: c),
        ],
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: AppColors.primary100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.primary300),
          ),
          child: Text(
            '포인트는 받은 가게에서만 쓸 수 있어요.\n'
            '그 가게에서 주문할 때 최소주문을 채우는 데 자동으로 쓰여요.',
            style: AppText.caption(color: AppColors.gray700),
          ),
        ),
      ];
}

class _CreditRow extends StatelessWidget {
  const _CreditRow({required this.credit});

  final StoreCredit credit;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          RemoteOrAssetImage(
            imageUrl: credit.imageUrl,
            assetPath: 'assets/images/store_dujjim.png',
            size: 36,
            radius: 8,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              credit.restaurantName,
              style: AppText.body2(color: AppColors.gray800)
                  .copyWith(fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text('${wonFormat(credit.balance)}P',
              style: AppText.sub2(color: AppColors.primary500)),
        ],
      );
}

class _CreditEmpty extends StatelessWidget {
  const _CreditEmpty();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 26, 10, 20),
        child: Column(
          children: [
            Text('아직 포인트가 없어요', style: AppText.body2(color: AppColors.gray700)),
            const SizedBox(height: 6),
            Text(
              '최소주문이 모자랄 때 그만큼을 포인트로 받아 두고,\n'
              '다음 주문에서 그대로 쓸 수 있어요.',
              textAlign: TextAlign.center,
              style: AppText.caption(color: AppColors.gray600),
            ),
          ],
        ),
      );
}

// ── 목록 ─────────────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(children: children),
      );
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.label,
    required this.onTap,
    this.color = Colors.black,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppText.body1(color: color))),
              const DsChevron.right(color: AppColors.gray400),
            ],
          ),
        ),
      );
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.gray300),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
          child: Text(label, style: AppText.body2(color: AppColors.gray700)),
        ),
      );
}


// ── 시트 ─────────────────────────────────────────────────────────────────────

/// 닉네임 변경. `PATCH /v1/users/me` 하나면 되는 일이라 화면을 새로 열지 않는다.
class _NickNameSheet extends StatefulWidget {
  const _NickNameSheet({required this.current});

  final String current;

  static Future<String?> show(BuildContext context, {required String current}) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _NickNameSheet(current: current),
      );

  @override
  State<_NickNameSheet> createState() => _NickNameSheetState();
}

class _NickNameSheetState extends State<_NickNameSheet> {
  late final _controller = TextEditingController(text: widget.current);

  @override
  void initState() {
    super.initState();
    // 글자 수 표시를 위해 다시 그린다.
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = _controller.text.trim();
    final valid = value.isNotEmpty && value.length <= 50;

    return _SheetShell(
      title: '닉네임 변경',
      description: '요기족보에 글을 쓸 때 이 이름으로 보여요',
      confirmLabel: '변경하기',
      onConfirm: valid ? () => Navigator.of(context).pop(value) : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            maxLength: 50,
            style: AppText.body1(),
            decoration: InputDecoration(
              counterText: '',
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide: const BorderSide(color: AppColors.gray300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.card),
                borderSide: const BorderSide(color: AppColors.primary400),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('50자 이내', style: AppText.caption(color: AppColors.gray600)),
              Text('${_controller.text.characters.length} / 50',
                  style: AppText.caption(color: AppColors.gray600)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 회원 탈퇴 확인. **확인 대화상자가 아니라 비밀번호를 받는다** —
/// 서버가 이메일과 비밀번호를 요구하고(`DeleteUserRequest`), 되돌릴 수 없다.
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet();

  static Future<String?> show(BuildContext context) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const _PasswordSheet(),
      );

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetShell(
        title: '정말 탈퇴하시겠어요?',
        description: '주문 내역과 포인트가 모두 사라지고 되돌릴 수 없어요.\n'
            '확인을 위해 비밀번호를 입력해 주세요.',
        confirmLabel: '탈퇴하기',
        confirmColor: AppColors.alert,
        onConfirm: _controller.text.isEmpty
            ? null
            : () => Navigator.of(context).pop(_controller.text),
        child: TextField(
          controller: _controller,
          obscureText: true,
          autofocus: true,
          style: AppText.body1(),
          decoration: InputDecoration(
            hintText: '비밀번호',
            hintStyle: AppText.body1(color: AppColors.gray500),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              borderSide: const BorderSide(color: AppColors.gray300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.card),
              borderSide: const BorderSide(color: AppColors.primary400),
            ),
          ),
        ),
      );
}

/// 시트 껍데기. 손잡이·제목·설명·본문·버튼 두 개가 두 시트에서 같다.
class _SheetShell extends StatelessWidget {
  const _SheetShell({
    required this.title,
    required this.description,
    required this.confirmLabel,
    required this.child,
    this.onConfirm,
    this.confirmColor,
  });

  final String title;
  final String description;
  final String confirmLabel;
  final Widget child;
  final VoidCallback? onConfirm;
  final Color? confirmColor;

  @override
  Widget build(BuildContext context) => Padding(
        // 키보드가 올라오면 시트도 같이 올라간다.
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.dragHandle,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                Text(title, style: AppText.sub1()),
                const SizedBox(height: 6),
                Text(description, style: AppText.caption(color: AppColors.gray600)),
                const SizedBox(height: 16),
                child,
                const SizedBox(height: 20),
                _ConfirmButton(
                  label: confirmLabel,
                  color: confirmColor,
                  onPressed: onConfirm,
                ),
                const SizedBox(height: 8),
                DsButton(
                  label: '취소',
                  size: DsButtonSize.s,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
        ),
      );
}

/// 탈퇴만 alert 색을 쓴다. [DsButton] 은 색을 못 받아서 그 자리만 직접 그린다.
class _ConfirmButton extends StatelessWidget {
  const _ConfirmButton({required this.label, this.color, this.onPressed});

  final String label;
  final Color? color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    if (color == null) return DsButton(label: label, onPressed: onPressed);

    final disabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: disabled ? AppColors.gray400 : color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: AppText.btn1(color: Colors.white)),
      ),
    );
  }
}
