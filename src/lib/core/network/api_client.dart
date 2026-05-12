import 'package:dio/dio.dart';

import '../auth/auth_token_store.dart';
import '../config/app_config.dart';
import '../error/error_mapper.dart';
import '../error/failure.dart';
import 'api_result.dart';
import 'auth_interceptor.dart';
import 'failure_exception.dart';

class ApiClient {
  ApiClient._(this._dio);

  final Dio _dio;

  factory ApiClient.create({
    required AuthTokenStore tokenStore,
    Future<void> Function()? onUnauthorized,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        sendTimeout: AppConfig.sendTimeout,
        responseType: ResponseType.json,

        /// Cho phép nhận cả 400/401/403/409/422 để tự parse ApiResult lỗi.
        validateStatus: (_) => true,
      ),
    );

    dio.interceptors.add(
      AuthInterceptor(
        tokenStore: tokenStore,
        onUnauthorized: onUnauthorized,
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
      ),
    );

    return ApiClient._(dio);
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.get<Object?>(
        path,
        queryParameters: queryParameters,
      );

      return _handleResponse<T>(response, fromJson);
    } on DioException catch (error) {
      throw FailureException(ErrorMapper.fromDioException(error));
    } catch (error) {
      if (error is FailureException) rethrow;
      throw FailureException(ErrorMapper.fromUnknown(error));
    }
  }

  Future<T> post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
      );

      return _handleResponse<T>(response, fromJson);
    } on DioException catch (error) {
      throw FailureException(ErrorMapper.fromDioException(error));
    } catch (error) {
      if (error is FailureException) rethrow;
      throw FailureException(ErrorMapper.fromUnknown(error));
    }
  }

  Future<T> put<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.put<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
      );

      return _handleResponse<T>(response, fromJson);
    } on DioException catch (error) {
      throw FailureException(ErrorMapper.fromDioException(error));
    } catch (error) {
      if (error is FailureException) rethrow;
      throw FailureException(ErrorMapper.fromUnknown(error));
    }
  }

  Future<T> patch<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.patch<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
      );

      return _handleResponse<T>(response, fromJson);
    } on DioException catch (error) {
      throw FailureException(ErrorMapper.fromDioException(error));
    } catch (error) {
      if (error is FailureException) rethrow;
      throw FailureException(ErrorMapper.fromUnknown(error));
    }
  }

  Future<T> delete<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
    required T Function(Object? json) fromJson,
  }) async {
    try {
      final response = await _dio.delete<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );

      return _handleResponse<T>(response, fromJson);
    } on DioException catch (error) {
      throw FailureException(ErrorMapper.fromDioException(error));
    } catch (error) {
      if (error is FailureException) rethrow;
      throw FailureException(ErrorMapper.fromUnknown(error));
    }
  }

  Future<void> deleteNoData(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? headers,
  }) async {
    try {
      final response = await _dio.delete<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
        options: Options(headers: headers),
      );

      _handleNoDataResponse(response);
    } on DioException catch (error) {
      throw FailureException(ErrorMapper.fromDioException(error));
    } catch (error) {
      if (error is FailureException) rethrow;
      throw FailureException(ErrorMapper.fromUnknown(error));
    }
  }

  Future<void> postNoData(
    String path, {
    Object? body,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dio.post<Object?>(
        path,
        data: body,
        queryParameters: queryParameters,
      );

      _handleNoDataResponse(response);
    } on DioException catch (error) {
      throw FailureException(ErrorMapper.fromDioException(error));
    } catch (error) {
      if (error is FailureException) rethrow;
      throw FailureException(ErrorMapper.fromUnknown(error));
    }
  }

  T _handleResponse<T>(
    Response<Object?> response,
    T Function(Object? json) fromJson,
  ) {
    final body = response.data;

    if (body is! Map<String, dynamic>) {
      throw FailureException(
        Failure(
          type: FailureType.unknown,
          message: 'Response không đúng định dạng ApiResult.',
          statusCode: response.statusCode,
        ),
      );
    }

    final result = ApiResult<T>.fromJson(body, fromJson);

    if (!result.isSuccess) {
      final errorResult = ApiResult<Object?>.fromJson(body, (json) => json);
      throw FailureException(ErrorMapper.fromApiResult(errorResult));
    }

    if (result.data == null) {
      throw FailureException(
        Failure(
          type: FailureType.unknown,
          message: 'Response thành công nhưng data bị null.',
          statusCode: response.statusCode,
          traceId: result.traceId,
        ),
      );
    }

    return result.data as T;
  }

  void _handleNoDataResponse(Response<Object?> response) {
    final body = response.data;

    if (body is! Map<String, dynamic>) {
      throw FailureException(
        Failure(
          type: FailureType.unknown,
          message: 'Response không đúng định dạng ApiResult.',
          statusCode: response.statusCode,
        ),
      );
    }

    final result = ApiResult<Object?>.fromJson(body, (json) => json);

    if (!result.isSuccess) {
      throw FailureException(ErrorMapper.fromApiResult(result));
    }
  }
}