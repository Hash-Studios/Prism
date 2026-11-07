import 'package:Prism/features/folders/domain/entities/folder_section.dart';

/// One change a member makes to the sections of a folder.
sealed class FolderEdit {
  const FolderEdit();
}

final class SectionAdded extends FolderEdit {
  const SectionAdded({required this.id, required this.name});

  final String id;
  final String name;
}

final class SectionRenamed extends FolderEdit {
  const SectionRenamed({required this.id, required this.name});

  final String id;
  final String name;
}

/// The walls of the section go to Unsorted. Their items keep the old id, which no longer names a section.
final class SectionDeleted extends FolderEdit {
  const SectionDeleted(this.id);

  final String id;
}

final class SectionMoved extends FolderEdit {
  const SectionMoved({required this.id, required this.toIndex});

  final String id;
  final int toIndex;
}

enum WallMoveMethod { drag, menu }

/// [sectionId] null moves the walls to Unsorted.
final class WallsMoved extends FolderEdit {
  const WallsMoved({required this.itemKeys, required this.sectionId, required this.method});

  final List<String> itemKeys;
  final String? sectionId;
  final WallMoveMethod method;
}

/// One accepted suggestion. [sectionId] is an existing section with the same name, or the id for a new one.
class AcceptedGroup {
  const AcceptedGroup({required this.sectionId, required this.name, required this.itemKeys});

  final String sectionId;
  final String name;
  final List<String> itemKeys;
}

final class SuggestionsAccepted extends FolderEdit {
  const SuggestionsAccepted(this.groups);

  final List<AcceptedGroup> groups;
}

/// What an edit writes. [sections] is null when the section list does not change. [moves] maps an item key to its
/// new section id, or to null for Unsorted.
class FolderEditResult {
  const FolderEditResult({required this.sections, required this.moves});

  final List<FolderSection>? sections;
  final Map<String, String?> moves;
}

/// Applies [edit] to a folder with [sections] and walls [sectionOf] (item key to section id). Null when the edit is
/// not valid: a bad name, an unknown section, a wall not in the folder, or more than [folderMaxSections] sections.
FolderEditResult? applyFolderEdit(List<FolderSection> sections, Map<String, String?> sectionOf, FolderEdit edit) {
  int indexOf(String id) => sections.indexWhere((section) => section.id == id);
  switch (edit) {
    case SectionAdded(:final id, :final name):
      final String? clean = normalizeSectionName(name);
      if (clean == null || !isFolderSectionId(id) || indexOf(id) >= 0 || sections.length >= folderMaxSections) {
        return null;
      }
      return FolderEditResult(
        sections: <FolderSection>[
          ...sections,
          FolderSection(id: id, name: clean),
        ],
        moves: {},
      );
    case SectionRenamed(:final id, :final name):
      final String? clean = normalizeSectionName(name);
      final int index = indexOf(id);
      if (clean == null || index < 0) return null;
      if (sections[index].name == clean) return const FolderEditResult(sections: null, moves: {});
      return FolderEditResult(
        sections: <FolderSection>[
          for (final s in sections)
            if (s.id == id) s.rename(clean) else s,
        ],
        moves: const {},
      );
    case SectionDeleted(:final id):
      if (indexOf(id) < 0) return null;
      return FolderEditResult(sections: sections.where((s) => s.id != id).toList(), moves: const {});
    case SectionMoved(:final id, :final toIndex):
      final int index = indexOf(id);
      if (index < 0) return null;
      final int target = toIndex.clamp(0, sections.length - 1);
      if (target == index) return const FolderEditResult(sections: null, moves: {});
      return FolderEditResult(sections: moveEntry(sections, index, target), moves: const {});
    case WallsMoved(:final itemKeys, :final sectionId):
      if (sectionId != null && indexOf(sectionId) < 0) return null;
      if (itemKeys.isEmpty || itemKeys.any((key) => !sectionOf.containsKey(key))) return null;
      return FolderEditResult(
        sections: null,
        moves: <String, String?>{
          for (final String key in itemKeys)
            if (_current(sections, sectionOf[key]) != sectionId) key: sectionId,
        },
      );
    case SuggestionsAccepted(:final groups):
      final List<FolderSection> next = List<FolderSection>.of(sections);
      final Map<String, String?> moves = <String, String?>{};
      for (final AcceptedGroup group in groups) {
        if (indexOf(group.sectionId) < 0 && next.every((s) => s.id != group.sectionId)) {
          final String? clean = normalizeSectionName(group.name);
          if (clean == null || !isFolderSectionId(group.sectionId)) return null;
          next.add(FolderSection(id: group.sectionId, name: clean));
        }
        for (final String key in group.itemKeys) {
          if (!sectionOf.containsKey(key)) return null;
          moves[key] = group.sectionId;
        }
      }
      if (next.length > folderMaxSections) return null;
      return FolderEditResult(sections: next.length == sections.length ? null : next, moves: moves);
  }
}

/// The section a wall is in. A section that no longer exists reads as Unsorted.
String? _current(List<FolderSection> sections, String? sectionId) =>
    sectionId != null && sections.any((section) => section.id == sectionId) ? sectionId : null;
