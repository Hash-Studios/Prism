import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';
import 'package:flutter/widgets.dart' show StringCharacters;

const String defaultSubmissionCategory = 'General';
const int maxSubmissionTitleLength = 60;
const int maxSubmissionDescriptionLength = 500;
const int maxSubmissionTags = 8;
const int maxSubmissionTagLength = 24;

bool submissionTextIsSafe(String text) {
  if (text.runes.any(
    (rune) =>
        rune < 32 ||
        (rune >= 127 && rune <= 159) ||
        (rune >= 0x200b && rune <= 0x200f) ||
        (rune >= 0x202a && rune <= 0x202e) ||
        (rune >= 0x2060 && rune <= 0x206f) ||
        (rune >= 0xe000 && rune <= 0xf8ff) ||
        rune == 0xfeff,
  )) {
    return false;
  }
  const blocked = <String>[
    'nigger',
    'nigga',
    'faggot',
    'fag',
    'retard',
    'kike',
    'chink',
    'spic',
    'tranny',
    'porn',
    'porno',
    'nude',
    'nudes',
    'naked',
    'nsfw',
    'hentai',
    'sex',
    'sexy',
    'xxx',
    'boobs',
    'tits',
    'dick',
    'cock',
    'pussy',
    'cum',
    'rape',
    'milf',
  ];
  const leet = <String, String>{'0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', r'$': 's'};
  final value = text.toLowerCase().replaceAllMapped(RegExp(r'[013457@$]'), (match) => leet[match[0]]!);
  final words = value.split(RegExp('[^a-z0-9]+'));
  return !words.any(
    (word) => blocked.any((term) => RegExp('^${term.split('').map((c) => '$c+').join()}\$').hasMatch(word)),
  );
}

bool submissionMetadataIsValid(SubmissionMetadata value) =>
    value.title.characters.length <= maxSubmissionTitleLength &&
    value.description.characters.length <= maxSubmissionDescriptionLength &&
    value.tags.length <= maxSubmissionTags &&
    value.tags.every((tag) => tag.characters.length <= maxSubmissionTagLength) &&
    <String>[value.title, value.description, ...value.tags].every(submissionTextIsSafe);

/// Categories a creator can pick. `General` first: the server classifier files those walls later.
List<String> get submissionCategories => <String>[
  defaultSubmissionCategory,
  for (final category in categoryDefinitions)
    if (category.hasPrismWalls) category.name,
];

/// A lower-case tag without `#`, spaces collapsed, or null when nothing is left.
String? normalizeSubmissionTag(String raw) {
  final String tag = raw.replaceAll('#', ' ').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (tag.isEmpty) return null;
  return tag.length > maxSubmissionTagLength ? tag.substring(0, maxSubmissionTagLength).trim() : tag;
}

/// Optional details a creator adds to a wallpaper before review. Every field can stay empty.
class SubmissionMetadata {
  const SubmissionMetadata({
    this.title = '',
    this.description = '',
    this.category = defaultSubmissionCategory,
    this.tags = const <String>[],
    this.requestId = '',
    this.requestText = '',
    this.challengeId = '',
    this.challengeTheme = '',
    this.challengeRemoved = false,
  });

  final String title;
  final String description;
  final String category;
  final List<String> tags;

  /// The wall request this upload fills, or empty when it fills none.
  final String requestId;

  /// The text of [requestId], kept so the upload form can show it without a lookup.
  final String requestText;
  final String challengeId;
  final String challengeTheme;
  final bool challengeRemoved;
  ChallengeSeed? get challengeSeed =>
      challengeId.isEmpty ? null : ChallengeSeed(id: challengeId, theme: challengeTheme);

  bool get hasTitle => title.trim().isNotEmpty;

  SubmissionMetadata copyWith({
    String? title,
    String? description,
    String? category,
    List<String>? tags,
    String? requestId,
    String? requestText,
    String? challengeId,
    String? challengeTheme,
    bool? challengeRemoved,
  }) => SubmissionMetadata(
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    requestId: requestId ?? this.requestId,
    requestText: requestText ?? this.requestText,
    challengeId: challengeId ?? this.challengeId,
    challengeTheme: challengeTheme ?? this.challengeTheme,
    challengeRemoved: challengeRemoved ?? this.challengeRemoved,
  );
}
