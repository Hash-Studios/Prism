import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';

const int smartMaxKinds = 3;
const int smartMaxValuesPerKind = 6;

/// One kind of smart folder rule. [wire] is the value in `folders/{id}.smartRules` and in the callables. The order is
/// the order the rule builder shows.
enum SmartRuleKind {
  mood('mood'),
  colour('colour'),
  category('category'),
  followed('followed', hasValue: false),
  creator('creator'),
  desktop('desktop', hasValue: false),
  editorsChoice('editorsChoice', hasValue: false);

  const SmartRuleKind(this.wire, {this.hasValue = true});

  final String wire;
  final bool hasValue;

  static SmartRuleKind? parse(Object? wire) {
    for (final SmartRuleKind kind in values) {
      if (kind.wire == wire) return kind;
    }
    return null;
  }
}

/// The categories the server classifier writes to `walls.category`. Keep in sync with `CATEGORY_NAMES` in
/// functions/src/wallCategory.ts; `functions/src/__tests__/smartRuleParity.test.ts` fails when they differ.
const List<String> smartCategoryNames = <String>[
  'Nature',
  'Architecture',
  'Cars',
  'Anime',
  'Gaming',
  'Space',
  'Ocean',
  'Flowers',
  'Neon',
  'Dark',
  'Abstract',
  '3D Render',
  'Minimal',
  'Gradient',
  'AI Art',
  'Cyberpunk',
  'Vintage',
  'Landscape',
  'Galaxy',
  'Pastel',
];

/// One rule of a smart folder. Rules of different kinds join with AND. Rules of one kind join with OR.
final class SmartRule {
  const SmartRule(this.kind, [this.value = '']);

  final SmartRuleKind kind;

  /// Empty for kinds without a value.
  final String value;

  Map<String, String> toJson() => <String, String>{'kind': kind.wire, 'value': value};

  @override
  bool operator ==(Object other) => other is SmartRule && other.kind == kind && other.value == value;

  @override
  int get hashCode => Object.hash(kind, value);

  @override
  String toString() => 'SmartRule(${kind.wire}:$value)';
}

bool _validValue(SmartRuleKind kind, String value) => switch (kind) {
  SmartRuleKind.mood => WallMood.parse(value) != null,
  SmartRuleKind.colour => prismPalette.any((colour) => colour.id == value),
  SmartRuleKind.category => smartCategoryNames.contains(value),
  SmartRuleKind.creator => RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value),
  SmartRuleKind.followed || SmartRuleKind.desktop || SmartRuleKind.editorsChoice => value.isEmpty,
};

/// The rules in a folder doc, or null when the folder is not a smart folder. Unknown rules from a newer app are dropped.
List<SmartRule>? smartRulesFromDoc(Object? raw) {
  if (raw is! List) return null;
  final List<SmartRule> rules = <SmartRule>[];
  for (final Object? entry in raw) {
    if (entry is! Map) continue;
    final SmartRuleKind? kind = SmartRuleKind.parse(entry['kind']);
    final Object? value = entry['value'] ?? '';
    if (kind == null || value is! String || !_validValue(kind, value)) continue;
    final SmartRule rule = SmartRule(kind, value);
    if (!rules.contains(rule)) rules.add(rule);
  }
  return sortSmartRules(rules);
}

List<SmartRule> sortSmartRules(Iterable<SmartRule> rules) => rules.toList()
  ..sort((a, b) {
    final int byKind = a.kind.index.compareTo(b.kind.index);
    return byKind != 0 ? byKind : a.value.compareTo(b.value);
  });

Set<SmartRuleKind> smartKindsOf(Iterable<SmartRule> rules) => <SmartRuleKind>{for (final SmartRule r in rules) r.kind};

/// True when [rule] can be added: it opens no fourth kind and its kind has room for one more value.
bool canAddSmartRule(List<SmartRule> rules, SmartRule rule) {
  if (rules.contains(rule)) return true;
  final Set<SmartRuleKind> kinds = smartKindsOf(rules);
  if (!kinds.contains(rule.kind) && kinds.length >= smartMaxKinds) return false;
  return rules.where((r) => r.kind == rule.kind).length < smartMaxValuesPerKind;
}

/// Adds [rule], or removes it when it is already there. Returns [rules] unchanged when the rule does not fit.
List<SmartRule> toggleSmartRule(List<SmartRule> rules, SmartRule rule) {
  if (rules.contains(rule)) return sortSmartRules(rules.where((r) => r != rule));
  if (!canAddSmartRule(rules, rule)) return rules;
  return sortSmartRules(<SmartRule>[...rules, rule]);
}

/// The rules grouped by kind, in builder order. The summary line and the analytics use it.
Map<SmartRuleKind, List<String>> smartRulesByKind(List<SmartRule> rules) => <SmartRuleKind, List<String>>{
  for (final SmartRuleKind kind in SmartRuleKind.values)
    if (rules.any((r) => r.kind == kind))
      kind: <String>[
        for (final SmartRule r in rules)
          if (r.kind == kind) r.value,
      ],
};
