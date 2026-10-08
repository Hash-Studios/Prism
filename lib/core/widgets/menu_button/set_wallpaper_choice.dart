import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;

/// What the set sheet asks the flow to do next.
enum SetChoiceKind {
  /// Set the wall on [SetWallpaperChoice.target] now.
  apply,

  /// Open the position studio.
  adjust,

  /// Pick a second wall for the lock screen.
  pair,
}

/// What the user picked in the set sheet.
class SetWallpaperChoice {
  const SetWallpaperChoice(this.target, {this.fit = WallpaperFit.fill, this.kind = SetChoiceKind.apply});

  const SetWallpaperChoice.adjust() : this(WallpaperTarget.both, kind: SetChoiceKind.adjust);

  const SetWallpaperChoice.pair({WallpaperFit fit = WallpaperFit.fill})
    : this(WallpaperTarget.home, fit: fit, kind: SetChoiceKind.pair);

  final WallpaperTarget target;
  final WallpaperFit fit;
  final SetChoiceKind kind;
}

/// True when the device can set [target]. Unknown capabilities count as supported.
bool isWallpaperTargetSupported(aw.WallpaperCapabilities capabilities, WallpaperTarget target) {
  if (!capabilities.supportsStaticWallpaper) return true;
  return switch (target) {
    WallpaperTarget.home => capabilities.supportsHomeWallpaper,
    WallpaperTarget.lock => capabilities.supportsLockWallpaper,
    WallpaperTarget.both => capabilities.supportsBothWallpapers,
  };
}
