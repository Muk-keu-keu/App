import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mukbang_ttaradamgi/api/api_client.dart';
import 'package:mukbang_ttaradamgi/app_flow.dart';
import 'package:mukbang_ttaradamgi/models/auth.dart';
import 'package:mukbang_ttaradamgi/repository/auth_repository.dart';
import 'package:mukbang_ttaradamgi/repository/post_repository.dart';
import 'package:mukbang_ttaradamgi/screens/login_screen.dart';
import 'package:mukbang_ttaradamgi/screens/signup_screen.dart';
import 'package:mukbang_ttaradamgi/services/location_service.dart';
import 'package:mukbang_ttaradamgi/theme.dart';
import 'package:mukbang_ttaradamgi/widgets/ds.dart';

class _NoLocation implements LocationService {
  const _NoLocation();

  @override
  Future<LocationResult> current() async =>
      const LocationResult.failed(LocationFailure.denied);
}

/// 정해진 결과만 돌려주는 인증. 실패 문구가 화면에 뜨는지 보려면 실패를 만들 수 있어야 한다.
class _StubAuth implements AuthRepository {
  _StubAuth({this.failWith});

  /// null 이면 성공한다.
  final ApiException? failWith;

  String? sentEmail;
  String? sentNickName;

  @override
  Future<AuthTokens> login({required String email, required String password}) async {
    sentEmail = email;
    if (failWith != null) throw failWith!;
    return const AuthTokens(accessToken: 'a', refreshToken: 'r');
  }

  @override
  Future<AuthTokens> signup({
    required String email,
    required String password,
    required String nickName,
  }) async {
    sentEmail = email;
    sentNickName = nickName;
    if (failWith != null) throw failWith!;
    return const AuthTokens(accessToken: 'a', refreshToken: 'r');
  }

  @override
  Future<AuthTokens?> reissue(String refreshToken) async => null;

  @override
  Future<void> logout() async {}

  @override
  Future<AuthUser> me() async =>
      const AuthUser(id: 1, email: 'a@b.com', role: 'USER');
}

void main() {
  Future<void> pumpScreen(WidgetTester tester, Widget screen, AppFlow flow) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppFlow>.value(
        value: flow,
        child: MaterialApp(
          theme: buildAppTheme(),
          home: Scaffold(body: screen),
        ),
      ),
    );
    // pumpAndSettle 은 쓰지 않는다. 입력창 커서가 계속 깜빡여 "정지"에 닿지 않는다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// 지연을 0으로 둔다. 위젯 테스트는 가짜 시계에서 돌아 `Future.delayed` 가
  /// 저절로 진행되지 않고, 로그인 뒤 인기 조합을 받는 타이머가 남아 테스트가 실패한다.
  AppFlow flowWith(AuthRepository auth) => AppFlow(
        locationService: const _NoLocation(),
        authRepository: auth,
        postRepository: MockPostRepository(delay: Duration.zero),
      );

  group('로그인 화면', () {
    testWidgets('크래시 없이 그려진다', (tester) async {
      await pumpScreen(tester, const LoginScreen(), flowWith(_StubAuth()));

      expect(tester.takeException(), isNull);
      expect(find.text('로그인'), findsOneWidget);
      expect(find.text('이메일로 회원가입'), findsOneWidget);
    });

    testWidgets('빈 칸으로 누르면 서버를 부르지 않고 안내만 띄운다', (tester) async {
      final auth = _StubAuth();
      final flow = flowWith(auth);
      await pumpScreen(tester, const LoginScreen(), flow);

      await tester.tap(find.text('로그인'));
      await tester.pump();

      expect(find.text('이메일과 비밀번호를 입력해 주세요.'), findsOneWidget);
      expect(auth.sentEmail, isNull);
      expect(flow.stage, AppStage.login);
    });

    testWidgets('입력하고 누르면 로그인하고 홈으로 간다', (tester) async {
      final auth = _StubAuth();
      final flow = flowWith(auth);
      await pumpScreen(tester, const LoginScreen(), flow);

      await tester.enterText(find.byType(TextField).first, ' qa@example.com ');
      await tester.enterText(find.byType(TextField).last, 'Test1234!');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 앞뒤 공백은 잘라서 보낸다. 붙여넣기로 공백이 붙는 일이 흔하다.
      expect(auth.sentEmail, 'qa@example.com');
      expect(flow.stage, AppStage.yogiyoHome);
    });

    testWidgets('자격이 틀리면 실패 문구가 뜨고 화면에 남는다', (tester) async {
      final flow = flowWith(_StubAuth(
        failWith: const ApiException(statusCode: 401, code: 'INVALID_CREDENTIALS'),
      ));
      await pumpScreen(tester, const LoginScreen(), flow);

      await tester.enterText(find.byType(TextField).first, 'qa@example.com');
      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);
      expect(flow.stage, AppStage.login);
    });

    testWidgets('다시 입력하면 실패 문구가 사라진다', (tester) async {
      final flow = flowWith(_StubAuth(
        failWith: const ApiException(statusCode: 401, code: 'INVALID_CREDENTIALS'),
      ));
      await pumpScreen(tester, const LoginScreen(), flow);

      await tester.enterText(find.byType(TextField).first, 'qa@example.com');
      await tester.enterText(find.byType(TextField).last, 'wrong');
      await tester.tap(find.text('로그인'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsOneWidget);

      await tester.enterText(find.byType(TextField).last, 'Test1234!');
      await tester.pump();

      expect(find.text('이메일 또는 비밀번호가 올바르지 않습니다.'), findsNothing);
    });

    testWidgets('"이메일로 회원가입" 은 회원가입 화면으로 보낸다', (tester) async {
      final flow = flowWith(_StubAuth());
      await pumpScreen(tester, const LoginScreen(), flow);

      await tester.tap(find.text('이메일로 회원가입'));
      await tester.pump();

      expect(flow.stage, AppStage.signup);
    });
  });

  group('회원가입 화면', () {
    Future<void> fill(
      WidgetTester tester, {
      String email = 'qa@example.com',
      String password = 'Test1234!',
      String? confirm,
      String nickname = '큐에이',
    }) async {
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), email);
      await tester.enterText(fields.at(1), password);
      await tester.enterText(fields.at(2), confirm ?? password);
      await tester.enterText(fields.at(3), nickname);
    }

    testWidgets('크래시 없이 그려진다', (tester) async {
      await pumpScreen(tester, const SignupScreen(), flowWith(_StubAuth()));

      expect(tester.takeException(), isNull);
      expect(find.text('회원가입'), findsOneWidget);
      // 이메일 · 비밀번호 · 비밀번호 확인 · 닉네임
      expect(find.byType(TextField), findsNWidgets(4));
    });

    testWidgets('가입하면 로그인된 상태로 홈에 도착한다', (tester) async {
      final auth = _StubAuth();
      final flow = flowWith(auth);
      await pumpScreen(tester, const SignupScreen(), flow);

      await fill(tester);
      await tester.tap(find.text('가입하고 시작하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(auth.sentNickName, '큐에이');
      expect(flow.isLoggedIn, isTrue);
      expect(flow.stage, AppStage.yogiyoHome);
    });

    testWidgets('비밀번호가 8자보다 짧으면 서버를 부르지 않는다', (tester) async {
      final auth = _StubAuth();
      await pumpScreen(tester, const SignupScreen(), flowWith(auth));

      await fill(tester, password: 'short');
      await tester.tap(find.text('가입하고 시작하기'));
      await tester.pump();

      expect(find.text('비밀번호는 8자 이상 64자 이하여야 합니다.'), findsOneWidget);
      expect(auth.sentEmail, isNull);
    });

    testWidgets('비밀번호 확인이 다르면 막는다', (tester) async {
      final auth = _StubAuth();
      await pumpScreen(tester, const SignupScreen(), flowWith(auth));

      await fill(tester, confirm: 'Test1234?');
      await tester.tap(find.text('가입하고 시작하기'));
      await tester.pump();

      expect(find.text('비밀번호가 서로 달라요.'), findsOneWidget);
      expect(auth.sentEmail, isNull);
    });

    testWidgets('이메일 형식이 아니면 막는다', (tester) async {
      final auth = _StubAuth();
      await pumpScreen(tester, const SignupScreen(), flowWith(auth));

      await fill(tester, email: 'not-an-email');
      await tester.tap(find.text('가입하고 시작하기'));
      await tester.pump();

      expect(find.text('이메일 형식이 올바르지 않습니다.'), findsOneWidget);
      expect(auth.sentEmail, isNull);
    });

    testWidgets('이미 가입된 이메일이면 서버 문구를 보여준다', (tester) async {
      final flow = flowWith(_StubAuth(
        failWith: const ApiException(
          statusCode: 409,
          code: 'EMAIL_ALREADY_EXISTS',
          message: '이미 존재하는 이메일입니다.',
        ),
      ));
      flow.openSignup();
      await pumpScreen(tester, const SignupScreen(), flow);

      await fill(tester);
      await tester.tap(find.text('가입하고 시작하기'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('이미 존재하는 이메일입니다.'), findsOneWidget);
      expect(flow.stage, AppStage.signup);
    });

    testWidgets('뒤로 가면 로그인 화면으로 돌아간다', (tester) async {
      final flow = flowWith(_StubAuth());
      flow.openSignup();
      await pumpScreen(tester, const SignupScreen(), flow);

      await tester.tap(find.byType(DsChevron));
      await tester.pump();

      expect(flow.stage, AppStage.login);
    });
  });
}
