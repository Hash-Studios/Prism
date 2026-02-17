import 'dart:convert';

enum FirestoreFilterOp {
  isEqualTo,
  isNotEqualTo,
  isLessThan,
  isLessThanOrEqualTo,
  isGreaterThan,
  isGreaterThanOrEqualTo,
  arrayContains,
  arrayContainsAny,
  whereIn,
  whereNotIn,
  isNull,
}

enum FirestoreCachePolicy {
  networkOnly,
  staleWhileRevalidate,
  memoryFirst,
}

class FirestoreFilter {
  const FirestoreFilter({
    required this.field,
    required this.op,
    this.value,
  });

  final String field;
  final FirestoreFilterOp op;
  final Object? value;

  Map<String, Object?> toJson() => <String, Object?>{
        'field': field,
        'op': op.name,
        'value': value,
      };
}

class FirestoreOrderBy {
  const FirestoreOrderBy({
    required this.field,
    this.descending = false,
  });

  final String field;
  final bool descending;

  Map<String, Object?> toJson() => <String, Object?>{
        'field': field,
        'descending': descending,
      };
}

class FirestoreQuerySpec {
  const FirestoreQuerySpec({
    required this.collection,
    required this.sourceTag,
    this.filters = const <FirestoreFilter>[],
    this.orderBy = const <FirestoreOrderBy>[],
    this.limit,
    this.startAfterDocId,
    this.startAfterFieldValues,
    this.isStream = false,
    this.cachePolicy = FirestoreCachePolicy.networkOnly,
    this.dedupeWindowMs = 0,
  });

  final String collection;
  final String sourceTag;
  final List<FirestoreFilter> filters;
  final List<FirestoreOrderBy> orderBy;
  final int? limit;
  final String? startAfterDocId;
  final List<Object?>? startAfterFieldValues;
  final bool isStream;
  final FirestoreCachePolicy cachePolicy;
  final int dedupeWindowMs;

  Map<String, Object?> toJson() => <String, Object?>{
        'collection': collection,
        'sourceTag': sourceTag,
        'filters': filters.map((f) => f.toJson()).toList(growable: false),
        'orderBy': orderBy.map((o) => o.toJson()).toList(growable: false),
        'limit': limit,
        'startAfterDocId': startAfterDocId,
        'startAfterFieldValues': startAfterFieldValues,
        'isStream': isStream,
        'cachePolicy': cachePolicy.name,
        'dedupeWindowMs': dedupeWindowMs,
      };

  String get filtersHash => base64Url.encode(utf8.encode(jsonEncode(toJson())));
}
