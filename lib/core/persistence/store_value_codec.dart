import 'dart:convert';

class StoreValueCodec {
  const StoreValueCodec._();

  static String encode(Object? value) {
    final envelope = <String, Object?>{'value': _jsonSafe(value)};
    return jsonEncode(envelope);
  }

  static Object? decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded.containsKey('value')) {
        return decoded['value'];
      }
      return decoded;
    } catch (_) {
      return raw;
    }
  }

  static Object? _jsonSafe(Object? value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    if (value is DateTime) {
      return value.toUtc().toIso8601String();
    }
    if (value is List) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    if (value is Map) {
      return value.map<String, Object?>((key, val) => MapEntry(key.toString(), _jsonSafe(val)));
    }
    return value.toString();
  }
}
