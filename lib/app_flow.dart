import 'package:flutter/foundation.dart';

import 'api/api_client.dart';
import 'api/mukbang_api.dart';
import 'api/user_api.dart';
import 'models/analysis_source.dart';
import 'models/auth.dart';
import 'models/combo.dart';
import 'models/order.dart';
import 'models/post.dart';
import 'models/preference.dart';
import 'models/user_location.dart';
import 'repository/auth_repository.dart';
import 'repository/combo_repository.dart';
import 'repository/order_repository.dart';
import 'repository/post_repository.dart';
import 'env.dart';
import 'services/gemini_extractor.dart';
import 'services/location_service.dart';
import 'services/metadata_fetcher.dart';
import 'services/openai_extractor.dart';
import 'services/token_store.dart';

enum AppStage {
  login, // 로그인 (앱 첫 진입)
  signup, // 이메일로 회원가입
  yogiyoHome, // 요기요 메인 홈 (배너·검색·카테고리·요기족보 차트)
  orders, // 결제 내역 (요기족보 작성 진입점)
  orderDetail, // 주문내역 상세 (상세보기)
  home, // 공유 안내
  keyword, // 취향 설정
  analyzing, // 분석 중
  combo, // 영상에 나온 조합
  comboList, // 여러 매장 비교
  storeMenu, // 매장 메뉴 전체 (메뉴 수정하기)
  menuDetail, // 메뉴 추가하기 (옵션 고르고 담기)
  cart, // 장바구니 (여러 매장 묶음 결제)
  orderDone, // 주문 접수 완료
  failed, // 실패 안내
  jokboHome, // 요기족보 홈 (실시간 인기 + 목록)
  jokboDetail, // 조합 상세
  jokboOrder, // 나도 주문하기
  jokboCompose, // 족보 작성 (조합 공유)
  jokboEdit, // 족보 수정 (제목·본문만)
}

/// 화면 전환과 분석·주문 파이프라인.
///
/// 회의(2026-08-04) 결정에 따라 **장바구니를 여기서 들고 있는다.** 백엔드가
/// 장바구니를 저장하지 않으므로, 사용자가 고른 것은 결제 버튼을 누를 때까지 이
/// 객체 안에만 있다. 앱을 껐다 켜면 사라진다 — 명세가 "프론트가 상태를 들고 있다가
/// 주문 시점에 통째로 POST" 라고 정한 범위 그대로다.
class AppFlow extends ChangeNotifier {
  /// `.env` 에 서버 주소가 있으면 실제 API, 없으면 더미로 조립한다.
  ///
  /// 백엔드가 아직 없어서 기본값이 더미다. 서버가 올라오면 `.env` 의
  /// `API_BASE_URL` 만 채우면 되고 코드는 손대지 않는다.
  ///
  /// **[ApiClient] 는 하나만 만들어 모든 repository 가 나눠 쓴다.** 저장소마다 따로
  /// 만들면 로그인으로 받은 토큰이 그 중 하나에만 꽂혀서, 같은 로그인 상태인데도
  /// 화면에 따라 401 이 나는 상태가 된다. 토큰을 담는 자리가 하나여야 한다.
  factory AppFlow({
    ComboRepository? repository,
    LocationService? locationService,
    PostRepository? postRepository,
    OrderRepository? orderRepository,
    AuthRepository? authRepository,
    TokenStore? tokenStore,
    ApiClient? apiClient,
  }) {
    final client =
        apiClient ?? (Env.hasApiBaseUrl ? ApiClient(baseUrl: Env.apiBaseUrl) : null);
    final api = client == null ? null : MukbangApi(client);

    // 인자 순서는 아래 `AppFlow._` 의 선언 순서다. 이름을 붙일 수 없는 이유는
    // private 필드(`_repository`)를 named 파라미터로 받을 수 없기 때문이다.
    final flow = AppFlow._(
      repository ?? (api == null ? const MockComboRepository() : ApiComboRepository(api)),
      locationService ?? const GeolocatorLocationService(),
      postRepository ?? (api == null ? MockPostRepository() : ApiPostRepository(api)),
      orderRepository ?? (api == null ? MockOrderRepository() : ApiOrderRepository(api)),
      authRepository ??
          (client == null ? MockAuthRepository() : ApiAuthRepository(UserApi(client))),
      // 더미로 도는 동안에는 토큰을 기기에 남기지 않는다. 더미 토큰으로 자동 로그인이
      // 걸리면 시연에서 로그인 화면을 다시 보려면 앱을 지워야 한다.
      tokenStore ?? (client == null ? MemoryTokenStore() : const PreferencesTokenStore()),
      client,
    );

    // 401 을 받으면 재발급을 시도하고 그 요청을 한 번 더 보낸다.
    // HTTP 계층은 로그인 도메인을 모르므로 여기서 꽂아 준다.
    client?.onUnauthorized = flow._reissueTokens;
    return flow;
  }

  AppFlow._(
    this._repository,
    this._locationService,
    this._postRepository,
    this._orderRepository,
    this._authRepository,
    this._tokenStore,
    this._client,
  );

  final ComboRepository _repository;
  final LocationService _locationService;
  final PostRepository _postRepository;
  final OrderRepository _orderRepository;
  final AuthRepository _authRepository;
  final TokenStore _tokenStore;

  /// 서버를 쓸 때의 HTTP 클라이언트. 더미로 돌 때는 null 이다.
  /// 토큰을 꽂는 유일한 자리다.
  final ApiClient? _client;

  AppStage _stage = AppStage.login;
  AppStage get stage => _stage;

  String _pendingLink = '';
  String _failureMessage = '';
  String get failureMessage => _failureMessage;

  TastePreference preference = TastePreference();
  ComboSort sort = ComboSort.similarity;

  /// 마지막 분석 결과. `exactMatches` + `combos` 를 그대로 들고 있는다.
  AnalysisResult analysis = const AnalysisResult.empty();

  /// 카드를 넘겨 볼 순서. 영상에 나온 브랜드가 앞, 비슷한 곳이 뒤다.
  List<ComboSuggestion> get suggestions => analysis.all;

  int selectedComboIndex = 0;

  /// 이번 분석의 입력(원문 텍스트·링크·플랫폼).
  /// 서버에 분석을 넘길 때 추출 결과와 함께 보내야 하므로 버리지 않고 들고 있는다.
  AnalysisSource? source;

  /// 마지막 분석의 AI 추출 결과. [source] 와 짝이다.
  ExtractionResult? extraction;

  ComboSuggestion? get selectedCombo =>
      selectedComboIndex >= 0 && selectedComboIndex < suggestions.length
          ? suggestions[selectedComboIndex]
          : null;

  void _setStage(AppStage next) {
    _stage = next;
    notifyListeners();
  }

  /// 링크를 받으면 바로 분석하지 않고 취향 설정 화면을 먼저 보여준다.
  void start(String link) {
    _pendingLink = link;
    _setStage(AppStage.keyword);
  }

  // ── 인증 ──────────────────────────────────────────────────────────────────

  /// 로그인한 사람. 서버가 `{id, email, role}` 만 주므로 그만큼만 안다.
  /// 로그인 전과 로그아웃 뒤에는 null 이다.
  AuthUser? currentUser;

  /// 로그인·회원가입 요청이 도는 중인지. 버튼을 두 번 눌러 두 번 로그인하는 것을 막는다.
  bool isAuthenticating = false;

  /// 저장된 토큰으로 자동 로그인을 시도하는 중인지.
  ///
  /// 끝날 때까지 로그인 화면 대신 빈 화면을 둔다 — 자동 로그인이 될 사람에게
  /// 로그인 화면이 한 번 번쩍이면 앱이 로그아웃된 것처럼 보인다.
  bool isRestoringSession = false;

  /// 토큰을 들고 있는지. `currentUser` 가 null 이어도 로그인 상태일 수 있다 —
  /// 로그인 응답에 사용자 정보가 없어서 `me()` 를 따로 부르는데, 그 호출만 실패하면
  /// 토큰은 멀쩡하다. 로그인 여부는 토큰이 기준이다.
  bool get isLoggedIn => _hasSession;

  bool _hasSession = false;

  /// 앱을 켤 때 1회. 저장된 토큰이 살아 있으면 로그인 화면을 건너뛴다.
  ///
  /// 토큰이 죽었으면 지우고 로그인 화면에 남는다. 여기서 `me()` 를 부르는 이유는
  /// 토큰이 있다는 것만으로는 살아 있는지 알 수 없기 때문이다. 만료됐다면 그 401 을
  /// [ApiClient] 가 재발급으로 받아 주고, 재발급도 실패하면 예외로 올라온다.
  Future<void> restoreSession() async {
    final saved = await _tokenStore.read();
    if (saved == null || !saved.isUsable) return;

    isRestoringSession = true;
    notifyListeners();

    _client?.accessToken = saved.accessToken;
    _refreshToken = saved.refreshToken;
    _hasSession = true;

    try {
      currentUser = await _authRepository.me();
      completeLogin();
    } on Object {
      // 만료·위조된 토큰이다. 지우고 로그인 화면에 남는다.
      await _clearSession();
    } finally {
      isRestoringSession = false;
      notifyListeners();
    }
  }

  /// 저장된 refreshToken. 재발급 때만 쓴다.
  String _refreshToken = '';

  Future<AuthResult> login({required String email, required String password}) =>
      _authenticate(() => _authRepository.login(email: email.trim(), password: password));

  /// 회원가입. 서버가 토큰을 주지 않아 repository 가 이어서 로그인까지 하고,
  /// 앱은 가입과 로그인을 한 동작으로 다룬다.
  Future<AuthResult> signUp({
    required String email,
    required String password,
    required String nickname,
  }) =>
      _authenticate(() => _authRepository.signup(
            email: email.trim(),
            password: password,
            nickName: nickname.trim(),
          ));

  Future<AuthResult> _authenticate(Future<AuthTokens> Function() request) async {
    if (isAuthenticating) return const AuthResult.failed(AuthFailure.server);

    isAuthenticating = true;
    notifyListeners();

    try {
      final tokens = await request();
      await _applyTokens(tokens);

      // 서버 로그인 응답에는 사용자 정보가 없다. 누가 로그인했는지 알려면
      // `me()` 를 따로 불러야 한다. 실패해도 토큰은 멀쩡하니 로그인은 성공으로 둔다 —
      // 지금 앱에 사용자 정보를 그리는 화면이 없어 흐름을 막을 이유가 없다.
      try {
        currentUser = await _authRepository.me();
      } on Object {
        currentUser = null;
      }

      completeLogin();
      return const AuthResult.success();
    } on Object catch (e) {
      return _authFailure(e);
    } finally {
      isAuthenticating = false;
      notifyListeners();
    }
  }

  /// 로그아웃. 서버에 알리고 앱이 들고 있던 것을 전부 버린다.
  ///
  /// 장바구니·주문·조합을 함께 비우는 이유는 다음에 로그인한 사람이 남의 장바구니를
  /// 보게 되면 안 되기 때문이다. 서버가 토큰을 무효화하지 않으므로 실질적인
  /// 로그아웃은 토큰을 지우는 이쪽이다.
  Future<void> logout() async {
    await _authRepository.logout();
    await _clearSession();

    cart = Cart();
    orders = [];
    ordersNextCursor = null;
    orderDetail = null;
    receipt = null;
    posts = [];
    popularPosts = [];
    selectedPost = null;
    postComments = [];
    analysis = const AnalysisResult.empty();
    source = null;
    extraction = null;

    _setStage(AppStage.login);
  }

  /// 토큰을 이번 실행에 꽂고 기기에도 남긴다.
  ///
  /// 저장 실패는 삼킨다. 저장은 **다음 실행의 자동 로그인용 편의**이고 지금 로그인의
  /// 조건이 아니다. 저장이 안 됐다고 로그인을 실패로 돌리면, 앱이 이미 토큰을 들고
  /// 있는데도 로그인 화면에 남는 앞뒤가 안 맞는 상태가 된다.
  Future<void> _applyTokens(AuthTokens tokens) async {
    _client?.accessToken = tokens.accessToken;
    _refreshToken = tokens.refreshToken;
    _hasSession = true;
    try {
      await _tokenStore.write(tokens);
    } on Object catch (e) {
      // 다음에 켤 때 로그인 화면을 한 번 더 보는 것뿐이다. 다만 조용히 넘기면
      // 자동 로그인이 안 되는 이유를 찾을 수 없어, 개발 빌드에서는 남긴다.
      debugPrint('토큰 저장 실패 — 자동 로그인이 되지 않는다: $e');
    }
  }

  Future<void> _clearSession() async {
    currentUser = null;
    _refreshToken = '';
    _hasSession = false;
    _client?.accessToken = null;
    try {
      await _tokenStore.clear();
    } on Object catch (e) {
      // 지우지 못해도 이번 실행은 로그아웃 상태다. 다음 실행의 자동 로그인은
      // `me()` 가 막는다 — 서버가 거절하면 그 자리에서 다시 지운다.
      debugPrint('토큰 삭제 실패 — 다음 실행에서 me 가 걸러낸다: $e');
    }
  }

  /// [ApiClient] 가 401 을 받았을 때 부른다. 새 토큰을 얻으면 true —
  /// 그러면 클라이언트가 그 요청을 한 번 더 보낸다.
  Future<bool> _reissueTokens() async {
    final tokens = await _authRepository.reissue(_refreshToken);
    if (tokens == null) {
      // 다시 로그인해야 한다. 지금 보고 있는 화면을 끊고 로그인으로 돌려보낸다 —
      // 토큰이 죽은 채로 남으면 화면마다 조용히 빈 목록이 된다.
      await _clearSession();
      _setStage(AppStage.login);
      return false;
    }
    await _applyTokens(tokens);
    return true;
  }

  /// 실패 원인을 화면이 쓸 형태로 바꾼다. 서버가 준 문구가 있으면 함께 넘긴다 —
  /// 비밀번호 길이 같은 규칙은 서버만 알고 있어 앱이 지어내면 어긋난다.
  static AuthResult _authFailure(Object error) => switch (error) {
        NetworkException() => const AuthResult.failed(AuthFailure.network),
        ApiNotConfiguredException() => const AuthResult.failed(AuthFailure.network),
        ApiException(statusCode: 401) =>
          const AuthResult.failed(AuthFailure.invalidCredentials),
        ApiException(statusCode: 409, message: final m) =>
          AuthResult.failed(AuthFailure.emailTaken, message: m),
        ApiException(statusCode: 400, message: final m) =>
          AuthResult.failed(AuthFailure.invalidInput, message: m),
        _ => const AuthResult.failed(AuthFailure.server),
      };

  /// 회원가입 화면으로. 로그인 화면의 "이메일로 회원가입" 이 부른다.
  void openSignup() => _setStage(AppStage.signup);

  void backToLogin() => _setStage(AppStage.login);

  /// 인증이 끝나고 화면을 홈으로 보낸다.
  ///
  /// 곧바로 위치를 1회 수집한다. 배달 주소가 필요한 화면에 도달했을 때 이미
  /// 준비돼 있어야 흐름이 끊기지 않는다.
  void completeLogin() {
    _setStage(AppStage.yogiyoHome);
    refreshLocation();
    loadPopularPosts();
  }

  /// 요기요 메인 홈의 "요기족보 실시간 인기조합" 차트에 쓸 목록.
  List<YogijokboPost> popularPosts = [];

  /// 로그인 직후 기다리지 않고 부르는 자리다 (`completeLogin`). 실패를 던지면
  /// 잡을 사람이 없으므로 여기서 삼키고, 홈의 그 줄만 비워 둔다.
  Future<void> loadPopularPosts() async {
    try {
      final page = await _postRepository.list(sort: PostSort.popular);
      popularPosts = page.items;
    } on Object {
      popularPosts = [];
    }
    notifyListeners();
  }

  /// 퀵메뉴 "먹방요기" — 공유 안내 화면으로 간다.
  void openShareGuide() => _setStage(AppStage.home);

  /// 홈으로 돌아간다.
  ///
  /// 인기 조합을 **매번** 다시 받아온다. 비어 있을 때만 받으면 두 가지가 깨진다.
  /// 하나는 로그인 때 실패했거나 로그인을 거치지 않고 홈에 온 경우 시안(681:6436)의
  /// 카드 자리가 빈 분홍 영역으로 남는 것이고, 다른 하나는 이미 채워진 목록이
  /// 세션 내내 갱신되지 않아 지워진 글이 계속 떠 있는 것이다.
  void backToYogiyoHome() {
    _setStage(AppStage.yogiyoHome);
    loadPopularPosts();
  }

  // ── 결제 내역 ──────────────────────────────────────────────────────────────

  /// `GET v1/orders` 의 카드들. 카드 하나 = 결제 하나 = 영상 하나다.
  List<OrderSummary> orders = [];

  /// 결제 목록 다음 커서. null 이면 더 없다.
  String? ordersNextCursor;

  Future<void> openOrders() async {
    _setStage(AppStage.orders);
    await loadOrders();
  }

  Future<void> loadOrders() async {
    final page = await _orderRepository.list();
    orders = page.orders;
    ordersNextCursor = page.nextCursor;
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    final cursor = ordersNextCursor;
    if (cursor == null) return;
    final page = await _orderRepository.list(cursor: cursor);
    orders = [...orders, ...page.orders];
    ordersNextCursor = page.nextCursor;
    notifyListeners();
  }

  /// 이 결제로 이미 족보를 썼는지. 서버가 알려주지 않아 앱이 기억한 값이다.
  bool isPostedToJokbo(int checkoutId) => _orderRepository.isPostedToJokbo(checkoutId);

  /// "상세보기" 로 연 결제 상세 (시안 857:4509). null 이면 아직 안 받았다.
  OrderDetail? orderDetail;

  /// 주문내역 카드의 "상세보기" — `GET v1/orders/{checkoutId}`.
  ///
  /// 목록 응답에는 메뉴·옵션·금액이 없어서 상세를 따로 받아야 한다.
  /// 먼저 화면을 띄우고 받는다 — 응답을 기다리는 동안 목록에 머물면 버튼이
  /// 안 눌린 것처럼 보인다.
  Future<void> openOrderDetail(int checkoutId) async {
    orderDetail = null;
    _setStage(AppStage.orderDetail);
    orderDetail = await _orderRepository.detail(checkoutId);
    notifyListeners();
  }

  void closeOrderDetail() {
    orderDetail = null;
    _setStage(AppStage.orders);
  }

  /// 결제 내역에서 족보 작성으로. 그 결제의 조합과 출처 영상을 그대로 들고 간다.
  Future<void> composeFromOrder(OrderSummary order) async {
    final detail = await _orderRepository.detail(order.checkoutId);
    if (detail == null) return;

    composeCart = detail.toCart();
    composeSource = detail.source == null
        ? null
        : PostSource(
            platform: detail.source!.platform == SourceKind.instagram
                ? PostPlatform.instagram
                : PostPlatform.youtube,
            title: detail.source!.title,
            url: detail.source!.url,
            thumbnailUrl: detail.source!.thumbnailUrl,
          );
    composeCheckoutId = detail.checkoutId;
    _setStage(AppStage.jokboCompose);
  }

  /// 작성 완료 시 어떤 결제에서 왔는지 표시하기 위해 들고 있는다.
  int? composeCheckoutId;

  /// "다시 주문" — 결제 상세를 장바구니로 되돌려 장바구니 화면을 연다.
  Future<void> reorderFromHistory(OrderSummary order) async {
    final detail = await _orderRepository.detail(order.checkoutId);
    if (detail == null) return;

    final restored = detail.toCart();
    await _hydrateStores(restored);

    cart = restored;
    _setStage(AppStage.cart);
  }

  /// 장바구니의 매장 정보를 온전한 값으로 채운다.
  ///
  /// 결제 상세와 게시글의 `order` 블록은 매장 정보를 세 개(id·이름·배달비)만 준다.
  /// 그대로 그리면 평점·리뷰 수·거리·예상 시간이 0이고, **최소 주문 금액도 0이라
  /// 미달인데도 결제 버튼이 열린다.** `GET v1/restaurants/{id}/menus` 의
  /// `restaurant` 블록으로 갈아끼워 그 값들을 채운다.
  ///
  /// 매장이 두세 곳이라 호출 수가 문제되지 않는다. 한 곳이 실패해도 그 매장만
  /// 예전 값으로 남고 흐름은 계속된다.
  ///
  /// **id 가 맞는 응답만 받아들인다.** 그러지 않으면 엉뚱한 응답이 왔을 때 결제
  /// 스냅샷에서 알던 이름·배달비까지 0으로 덮인다 — 아는 값을 모르는 값으로
  /// 바꾸는 셈이다.
  Future<void> _hydrateStores(Cart target) async {
    for (final store in target.stores) {
      final menus = await _safeMenus(store.restaurantId);
      if (menus?.restaurant.restaurantId == store.restaurantId) {
        store.hydrate(menus!);
      }
    }
  }

  UserLocation? location;

  /// 마지막 위치 수집 실패 원인. 성공하면 null.
  LocationFailure? locationFailure;

  bool _isLocating = false;
  bool get isLocating => _isLocating;

  /// 다시 물어봐도 소용없어 주소 직접 입력이 필요한 상태인지.
  bool get needsAddressInput =>
      location == null &&
      (locationFailure == LocationFailure.deniedForever ||
          locationFailure == LocationFailure.serviceDisabled);

  /// 기기 좌표를 가져온다. 실패해도 흐름을 막지 않는다 —
  /// 위치는 보조 정보이고, 없으면 주소 직접 입력으로 메꾼다.
  Future<void> refreshLocation() async {
    if (_isLocating) return;
    _isLocating = true;
    notifyListeners();

    final result = await _locationService.current();
    if (result.isSuccess) {
      location = result.location;
      locationFailure = null;
    } else {
      locationFailure = result.failure;
    }

    _isLocating = false;
    notifyListeners();
  }

  /// 권한 거부 시 사용자가 주소를 직접 입력한 경우.
  ///
  /// 좌표를 모르는 상태이므로 서버가 주소로 좌표를 찾아야 한다. 앱은 문자열만 들고
  /// 있고 lat/lng 는 0 으로 둔다 — 아무 좌표나 지어내면 엉뚱한 매장이 걸린다.
  void setManualAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.isEmpty) return;
    location = UserLocation(
      lat: 0,
      lng: 0,
      origin: LocationOrigin.manual,
      address: trimmed,
    );
    locationFailure = null;
    notifyListeners();
  }

  /// 디버그 빌드의 좌표 override. 시연 더미가 강남·용산 기준이라
  /// 리허설 장소가 달라도 화면이 맞게 나오도록 쓴다.
  void applyDebugLocation(UserLocation preset) {
    location = preset;
    locationFailure = null;
    notifyListeners();
  }

  void backToCombo() => _setStage(AppStage.combo);

  void backToHome() {
    analysis = const AnalysisResult.empty();
    selectedComboIndex = 0;
    source = null;
    extraction = null;
    cart = Cart();
    _setStage(AppStage.home);
  }

  void showComboList() => _setStage(AppStage.comboList);

  void selectCombo(int comboId) {
    final i = suggestions.indexWhere((c) => c.id == comboId);
    if (i < 0) return;
    selectedComboIndex = i;
    notifyListeners();
  }

  // ── 장바구니 (다중 매장 묶음) ───────────────────────────────────────────────

  /// 결제 전까지 앱이 들고 있는 장바구니. 서버에 저장되지 않는다.
  Cart cart = Cart();

  /// 분석 결과에서 고른 조합들을 장바구니에 담고 장바구니 화면을 연다.
  ///
  /// 영상에 나온 브랜드가 여러 개면 기본으로 전부 담는다 — 떡볶이+핫도그 영상이면
  /// 두 가게가 담긴 채로 시작한다. 그게 회의에서 정한 "한 번에 결제" 의 기본값이다.
  /// **이미 담아 둔 것이 있으면 그대로 쓴다.** 조합 카드의 체크박스가 곧 담기이므로
  /// 여기서 덮어쓰면 사용자가 체크를 뺀 가게가 되살아난다. 아무것도 안 골랐을 때만
  /// 영상 브랜드를 기본으로 담는다.
  void openCartFromAnalysis() {
    if (cart.isEmpty) {
      final selected = analysis.exactMatches.isEmpty
          // 영상 브랜드를 못 찾았으면 지금 보고 있는 카드를 담는다.
          ? [if (selectedCombo != null) selectedCombo!.toStoreCart()]
          : analysis.exactStoreCarts;

      cart = Cart(source: _cartSource(), stores: selected);
    }
    _setStage(AppStage.cart);
  }

  /// 카드 하나만 장바구니에 담는다. 비교 목록에서 고른 대안 매장이 여기로 온다.
  void addSuggestionToCart(ComboSuggestion suggestion) {
    cart.source ??= _cartSource();
    final store = cart.storeOf(suggestion.id);
    if (store == null) {
      cart.stores = [...cart.stores, suggestion.toStoreCart()];
    } else {
      // 이미 담긴 가게면 메뉴만 합친다. 같은 메뉴는 수량이 올라간다.
      for (final line in suggestion.items) {
        final existing = store.lineOf(line.menuId);
        if (existing != null) {
          existing.quantity += line.quantity;
        } else {
          store.lines = [...store.lines, line.copy()];
        }
      }
    }
    notifyListeners();
  }

  /// 장바구니에 담긴 가게인지. 비교 목록 체크박스가 쓴다.
  bool isInCart(int restaurantId) => cart.storeOf(restaurantId) != null;

  /// 체크박스 토글. 담겨 있으면 빼고, 없으면 담는다.
  void toggleSuggestionInCart(ComboSuggestion suggestion) {
    if (isInCart(suggestion.id)) {
      removeStoreFromCart(suggestion.id);
    } else {
      addSuggestionToCart(suggestion);
    }
  }

  void removeStoreFromCart(int restaurantId) {
    cart.stores = [for (final s in cart.stores) if (s.restaurantId != restaurantId) s];
    notifyListeners();
  }

  void openCart() => _setStage(AppStage.cart);

  /// 장바구니 수량 변경. 마지막 메뉴를 빼면 그 가게도 함께 사라진다 —
  /// 이름만 남으면 배달비가 총액에 계속 붙어 금액이 틀린다.
  void changeCartQuantity({
    required int restaurantId,
    required int menuId,
    required int delta,
  }) {
    final store = cart.storeOf(restaurantId);
    if (store == null) return;
    store.changeQuantity(menuId: menuId, delta: delta);
    cart.pruneEmptyStores();
    notifyListeners();
  }

  /// 조합 카드의 수량 변경.
  ///
  /// 이미 담긴 매장이면 장바구니 쪽을 고친다 — 카드와 장바구니가 다른 수량을
  /// 보여주면 어느 쪽이 결제되는지 알 수 없다. 아직 안 담긴 매장은 카드만 고친다.
  void changeSuggestionQuantity({
    required ComboSuggestion combo,
    required int menuId,
    required int delta,
  }) {
    // 장바구니에 담긴 카드면 그쪽도 함께 고친다. **카드를 그리는 건 언제나
    // `combo.items` 다** — 예전에는 담긴 카드일 때 장바구니만 고치고 돌아가서,
    // 체크된 카드에서는 수량도 휴지통도 눌러도 아무 일이 없어 보였다
    // (디자이너 피드백 2026-08-13).
    final store = cart.storeOf(combo.id);
    if (store != null) {
      store.changeQuantity(menuId: menuId, delta: delta);
      cart.pruneEmptyStores();
    }

    final line = combo.lineOf(menuId);
    if (line == null) {
      notifyListeners();
      return;
    }
    final next = line.quantity + delta;

    // 수량 1에서 한 번 더 내리면 휴지통 아이콘이 되고, 그때는 그 메뉴를 뺀다
    // (피드백 2026-08-09). 예전에는 카드가 비는 것을 막으려고 아무 일도 하지
    // 않았는데, 아이콘이 휴지통인데 안 지워지니 눌리지 않는 것으로 보였다.
    if (next <= 0) {
      combo.items = [for (final l in combo.items) if (l.menuId != menuId) l];
      notifyListeners();
      return;
    }

    line.quantity = next;
    notifyListeners();
  }

  /// 옵션 변경 시트에서 고른 것들을 반영한다.
  void updateLineOptions({
    required int restaurantId,
    required int menuId,
    required List<MenuOption> chosen,
    SpiceLevel? spice,
  }) {
    final line = cart.storeOf(restaurantId)?.lineOf(menuId);
    if (line == null) return;
    line.applySelection(chosen);
    if (spice != null) line.selectedSpice = spice;
    notifyListeners();
  }

  /// 조합 카드에서 옵션을 바꾼다 (시안 925:4243).
  ///
  /// [updateLineOptions] 는 장바구니에 이미 있는 줄만 고친다. 조합 카드는 담기
  /// 전 화면이라 그 줄이 장바구니에 없어 아무 일도 일어나지 않는다. 그래서 조합
  /// 쪽을 직접 고치고, 그 매장을 이미 담아 뒀으면 장바구니도 함께 맞춘다 —
  /// 한쪽만 바뀌면 카드와 담아 둔 내용이 어긋난다.
  void updateSuggestionLineOptions({
    required ComboSuggestion suggestion,
    required int menuId,
    required List<MenuOption> chosen,
    SpiceLevel? spice,
  }) {
    for (final line in suggestion.items) {
      if (line.menuId != menuId) continue;
      line.applySelection(chosen);
      if (spice != null) line.selectedSpice = spice;
    }
    updateLineOptions(
      restaurantId: suggestion.restaurant.restaurantId,
      menuId: menuId,
      chosen: chosen,
      spice: spice,
    );
    notifyListeners();
  }

  /// 출처 영상을 주문 요청에 실을 형태로. 분석에 쓴 링크를 그대로 재사용한다.
  ///
  /// `title` 은 **영상 제목**이다. 예전에는 가게 이름(`primaryRestaurantName`)이
  /// 들어갔는데, 주문내역 카드와 족보의 출처 줄이 이 값을 "어느 영상에서 담았는지"
  /// 로 보여주기 때문에 가게 이름이 오면 카드마다 같은 글자가 반복된다.
  /// 제목을 못 건진 링크에서만 예전처럼 가게 이름으로 채운다.
  OrderSource? _cartSource() {
    final s = source;
    if (s == null) return null;
    final title = s.title.trim();
    return OrderSource(
      platform: s.platform == SourcePlatform.instagram
          ? SourceKind.instagram
          : SourceKind.youtube,
      url: s.url,
      thumbnailUrl: _lastThumbnailUrl,
      title: title.isNotEmpty ? title : (extraction?.primaryRestaurantName ?? ''),
    );
  }

  // ── 결제 ──────────────────────────────────────────────────────────────────

  /// 결제 진행 중인지. 버튼을 두 번 눌러 주문이 두 건 생기지 않게 막는다.
  bool isCheckingOut = false;

  /// `POST v1/orders` 의 응답. 완료 화면이 그린다.
  OrderReceipt? receipt;

  /// 완료 화면이 보여줄 금액 (시안 949:4470 의 금액 카드).
  ///
  /// **앱이 계산한 값이다.** `POST v1/orders` 의 201 응답에 금액이 없어 서버 확정액을
  /// 알 수 없다. 결제 직전 화면에서 사용자가 본 숫자와 같은 값을 그대로 보여준다 —
  /// 서버가 다시 계산해 달라진다면 주문내역에서 드러난다.
  ({int itemsTotal, int deliveryFee, int total})? paidAmounts;

  /// 장바구니를 통째로 보낸다. 가게가 여러 곳이어도 요청은 한 번이다.
  ///
  /// 응답에 `orderId` 가 없어 완료 화면에서 특정 상세로 갈 수 없다. 목록으로만 간다
  /// (`docs/api-spec.md` 확인 필요 항목).
  Future<void> checkout() async {
    if (isCheckingOut || !cart.canCheckout) return;

    isCheckingOut = true;
    notifyListeners();

    try {
      receipt = await _orderRepository.create(cart);
      // 장바구니를 비우기 전에 금액을 붙잡아 둔다.
      paidAmounts = (
        itemsTotal: cart.itemsTotal,
        deliveryFee: cart.deliveryFeeTotal,
        total: cart.totalPrice,
      );
      cart = Cart();
      _setStage(AppStage.orderDone);
    } on ApiException catch (e) {
      _fail(_checkoutFailureMessage(e));
    } on NetworkException {
      _fail('주문을 보내지 못했어요.\n연결을 확인하고 다시 시도해 주세요.');
    } finally {
      isCheckingOut = false;
      notifyListeners();
    }
  }

  /// 주문 실패 안내. 400 은 대개 프론트가 계산한 값이 서버와 어긋난 경우다 —
  /// 서버가 menuId 로 다시 계산하므로 사용자가 할 수 있는 건 다시 담는 것뿐이다.
  ///
  /// 디버그 빌드에서는 서버가 준 사유를 그대로 붙인다. 이게 없으면 어떤 필드가
  /// 검증에 걸렸는지 기기에서는 알 방법이 없고, 실제로 그것 때문에 "메뉴나 가격이
  /// 바뀌었을 수 있어요" 를 보며 엉뚱한 곳을 뒤졌다.
  static String _checkoutFailureMessage(ApiException e) {
    final base = switch (e.statusCode) {
      400 => '주문 내용을 다시 확인해 주세요.\n메뉴나 가격이 바뀌었을 수 있어요.',
      404 => '지금은 주문할 수 없는 메뉴가 있어요.',
      _ => '주문에 실패했어요.\n잠시 후 다시 시도해 주세요.',
    };
    final detail = (e.message ?? '').trim();
    if (!kDebugMode || detail.isEmpty) return base;
    return '$base\n\n[HTTP ${e.statusCode}] $detail';
  }

  /// 완료 화면의 "홈으로 이동하기" (시안 949:4470 의 유일한 버튼).
  void backToYogiyoHomeFromReceipt() {
    receipt = null;
    paidAmounts = null;
    backToYogiyoHome();
  }

  /// 완료 화면에서 결제 내역으로.
  Future<void> openOrdersFromReceipt() async {
    receipt = null;
    paidAmounts = null;
    await openOrders();
  }

  // ── 매장 메뉴 (메뉴 수정하기) ───────────────────────────────────────────────

  /// 메뉴를 담을 대상 매장 id. 매장 메뉴 화면이 어디에서 열렸는지 기억한다.
  int? storeMenuRestaurantId;
  Restaurant? storeMenuRestaurant;
  List<Menu> storeMenuItems = [];

  /// 매장 메뉴를 닫았을 때 돌아갈 화면.
  AppStage _storeMenuOrigin = AppStage.cart;

  Future<void> openStoreMenu(int restaurantId) async {
    storeMenuRestaurantId = restaurantId;
    storeMenuRestaurant = null;
    storeMenuItems = [];
    _storeMenuOrigin = _stage;
    _setStage(AppStage.storeMenu);

    final menus = await _safeMenus(restaurantId);
    if (menus == null) {
      // 404 이거나 못 불러왔다. 화면은 빈 목록으로 두고 조합은 그대로 남긴다.
      notifyListeners();
      return;
    }
    storeMenuRestaurant = menus.restaurant;
    storeMenuItems = menus.menus;
    notifyListeners();
  }

  void closeStoreMenu() => _setStage(_storeMenuOrigin);

  /// "메뉴 추가하기" 화면에 띄울 메뉴 (시안 925:4037).
  Menu? menuDetail;

  /// 메뉴를 눌러 상세로 들어간다. 목록의 + 는 옵션 없이 바로 담는 빠른 길이고,
  /// 이 화면은 옵션을 고르고 담는 길이다.
  void openMenuDetail(Menu menu) {
    menuDetail = menu;
    _setStage(AppStage.menuDetail);
  }

  void closeMenuDetail() {
    menuDetail = null;
    _setStage(AppStage.storeMenu);
  }

  /// 매장 메뉴의 + 버튼. 이미 담긴 메뉴면 수량만 올린다.
  ///
  /// [chosen] 이 오면 상세 화면에서 고른 옵션이다. 담은 뒤 그 값으로 줄을 고친다 —
  /// `Menu.toCartLine` 은 미리 체크된 옵션만 담아서 사용자가 고른 것을 모른다.
  /// [thenClose] 는 상세 화면에서 담은 경우다. 담고 그 화면을 닫는다.
  void addMenuToCart(
    Menu menu, {
    List<MenuOption>? chosen,
    SpiceLevel? spice,
    bool thenClose = false,
  }) {
    final restaurant = storeMenuRestaurant ??
        (storeMenuRestaurantId == null
            ? null
            : cart.storeOf(storeMenuRestaurantId!)?.restaurant);
    if (restaurant == null) return;

    cart.source ??= _cartSource();
    cart.ensureStore(restaurant).add(menu);

    if (chosen != null) {
      updateLineOptions(
        restaurantId: restaurant.restaurantId,
        menuId: menu.menuId,
        chosen: chosen,
        spice: spice,
      );
    }

    // 먹방 조합·다른 결과보기의 카드에도 같이 넣는다. 그 화면들은 장바구니가
    // 아니라 `ComboSuggestion.items` 를 그리므로, 장바구니에만 담으면 돌아갔을 때
    // 추가된 것이 보이지 않는다 (디자이너 피드백 2026-08-13).
    _addToSuggestion(restaurant.restaurantId, menu, chosen: chosen, spice: spice);

    if (thenClose) {
      closeMenuDetail();
      return;
    }
    notifyListeners();
  }

  /// 매장 메뉴에서 담은 것을 그 매장의 조합 카드에도 넣는다.
  ///
  /// 조합 카드는 분석 결과의 스냅샷이라 장바구니와 별개의 목록을 들고 있다.
  /// 해당 매장의 카드가 없으면(장바구니에서 연 경우) 아무 일도 하지 않는다.
  void _addToSuggestion(
    int restaurantId,
    Menu menu, {
    List<MenuOption>? chosen,
    SpiceLevel? spice,
  }) {
    for (final combo in suggestions) {
      if (combo.id != restaurantId) continue;

      final line = combo.lineOf(menu.menuId);
      if (line != null) {
        // 이미 있는 메뉴면 수량만 올린다. 장바구니와 같은 규칙이다.
        line.quantity += 1;
      } else {
        final added = menu.toCartLine();
        if (chosen != null) added.applySelection(chosen);
        if (spice != null) added.selectedSpice = spice;
        combo.items = [...combo.items, added];
      }
      return;
    }
  }

  /// 그 메뉴가 장바구니에 몇 개 담겼는지. 매장 메뉴 화면이 수량을 보여준다.
  int cartQuantityOf(int menuId) {
    final id = storeMenuRestaurantId;
    if (id == null) return 0;
    return cart.storeOf(id)?.lineOf(menuId)?.quantity ?? 0;
  }

  /// 메뉴 조회 실패를 화면 흐름으로 삼키지 않고 null 로 바꾼다.
  Future<RestaurantMenus?> _safeMenus(int restaurantId) async {
    try {
      return await _repository.menus(restaurantId);
    } on ApiException {
      return null;
    } on NetworkException {
      return null;
    } on ApiNotConfiguredException {
      return null;
    }
  }

  void updatePreference(TastePreference next) {
    preference = next;
    notifyListeners();
  }

  void updateSort(ComboSort next) {
    sort = next;
    notifyListeners();
  }

  /// 정렬을 적용한 비교 목록.
  List<ComboSuggestion> get sortedSuggestions => sort.apply(suggestions);

  /// 취향 설정 화면을 필터로 다시 열었는지.
  ///
  /// 시안의 "필터"(681:6194)는 키워드 선택 화면과 구조가 같다 — 디자이너가 같은
  /// 화면을 재사용했다. 그래서 화면을 새로 만들지 않고 이 깃발로 갈라 쓴다.
  bool _keywordIsFilter = false;

  /// 마지막 분석의 썸네일. 필터를 다시 걸 때 같은 이미지를 써야 카드가 바뀌지 않는다.
  String? _lastThumbnailUrl;

  /// 비교 목록의 필터 칩. 취향 설정 화면을 필터로 다시 연다.
  void openFilter() {
    _keywordIsFilter = true;
    _setStage(AppStage.keyword);
  }

  /// 취향 설정에서 "적용하기"를 누르면 실제 분석을 시작한다.
  /// 필터로 열렸을 때는 AI 를 다시 부르지 않고 분석만 다시 요청한다 —
  /// 영상에서 뽑은 내용은 그대로이고 취향만 바뀌었다.
  Future<void> applyPreferenceAndAnalyze() async {
    if (_keywordIsFilter) {
      _keywordIsFilter = false;
      return _reapplyPreference();
    }
    return _analyze();
  }

  Future<void> _reapplyPreference() async {
    final result = extraction;
    final input = source;
    if (result == null || input == null) {
      _setStage(AppStage.comboList);
      return;
    }

    _setStage(AppStage.analyzing);
    final analyzed = await _requestAnalysis(input, result);
    if (analyzed == null) return;

    analysis = analyzed;
    selectedComboIndex = 0;
    _setStage(AppStage.comboList);
  }

  Future<void> _analyze() async {
    final link = _pendingLink;
    // 이전 분석의 입력·결과가 남아 새 링크의 것으로 오인되지 않게 먼저 비운다.
    source = null;
    extraction = null;
    analysis = const AnalysisResult.empty();
    _setStage(AppStage.analyzing);

    final uri = Uri.tryParse(link);
    if (uri == null || !uri.scheme.startsWith('http')) {
      _fail('올바른 링크가 아니에요');
      return;
    }

    // 명세의 `source.platform` 은 INSTAGRAM | YOUTUBE 두 값만 받는다.
    // 그 밖의 링크는 보낼 수 없으므로 텍스트를 긁기 전에 막는다.
    final platform = SourcePlatform.fromUrl(uri);
    if (!platform.isSupported) {
      _fail('인스타그램과 유튜브 링크만 분석할 수 있어요');
      return;
    }

    String text;
    String? thumbnailUrl;
    String videoTitle;
    try {
      final metadata = await const MetadataFetcher().fetch(uri);
      text = metadata.combinedText;
      thumbnailUrl = metadata.imageUrl;
      // 주문내역 카드와 족보의 출처 줄이 쓸 값이다. `combinedText` 안에도 있지만
      // 계정명·설명과 붙어 있어 거기서는 제목만 떼어낼 수 없다.
      videoTitle = metadata.title ?? '';
      _lastThumbnailUrl = thumbnailUrl;
    } catch (_) {
      _fail('게시물 내용을 가져오지 못했어요.\n잠시 후 다시 시도해 주세요.');
      return;
    }

    // Gemini 에 넣은 텍스트를 그대로 보관한다. 서버로 분석을 넘길 때
    // 추출 결과만으로는 부족하고 원문이 함께 필요하다.
    final input = AnalysisSource.fromUrl(url: uri, rawText: text, title: videoTitle);
    source = input;

    // 호출 전에 키를 확인한다. 없거나 템플릿 값이면 네트워크를 태울 필요가 없고,
    // "잠시 후 다시 시도"는 거짓말이 된다 — 키 문제는 재시도로 낫지 않는다.
    if (!Env.hasAiKey) {
      _fail(_keyProblemMessage);
      return;
    }

    final extractor = _extractor();
    ExtractionResult? result;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        result = await extractor.extract(text);
        break;
      } on ExtractorAuthException {
        // 키가 거부됐다. 재시도해도 같은 결과라 즉시 포기한다.
        _fail(_keyProblemMessage);
        return;
      } on ExtractorRequestException catch (e) {
        // 우리가 보낸 요청이 잘못됐다. 재시도가 소용없는 건 키 문제와 같지만
        // 사용자가 할 수 있는 일이 없고, 키를 의심하게 두면 원인을 놓친다.
        _fail(_requestProblemMessage(e));
        return;
      } on ExtractorQuotaException catch (e) {
        // 재시도하지 않는다. 한도가 닫힌 상태라 한 번 더 부르면 남은 몫만 준다.
        _fail(_quotaProblemMessage(e));
        return;
      } catch (e) {
        // 그 밖의 실패(네트워크·타임아웃)는 1회 자동 재시도.
        // 삼키면 기기에서 무엇이 터졌는지 알 방법이 없어 로그로는 남긴다.
        debugPrint('AI 추출 실패 (재시도 ${attempt + 1}/2): $e');
      }
    }
    if (result == null) {
      _fail('AI 분석에 실패했어요.\n잠시 후 다시 시도해 주세요.');
      return;
    }
    extraction = result;

    final analyzed = await _requestAnalysis(input, result);
    if (analyzed == null) return;

    analysis = analyzed;
    selectedComboIndex = 0;
    _setStage(AppStage.combo);
  }

  /// `POST v1/analyses` 호출. 실패하면 실패 화면으로 보내고 null 을 준다.
  ///
  /// 결과가 0개인 것은 실패가 아니지만(명세가 200 + 빈 배열) 보여줄 화면이 없어
  /// 같은 안내로 처리한다.
  Future<AnalysisResult?> _requestAnalysis(
    AnalysisSource input,
    ExtractionResult result,
  ) async {
    AnalysisResult analyzed;
    try {
      analyzed = await _repository.analyze(
        source: input,
        extraction: result,
        thumbnailUrl: _lastThumbnailUrl,
        preference: preference,
      );
    } on ApiException {
      _fail('조합을 찾는 데 실패했어요.\n잠시 후 다시 시도해 주세요.');
      return null;
    } on NetworkException {
      _fail('서버에 연결하지 못했어요.\n연결을 확인하고 다시 시도해 주세요.');
      return null;
    } on ApiNotConfiguredException {
      _fail('서버 주소가 설정되지 않았어요.\n.env 의 API_BASE_URL 을 확인해 주세요.');
      return null;
    }

    // 요리와 카테고리가 다른 후보를 걷어낸다. 서버가 "가장 가까운 N개" 를 주기
    // 때문에, 그 카테고리 가게가 반경 안에 없으면 전혀 다른 음식이 올라온다
    // (포테이토피자 릴스에 한솥도시락이 추천된 건이 그랬다).
    final filtered = analyzed.withCategoryFilter({
      for (final dish in result.dishes)
        if (dish.foodCategory != null) dish.name: dish.foodCategory!,
    });

    if (filtered.isEmpty) {
      _fail('조건에 맞는 조합을 찾지 못했어요.');
      return null;
    }
    return filtered;
  }

  // ── 요기족보 ───────────────────────────────────────────────────────────────

  List<YogijokboPost> posts = [];
  bool postsLoading = false;

  PostSort postSort = PostSort.popular;

  YogijokboPost? selectedPost;
  List<PostComment> postComments = [];

  /// 작성 화면이 공유할 조합.
  Cart? composeCart;

  /// 작성 화면 상단 영상 카드에 쓸 출처.
  PostSource? composeSource;

  /// 반환된 Future 는 목록 로딩이 끝날 때 완료된다. 화면은 기다리지 않아도 되지만
  /// 테스트가 로딩 완료를 기다릴 수 있어야 한다.
  Future<void> openJokbo() async {
    _setStage(AppStage.jokboHome);
    // 이 화면은 목록과 인기 배너를 함께 보여준다. 목록만 새로 받으면 배너는
    // 로그인 시점 스냅샷으로 남아, 지워진 글이 위에만 계속 떠 있게 된다.
    await Future.wait([loadPosts(), loadPopularPosts()]);
  }

  /// 다음 페이지 커서. null 이면 더 없다 (api-yogijokbo.md 1번).
  String? postsNextCursor;

  /// 목록을 받아오지 못했는지. 빈 목록과 구분해야 한다 — 실패를 "아직 글이 없어요"
  /// 로 보여주면 사용자가 다시 시도할 이유를 알 수 없다.
  bool postsLoadFailed = false;

  Future<void> loadPosts() async {
    postsLoading = true;
    postsLoadFailed = false;
    notifyListeners();

    try {
      final page = await _postRepository.list(sort: postSort);
      posts = page.items;
      postsNextCursor = page.nextCursor;
    } on Object {
      // 서버·네트워크 문제. 여기서 던지면 로딩 표시가 영원히 남는다.
      posts = [];
      postsNextCursor = null;
      postsLoadFailed = true;
    }

    postsLoading = false;
    notifyListeners();
  }

  /// 목록 끝에서 다음 페이지를 이어 붙인다.
  Future<void> loadMorePosts() async {
    final cursor = postsNextCursor;
    if (cursor == null || postsLoading) return;

    postsLoading = true;
    notifyListeners();

    try {
      final page = await _postRepository.list(sort: postSort, cursor: cursor);
      posts = [...posts, ...page.items];
      postsNextCursor = page.nextCursor;
    } on Object {
      // 이미 보고 있는 목록은 그대로 둔다. 커서만 지워 같은 실패를 반복하지 않는다.
      postsNextCursor = null;
    }

    postsLoading = false;
    notifyListeners();
  }

  Future<void> updatePostSort(PostSort next) async {
    if (postSort == next) return;
    postSort = next;
    await loadPosts();
  }

  Future<void> openPost(String postId) async {
    final post = await _postRepository.detail(postId);
    if (post == null) return;

    selectedPost = post;
    postComments = [];
    _setStage(AppStage.jokboDetail);

    // 댓글은 화면을 띄운 뒤 채운다. 상세 응답이 댓글을 내려주지 않아 별도 호출이다.
    await loadComments(postId);
  }

  /// 서버가 한 글의 댓글을 한 번에 다 준다. 이어 받을 커서가 없다.
  Future<void> loadComments(String postId) async {
    postComments = await _postRepository.comments(postId);
    notifyListeners();
  }

  void backToJokboHome() {
    selectedPost = null;
    postComments = [];
    _setStage(AppStage.jokboHome);
  }

  Future<void> toggleLike() async {
    final post = selectedPost;
    if (post == null) return;
    await _toggleLikeOf(post);
  }

  /// 목록에서 누른 좋아요. 시안(681:8066)의 목록 행에도 좋아요 버튼이 있어
  /// 글을 열지 않고 바로 누를 수 있어야 한다.
  Future<void> toggleLikeOn(String postId) async {
    for (final list in [posts, popularPosts]) {
      final i = list.indexWhere((p) => p.id == postId);
      if (i >= 0) return _toggleLikeOf(list[i]);
    }
  }

  Future<void> _toggleLikeOf(YogijokboPost post) async {
    // 낙관적 업데이트. 서버가 변경 후 카운트를 돌려주므로 응답으로 덮어쓴다.
    post.likedByMe = !post.likedByMe;
    post.likeCount += post.likedByMe ? 1 : -1;
    notifyListeners();

    // 명세는 좋아요와 취소를 다른 엔드포인트로 나눈다. 둘 다 멱등이라
    // 낙관적 업데이트가 서버 상태와 어긋나도 응답으로 맞춰진다.
    final result = post.likedByMe
        ? await _postRepository.like(post.id)
        : await _postRepository.unlike(post.id);
    post.likeCount = result.likeCount;
    post.likedByMe = result.likedByMe;
    notifyListeners();
  }

  Future<void> submitComment(String body) async {
    final post = selectedPost;
    final trimmed = body.trim();
    if (post == null || trimmed.isEmpty) return;

    // 작성 응답이 갱신된 목록 전체를 준다. 서버가 매긴 id·작성시각이 그 안에 있어
    // 목록을 다시 받지 않는다.
    postComments = await _postRepository.addComment(post.id, trimmed);
    post.commentCount = postComments.length;
    notifyListeners();
  }

  // ── 게시물 수정·삭제 (시안 922:2734) ────────────────────────────────────────

  /// 게시물 헤더의 점 아이콘 → "수정하기". 상세에서만 들어온다.
  void openPostEdit() {
    if (selectedPost == null) return;
    _setStage(AppStage.jokboEdit);
  }

  void cancelPostEdit() => _setStage(AppStage.jokboDetail);

  /// 족보 수정 저장. 조합은 결제 스냅샷이라 제목·본문만 바뀐다.
  ///
  /// 서버는 사진을 부분 수정하지 않는다 — 보낸 목록이 사진 전체를 대체한다. 그래서
  /// 제목만 고칠 때도 **지금 붙어 있는 사진을 그대로 다시 넘긴다.** 넘기지 않으면
  /// 사용자가 건드리지도 않은 사진이 지워진다.
  ///
  /// 저장했는지를 돌려준다. 사진을 다시 올릴 수 없어 멈춘 경우 false 이고, 화면은
  /// 수정 화면에 남아 사용자에게 알린다.
  /// [images] 가 저장 후 남을 사진 **전부**다. 서버가 받은 것으로 통째로 갈아
  /// 끼우므로, 뺀 사진은 목록에서 빠지는 것만으로 지워진다.
  /// 넘기지 않으면 지금 붙어 있는 사진을 그대로 유지한다.
  Future<bool> savePostEdit({
    required String title,
    required String body,
    List<PostImage>? images,
  }) async {
    final post = selectedPost;
    final trimmed = title.trim();
    if (post == null || trimmed.isEmpty) return false;

    final next =
        images ?? [for (final url in post.imageUrls) PostImage.kept(url)];

    try {
      await _postRepository.updatePost(
        post.id,
        title: trimmed,
        body: body.trim(),
        images: next,
      );
    } on PostImagesUnavailableException {
      return false;
    }

    // 화면에 떠 있는 글도 새 사진 목록으로 맞춘다. 서버에 올린 사진의 URL 은
    // 응답이 주지 않으므로, 새로 고른 사진은 상세를 다시 열 때 채워진다.
    post.imageUrls = [
      for (final image in next)
        if (image is KeptPostImage) image.url,
    ];

    // 목록에도 같은 글이 떠 있다. 다시 받지 않고 그 자리에서 맞춘다 —
    // 수정 후 목록으로 돌아갔을 때 옛 제목이 남아 있으면 저장이 안 된 것처럼 보인다.
    post.title = trimmed;
    post.body = body.trim();
    for (final list in [posts, popularPosts]) {
      for (final p in list) {
        if (p.id != post.id) continue;
        p.title = post.title;
        p.body = post.body;
      }
    }

    _setStage(AppStage.jokboDetail);
    return true;
  }

  /// 게시물 삭제. 돌아갈 상세가 없어지므로 목록으로 나간다.
  Future<void> deleteCurrentPost() async {
    final post = selectedPost;
    if (post == null) return;

    await _postRepository.deletePost(post.id);
    posts = [for (final p in posts) if (p.id != post.id) p];
    popularPosts = [for (final p in popularPosts) if (p.id != post.id) p];
    selectedPost = null;
    postComments = [];
    _setStage(AppStage.jokboHome);

    // 로컬에서 빼는 것만으로는 부족하다. 자리가 하나 비었으니 순위에 밀려 있던
    // 다음 글이 배너로 올라와야 한다. 서버 기준으로 다시 받는다.
    await loadPopularPosts();
  }

  /// 댓글 삭제. 카운트는 남은 댓글 수로 다시 센다.
  Future<void> deleteComment(String commentId) async {
    final post = selectedPost;
    if (post == null) return;

    await _postRepository.deleteComment(post.id, commentId);
    await loadComments(post.id);
    post.commentCount = postComments.length;
    notifyListeners();
  }

  /// "나도 주문하기".
  ///
  /// 전용 API 가 없다 (api-yogijokbo.md "나도 주문하기 흐름"). 게시글의 조합이 이미
  /// 장바구니 모양이라 그것을 복사해 장바구니 화면으로 넘긴다. 복사본이라 장바구니에서
  /// 수량을 바꿔도 게시글 스냅샷은 그대로다.
  ///
  /// 매장이 여러 곳인 글이면 그대로 여러 가게가 담긴 장바구니가 된다.
  ///
  /// 게시글의 매장 정보는 id·이름·배달비뿐이다. 화면을 먼저 띄우고 매장 정보를
  /// 뒤이어 채운다 — 최소 주문 금액이 0인 채로 두면 미달인데도 결제가 열린다.
  /// 기다렸다 띄우면 매장 수만큼 요청이 끝날 때까지 아무 일도 없어 보인다.
  Future<void> startReorder() async {
    final post = selectedPost;
    if (post == null) return;

    cart = post.toCart();
    if (post.source != null) {
      cart.source = OrderSource(
        platform: post.source!.platform == PostPlatform.instagram
            ? SourceKind.instagram
            : SourceKind.youtube,
        url: post.source!.url,
        thumbnailUrl: post.source!.thumbnailUrl,
        title: post.source!.title,
      );
    }
    _setStage(AppStage.jokboOrder);

    await _hydrateStores(cart);
    notifyListeners();
  }

  void backToPostDetail() => _setStage(AppStage.jokboDetail);

  void cancelCompose() {
    composeCart = null;
    composeSource = null;
    composeCheckoutId = null;
    _setStage(AppStage.orders);
  }

  /// 작성 완료. 서버는 postId 만 돌려주므로 그 id 로 상세를 열어 확인시켜 준다
  /// (api-yogijokbo.md 3번 흐름).
  ///
  /// 조합 내용은 보내지 않는다. checkoutId 만 보내면 서버가 결제 스냅샷에서 읽어 붙인다.
  /// 조합을 공유한다. 성공하면 만들어진 `postId` 를 돌려준다.
  ///
  /// 공유 후에는 **주문내역으로 돌아간다** (시안 952:5089 — "조합 공유하기 선택 시
  /// 주문내역 화면으로 넘어가고 하단 토스트 알림"). 예전에는 방금 쓴 글을 바로
  /// 열었는데, 작성은 주문내역에서 시작하므로 왔던 자리로 돌려보내는 쪽으로 바뀌었다.
  /// 쓴 글로 가고 싶으면 토스트의 "보러가기" 를 쓴다 — 그 이동은 화면이 맡는다.
  Future<String?> submitPost({
    required String title,
    required String body,
    List<String> imagePaths = const [],
  }) async {
    final checkoutId = composeCheckoutId;
    if (checkoutId == null || title.trim().isEmpty) return null;

    final postId = await _postRepository.create(
      checkoutId: checkoutId,
      title: title.trim(),
      body: body.trim(),
      // 명세상 0장도 허용된다. 고른 사진이 없으면 파트를 아예 안 보낸다.
      imagePaths: imagePaths,
    );

    await _orderRepository.markPosted(checkoutId);
    composeCart = null;
    composeSource = null;
    composeCheckoutId = null;
    await openOrders();
    return postId;
  }

  /// 키 문제일 때 보여줄 문구.
  ///
  /// 개발·디버그 빌드에서는 원인을 그대로 알려준다. 이 화면이 "잠시 후 다시
  /// 시도해 주세요"로 보이면 네트워크 문제로 오해해 시연 중에 원인을 못 찾는다.
  /// 릴리즈 빌드에서는 사용자에게 `.env` 를 말할 수 없으니 담당자 확인을 안내한다.
  /// 요청이 잘못됐을 때. 사용자가 고칠 수 있는 게 없으므로 밖으로는 일반 안내를 준다.
  ///
  /// 디버그 빌드에서는 Gemini 가 준 설명을 그대로 보여준다. 이게 없으면 스키마
  /// 오류가 "AI 분석에 실패했어요" 로만 보여서, 네트워크 문제인지 우리 버그인지
  /// 화면만 보고는 구분할 수 없다.
  /// 할당량이 닫혔을 때. **사용자가 다시 눌러도 열리지 않는다** — 무료 등급은
  /// 하루 단위라 "잠시 후 다시 시도" 라고 하면 계속 누르게 만든다.
  /// 쓸 모델을 키로 고른다. [Env.prefersOpenAi] 가 우선순위를 들고 있다.
  static DishExtractor _extractor() => Env.prefersOpenAi
      ? OpenAiExtractor(
          apiKey: Env.openAiApiKey,
          model: Env.openAiModel.isEmpty
              ? OpenAiExtractor.defaultModel
              : Env.openAiModel,
        )
      : GeminiExtractor(apiKey: Env.geminiApiKey);

  static String _quotaProblemMessage(ExtractorQuotaException e) => kDebugMode
      ? 'AI 사용량 한도를 넘었어요.\n${e.message}'
      : e.isDaily
          ? '오늘 AI 분석 사용량을 다 썼어요.\n내일 다시 시도해 주세요.'
          : '지금 요청이 몰렸어요.\n잠시 후 다시 시도해 주세요.';

  static String _requestProblemMessage(ExtractorRequestException e) => kDebugMode
      ? 'AI 요청이 거부됐어요 (HTTP ${e.statusCode}).\n${e.message}'
      : 'AI 분석에 실패했어요.\n담당자에게 문의해 주세요.';

  static String get _keyProblemMessage => kDebugMode
      ? 'AI API 키가 설정되지 않았어요.\n'
          '.env 의 OPENAI_API_KEY 또는 GEMINI_API_KEY 를 실제 키로 채우고\n'
          '다시 빌드해 주세요.'
      : '지금 AI 분석을 쓸 수 없어요.\n담당자에게 문의해 주세요.';

  void _fail(String message) {
    _failureMessage = message;
    _setStage(AppStage.failed);
  }
}

/// 결제 상세로 되돌린 장바구니의 매장 정보를 온전한 값으로 채운다.
///
/// 결제 상세는 매장 id·이름·배달비만 준다. GET menus 로 받은 매장으로 갈아끼우면
/// 평점·최소 주문 금액·거리가 화면에 제대로 나온다. 옵션 후보도 같은 이유로 채운다 —
/// 주문 상세의 `selectedOptions` 는 고른 것만이라 시트를 열면 후보가 부족하다.
extension on StoreCart {
  void hydrate(RestaurantMenus menus) {
    restaurant = menus.restaurant;
    final byId = {for (final m in menus.menus) m.menuId: m};
    lines = [
      for (final line in lines)
        if (byId[line.menuId] case final menu?)
          CartLine(
            menuId: line.menuId,
            name: line.name,
            menuType: menu.menuType,
            price: line.price,
            quantity: line.quantity,
            imageUrl: menu.imageUrl,
            imagePath: menu.imagePath,
            spiceLevel: menu.spiceLevel,
            spiceAdjustable: menu.spiceAdjustable,
            selectedSpice: line.selectedSpice,
            // 후보 전체를 넣고, 그때 고른 것만 다시 체크한다.
            options: [
              for (final option in menu.options)
                option.copyWith(
                  selected: line.selectedOptions.any((s) => s.isSameAs(option)),
                ),
            ],
          )
        else
          line,
    ];
  }
}
