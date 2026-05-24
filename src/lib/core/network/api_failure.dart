class ApiFailure implements Exception {
  const ApiFailure(this.message, {this.statusCode, this.traceId});

  final String message;
  final int? statusCode;
  final String? traceId;

  @override
  String toString() => message;
}
