enum FailureType {
  validation,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  unprocessable,
  server,
  network,
  timeout,
  cancelled,
  unknown,
}

class Failure {
  const Failure({
    required this.type,
    required this.message,
    required this.statusCode,
    this.code,
    this.details = const <String>[],
    this.traceId,
  });

  final FailureType type;
  final String message;
  final int? statusCode;
  final String? code;
  final List<String> details;
  final String? traceId;

  bool get isUnauthorized => type == FailureType.unauthorized;
  bool get isConflict => type == FailureType.conflict;
  bool get isValidation => type == FailureType.validation;

  @override
  String toString() {
    return 'Failure(type: $type, message: $message, statusCode: $statusCode, code: $code, traceId: $traceId)';
  }
}
