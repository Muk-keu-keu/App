/// 로그인 토큰을 기기에 남기는 자리. 자동 로그인이 이것으로 돈다.
///
/// `shared_preferences` 는 iOS `UserDefaults` · 안드로이드 `SharedPreferences` 다.
/// 암호화되지 않으므로 탈옥·루팅된 기기에서는 토큰이 보인다. 데모 단계라 이대로 두고,
/// 실서비스로 가면 `flutter_secure_storage`(키체인·Keystore)로 [TokenStore] 구현만
/// 갈아끼우면 된다 — 부르는 쪽은 이 계약만 본다.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth.dart';

abstract class TokenStore {
  /// 저장된 토큰. 없으면 null.
  Future<AuthTokens?> read();

  Future<void> write(AuthTokens tokens);

  Future<void> clear();
}

class PreferencesTokenStore implements TokenStore {
  const PreferencesTokenStore();

  static const _accessKey = 'auth.accessToken';
  static const _refreshKey = 'auth.refreshToken';

  @override
  Future<AuthTokens?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_accessKey) ?? '';
    if (access.trim().isEmpty) return null;
    return AuthTokens(
      accessToken: access,
      refreshToken: prefs.getString(_refreshKey) ?? '',
    );
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, tokens.accessToken);
    await prefs.setString(_refreshKey, tokens.refreshToken);
  }

  @override
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}

/// 메모리에만 두는 구현. 단위 테스트와, 저장소를 못 쓰는 상황의 대체용이다.
class MemoryTokenStore implements TokenStore {
  MemoryTokenStore([this._tokens]);

  AuthTokens? _tokens;

  @override
  Future<AuthTokens?> read() async => _tokens;

  @override
  Future<void> write(AuthTokens tokens) async => _tokens = tokens;

  @override
  Future<void> clear() async => _tokens = null;
}
