import '../config/app_config.dart';

String? resolveImageUrl(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return null;
  final lower = raw.toLowerCase();
  if (lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('data:') || lower.startsWith('blob:')) return raw;

  var apiBase = AppConfig.normalizedApiBaseUrl;
  while (apiBase.endsWith('/')) {
    apiBase = apiBase.substring(0, apiBase.length - 1);
  }
  apiBase = apiBase.replaceFirst(RegExp(r'/api/v\d+$', caseSensitive: false), '');
  apiBase = apiBase.replaceFirst(RegExp(r'/api$', caseSensitive: false), '');

  if (raw.startsWith('/')) return '$apiBase$raw';
  return '$apiBase/$raw';
}
