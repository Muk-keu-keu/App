import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../models/auth.dart';
import '../theme.dart';
import '../widgets/ds.dart';
import 'auth_fields.dart';

/// Figma "로그인" (node 681:7951).
///
/// 간격은 시안의 절대 좌표에서 역산했다. 시안 프레임(390x844)은 상단에
/// iOS 상태바 53 이 포함돼 있어, SafeArea 기준으로 옮길 때 그만큼 뺐다.
///
/// 시안에는 오류 문구 자리가 없다. 비밀번호를 틀렸을 때 아무 반응이 없으면 버튼이
/// 안 눌린 것으로 보이므로, 버튼 위에 한 줄을 넣고 오류가 없을 때는 자리만 비워 둔다 —
/// 문구가 나타날 때 아래 요소가 밀려 내려가면 누르던 버튼이 움직인다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  /// 화면에 보여줄 실패 문구. 성공하거나 다시 입력하면 비운다.
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      _email.text.trim().isNotEmpty && _password.text.isNotEmpty;

  Future<void> _submit() async {
    final flow = context.read<AppFlow>();
    if (flow.isAuthenticating) return;

    // 빈 값은 서버까지 보내지 않는다. 400 을 받아 오는 것보다 즉시 알려주는 게 빠르다.
    if (!_canSubmit) {
      setState(() => _error = '이메일과 비밀번호를 입력해 주세요.');
      return;
    }

    setState(() => _error = null);
    final result = await flow.login(email: _email.text, password: _password.text);

    // 성공하면 화면이 이미 홈으로 바뀌어 있다. 그 뒤 setState 는 하지 않는다.
    if (!mounted || result.isSuccess) return;
    setState(() => _error = loginFailureMessage(result));
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AppFlow>().isAuthenticating;

    return Container(
      color: Colors.white,
      width: double.infinity,
      child: SafeArea(
        // 키보드가 올라오면 화면이 844 보다 좁아진다. 스크롤이 없으면 넘친 만큼
        // 잘려 버튼이 키보드 아래로 숨는다.
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.sizeOf(context).height -
                  MediaQuery.viewInsetsOf(context).bottom -
                  MediaQuery.paddingOf(context).vertical,
            ),
            // Spacer 가 남은 높이를 쓰려면 Column 의 높이가 정해져 있어야 한다.
            // 스크롤 안에서는 높이가 무한이라 IntrinsicHeight 로 묶는다.
            child: IntrinsicHeight(
              child: Column(
              children: [
                const SizedBox(height: 125), // 시안 로고 top 178 - 상태바 53
                Image.asset('assets/images/yogiyo_logo.png', width: 179, height: 58),
                const SizedBox(height: 31),
                Text(
                  '로그인하고 다양한 혜택을 받아보세요!',
                  style: AppText.sub1().copyWith(letterSpacing: -0.45),
                ),
                const SizedBox(height: 56),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      AuthField(
                        controller: _email,
                        hint: '이메일',
                        keyboardType: TextInputType.emailAddress,
                        onChanged: _clearError,
                      ),
                      const SizedBox(height: 12),
                      AuthField(
                        controller: _password,
                        hint: '비밀번호',
                        obscure: true,
                        onChanged: _clearError,
                        onSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 16),
                      AuthErrorText(_error),
                      const SizedBox(height: 12),
                      DsButton(
                        label: busy ? '로그인 중…' : '로그인',
                        // 요청이 도는 동안 비활성. 두 번 눌러 두 번 로그인하는 것을 막는다.
                        onPressed: busy ? null : _submit,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: busy ? null : () => context.read<AppFlow>().openSignup(),
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    '이메일로 회원가입',
                    style: AppText.body1(color: AppColors.gray700).copyWith(
                      letterSpacing: -0.4,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 다시 입력하기 시작하면 이전 오류를 지운다. 고친 뒤에도 빨간 문구가 남아 있으면
  /// 방금 입력한 것이 또 틀린 것처럼 보인다.
  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }
}

/// 로그인 실패 문구.
///
/// 서버가 준 설명을 그대로 쓰지 않는 자리가 있다. `401` 은 서버 문구도 친절하지만
/// 이메일과 비밀번호 중 어느 쪽이 틀렸는지 알려주지 않는 편이 안전하다 —
/// 가입된 이메일인지 떠보는 데 쓰일 수 있다.
String loginFailureMessage(AuthResult result) => switch (result.failure) {
      AuthFailure.invalidCredentials => '이메일 또는 비밀번호가 올바르지 않습니다.',
      AuthFailure.network => '서버에 연결하지 못했어요.\n연결을 확인하고 다시 시도해 주세요.',
      AuthFailure.invalidInput => result.message ?? '입력한 내용을 다시 확인해 주세요.',
      AuthFailure.emailTaken => result.message ?? '이미 가입된 이메일입니다.',
      _ => '로그인에 실패했어요.\n잠시 후 다시 시도해 주세요.',
    };
