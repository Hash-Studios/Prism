import 'dart:math' as math;

import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_member.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';

const int folderNameMaxLength = 50;
const int folderMaxCovers = 4;

/// A folder the user owns or edits, `folders/{id}`.
class FolderEntity {
  const FolderEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.itemCount,
    required this.covers,
    this.isPublic = false,
    this.editors = const <FolderMember>[],
    this.sections = const <FolderSection>[],
  });

  final String id;
  final String ownerId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;

  /// Up to [folderMaxCovers] thumbnail URLs, newest first.
  final List<String> covers;

  /// Others can see the folder. Only the server sets it, through the setFolderPublic callable.
  final bool isPublic;

  /// The people the owner invited, oldest first. Only the server sets them.
  final List<FolderMember> editors;

  /// The named parts of the folder, in order. The owner and the editors write them.
  final List<FolderSection> sections;

  bool isOwnedBy(String uid) => uid.isNotEmpty && uid == ownerId;

  /// Owner or editor. Null for anyone else.
  FolderRole? roleOf(String uid) => isOwnedBy(uid)
      ? FolderRole.owner
      : editors.any((member) => member.uid == uid)
      ? FolderRole.editor
      : null;

  /// The owner first, then the editors.
  List<FolderMember> get members => <FolderMember>[
    FolderMember(uid: ownerId, role: FolderRole.owner, addedBy: ownerId, addedAt: createdAt),
    ...editors,
  ];

  FolderEntity copyWith({
    String? name,
    DateTime? updatedAt,
    int? itemCount,
    List<String>? covers,
    bool? isPublic,
    List<FolderSection>? sections,
  }) => FolderEntity(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    itemCount: itemCount ?? this.itemCount,
    covers: covers ?? this.covers,
    isPublic: isPublic ?? this.isPublic,
    editors: editors,
    sections: sections ?? this.sections,
  );

  FolderEntity withItemAdded(String thumbnailUrl, DateTime at) => copyWith(
    updatedAt: at,
    itemCount: itemCount + 1,
    covers: <String>[thumbnailUrl, ...covers.where((url) => url != thumbnailUrl)].take(folderMaxCovers).toList(),
  );

  /// [newestRemaining] are the folder's newest items after the removal, newest first.
  FolderEntity withItemRemoved(List<String> newestRemaining, DateTime at) => copyWith(
    updatedAt: at,
    itemCount: math.max(0, itemCount - 1),
    covers: newestRemaining.toSet().take(folderMaxCovers).toList(),
  );
}

/// The item doc id. The provider is part of the key, so walls with the same id from two sources never collide.
String folderItemKey(FavouriteWallEntity wall) => '${wall.source.legacyProviderString.toLowerCase()}_${wall.id}';

/// The trimmed name, or null when it is empty or too long.
String? normalizeFolderName(String raw) {
  final String name = raw.trim();
  return name.isEmpty || name.length > folderNameMaxLength ? null : name;
}

/// A random 20 character id, the same shape as a Firestore auto id.
String newFolderId([math.Random? random]) {
  const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final math.Random rng = random ?? math.Random.secure();
  return String.fromCharCodes(List<int>.generate(20, (_) => chars.codeUnitAt(rng.nextInt(chars.length))));
}
