import 'dart:convert';

import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/wall_mood_rules_data.dart';

/// The fields of a `walls` doc that the mood rules read.
class WallMoodFields {
  const WallMoodFields({
    this.colors = const <String>[],
    this.tags = const <String>[],
    this.visionLabels = const <String>[],
    this.collections = const <String>[],
    this.category = '',
    this.spatialTier = '',
    this.depthTier = '',
  });

  factory WallMoodFields.fromDoc(Map<String, Object?> data) {
    List<String> strings(Object? value) =>
        value is List ? value.whereType<String>().toList(growable: false) : const <String>[];
    String tier(Object? value) => value is Map && value['tier'] is String ? value['tier'] as String : '';
    return WallMoodFields(
      colors: strings(data['colors']),
      tags: strings(data['tags']),
      visionLabels: strings(data['visionLabels']),
      collections: strings(data['collections']),
      category: switch (data['category']) {
        final String category => category,
        _ => '',
      },
      spatialTier: tier(data['spatial']),
      depthTier: tier(data['depth']),
    );
  }

  final List<String> colors;
  final List<String> tags;
  final List<String> visionLabels;
  final List<String> collections;
  final String category;
  final String spatialTier;
  final String depthTier;
}

/// The moods of a wall, in the order of the server's `MOODS`. Unknown mood ids are skipped.
List<WallMood> wallMoodsOf(WallMoodFields wall) => <WallMood>[
  for (final Map<String, Object?> rule in _rules)
    if (WallMood.parse(rule['id']) case final WallMood mood when _matches(rule, wall)) mood,
];

final List<Map<String, Object?>> _rules = (jsonDecode(wallMoodRulesJson) as List<Object?>).cast<Map<String, Object?>>();

List<String>? _list(Map<String, Object?> rule, String key) => (rule[key] as List<Object?>?)?.cast<String>();

/// A Dart copy of `matchesMood` in functions/src/wallMoods.ts. True when the wall satisfies every field the rule sets.
bool _matches(Map<String, Object?> rule, WallMoodFields wall) {
  final List<String> colors = wall.colors;
  final List<String> tags = wall.tags.map((tag) => tag.trim().toLowerCase()).toList();
  final List<String> labels = wall.visionLabels.map((label) => label.toLowerCase()).toList();
  final List<String> collections = <String>[
    ...wall.collections.map((c) => c.trim().toLowerCase()),
    wall.category.toLowerCase(),
  ];
  final List<String>? anyTag = _list(rule, 'anyTag');
  if (anyTag != null && !tags.any(anyTag.contains)) return false;
  final List<String>? firstColour = _list(rule, 'firstColour');
  if (firstColour != null && (colors.isEmpty || !firstColour.contains(colors.first))) return false;
  final List<String>? onlyColours = _list(rule, 'onlyColours');
  if (onlyColours != null && !colors.every(onlyColours.contains)) return false;
  final int? maxColours = rule['maxColours'] as int?;
  if (maxColours != null && colors.length > maxColours) return false;
  if (rule['minColoursFrom'] case {'colours': final List<Object?> colours, 'count': final int count}) {
    if (colors.where(colours.contains).length < count) return false;
  }
  final List<String>? noColours = _list(rule, 'noColours');
  if (noColours != null && colors.any(noColours.contains)) return false;
  final List<String>? anyLabel = _list(rule, 'anyLabel');
  if (anyLabel != null && !labels.any(anyLabel.contains)) return false;
  final List<String>? noLabel = _list(rule, 'noLabel');
  if (noLabel != null && labels.any(noLabel.contains)) return false;
  final List<String>? anyCollection = _list(rule, 'anyCollection');
  if (anyCollection != null && !collections.any(anyCollection.contains)) return false;
  final List<String>? spatialTiers = _list(rule, 'spatialTiers');
  if (spatialTiers != null && !spatialTiers.contains(wall.spatialTier)) return false;
  final List<String>? depthTiers = _list(rule, 'depthTiers');
  if (depthTiers != null && !depthTiers.contains(wall.depthTier)) return false;
  return true;
}
