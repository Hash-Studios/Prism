import 'package:Prism/l10n/l10n.dart';

/// Every feature hint. The surface that shows a hint wraps its control in `FeatureHint(id: ...)`.
enum HintId {
  /// The heart on wall detail. Hold it to save the wall to a Folder.
  folderHold,

  /// The colour variant dots on wall detail.
  variantDots,

  /// The photo search button on Search.
  photoSearch,

  /// The Follow button on a category page.
  followCategory,

  /// The New smart folder tile in Library > Folders.
  smartFolders,

  /// The more button on a large Folder that has no sections.
  folderSections,

  /// The From your photo card on the AI tab.
  photoFit,

  /// The Live Photo button on the iOS set screen.
  livePhoto;

  /// The id in analytics, storage and the `hints_disabled_ids` Remote Config list, such as `folder_hold`.
  String get key => name.replaceAllMapped(RegExp('[A-Z]'), (Match m) => '_${m[0]!.toLowerCase()}');
}

enum HintDismissMethod { gotIt, tapOutside, interrupted }

/// When a hint shows and what it says. [views] is how many times the user must see the surface first. The surface
/// adds its own condition. [usedEvent] is the analytics event of the feature: once it fires, the hint never shows.
class Hint {
  const Hint({required this.id, required this.views, required this.usedEvent, required this.copy});

  final HintId id;
  final int views;
  final String usedEvent;
  final String Function(AppLocalizations l10n) copy;
}

final Map<HintId, Hint> kHints = <HintId, Hint>{
  for (final Hint hint in <Hint>[
    Hint(id: HintId.folderHold, views: 3, usedEvent: 'wall_saved_to_folder', copy: (l) => l.hintFolderHold),
    Hint(id: HintId.variantDots, views: 1, usedEvent: 'wallpaper_variant_switched', copy: (l) => l.hintVariantDots),
    Hint(id: HintId.photoSearch, views: 3, usedEvent: 'photo_search_started', copy: (l) => l.hintPhotoSearch),
    Hint(id: HintId.followCategory, views: 2, usedEvent: 'topic_followed', copy: (l) => l.hintFollowCategory),
    Hint(id: HintId.smartFolders, views: 2, usedEvent: 'smart_folder_created', copy: (l) => l.hintSmartFolders),
    Hint(
      id: HintId.folderSections,
      views: 1,
      usedEvent: 'folder_section_suggestions_shown',
      copy: (l) => l.hintFolderSections,
    ),
    Hint(id: HintId.photoFit, views: 2, usedEvent: 'photo_job_started', copy: (l) => l.hintPhotoFit),
    Hint(id: HintId.livePhoto, views: 2, usedEvent: 'live_photo_export_started', copy: (l) => l.hintLivePhoto),
  ])
    hint.id: hint,
};

/// How often hints may show: one a day, three a week, none in the first sessions, and none soon after another prompt.
class HintBudget {
  const HintBudget._();

  static const int quietSessions = 2;
  static const int perWeek = 3;
  static const Duration day = Duration(days: 1);
  static const Duration week = Duration(days: 7);
  static const Duration promptCooldown = Duration(minutes: 10);

  static bool allows({
    required DateTime now,
    required int session,
    required Iterable<DateTime> shownAt,
    DateTime? lastPromptAt,
  }) {
    if (session <= quietSessions) return false;
    if (lastPromptAt != null && now.difference(lastPromptAt) < promptCooldown) return false;
    final List<Duration> ages = shownAt.map(now.difference).where((Duration age) => age < week).toList();
    return ages.length < perWeek && !ages.any((Duration age) => age < day);
  }
}
