class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://localhost:7286/api/v1',
  );

  static String get normalizedApiBaseUrl {
    var base = apiBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    return '$base/';
  }

  static String get collaborationHubUrl {
    var base = apiBaseUrl.trim();
    while (base.endsWith('/')) {
      base = base.substring(0, base.length - 1);
    }
    base = base.replaceFirst(RegExp(r'/api/v\d+$', caseSensitive: false), '');
    base = base.replaceFirst(RegExp(r'/api$', caseSensitive: false), '');
    return '$base/hubs/collaboration';
  }
}
