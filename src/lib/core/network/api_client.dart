import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../storage/auth_token_store.dart';
import '../utils/json_utils.dart';
import 'api_failure.dart';

class ApiClient {
  ApiClient({required this.tokenStore}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.normalizedApiBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        responseType: ResponseType.json,
        validateStatus: (_) => true,
        headers: const {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await tokenStore.readAccessToken();
          if (token != null && token.trim().isNotEmpty) {
            final type = await tokenStore.readTokenType();
            options.headers['Authorization'] = '$type $token';
          }
          handler.next(options);
        },
        onResponse: (response, handler) async {
          if (response.statusCode == 401) {
            await tokenStore.clear();
          }
          handler.next(response);
        },
      ),
    );
  }

  final AuthTokenStore tokenStore;
  late final Dio _dio;

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required T Function(Object? json) parser,
  }) {
    return request<T>('GET', path, query: query, parser: parser);
  }

  Future<T> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    required T Function(Object? json) parser,
  }) {
    return request<T>(
      'POST',
      path,
      data: data,
      query: query,
      parser: parser,
    );
  }

  Future<T> put<T>(
    String path, {
    Object? data,
    required T Function(Object? json) parser,
  }) {
    return request<T>('PUT', path, data: data, parser: parser);
  }

  Future<T> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    required T Function(Object? json) parser,
  }) {
    return request<T>(
      'PATCH',
      path,
      data: data,
      query: query,
      parser: parser,
    );
  }

  Future<T> delete<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    required T Function(Object? json) parser,
  }) {
    return request<T>(
      'DELETE',
      path,
      query: query,
      headers: headers,
      parser: parser,
    );
  }

  Future<T> postForm<T>(
    String path, {
    required FormData formData,
    Map<String, dynamic>? query,
    required T Function(Object? json) parser,
  }) async {
    return request<T>(
      'POST',
      path,
      data: formData,
      query: query,
      parser: parser,
    );
  }

  Future<T> request<T>(
    String method,
    String path, {
    Object? data,
    Map<String, dynamic>? query,
    Map<String, dynamic>? headers,
    required T Function(Object? json) parser,
  }) async {
    try {
      final response = await _dio.request<Object?>(
        _endpoint(path),
        data: data,
        queryParameters: _cleanQuery(query),
        options: Options(method: method, headers: headers),
      );

      final status = response.statusCode ?? 0;
      final body = normalizeJsonKeys(response.data);
      if (status >= 400) {
        throw ApiFailure(
          _friendlyMessage(status, body, 'Không thao tác được.'),
          statusCode: status,
        );
      }

      final map = body is Map ? asMap(body) : <String, dynamic>{};
      final isApiResult = map.containsKey('isSuccess') ||
          map.containsKey('statusCode') ||
          map.containsKey('traceId');
      if (isApiResult) {
        final ok = asBool(map['isSuccess']);
        if (!ok) {
          final resultStatus = asInt(map['statusCode'], status);
          throw ApiFailure(
            _friendlyMessage(resultStatus, map, 'Không thao tác được.'),
            statusCode: resultStatus,
            traceId: asString(map['traceId'], ''),
          );
        }
        return parser(map['data']);
      }

      return parser(body);
    } on DioException catch (_) {
      throw const ApiFailure('Không kết nối được server.');
    }
  }

  String _endpoint(String path) =>
      path.startsWith('/') ? path.substring(1) : path;

  Map<String, dynamic>? _cleanQuery(Map<String, dynamic>? query) {
    if (query == null) return null;
    final cleaned = <String, dynamic>{};
    query.forEach((key, value) {
      if (value != null && value.toString().trim().isNotEmpty) {
        cleaned[key] = value;
      }
    });
    return cleaned;
  }

  String _friendlyMessage(int statusCode, Object? body, String fallback) {
    if (statusCode == 401) return 'Bạn cần đăng nhập lại.';
    if (statusCode == 403) return 'Không có quyền thực hiện thao tác này.';
    if (statusCode == 404) return 'Không tìm thấy dữ liệu.';
    if (statusCode == 409) return 'Không thao tác được.';
    if (statusCode >= 500) return 'Server đang bận, thử lại sau.';

    return _sanitizeMessage(_extractMessage(body, fallback), fallback);
  }

  String _sanitizeMessage(String message, String fallback) {
    final text = message.trim();
    if (text.isEmpty) return fallback;

    final lower = text.toLowerCase();
    if (lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('workspace.forbidden') ||
        lower.contains('task.forbidden') ||
        lower.contains('comment.createforbidden') ||
        lower.contains('không có quyền')) {
      return 'Không có quyền thực hiện thao tác này.';
    }

    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Bạn cần đăng nhập lại.';
    }

    if (lower.contains('exception') ||
        lower.contains('traceid') ||
        lower.contains('status code')) {
      return fallback;
    }

    return text;
  }

  String _extractMessage(Object? body, String fallback) {
    final map = asMap(body);
    final direct = map['message'] ?? map['title'] ?? map['error'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString();
    }

    final error = asMap(map['error']);
    final details = error['details'];
    if (details is List && details.isNotEmpty) {
      return details.map((item) => item.toString()).join('\n');
    }

    final code = asString(error['code']);
    return code.isEmpty ? fallback : code;
  }
}
