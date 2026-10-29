import 'dart:convert';
import 'dart:math';

import 'package:collection/collection.dart';

String newWallMetadataOperationId() {
  final Random random = Random.secure();
  return base64UrlEncode(List<int>.generate(24, (_) => random.nextInt(256))).replaceAll('=', '');
}

/// Creator-editable text. Category is deliberately not part of an approved edit.
class WallTextMetadata {
  const WallTextMetadata({this.title = '', this.description = '', this.tags = const <String>[]});

  final String title;
  final String description;
  final List<String> tags;

  factory WallTextMetadata.fromMap(Map<String, dynamic> data) => WallTextMetadata(
    title: data['title'] is String ? data['title'] as String : '',
    description: data['desc'] is String ? data['desc'] as String : '',
    tags: data['tags'] is List ? (data['tags'] as List).whereType<String>().toList(growable: false) : const [],
  );

  Map<String, dynamic> toMap() => <String, dynamic>{'title': title, 'desc': description, 'tags': tags};

  @override
  bool operator ==(Object other) =>
      other is WallTextMetadata &&
      title == other.title &&
      description == other.description &&
      const ListEquality<String>().equals(tags, other.tags);

  @override
  int get hashCode => Object.hash(title, description, const ListEquality<String>().hash(tags));
}

class PendingWallMetadata {
  const PendingWallMetadata({required this.text, this.category = 'General'});

  final WallTextMetadata text;
  final String category;

  factory PendingWallMetadata.fromMap(Map<String, dynamic> data) => PendingWallMetadata(
    text: WallTextMetadata.fromMap(data),
    category: data['category'] is String ? data['category'] as String : 'General',
  );

  Map<String, dynamic> toMap() => <String, dynamic>{...text.toMap(), 'category': category};

  List<String> changedFields(PendingWallMetadata other, {required bool approved}) => <String>[
    if (text.title != other.text.title) 'title',
    if (text.description != other.text.description) 'desc',
    if (!const ListEquality<String>().equals(text.tags, other.text.tags)) 'tags',
    if (!approved && category != other.category) 'category',
  ];

  @override
  bool operator ==(Object other) => other is PendingWallMetadata && text == other.text && category == other.category;

  @override
  int get hashCode => Object.hash(text, category);
}

class WallMetadataSnapshot {
  const WallMetadataSnapshot({
    required this.metadata,
    required this.approved,
    this.revision = '',
    this.expectedPendingFields = const <String, dynamic>{},
  });

  final PendingWallMetadata metadata;
  final bool approved;
  final String revision;
  final Map<String, dynamic> expectedPendingFields;

  static Map<String, dynamic> pendingFields(Map<String, dynamic> data) => <String, dynamic>{
    for (final String key in const ['title', 'desc', 'tags', 'category'])
      if (data.containsKey(key)) key: data[key] is List ? List<Object?>.of(data[key] as List) : data[key],
  };
}

enum WallMetadataFailure { conflict, statusChanged, missing, denied, signedOut, invalid, dailyLimit, unavailable }

class WallMetadataException implements Exception {
  const WallMetadataException(this.failure);

  final WallMetadataFailure failure;

  @override
  String toString() => 'WallMetadataException(${failure.name})';
}

class WallMetadataAudit {
  const WallMetadataAudit({
    required this.id,
    required this.before,
    required this.after,
    required this.actorUid,
    this.createdAt,
    this.canRevert = false,
  });

  final String id;
  final Map<String, dynamic> before;
  final Map<String, dynamic> after;
  final String actorUid;
  final DateTime? createdAt;
  final bool canRevert;
}

class WallMetadataAuditPage {
  const WallMetadataAuditPage({required this.edits, this.cursor});

  final List<WallMetadataAudit> edits;
  final String? cursor;
}

class WallResubmissionContext {
  const WallResubmissionContext({required this.attempt, required this.previousReason});

  final int attempt;
  final String previousReason;
}
