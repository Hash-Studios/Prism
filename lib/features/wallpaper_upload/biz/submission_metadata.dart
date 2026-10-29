import 'package:Prism/data/categories/categories.dart';

const String defaultSubmissionCategory = 'General';
const int maxSubmissionTitleLength = 60;
const int maxSubmissionTags = 8;
const int maxSubmissionTagLength = 24;

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
    this.category = defaultSubmissionCategory,
    this.tags = const <String>[],
    this.requestId = '',
    this.requestText = '',
  });

  final String title;
  final String category;
  final List<String> tags;

  /// The wall request this upload fills, or empty when it fills none.
  final String requestId;

  /// The text of [requestId], kept so the upload form can show it without a lookup.
  final String requestText;

  bool get hasTitle => title.trim().isNotEmpty;

  SubmissionMetadata copyWith({
    String? title,
    String? category,
    List<String>? tags,
    String? requestId,
    String? requestText,
  }) => SubmissionMetadata(
    title: title ?? this.title,
    category: category ?? this.category,
    tags: tags ?? this.tags,
    requestId: requestId ?? this.requestId,
    requestText: requestText ?? this.requestText,
  );
}
