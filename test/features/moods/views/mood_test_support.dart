import 'dart:async';

import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

import '../../../support/favourite_test_scope.dart';

PrismWallpaper mockMoodWall(String id) => PrismWallpaper(
  core: WallpaperCore(id: id, source: WallpaperSource.prism, fullUrl: '', thumbnailUrl: '', authorName: id),
);

List<PrismWallpaper> mockMoodWalls(int count) => [for (var i = 0; i < count; i++) mockMoodWall('wall-$i')];

class FakeMoodRepository implements MoodRepository {
  @override
  Stream<void> watchVisibilityChanges() => const Stream<void>.empty();

  FakeMoodRepository({
    this.moods = const <MoodList>[],
    this.walls = const <PrismWallpaper>[],
    this.fail = false,
    this.gate,
  });

  final List<MoodList> moods;
  final List<PrismWallpaper> walls;
  final bool fail;

  /// Holds [fetchMoodWalls] until it completes, so a test can see the loading state.
  final Future<void>? gate;

  int moodReads = 0;

  @override
  Future<List<MoodList>> fetchMoods() async {
    moodReads++;
    if (fail) throw StateError('offline');
    return moods;
  }

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids) async {
    if (gate != null) await gate;
    if (fail) throw StateError('offline');
    return walls;
  }
}

/// A [MaterialApp] with the app's localizations and the favourite-card dependencies that wallpaper tiles read.
Widget moodTestApp(Widget home) => MaterialApp(
  builder: favouriteTestBuilder,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);
