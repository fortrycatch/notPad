import 'dart:convert';

Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Expected object, got ${value.runtimeType}');
}

Map<String, dynamic> asMeta(Object? value) {
  if (value == null) return const {};
  if (value is Map) return asMap(value);
  if (value is String && value.isNotEmpty) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return asMap(decoded);
    } catch (_) {}
  }
  return const {};
}

List<T> asList<T>(Object? value, T Function(Object?) map) {
  if (value is! List) return const [];
  return value.map(map).toList();
}

String asString(Object? value, [String fallback = '']) {
  if (value == null) return fallback;
  return value.toString();
}

int asInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double asDouble(Object? value, [double fallback = 0]) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return fallback;
}

DateTime asDate(Object? value) {
  if (value is DateTime) return value;
  if (value == null) return DateTime.fromMillisecondsSinceEpoch(0);
  return DateTime.tryParse(value.toString()) ??
      DateTime.fromMillisecondsSinceEpoch(0);
}

String? asStringOrNull(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}
