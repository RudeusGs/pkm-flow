import 'package:dio/dio.dart';

import '../auth/auth_token_store.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required AuthTokenStore tokenStore,
    Future<void> Function()? onUnauthorized,
  })  : _tokenStore = tokenStore,
        _onUnauthorized = onUnauthorized;

  final AuthTokenStore _tokenStore;
  final Future<void> Function()? _onUnauthorized;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await _tokenStore.getAccessToken();
    final tokenType = await _tokenStore.getTokenType();

    if (token != null && token.trim().isNotEmpty) {
      options.headers['Authorization'] = '$tokenType $token';
    }

    options.headers['Accept'] = 'application/json';
    options.headers['Content-Type'] = 'application/json';

    handler.next(options);
  }

  @override
  Future<void> onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) async {
    if (response.statusCode == 401) {
      await _tokenStore.clear();
      await _onUnauthorized?.call();
    }

    handler.next(response);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    if (err.response?.statusCode == 401) {
      await _tokenStore.clear();
      await _onUnauthorized?.call();
    }

    handler.next(err);
  }
}