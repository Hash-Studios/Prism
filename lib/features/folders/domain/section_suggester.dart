import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';

enum SuggestionKind { mood, category, colour }

/// The wall fields that suggestions group by.
class WallTraits {
  const WallTraits({this.moods = const <WallMood>[], this.category = '', this.colours = const <String>[]});

  /// In the order of the server's mood rules.
  final List<WallMood> moods;
  final String category;

  /// Palette ids, most dominant first.
  final List<String> colours;

  /// The group key for [kind], or null when the wall has no value. "General" is the default category, so it is not a
  /// group.
  String? keyFor(SuggestionKind kind) => switch (kind) {
    SuggestionKind.mood => moods.firstOrNull?.id,
    SuggestionKind.category => category.isEmpty || category.toLowerCase() == 'general' ? null : category,
    SuggestionKind.colour => colours.firstOrNull,
  };
}

/// One proposed section. [existingSectionId] is set when a section with the same name exists, so its walls join it.
class SectionSuggestion {
  const SectionSuggestion({required this.key, required this.name, required this.itemKeys, this.existingSectionId});

  final String key;
  final String name;

  /// Newest first. The first wall is the cover.
  final List<String> itemKeys;
  final String? existingSectionId;
}

/// A group needs at least this many walls. One wall is not a section worth making.
const int minSuggestedGroup = 2;

/// Groups [itemKeys] (newest first) by [kind]. Walls with no value, and groups below [minSuggestedGroup], stay
/// out. Larger groups come first. New sections stop at [folderMaxSections]; groups that join an existing section by
/// name always fit.
List<SectionSuggestion> suggestSections({
  required SuggestionKind kind,
  required List<String> itemKeys,
  required Map<String, WallTraits> traits,
  required List<FolderSection> sections,
  required String Function(String key) nameOf,
}) {
  final Map<String, List<String>> groups = <String, List<String>>{};
  for (final String itemKey in itemKeys) {
    final String? key = traits[itemKey]?.keyFor(kind);
    if (key != null) (groups[key] ??= <String>[]).add(itemKey);
  }
  final List<MapEntry<String, List<String>>> ranked =
      groups.entries.where((entry) => entry.value.length >= minSuggestedGroup).toList()
        ..sort((a, b) => b.value.length.compareTo(a.value.length));
  int freeSlots = folderMaxSections - sections.length;
  final List<SectionSuggestion> suggestions = <SectionSuggestion>[];
  for (final MapEntry<String, List<String>> entry in ranked) {
    final String? name = normalizeSectionName(nameOf(entry.key));
    if (name == null) continue;
    final String? existing = sections
        .where((section) => section.name.toLowerCase() == name.toLowerCase())
        .firstOrNull
        ?.id;
    if (existing == null) {
      if (freeSlots == 0) continue;
      freeSlots--;
    }
    suggestions.add(SectionSuggestion(key: entry.key, name: name, itemKeys: entry.value, existingSectionId: existing));
  }
  return suggestions;
}

/// The kind that sorts the most walls. Ties go to mood, then category, then colour.
SuggestionKind bestSuggestionKind(Map<SuggestionKind, List<SectionSuggestion>> byKind) {
  int sorted(SuggestionKind kind) =>
      (byKind[kind] ?? const <SectionSuggestion>[]).fold(0, (sum, group) => sum + group.itemKeys.length);
  return SuggestionKind.values.reduce((best, kind) => sorted(kind) > sorted(best) ? kind : best);
}
