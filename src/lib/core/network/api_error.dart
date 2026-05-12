class ApiError {
  const ApiError({
    required this.code,
    required this.type,
    required this.details,
  });

  final String code;
  final String type;
  final List<String> details;

  factory ApiError.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const ApiError(
        code: 'Unknown',
        type: 'unknown',
        details: <String>[],
      );
    }

    return ApiError(
      code: json['code']?.toString() ?? 'Unknown',
      type: json['type']?.toString() ?? 'unknown',
      details: (json['details'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          <String>[],
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'code': code,
      'type': type,
      'details': details,
    };
  }
}