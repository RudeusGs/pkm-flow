class AppConfig {
  const AppConfig._();

  /// Android emulator gọi localhost máy thật bằng 10.0.2.2
  /// Backend của bạn đang có http://localhost:5029 và https://localhost:7286.
  ///
  /// Khi chạy Android emulator:
  /// --dart-define=API_BASE_URL=http://10.0.2.2:5029
  ///
  /// Khi chạy iOS simulator:
  /// --dart-define=API_BASE_URL=http://localhost:5029
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5029',
  );

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);
}