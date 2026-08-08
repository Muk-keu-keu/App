import 'package:flutter/material.dart';

import '../theme.dart';

/// 로그인·회원가입이 함께 쓰는 입력칸.
///
/// Figma `text field` state=default, size=S — 350x44, 라운딩 8, gray200.
/// 시안에 회원가입 화면이 없어서 로그인의 이 컴포넌트를 그대로 쓴다.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) => Container(
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
          keyboardType: keyboardType,
          // 이메일·비밀번호에 자동 대문자가 걸리면 첫 글자가 대문자로 바뀌어
          // 로그인이 조용히 실패한다.
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          enableSuggestions: !obscure,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
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

/// 입력 위에 뜨는 실패 문구.
///
/// 문구가 없을 때도 같은 높이를 차지한다. 나타날 때 아래 버튼이 밀려 내려가면
/// 누르려던 자리가 움직여 엉뚱한 것을 누른다.
class AuthErrorText extends StatelessWidget {
  const AuthErrorText(this.message, {super.key});

  final String? message;

  /// 두 줄 문구(네트워크 오류)까지 담기는 높이.
  static const _reservedHeight = 36.0;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: _reservedHeight,
        width: double.infinity,
        child: message == null
            ? null
            : Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.caption(color: AppColors.alert),
              ),
      );
}
