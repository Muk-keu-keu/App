import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Figma "로그인" (node 480:2157).
///
/// 지금은 화면만 있고 실제 인증은 없다. 백엔드에 인증 API 가 생기면
/// _submit 안에서 호출하고 결과에 따라 다음 화면으로 보내면 된다.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    // TODO: 백엔드 인증 API 연동. 지금은 화면 흐름만 이어준다.
    context.read<AppFlow>().completeLogin();
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        width: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 90),
              Image.asset('assets/images/yogiyo_logo.png', width: 179, height: 58),
              const SizedBox(height: 31),
              Text(
                '로그인하고 다양한 혜택을 받아보세요!',
                style: AppText.semiBold(18, spacing: -0.45),
              ),
              const SizedBox(height: 47),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _field(controller: _email, hint: '이메일'),
                    const SizedBox(height: 8),
                    _field(controller: _password, hint: '비밀번호', obscure: true),
                    const SizedBox(height: 24),
                    PrimaryButton(label: '로그인', onPressed: _submit),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _submit,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '이메일로 회원가입',
                  style: AppText.regular(16, spacing: -0.4, color: AppColors.gray700)
                      .copyWith(decoration: TextDecoration.underline),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    bool obscure = false,
  }) =>
      Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          obscureText: obscure,
          style: AppText.regular(14, spacing: -0.35),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: AppText.regular(14, spacing: -0.35, color: AppColors.gray600),
          ),
        ),
      );
}
