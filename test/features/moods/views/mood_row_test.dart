import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/features/category_feed/views/widgets/wallpaper_tile.dart';
import 'package:Prism/features/moods/biz/mood_walls_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/widgets/mood_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/favourite_test_scope.dart';
import 'mood_test_support.dart';

const MoodList _dreamy = MoodList(mood: WallMood.dreamy, wallIds: <String>['wall-0', 'wall-1', 'wall-2']);

void _registerRepository(FakeMoodRepository repository) {
  getIt.registerFactory<MoodWallsCubit>(() => MoodWallsCubit(repository));
}

Future<void> _pumpRow(WidgetTester tester) async {
  await tester.pumpWidget(
    moodTestApp(
      const Scaffold(
        body: SingleChildScrollView(child: MoodRow(list: _dreamy, slot: 0)),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  setUpFavouriteCounts();

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('shows a skeleton while the walls load', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const [_dreamy], gate: Completer<void>().future));

    await _pumpRow(tester);

    expect(find.byType(PrismSkeleton), findsOneWidget);
    expect(find.byType(WallpaperTile), findsNothing);
  });

  testWidgets('shows the title, the body line, See all and the wall strip when loaded', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const [_dreamy], walls: mockMoodWalls(5)));

    await _pumpRow(tester);

    expect(find.text('Dreamy'), findsOneWidget);
    expect(find.text('Soft skies and pastel light.'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    expect(find.byType(WallpaperTile), findsWidgets);
  });

  testWidgets('renders nothing when fewer than three walls load', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const [_dreamy], walls: mockMoodWalls(2)));

    await _pumpRow(tester);

    expect(find.text('Dreamy'), findsNothing);
    expect(find.text('See all'), findsNothing);
    expect(find.byType(WallpaperTile), findsNothing);
  });

  testWidgets('renders nothing when the read fails', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const [_dreamy], fail: true));

    await _pumpRow(tester);

    expect(find.text('Dreamy'), findsNothing);
    expect(find.text("Couldn't load these wallpapers"), findsNothing);
    expect(find.byType(WallpaperTile), findsNothing);
  });
}
