import '../../../core/network/api_client.dart';
import '../../../core/storage/auth_token_store.dart';
import '../../../core/utils/json_utils.dart';
import '../domain/auth_token.dart';
import '../domain/auth_user.dart';

class AuthRepository {
  const AuthRepository(
      {required ApiClient apiClient, required AuthTokenStore tokenStore})
      : _apiClient = apiClient,
        _tokenStore = tokenStore;

  final ApiClient _apiClient;
  final AuthTokenStore _tokenStore;

  Future<AuthToken> login(String userName, String password) async {
    final token = await _apiClient.post<AuthToken>(
      'auth/login',
      data: {'userName': userName, 'password': password},
      parser: (json) => AuthToken.fromJson(asMap(json)),
    );
    await _tokenStore.save(token);
    return token;
  }

  Future<AuthUser> register({
    required String userName,
    required String email,
    required String fullName,
    required String password,
  }) {
    return _apiClient.post<AuthUser>(
      'auth/register',
      data: {
        'userName': userName,
        'email': email,
        'fullName': fullName,
        'password': password
      },
      parser: (json) => AuthUser.fromJson(asMap(json)),
    );
  }

  Future<AuthUser> me() => _apiClient.get<AuthUser>('me',
      parser: (json) => AuthUser.fromJson(asMap(json)));

  Future<AuthUser> updateProfile(
      {required String fullName, String? avatarUrl}) {
    return _apiClient
        .patch<AuthUser>(
      'me/profile',
      data: {'fullName': fullName, 'avatarUrl': avatarUrl},
      parser: (json) => AuthUser.fromJson(asMap(json)),
    )
        .then((user) async {
      await _tokenStore.saveUser(user);
      return user;
    });
  }

  Future<void> logout() async {
    final refresh = await _tokenStore.readRefreshToken();
    if (refresh != null && refresh.trim().isNotEmpty) {
      try {
        await _apiClient.post<void>('auth/logout',
            data: {'refreshToken': refresh}, parser: (_) {});
      } catch (_) {}
    }
    await _tokenStore.clear();
  }

  Future<AuthUser?> cachedUser() => _tokenStore.readUser();
  Future<bool> hasToken() => _tokenStore.hasToken();
}
