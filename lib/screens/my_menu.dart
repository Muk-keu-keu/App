import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';

/// 하단 네비 "마이요기요".
///
/// 예전에는 화면이 없어서 로그아웃만 담은 액션시트를 띄웠다. 이제 [MyPageScreen]
/// 이 있어서 그리로 보낸다. 부르는 자리가 세 곳(홈·주문내역·요기족보)이라
/// 함수는 남겨 두고 내용만 바꿨다 — 세 화면을 각각 고치면 하나를 빠뜨린다.
Future<void> showMyMenu(BuildContext context) =>
    context.read<AppFlow>().openMyPage();
