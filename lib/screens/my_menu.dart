import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flow.dart';
import '../widgets/overlays.dart';

/// 하단 네비 "마이요기요" 에서 올라오는 시트.
///
/// 마이요기요 화면은 시안에 없다. 그래도 로그아웃할 자리는 있어야 해서, 화면을
/// 새로 지어내는 대신 이미 있는 액션시트로 로그아웃만 붙였다. 시안이 나오면
/// 이 시트를 그 화면으로 대체하면 된다.
///
/// 로그아웃에 확인 대화상자를 두지 않았다. 되돌리는 방법이 다시 로그인하는 것뿐이고
/// 잃는 것도 없어서, 시트의 취소만으로 충분하다.
Future<void> showMyMenu(BuildContext context) async {
  final flow = context.read<AppFlow>();

  final picked = await AppActionSheet.show(
    context,
    items: const [AppActionSheetItem(label: '로그아웃', value: 'logout')],
  );
  if (picked != 'logout') return;

  await flow.logout();
}
