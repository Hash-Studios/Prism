import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/analytics/trackers/wallpaper_impression.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_skeleton.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
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

class _MoodSpecificWallsRepository extends FakeMoodRepository {
  _MoodSpecificWallsRepository({required super.moods});

  final List<List<String>> requestedWallIds = <List<String>>[];

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async {
    requestedWallIds.add(List<String>.of(ids));
    return ids.map(mockMoodWall).toList();
  }
}

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

  late FakeAppAnalytics recordingAnalytics;

  setUp(() {
    recordingAnalytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = recordingAnalytics;
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

  testWidgets('loads the supplied wall ids without rereading the mood document', (tester) async {
    final repository = _MoodSpecificWallsRepository(moods: const <MoodList>[_dreamy]);
    _registerRepository(repository);

    await _pumpRow(tester);

    expect(repository.moodReads, 0);
    expect(repository.requestedWallIds, <List<String>>[_dreamy.wallIds]);
  });

  testWidgets('reloads changed wall ids but not an equal mood-list rebuild', (tester) async {
    final repository = _MoodSpecificWallsRepository(moods: const <MoodList>[_dreamy]);
    _registerRepository(repository);

    Future<void> pump(MoodList list) async {
      await tester.pumpWidget(
        moodTestApp(
          Scaffold(
            body: SingleChildScrollView(
              child: MoodRow(key: const ValueKey<String>('row'), list: list, slot: 0),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    await pump(_dreamy);
    await pump(MoodList(mood: WallMood.dreamy, wallIds: List<String>.of(_dreamy.wallIds)));

    expect(repository.requestedWallIds, <List<String>>[_dreamy.wallIds]);

    const MoodList refreshed = MoodList(mood: WallMood.dreamy, wallIds: <String>['fresh-0', 'fresh-1', 'fresh-2']);
    await pump(refreshed);

    expect(repository.requestedWallIds, <List<String>>[_dreamy.wallIds, refreshed.wallIds]);
    expect(
      tester.widgetList<WallpaperTile>(find.byType(WallpaperTile)).map((tile) => tile.item.id),
      contains('fresh-0'),
    );
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

  testWidgets('tracks the new mood when the row is reused', (tester) async {
    const MoodList bold = MoodList(mood: WallMood.brightBold, wallIds: <String>['bold-0', 'bold-1', 'bold-2']);
    _registerRepository(_MoodSpecificWallsRepository(moods: const <MoodList>[_dreamy, bold]));

    await tester.pumpWidget(
      moodTestApp(
        const Scaffold(
          body: SingleChildScrollView(
            child: MoodRow(key: ValueKey<String>('reused-row'), list: _dreamy, slot: 0),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    await tester.pumpWidget(
      moodTestApp(
        const Scaffold(
          body: SingleChildScrollView(
            child: MoodRow(key: ValueKey<String>('reused-row'), list: bold, slot: 0),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(
      recordingAnalytics.events.whereType<MoodRowSeenEvent>().map((event) => event.moodId),
      unorderedEquals(<String>['dreamy', 'bright_bold']),
    );
  });

  testWidgets('keeps overlapping mood-row impressions and feed heroes scoped', (tester) async {
    const MoodList bold = MoodList(mood: WallMood.brightBold, wallIds: <String>['wall-0', 'wall-1', 'wall-2']);
    _registerRepository(FakeMoodRepository(moods: const <MoodList>[_dreamy, bold], walls: mockMoodWalls(5)));
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      moodTestApp(
        WallpaperImpressionScope(
          session: WallpaperImpressionSession(),
          child: CustomScrollView(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 180,
                  child: WallpaperTile(
                    item: PrismFeedItem(id: 'wall-0', wallpaper: mockMoodWall('wall-0')),
                    index: 0,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: MoodRow(list: _dreamy, slot: 0)),
              const SliverToBoxAdapter(child: MoodRow(list: bold, slot: 1)),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    final List<String> heroTags = tester
        .widgetList<Hero>(find.byType(Hero))
        .map((hero) => hero.tag as String)
        .toList(growable: false);
    expect(heroTags.length, greaterThanOrEqualTo(3));
    expect(heroTags.toSet(), hasLength(heroTags.length));
    expect(
      recordingAnalytics.events.whereType<MoodRowSeenEvent>().map((event) => event.moodId),
      unorderedEquals(<String>['dreamy', 'bright_bold']),
    );
  });

  testWidgets('tracks the row when a later tile becomes visible before the first tile', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const <MoodList>[_dreamy], walls: mockMoodWalls(5)));

    await tester.pumpWidget(
      moodTestApp(
        const Scaffold(
          body: SingleChildScrollView(child: MoodRow(list: _dreamy, slot: 0)),
        ),
      ),
    );
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(-1000, 0));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(recordingAnalytics.events.whereType<MoodRowSeenEvent>(), hasLength(1));
  });
}
