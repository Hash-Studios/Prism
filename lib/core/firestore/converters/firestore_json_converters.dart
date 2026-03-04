import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

class FirestoreDateTimeConverter implements JsonConverter<DateTime?, Object?> {
  const FirestoreDateTimeConverter();

  @override
  DateTime? fromJson(Object? json) {
    if (json == null) return null;
    if (json is DateTime) return json;
    if (json is Timestamp) return json.toDate();
    if (json is String) return DateTime.tryParse(json);
    if (json is int) return DateTime.fromMillisecondsSinceEpoch(json, isUtc: true);
    return null;
  }

  @override
  Object? toJson(DateTime? object) => object;
}

class FirestoreStringConverter implements JsonConverter<String, Object?> {
  const FirestoreStringConverter();

  @override
  String fromJson(Object? json) {
    if (json == null) return '';
    if (json is String) return json;
    if (json is List) return jsonEncode(json);
    return json.toString();
  }

  @override
  Object? toJson(String object) => object;
}

class FirestoreStringListConverter implements JsonConverter<List<String>, Object?> {
  const FirestoreStringListConverter();

  @override
  List<String> fromJson(Object? json) {
    if (json is! List) return const <String>[];
    return json.map((item) => item?.toString() ?? '').where((item) => item.isNotEmpty).toList(growable: false);
  }

  @override
  Object? toJson(List<String> object) => object;
}

class FirestoreStringMapConverter implements JsonConverter<Map<String, String>, Object?> {
  const FirestoreStringMapConverter();

  @override
  Map<String, String> fromJson(Object? json) {
    if (json is! Map) return const <String, String>{};
    final Map<String, String> result = <String, String>{};
    for (final MapEntry<Object?, Object?> entry in json.entries) {
      final String key = entry.key?.toString() ?? '';
      if (key.isEmpty || entry.value == null) {
        continue;
      }
      result[key] = entry.value.toString();
    }
    return result;
  }

  @override
  Object? toJson(Map<String, String> object) => object;
}

class FirestoreJsonMapConverter implements JsonConverter<Map<String, Object?>, Object?> {
  const FirestoreJsonMapConverter();

  @override
  Map<String, Object?> fromJson(Object? json) {
    if (json is! Map) return const <String, Object?>{};
    final Map<String, Object?> result = <String, Object?>{};
    for (final MapEntry<Object?, Object?> entry in json.entries) {
      final String key = entry.key?.toString() ?? '';
      if (key.isEmpty) {
        continue;
      }
      result[key] = entry.value;
    }
    return result;
  }

  @override
  Object? toJson(Map<String, Object?> object) => object;
}
