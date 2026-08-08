import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../widgets/ds.dart';
import 'auth_fields.dart';
import 'login_screen.dart';

/// 이메일 회원가입.
///
/// **시안에 없는 화면이다.** 로그인 화면(681:7951)의 "이메일로 회원가입" 이 가리키는
/// 곳인데 디자이너 시안에 대응 프레임이 없어서, 로그인 화면의 입력칸·버튼·간격을
/// 그대로 재사용해 같은 화면처럼 보이게 짰다. 시안이 나오면 이 파일만 고치면 된다.
///
/// 서버가 거절하는 조건은 여기서 먼저 걸러낸다 — 비밀번호 8~64자, 이메일 형식,
/// 닉네임 필수. 왕복을 한 번 줄이려는 것이고, 규칙의 기준은 여전히 서버다.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _passwordConfirm = TextEditingController();
  final _nickname = TextEditingController();

  String? _error;

  /// 서버 규칙. 응답 문구가 "비밀번호는 8자 이상 64자 이하여야 합니다" 다.
  static const _minPassword = 8;
  static const _maxPassword = 64;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordConfirm.dispose();
    _nickname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final busy = context.watch<AppFlow>().isAuthenticating;

    return Container(
      color: Colors.white,
      width: double.infinity,
      child: Column(
        children: [
          DsHeader.detail(
            title: '회원가입',
            onBack: busy ? null : () => context.read<AppFlow>().backToLogin(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 40),
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
                    hint: '비밀번호 ($_minPassword자 이상)',
                    obscure: true,
                    onChanged: _clearError,
                  ),
                  const SizedBox(height: 12),
                  AuthField(
                    controller: _passwordConfirm,
                    hint: '비밀번호 확인',
                    obscure: true,
                    onChanged: _clearError,
                  ),
                  const SizedBox(height: 12),
                  AuthField(
                    controller: _nickname,
                    hint: '닉네임',
                    onChanged: _clearError,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 16),
                  AuthErrorText(_error),
                  const SizedBox(height: 12),
                  DsButton(
                    label: busy ? '가입 중…' : '가입하고 시작하기',
                    onPressed: busy ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final flow = context.read<AppFlow>();
    if (flow.isAuthenticating) return;

    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() => _error = null);
    final result = await flow.signUp(
      email: _email.text,
      password: _password.text,
      nickname: _nickname.text,
    );

    // 가입하면 그대로 로그인된 상태로 홈에 도착한다. 성공했을 때 이 화면은 이미
    // 사라져 있으므로 따로 안내하지 않는다 — 홈에 도착한 것이 안내다.
    if (!mounted || result.isSuccess) return;
    setState(() => _error = loginFailureMessage(result));
  }

  /// 서버에 보내기 전에 걸러낼 것들. 통과하면 null.
  String? _validate() {
    final email = _email.text.trim();
    if (email.isEmpty) return '이메일을 입력해 주세요.';
    if (!_looksLikeEmail(email)) return '이메일 형식이 올바르지 않습니다.';

    final password = _password.text;
    if (password.length < _minPassword || password.length > _maxPassword) {
      return '비밀번호는 $_minPassword자 이상 $_maxPassword자 이하여야 합니다.';
    }
    if (password != _passwordConfirm.text) return '비밀번호가 서로 달라요.';

    if (_nickname.text.trim().isEmpty) return '닉네임을 입력해 주세요.';
    return null;
  }

  /// 형식의 기준은 서버다. 여기서는 오타를 걸러낼 만큼만 본다 —
  /// 앱이 더 깐깐하면 서버가 받아 주는 주소로 가입을 못 하는 일이 생긴다.
  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);

  void _clearError(String _) {
    if (_error != null) setState(() => _error = null);
  }
}
