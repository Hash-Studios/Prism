import 'dart:math' as math;

import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

const int folderMaxSections = 20;
const int folderSectionNameMaxLength = 40;

/// The rules cap a name at this many UTF-16 units, because they cannot count graphemes.
const int folderSectionNameMaxUnits = 160;

final RegExp _sectionIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,32}$');

/// A named part of a folder. Its order is its position in [FolderEntity.sections], so two sections never share an
/// order. A section has no privacy and no items of its own: an item names its section with `sectionId`.
class FolderSection {
  const FolderSection({required this.id, required this.name});

  final String id;
  final String name;

  FolderSection rename(String name) => FolderSection(id: id, name: name);

  Map<String, String> toDoc() => <String, String>{'id': id, 'name': name};

  @override
  bool operator ==(Object other) => other is FolderSection && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);

  @override
  String toString() => 'FolderSection($id, $name)';
}

/// A folder wall and the section it names. Null, or a section that no longer exists, means Unsorted.
class FolderItem {
  const FolderItem(this.wall, {this.sectionId});

  final FavouriteWallEntity wall;
  final String? sectionId;
}

bool isFolderSectionId(Object? id) => id is String && _sectionIdPattern.hasMatch(id);

/// The trimmed name, or null when it is empty or longer than [folderSectionNameMaxLength] graphemes.
String? normalizeSectionName(String raw) {
  final String name = raw.trim();
  final int length = name.characters.length;
  if (length == 0 || length > folderSectionNameMaxLength || name.length > folderSectionNameMaxUnits) return null;
  return name;
}

/// The `sections` field of a folder doc. Malformed entries and repeated ids are skipped. At most [folderMaxSections].
List<FolderSection> folderSectionsFromDoc(Object? raw) {
  if (raw is! List) return const <FolderSection>[];
  final Set<String> seen = <String>{};
  return <FolderSection>[
    for (final Object? entry in raw)
      if (entry is Map && isFolderSectionId(entry['id']) && entry['name'] is String)
        if (normalizeSectionName(entry['name'] as String) case final String name)
          if (seen.add(entry['id'] as String)) FolderSection(id: entry['id'] as String, name: name),
  ].take(folderMaxSections).toList(growable: false);
}

String newSectionId([math.Random? random]) => newFolderId(random);

/// [list] with the entry at [from] moved so it ends at index [to]. Out-of-range indexes are clamped.
List<T> moveEntry<T>(List<T> list, int from, int to) {
  if (list.isEmpty || from < 0 || from >= list.length) return List<T>.of(list);
  final List<T> next = List<T>.of(list);
  final T entry = next.removeAt(from);
  next.insert(to.clamp(0, next.length), entry);
  return next;
}

/// One group of the folder page: Unsorted when [section] is null.
class FolderGroup {
  const FolderGroup({required this.section, required this.walls});

  final FolderSection? section;

  /// Newest first.
  final List<FavouriteWallEntity> walls;

  /// The section cover is its first wall.
  FavouriteWallEntity? get cover => walls.firstOrNull;

  String get key => section?.id ?? '';
}

/// Unsorted first, then each section in order. Each keeps the order of [walls]. A wall whose section is gone is in
/// Unsorted. Unsorted is left out when it is empty and [keepEmptyUnsorted] is false.
List<FolderGroup> folderGroups(
  List<FolderSection> sections,
  List<FavouriteWallEntity> walls,
  Map<String, String> sectionOf, {
  bool keepEmptyUnsorted = false,
}) {
  final Map<String, List<FavouriteWallEntity>> bySection = <String, List<FavouriteWallEntity>>{
    for (final FolderSection section in sections) section.id: <FavouriteWallEntity>[],
  };
  final List<FavouriteWallEntity> unsorted = <FavouriteWallEntity>[];
  for (final FavouriteWallEntity wall in walls) {
    (bySection[sectionOf[folderItemKey(wall)]] ?? unsorted).add(wall);
  }
  return <FolderGroup>[
    if (unsorted.isNotEmpty || keepEmptyUnsorted) FolderGroup(section: null, walls: unsorted),
    for (final FolderSection section in sections) FolderGroup(section: section, walls: bySection[section.id]!),
  ];
}
