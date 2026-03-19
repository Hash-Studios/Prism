import 'dart:convert';

/// Safely decodes JSON response body to [Map<String, dynamic>].
///
/// [jsonDecode] returns internal types like `_JsonMap` that are not a subtype
/// of [Map<String, dynamic>], causing type cast failures in release builds.
/// This recursively converts to proper [Map<String, dynamic>] and [List].
Map<String, dynamic> decodeJsonMap(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map) {
    throw FormatException('Expected JSON object', source);
  }
  return _toMap(decoded);
}

/// Recursively converts a Map from jsonDecode to [Map<String, dynamic>].
/// Use when reading cached JSON or any value that may be `_JsonMap`.
/// Returns empty map if value is null or not a Map.
Map<String, dynamic> toJsonMap(Object? value) {
  if (value == null) return <String, dynamic>{};
  if (value is Map) return _toMap(value);
  return <String, dynamic>{};
}

Map<String, dynamic> _toMap(Map map) {
  return map.map<String, dynamic>((key, value) {
    return MapEntry(key.toString(), _toJsonValue(value));
  });
}

Object? _toJsonValue(Object? value) {
  if (value == null) return null;
  if (value is Map) return _toMap(value);
  if (value is List) return value.map(_toJsonValue).toList();
  return value;
}
