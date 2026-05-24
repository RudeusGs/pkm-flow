typedef JsonMap = Map<String, dynamic>;

String asString(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  final text = value?.toString().toLowerCase();
  if (text == 'true') return true;
  if (text == 'false') return false;
  return fallback;
}

JsonMap asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

List<JsonMap> asMapList(Object? value) {
  if (value is List) return value.map(asMap).toList();
  return const <JsonMap>[];
}

String lowerFirst(String value) {
  if (value.isEmpty) return value;
  return value.substring(0, 1).toLowerCase() + value.substring(1);
}

Object? normalizeJsonKeys(Object? value) {
  if (value is List) return value.map(normalizeJsonKeys).toList();
  if (value is Map) {
    return value.map((key, item) => MapEntry(lowerFirst(key.toString()), normalizeJsonKeys(item)));
  }
  return value;
}

JsonMap normalizedMap(Object? value) => asMap(normalizeJsonKeys(value));

List<T> parsePagedItems<T>(Object? value, T Function(JsonMap) fromJson) {
  final normalized = normalizeJsonKeys(value);
  if (normalized is List) return normalized.map((item) => fromJson(asMap(item))).toList();
  final map = asMap(normalized);
  final items = map['items'] ?? map['data'];
  if (items is List) return items.map((item) => fromJson(asMap(item))).toList();
  return <T>[];
}

String shortDate(Object? value) {
  final text = asString(value);
  if (text.isEmpty) return '';
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return text;
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}
