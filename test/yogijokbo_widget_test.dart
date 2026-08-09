import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/screens/yogijokbo/post_compose_screen.dart';
import 'package:mukbang_ttaradamgi/screens/yogijokbo/post_detail_screen.dart';
import 'package:mukbang_ttaradamgi/screens/cart_screen.dart';
import 'package:mukbang_ttaradamgi/screens/yogijokbo/yogijokbo_home_screen.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';
import 'package:mukbang_ttaradamgi/theme.dart';
import 'package:mukbang_ttaradamgi/widgets/ds.dart';

/// 위치 수집이 테스트에 끼어들지 않게 실패로 고정한다.
class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 화면을 실제로 그려 보는 테스트.
///
/// 모델·상태 테스트만으로는 `Container` 에 color 와 decoration 을 함께 준 실수 같은
/// **렌더링 시점에만 터지는 오류**를 잡을 수 없다. 실제로 그런 크래시가 요기족보
/// 목록에서 나왔기 때문에, 네 화면 모두 한 번은 그려 보는 테스트를 남긴다.
void main() {
  Future<AppFlow> pumpScreen(WidgetTester tester, Widget screen, AppFlow flow) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppFlow>.value(
        value: flow,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(backgroundColor: AppColors.pageBackground, body: screen),
        ),
      ),
    );
    // pumpAndSettle 은 쓰지 않는다. 입력창의 커서가 계속 깜빡여 "정지"에
    // 도달하지 않고 테스트가 멈춘다. 프레임 몇 장만 진행시키면 충분하다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    return flow;
  }

  /// 지연을 0으로 둔다. 위젯 테스트는 가짜 시계에서 돌아
  /// `Future.delayed` 가 저절로 진행되지 않는다.
  AppFlow newFlow() => AppFlow(
        locationService: const _NoLocation(),
        postRepository: MockPostRepository(delay: Duration.zero),
      );

  testWidgets('요기족보 홈이 크래시 없이 그려진다', (tester) async {
    final flow = newFlow();
    await flow.openJokbo();
    await pumpScreen(tester, const YogijokboHomeScreen(), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('요기족보'), findsWidgets);
    expect(find.text('떵개 추천 두찜 로제 닭발'), findsWidgets);
    // 정렬 선택 줄. 왼쪽 위치 필터는 기능 폐기로 빠졌다.
    expect(find.text('인기순'), findsWidgets);
    // 하단 내비 4탭
    expect(find.text('주문내역'), findsOneWidget);
    expect(find.text('마이요기요'), findsOneWidget);
  });

  testWidgets('목록 항목을 탭하면 상세로 넘어간다', (tester) async {
    final flow = newFlow();
    await flow.openJokbo();
    await pumpScreen(tester, const YogijokboHomeScreen(), flow);

    await tester.tap(find.text('떵개 추천 두찜 로제 닭발').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
    expect(flow.stage, AppStage.jokboDetail);
  });

  testWidgets('조합 상세가 크래시 없이 그려진다', (tester) async {
    final flow = newFlow();
    await flow.openPost('post_01H8X');
    await pumpScreen(tester, const PostDetailScreen(), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('배고픈 요기요'), findsWidgets);
    expect(find.text('2026.07.07'), findsOneWidget);
    expect(find.text('두찜-잠실새내점'), findsOneWidget);
    expect(find.text('나도 주문하기'), findsOneWidget);
    expect(find.text('[사이드] 치즈볼'), findsOneWidget);

    // 댓글 영역은 화면 밖이라 아직 만들어지지 않았다. 스크롤해서 확인한다.
    await tester.scrollUntilVisible(
      find.text('댓글 4'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('댓글 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('주문하기가 크래시 없이 그려지고 결제 금액이 맞다', (tester) async {
    final flow = newFlow();
    await flow.openPost('post_01H8X');
    await flow.startReorder();
    await pumpScreen(tester, CartScreen(title: '주문하기', onBack: () {}), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('주문하기'), findsOneWidget);
    expect(find.text('결제하기'), findsOneWidget);

    // 결제 요약은 화면 밖이라 아직 만들어지지 않았다. 스크롤해서 확인한다.
    await tester.scrollUntilVisible(
      find.text('결제 금액'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    // 주문 20,000 + 배달비 3,000 = 23,000 (시안과 같은 값)
    expect(find.text('23,000원'), findsWidgets);
    expect(find.text('20,000원'), findsWidgets);
  });

  testWidgets('매장이 여러 곳이면 매장마다 섹션과 배달비가 나온다', (tester) async {
    final flow = newFlow();
    await flow.openPost('post_02K3M');
    await flow.startReorder();
    await pumpScreen(tester, CartScreen(title: '주문하기', onBack: () {}), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('KFC-용산아이파크몰점'), findsOneWidget);
    expect(find.textContaining('2곳에서 따로 배달'), findsOneWidget);

    // 두 번째 매장 섹션은 화면 밖이라 스크롤해서 확인한다.
    await tester.scrollUntilVisible(
      find.text('편의점 배달-용산점'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    // 배달비 합계는 "배달비 (2곳)" 로 표기된다.
    await tester.scrollUntilVisible(
      find.text('배달비 (2곳)'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('4,500원'), findsOneWidget); // 2,500 + 2,000
  });

  testWidgets('족보 작성이 크래시 없이 그려지고 제목 없이는 공유할 수 없다', (tester) async {
    final flow = newFlow();
    await flow.openPost('post_01H8X');
    await flow.startReorder();
    flow.composeCart = flow.cart;
    await pumpScreen(tester, const PostComposeScreen(), flow);

    expect(tester.takeException(), isNull);
    expect(find.text('족보 작성'), findsOneWidget);
    expect(find.text('먹방 속 조합, 어땠나요?'), findsOneWidget);
    expect(find.text('0/20'), findsOneWidget);
    expect(find.text('0/400'), findsOneWidget);
    expect(find.text('사진 첨부'), findsOneWidget);

    // 제목이 비어 있으면 공유 버튼이 잠긴다
    expect(find.text('제목을 입력해주세요'), findsOneWidget);
    final share = tester.widget<DsButton>(find.byType(DsButton));
    expect(share.onPressed, isNull);
  });

  testWidgets('제목을 입력하면 공유 버튼이 열리고 글자수가 갱신된다', (tester) async {
    final flow = newFlow();
    await flow.openPost('post_01H8X');
    await flow.startReorder();
    flow.composeCart = flow.cart;
    await pumpScreen(tester, const PostComposeScreen(), flow);

    await tester.enterText(find.byType(TextField).first, '내 로제닭발 조합');
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('9/20'), findsOneWidget); // '내 로제닭발 조합' = 공백 포함 9자
    final share = tester.widget<DsButton>(find.byType(DsButton));
    expect(share.onPressed, isNotNull);
  });
}
