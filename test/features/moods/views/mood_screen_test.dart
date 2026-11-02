import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/moods/biz/mood_walls_cubit.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/pages/mood_screen.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/favourite_test_scope.dart';
import 'mood_test_support.dart';

const MoodList _dreamy = MoodList(mood: WallMood.dreamy, wallIds: <String>['wall-0', 'wall-1', 'wall-2']);

void _registerRepository(FakeMoodRepository repository, {Future<int?> Function()? iosMajor}) {
  getIt.registerFactory<MoodWallsCubit>(() => MoodWallsCubit(repository, iosMajor: iosMajor));
}

Future<void> _pumpScreen(WidgetTester tester, {String moodId = 'dreamy'}) async {
  await tester.pumpWidget(moodTestApp(MoodScreen(moodId: moodId, source: 'chip')));
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

  testWidgets('shows the loading cards while the walls load', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const [_dreamy], gate: Completer<void>().future));

    await _pumpScreen(tester);

    expect(find.byType(LoadingCards), findsOneWidget);
    expect(find.byType(FeedWallTile), findsNothing);
  });

  testWidgets('shows the title, the body line and the walls when loaded', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const [_dreamy], walls: mockMoodWalls(3)));

    await _pumpScreen(tester);

    expect(find.text('Dreamy'), findsOneWidget);
    expect(find.text('Soft skies and pastel light.'), findsOneWidget);
    expect(find.byType(FeedWallTile), findsNWidgets(3));
  });

  testWidgets('shows the error with a retry that loads again', (tester) async {
    final repository = FakeMoodRepository(moods: const [_dreamy], fail: true);
    _registerRepository(repository);

    await _pumpScreen(tester);

    expect(find.text("Couldn't load these wallpapers"), findsOneWidget);
    expect(repository.moodReads, 1);

    await tester.tap(find.text('Try again'));
    await tester.pump();
    await tester.pump();

    expect(repository.moodReads, 2);
    expect(recordingAnalytics.events.whereType<MoodPageOpenedEvent>(), hasLength(1));
  });

  testWidgets('shows the empty state when the mood has no walls', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const [_dreamy]));

    await _pumpScreen(tester);

    expect(find.text('No wallpapers here yet'), findsOneWidget);
    expect(find.byType(FeedWallTile), findsNothing);
  });

  testWidgets('an unknown mood id shows the empty state and never loads', (tester) async {
    final repository = FakeMoodRepository(moods: const [_dreamy], walls: mockMoodWalls(3));
    _registerRepository(repository);

    await _pumpScreen(tester, moodId: 'nope');

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('New wallpapers join every day.'), findsOneWidget);
    expect(repository.moodReads, 0);
  });

  testWidgets('loads the new mood when the page is reused for another id', (tester) async {
    const MoodList bold = MoodList(mood: WallMood.brightBold, wallIds: <String>['wall-0', 'wall-1', 'wall-2']);
    final FakeMoodRepository repository = FakeMoodRepository(moods: const [_dreamy, bold], walls: mockMoodWalls(3));
    _registerRepository(repository);

    await _pumpScreen(tester);
    expect(find.text('Dreamy'), findsOneWidget);

    await tester.pumpWidget(moodTestApp(const MoodScreen(moodId: 'bright_bold', source: 'chip')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Bright and bold'), findsOneWidget);
    expect(find.text('Big colour to wake up your screen.'), findsOneWidget);
    expect(repository.moodReads, 2);
    expect(
      recordingAnalytics.events.whereType<MoodPageOpenedEvent>().map((event) => event.moodId),
      unorderedEquals(<String>['dreamy', 'bright_bold']),
    );
  });

  testWidgets('does not duplicate page-open analytics on rebuild', (tester) async {
    _registerRepository(FakeMoodRepository(moods: const <MoodList>[_dreamy], walls: mockMoodWalls(3)));

    await _pumpScreen(tester);
    await tester.pumpWidget(moodTestApp(const MoodScreen(moodId: 'dreamy', source: 'chip')));
    await tester.pump();

    expect(recordingAnalytics.events.whereType<MoodPageOpenedEvent>(), hasLength(1));
  });

  testWidgets('unsupported platform deep links load no mood documents', (tester) async {
    const MoodList spatial = MoodList(mood: WallMood.spatialReady, wallIds: <String>['spatial-0']);
    const MoodList depth = MoodList(mood: WallMood.depthReady, wallIds: <String>['depth-0']);
    final repository = FakeMoodRepository(moods: const <MoodList>[spatial, depth], walls: mockMoodWalls(3));
    _registerRepository(repository, iosMajor: () async => null);

    await _pumpScreen(tester, moodId: 'spatial_ready');
    expect(find.text('Spatial ready'), findsOneWidget);
    expect(repository.moodReads, 0);
    expect(find.byType(FeedWallTile), findsNothing);

    await tester.pumpWidget(moodTestApp(const MoodScreen(moodId: 'depth_ready')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Depth ready'), findsOneWidget);
    expect(repository.moodReads, 0);
    expect(find.byType(FeedWallTile), findsNothing);
  });

  testWidgets('iOS 18 deep links load Depth but keep Spatial unavailable', (tester) async {
    const MoodList spatial = MoodList(mood: WallMood.spatialReady, wallIds: <String>['spatial-0']);
    const MoodList depth = MoodList(mood: WallMood.depthReady, wallIds: <String>['depth-0']);
    final repository = FakeMoodRepository(moods: const <MoodList>[spatial, depth], walls: mockMoodWalls(3));
    _registerRepository(repository, iosMajor: () async => 18);

    await _pumpScreen(tester, moodId: 'spatial_ready');
    expect(repository.moodReads, 0);
    expect(find.byType(FeedWallTile), findsNothing);

    await tester.pumpWidget(moodTestApp(const MoodScreen(moodId: 'depth_ready')));
    await tester.pump();
    await tester.pump();

    expect(repository.moodReads, 1);
    expect(find.byType(FeedWallTile), findsNWidgets(3));
  });
}
