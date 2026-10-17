import 'dart:convert';

class GuestFavouritesCodec {
  const GuestFavouritesCodec._();

  static Map<String, Map<String, Object?>> decode(String encoded) {
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;
    return <String, Map<String, Object?>>{
      for (final entry in decoded.entries) entry.key: Map<String, Object?>.from(entry.value as Map),
    };
  }

  static String encode(Map<String, Map<String, Object?>> items) => jsonEncode(items);
}
