import 'dart:convert';

import 'package:Prism/core/utils/json_utils.dart';

class StoreValueCodec {
  const StoreValueCodec._();

  static String encode(Object? value) {
    final envelope = <String, Object?>{'value': toJsonSafe(value)};
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
}
