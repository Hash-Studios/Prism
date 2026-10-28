import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/domain/repositories/mood_repository.dart';
import 'package:Prism/features/moods/views/pages/gallery_screen.dart';
import 'package:Prism/features/personalized_feed/views/widgets/feed_wall_tile.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/favourite_test_scope.dart';
import 'mood_test_support.dart';

class _LiveGalleryRepository implements MoodRepository {
  final StreamController<void> visibilityChanges = StreamController<void>.broadcast();
  final List<List<String>> requests = <List<String>>[];
  bool blocked = false;

  @override
  Future<List<MoodList>> fetchMoods() async => const <MoodList>[];

  @override
  Future<List<PrismWallpaper>> fetchMoodWalls(List<String> ids, {bool keepOrder = false}) async {
    requests.add(List<String>.of(ids));
    return blocked ? const <PrismWallpaper>[] : <PrismWallpaper>[for (final String id in ids) mockMoodWall(id)];
  }

  @override
  Stream<void> watchVisibilityChanges() => visibilityChanges.stream;
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

  testWidgets('shows an empty state when every push wall is unavailable', (tester) async {
    getIt.registerSingleton<MoodRepository>(FakeMoodRepository());

    await tester.pumpWidget(moodTestApp(const GalleryScreen(ids: 'wall-a,wall-b', source: 'push')));
    await tester.pump();
    await tester.pump();

    expect(find.byType(GlintState), findsOneWidget);
    expect(find.text('These walls are gone'), findsOneWidget);
    expect(find.text('They were removed or are no longer public.'), findsOneWidget);
    expect(recordingAnalytics.events.whereType<GalleryOpenedEvent>().single.wallCount, 2);
  });

  testWidgets('reloads walls when the requested ids or visibility changes', (tester) async {
    final _LiveGalleryRepository repository = _LiveGalleryRepository();
    getIt.registerSingleton<MoodRepository>(repository);
    addTearDown(repository.visibilityChanges.close);

    await tester.pumpWidget(moodTestApp(const GalleryScreen(ids: 'wall-a,wall-b', source: 'push')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(FeedWallTile), findsNWidgets(2));
    expect(repository.requests, <List<String>>[
      <String>['wall-a', 'wall-b'],
    ]);

    await tester.pumpWidget(moodTestApp(const GalleryScreen(ids: 'wall-c,wall-d', source: 'link')));
    await tester.pump();
    await tester.pump();
    expect(repository.requests.last, <String>['wall-c', 'wall-d']);
    expect(recordingAnalytics.events.whereType<GalleryOpenedEvent>(), hasLength(2));

    repository
      ..blocked = true
      ..visibilityChanges.add(null);
    await tester.pump();
    await tester.pump();

    expect(find.text('These walls are gone'), findsOneWidget);
    expect(repository.requests, hasLength(3));
  });
}
