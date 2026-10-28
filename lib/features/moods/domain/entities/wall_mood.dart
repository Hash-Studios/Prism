/// A Home mood. [id] is its key in `moods/current`. The rule that picks its walls is in `functions/src/wallMoods.ts`.
enum WallMood {
  dreamy('dreamy'),
  darkQuiet('dark_quiet'),
  brightBold('bright_bold'),
  minimal('minimal'),

  /// iOS 26 Spatial Scenes. Walls with `spatial.tier` great.
  spatialReady('spatial_ready', iosMajor: 26),

  /// The iOS Lock Screen Depth Effect. Walls with `depth.tier` auto or menu.
  depthReady('depth_ready', iosMajor: 16);

  const WallMood(this.id, {this.iosMajor});

  final String id;

  /// Set for an iOS-only mood: the first iOS major version that has the feature.
  final int? iosMajor;

  /// [iosMajor] is null on Android, and 0 on iOS when the version cannot be read.
  bool shownOn({required int? iosMajor}) {
    final int? needs = this.iosMajor;
    return needs == null || (iosMajor != null && iosMajor >= needs);
  }

  /// Null for an unknown id, for example a mood that a newer app version added.
  static WallMood? parse(Object? id) {
    for (final WallMood mood in values) {
      if (mood.id == id) return mood;
    }
    return null;
  }
}

/// One mood and the ids of its walls, newest first, as the daily job wrote them.
final class MoodList {
  const MoodList({required this.mood, required this.wallIds});

  final WallMood mood;
  final List<String> wallIds;
}
