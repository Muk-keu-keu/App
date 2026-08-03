import 'package:flutter/material.dart';

import '../theme.dart';

/// Figma "로딩화면" (node 681:5932).
///
/// 간격은 시안의 절대 좌표에서 상태바 53 을 뺀 값이다.
/// 제목 155 · 플래터 254 · "잠시만" 562 · 설명 612.
class AnalyzeScreen extends StatefulWidget {
  const AnalyzeScreen({super.key});

  @override
  State<AnalyzeScreen> createState() => _AnalyzeScreenState();
}

class _AnalyzeScreenState extends State<AnalyzeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        width: double.infinity,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 102),
              Text(
                '먹방 속 음식을 분석 중',
                style: AppText.semiBold(26).copyWith(height: 1.2),
              ),
              const SizedBox(height: 68),
              // 완전 정지 화면이면 멈춘 것처럼 보여서 아주 옅은 호흡 애니메이션만 준다.
              ScaleTransition(
                scale: Tween<double>(begin: 0.97, end: 1.03).animate(
                  CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
                ),
                child: Image.asset('assets/images/platter.png', width: 240, height: 240),
              ),
              const SizedBox(height: 68),
              Text(
                '잠시만 기다려 주세요',
                style: AppText.h3(color: AppColors.gray800).copyWith(height: 1.2),
              ),
              const SizedBox(height: 26),
              Text(
                '먹방 속 음식 조합을 찾아\n요기요에서 주문 가능한 메뉴로 바꿔드릴게요',
                textAlign: TextAlign.center,
                style: AppText.body1(color: AppColors.gray700).copyWith(height: 1.3),
              ),
              const Spacer(),
            ],
          ),
        ),
      );
}
