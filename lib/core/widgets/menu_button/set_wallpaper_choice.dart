import 'dart:io';
import 'dart:ui' show Size;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:Prism/features/wallpaper_position/domain/repositories/wallpaper_position_repository.dart';
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
  const PlacedWallpaper({required this.path, required this.placement, this.fromStudio = true});

  /// Renders the wall at [url] as [placement] says, at [outputSize] pixels, through the studio render. Readability
  /// fixes use it, so a fix changes only this new file and never [url].
  static Future<PlacedWallpaper> render(String url, WallpaperPlacement placement, Size outputSize) async {
    final WallpaperPositionRepository repository = getIt<WallpaperPositionRepository>();
    final PlacementSource source = await repository.load(url);
    try {
      final File file = await repository.render(source, placement, outputSize);
      return PlacedWallpaper(path: file.path, placement: placement, fromStudio: false);
    } finally {
      source.image.dispose();
    }
  }

  /// A PNG in a temporary folder of its own. [discard] deletes it.
  final String path;
  final WallpaperPlacement placement;

  /// False when only a readability fix shaped this wall, so analytics do not count it as a studio placement.
  final bool fromStudio;

  /// The analytics fit label of a set that uses this wall.
  String get fitLabel => fromStudio ? 'studio_${placement.fit.name}' : 'readability_fix';

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
