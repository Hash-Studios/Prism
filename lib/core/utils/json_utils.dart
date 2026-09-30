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

/// Converts [value] into something [jsonEncode] accepts: primitives pass through,
/// dates become UTC ISO strings, enums their name, collections recurse, the rest [Object.toString].
/// The map entries of a JSON list, each as [Map<String, dynamic>]. Returns an
/// empty list if value is not a List.
List<Map<String, dynamic>> toJsonMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value.whereType<Map>().map(_toMap).toList(growable: false);
}

Object? toJsonSafe(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return value;
  }
  if (value is DateTime) {
    return value.toUtc().toIso8601String();
  }
  if (value is Enum) {
    return value.name;
  }
  if (value is Iterable) {
    return value.map(toJsonSafe).toList(growable: false);
  }
  if (value is Map) {
    return value.map<String, Object?>((key, nested) => MapEntry(key.toString(), toJsonSafe(nested)));
  }
  return value.toString();
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
