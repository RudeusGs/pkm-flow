import 'package:dio/dio.dart';

import '../network/api_result.dart';
import 'failure.dart';

class ErrorMapper {
  const ErrorMapper._();

  static Failure fromApiResult(ApiResult<Object?> result) {
    return Failure(
      type: _typeFromStatusCode(result.statusCode),
      message: _messageFromApiResult(result),
      statusCode: result.statusCode,
      code: result.error?.code,
      details: result.error?.details ?? const <String>[],
      traceId: result.traceId,
    );
  }

  static Failure fromDioException(DioException exception) {
    switch (exception.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const Failure(
          type: FailureType.timeout,
          message: 'Kết nối quá thời gian. Vui lòng thử lại.',
          statusCode: null,
        );

      case DioExceptionType.cancel:
        return const Failure(
          type: FailureType.cancelled,
          message: 'Yêu cầu đã bị hủy.',
          statusCode: null,
        );

      case DioExceptionType.connectionError:
        return const Failure(
          type: FailureType.network,
          message: 'Không thể kết nối tới máy chủ.',
          statusCode: null,
        );

      case DioExceptionType.badResponse:
        return Failure(
          type: _typeFromStatusCode(exception.response?.statusCode),
          message: 'Máy chủ trả về lỗi.',
          statusCode: exception.response?.statusCode,
        );

      case DioExceptionType.badCertificate:
        return const Failure(
          type: FailureType.network,
          message: 'Chứng chỉ HTTPS không hợp lệ.',
          statusCode: null,
        );

      case DioExceptionType.unknown:
        return Failure(
          type: FailureType.unknown,
          message: exception.message ?? 'Đã xảy ra lỗi không xác định.',
          statusCode: exception.response?.statusCode,
        );
    }
  }

  static Failure fromUnknown(Object error) {
    return Failure(
      type: FailureType.unknown,
      message: error.toString(),
      statusCode: null,
    );
  }

  static FailureType _typeFromStatusCode(int? statusCode) {
    switch (statusCode) {
      case 400:
        return FailureType.validation;
      case 401:
        return FailureType.unauthorized;
      case 403:
        return FailureType.forbidden;
      case 404:
        return FailureType.notFound;
      case 409:
        return FailureType.conflict;
      case 422:
        return FailureType.unprocessable;
      case 500:
        return FailureType.server;
      default:
        if (statusCode != null && statusCode >= 500) {
          return FailureType.server;
        }
        return FailureType.unknown;
    }
  }

  static String _messageFromApiResult(ApiResult<Object?> result) {
    if (result.message != null && result.message!.trim().isNotEmpty) {
      return result.message!;
    }

    final details = result.error?.details ?? const <String>[];
    if (details.isNotEmpty) {
      return details.first;
    }

    switch (result.statusCode) {
      case 400:
        return 'Dữ liệu không hợp lệ.';
      case 401:
        return 'Bạn cần đăng nhập để tiếp tục.';
      case 403:
        return 'Bạn không có quyền thực hiện thao tác này.';
      case 404:
        return 'Không tìm thấy dữ liệu.';
      case 409:
        return 'Dữ liệu đã bị thay đổi. Vui lòng tải lại.';
      case 422:
        return 'Dữ liệu không thỏa mãn quy tắc hệ thống.';
      default:
        return 'Đã xảy ra lỗi. Vui lòng thử lại.';
    }
  }
}