import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/auth_token.dart';
import '../../features/auth/domain/auth_user.dart';
import '../utils/json_utils.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessToken = 'bb_access_token';
  static const _refreshToken = 'bb_refresh_token';
  static const _tokenType = 'bb_token_type';
  static const _userJson = 'bb_user_json';

  Future<void> save(AuthToken token) async {
    await _storage.write(key: _accessToken, value: token.accessToken);
    await _storage.write(key: _refreshToken, value: token.refreshToken);
    await _storage.write(key: _tokenType, value: token.tokenType.isEmpty ? 'Bearer' : token.tokenType);
    await _storage.write(key: _userJson, value: jsonEncode(token.user.toJson()));
  }

  Future<void> saveUser(AuthUser user) async {
    await _storage.write(key: _userJson, value: jsonEncode(user.toJson()));
  }

  Future<String?> readAccessToken() => _storage.read(key: _accessToken);
  Future<String?> readRefreshToken() => _storage.read(key: _refreshToken);
  Future<String> readTokenType() async => await _storage.read(key: _tokenType) ?? 'Bearer';

  Future<AuthUser?> readUser() async {
    final raw = await _storage.read(key: _userJson);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      return AuthUser.fromJson(asMap(jsonDecode(raw)));
    } catch (_) {
      return null;
    }
  }

  Future<bool> hasToken() async {
    final token = await readAccessToken();
    return token != null && token.trim().isNotEmpty;
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessToken);
    await _storage.delete(key: _refreshToken);
    await _storage.delete(key: _tokenType);
    await _storage.delete(key: _userJson);
  }
}
