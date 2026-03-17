import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Returns the first non-null value for the given keys in [map].
Object? firstPresent(JsonMap map, List<String> keys) {
  for (final String key in keys) {
    final Object? value = map[key];
    if (value != null) {
      return value;
    }
  }
  return null;
}

DateTime? parseDateTime(Object? v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) {
    final DateTime? parsed = DateTime.tryParse(v);
    if (parsed != null) return parsed;
  }
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  return null;
}

String parseString(Object? v, {String fallback = ''}) {
  if (v == null) return fallback;
  if (v is String) return v;
  return v.toString();
}

int? parseInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is double) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

T? parseEnum<T extends Enum>(Object? v, List<T> values) {
  if (v == null) return null;
  final String s = v.toString().toLowerCase().trim();
  for (final T entry in values) {
    if (entry.name.toLowerCase() == s) {
      return entry;
    }
  }
  return null;
}
