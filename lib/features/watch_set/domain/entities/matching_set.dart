import 'package:Prism/core/wallpaper/wall_desktop.dart';
import 'package:Prism/features/wallpaper_detail/domain/entities/crop_spec.dart';
import 'package:Prism/features/watch_set/domain/entities/watch_format.dart';

/// One wall in the sizes of the user's screens. The phone item is the wall itself. The watch item is [watchCrop] of the
/// wall, saved at [watch]'s pixel size. [desktop] is the wall's desktop version, or null when it has none.
final class MatchingSet {
  const MatchingSet({required this.watch, required this.watchCrop, this.desktop});

  final WatchFormat watch;

  /// The crop on the preview image. The save scales it to the full file.
  final CropSpec watchCrop;
  final WallDesktopVariant? desktop;

  bool get withDesktop => desktop != null;

  /// Names the watch file and the set in Downloads, for example `watch-apple_46`.
  String get watchKey => 'watch-${watch.id}';

  MatchingSet copyWith({WatchFormat? watch, CropSpec? watchCrop}) =>
      MatchingSet(watch: watch ?? this.watch, watchCrop: watchCrop ?? this.watchCrop, desktop: desktop);
}
