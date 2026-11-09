import 'dart:collection';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/readability/data/readability_render.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/wallpaper_position/domain/entities/wallpaper_placement.dart';
import 'package:flutter/foundation.dart';

/// What one analysis depends on. Two equal keys give the same result, so the result is cached under it.
///
/// [wall] is the wall id, or the link when there is none. [image] is the local file for an edited or placed wall, so a
/// new edit gets a new key. [placement] is the crop from the position studio. [tint] is the colour variation.
typedef ReadabilityKey = ({
  String wall,
  String image,
  WallpaperPlacement? placement,
  int? tint,
  TargetPlatform platform,
  int clockText,
  int frameHeight,
});

/// The analyzer [ReadabilityTips.check] runs. Tests replace it.
typedef ReadabilityAnalyzer =
    Map<ReadabilityZone, ReadabilityResult> Function(
      ReadabilityFrame frame, {
      required TargetPlatform platform,
      Map<ReadabilityZone, ui.Color> textColors,
    });

/// The Readability tips switch, the walls that already showed a tip this session, and the cached results.
class ReadabilityTips {
  ReadabilityTips._();

  static final ReadabilityTips instance = ReadabilityTips._();

  static const String enabledKey = 'readability.enabled';
  static const int _cacheSize = 32;

  /// False runs the analysis on the calling isolate. Widget tests use it, because a test zone cannot wait on an isolate.
  @visibleForTesting
  static bool useIsolate = true;

  @visibleForTesting
  static ReadabilityAnalyzer analyzer = analyzeReadability;

  /// A result that arrives later than this after the check starts is dropped, so a tip never pops in late.
  /// Widget tests raise it, because a cold image decode on a loaded test host can take longer.
  @visibleForTesting
  static Duration budget = const Duration(seconds: 2);

  final Set<String> _shown = <String>{};
  final LinkedHashMap<ReadabilityKey, Map<ReadabilityZone, ReadabilityResult>> _cache =
      LinkedHashMap<ReadabilityKey, Map<ReadabilityZone, ReadabilityResult>>();

  bool get enabled {
    try {
      if (!getIt.isRegistered<SettingsLocalDataSource>()) return true;
      return getIt<SettingsLocalDataSource>().get<bool>(enabledKey, defaultValue: true);
    } catch (_) {
      return true;
    }
  }

  Future<void> setEnabled(bool value) async {
    if (!getIt.isRegistered<SettingsLocalDataSource>()) return;
    await getIt<SettingsLocalDataSource>().set(enabledKey, value);
  }

  /// True when a tip for [wall] already showed in this app session.
  bool shownFor(String wall) => _shown.contains(wall);

  void markShown(String wall) => _shown.add(wall);

  /// Analyzes the wall as the screen shows it under [key]. [decode] gives a small decode of the wall. It runs only on a
  /// cache miss, and this method disposes its image.
  Future<Map<ReadabilityZone, ReadabilityResult>> check(
    ReadabilityKey key,
    Future<ui.Image> Function() decode, {
    ui.Color? tint,
  }) async {
    final Map<ReadabilityZone, ReadabilityResult>? cached = _cache.remove(key);
    if (cached != null) return _cache[key] = cached;
    final ui.Image source = await decode();
    final ui.Image frame;
    try {
      frame = await renderReadabilityFrame(
        source,
        width: analysisWidth,
        height: key.frameHeight,
        platform: key.platform,
        tint: tint,
      );
    } finally {
      source.dispose();
    }
    final ReadabilityFrame pixels;
    try {
      pixels = await readabilityFrameOf(frame);
    } finally {
      frame.dispose();
    }
    final ReadabilityAnalyzer analyze = analyzer;
    final TargetPlatform platform = key.platform;
    final Map<ReadabilityZone, ui.Color> textColors = <ReadabilityZone, ui.Color>{
      ReadabilityZone.clock: ui.Color(key.clockText),
    };
    Map<ReadabilityZone, ReadabilityResult> run() => analyze(pixels, platform: platform, textColors: textColors);
    final Map<ReadabilityZone, ReadabilityResult> result = useIsolate ? await Isolate.run(run) : run();
    _cache[key] = result;
    if (_cache.length > _cacheSize) _cache.remove(_cache.keys.first);
    return result;
  }

  @visibleForTesting
  void reset() {
    _shown.clear();
    _cache.clear();
  }
}
