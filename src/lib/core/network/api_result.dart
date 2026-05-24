import 'api_error.dart';

typedef JsonParser<T> = T Function(Object? json);

class ApiResult<T> {
  const ApiResult({
    required this.isSuccess,
    required this.message,
    required this.data,
    required this.error,
    required this.statusCode,
    required this.traceId,
  });

  final bool isSuccess;
  final String? message;
  final T? data;
  final ApiError? error;
  final int statusCode;
  final String? traceId;

  factory ApiResult.fromJson(
    Map<String, dynamic> json,
    JsonParser<T> parser,
  ) {
    return ApiResult<T>(
      isSuccess: json['isSuccess'] == true,
      message: json['message']?.toString(),
      data: json['data'] == null ? null : parser(json['data']),
      error: json['error'] == null
          ? null
          : ApiError.fromJson(json['error'] as Map<String, dynamic>?),
      statusCode: json['statusCode'] is int
          ? json['statusCode'] as int
          : int.tryParse(json['statusCode']?.toString() ?? '') ?? 0,
      traceId: json['traceId']?.toString(),
    );
  }
}
