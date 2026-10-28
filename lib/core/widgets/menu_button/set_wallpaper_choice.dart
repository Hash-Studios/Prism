import 'dart:io';

import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:async_wallpaper/async_wallpaper.dart' as aw;

/// What the Set screen asks the flow to do next.
enum SetChoiceKind {
  /// Set the wall on [SetWallpaperChoice.target] now.
  apply,

  /// Pick a second wall for the lock screen.
  pair,
}

/// What the user picked on the Set screen.
class SetWallpaperChoice {
  const SetWallpaperChoice(
    this.target, {
    this.useSystemCropper = false,
    this.placed,
    this.targetChanged,
    this.kind = SetChoiceKind.apply,
  });

  const SetWallpaperChoice.pair({bool? targetChanged})
    : this(WallpaperTarget.home, targetChanged: targetChanged, kind: SetChoiceKind.pair);

  final WallpaperTarget target;

  /// Opens the Android system editor first, so the user picks the exact area.
  final bool useSystemCropper;

  /// The wall as the user placed it in the position studio. Null sets the wall as it is.
  final PlacedWallpaper? placed;

  /// True when the user changed the target on the Set screen. Null when no screen was shown.
  final bool? targetChanged;
  final SetChoiceKind kind;
}

/// What the position studio hands back to the Set screen.
sealed class StudioResult {
  const StudioResult();
}

/// The wall rendered at screen size, as the user placed it.
class PlacedWallpaper extends StudioResult {
  const PlacedWallpaper({required this.path, required this.placement});

  /// A PNG in a temporary folder of its own. [discard] deletes it.
  final String path;
  final WallpaperPlacement placement;

  Future<void> discard() async {
    try {
      await File(path).parent.delete(recursive: true);
    } catch (_) {}
  }
}

/// The user wants the Android system editor to pick the area.
class SystemEditorRequested extends StudioResult {
  const SystemEditorRequested();
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
