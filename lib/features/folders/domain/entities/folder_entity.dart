import 'dart:math' as math;

import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';

const int folderNameMaxLength = 50;
const int folderMaxCovers = 4;

/// One of the user's private folders, `folders/{id}`.
class FolderEntity {
  const FolderEntity({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.itemCount,
    required this.covers,
  });

  final String id;
  final String ownerId;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;

  /// Up to [folderMaxCovers] thumbnail URLs, newest first.
  final List<String> covers;

  FolderEntity copyWith({String? name, DateTime? updatedAt, int? itemCount, List<String>? covers}) => FolderEntity(
    id: id,
    ownerId: ownerId,
    name: name ?? this.name,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    itemCount: itemCount ?? this.itemCount,
    covers: covers ?? this.covers,
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
