import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../theme.dart';
import '../widgets/ds.dart';

/// Figma "로그인" (node 681:7951).
///
/// 지금은 화면만 있고 실제 인증은 없다. 백엔드에 인증 API 가 생기면
/// _submit 안에서 호출하고 결과에 따라 다음 화면으로 보내면 된다.
///
/// 간격은 시안의 절대 좌표에서 역산했다. 시안 프레임(390x844)은 상단에
/// iOS 상태바 53 이 포함돼 있어, SafeArea 기준으로 옮길 때 그만큼 뺐다.
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
                    _field(controller: _email, hint: '이메일'),
                    const SizedBox(height: 12),
                    _field(controller: _password, hint: '비밀번호', obscure: true),
                    const SizedBox(height: 40),
                    DsButton(label: '로그인', onPressed: _submit),
                  ],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: _submit,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '이메일로 회원가입',
                  style: AppText.body1(color: AppColors.gray700)
                      .copyWith(letterSpacing: -0.4, decoration: TextDecoration.underline),
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
        // Figma `text field` state=default, size=S — 350x44, 라운딩 8, gray200
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.gray200,
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        alignment: Alignment.center,
        child: TextField(
          controller: controller,
          obscureText: obscure,
          style: AppText.body2().copyWith(letterSpacing: -0.35),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            hintText: hint,
            hintStyle: AppText.body2(color: AppColors.gray600).copyWith(letterSpacing: -0.35),
          ),
        ),
      );
}
