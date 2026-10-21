import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/quick_tiles/views/quick_tile_settings_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('prism/quick_settings');
  late FakeAppAnalytics analytics;
  final List<MethodCall> calls = <MethodCall>[];

  void fakeChannel({required int sdkInt, int addResult = 2}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return switch (call.method) {
        'sdkInt' => sdkInt,
        'requestAddTile' => addResult,
        _ => null,
      };
    });
  }

  setUp(() async {
    calls.clear();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  test('offline category tile candidates require an exact category and a retained asset', () {
    FeedItemEntity item(String id, {String? category, String? author}) => FeedItemEntity.prism(
      id: id,
      wallpaper: PrismWallpaper(
        core: WallpaperCore(
          id: id,
          source: WallpaperSource.prism,
          fullUrl: 'https://example.com/$id.jpg',
          thumbnailUrl: 'https://example.com/$id-thumb.jpg',
          category: category,
          authorName: author,
        ),
      ),
    );

    final List<String> candidates = categoryTileCandidates(
      <FeedItemEntity>[
        item('exact', category: 'Nature'),
        item('author-match', category: 'Abstract', author: 'Nature'),
        item('substring', category: 'Nature Photography'),
        item('not-retained', category: 'Nature'),
      ],
      category: 'Nature',
      source: WallpaperSource.prism,
      retainedPaths: <String, String>{
        'https://example.com/exact.jpg': '/retained/exact',
        'https://example.com/author-match.jpg': '/retained/author-match',
        'https://example.com/substring.jpg': '/retained/substring',
      },
    );

    expect(candidates, <String>['https://example.com/exact.jpg']);
  });

  Future<void> pumpScreen(WidgetTester tester, {bool settle = true}) async {
    tester.view.physicalSize = const Size(1000, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: QuickTileSettingsScreen(),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }

  testWidgets('shows a skeleton while loading, then one card per tile', (tester) async {
    fakeChannel(sdkInt: 32);
    await pumpScreen(tester, settle: false);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text('Quick tiles'), findsOneWidget);
    expect(find.text('Shuffle wallpaper tile'), findsOneWidget);
    expect(find.text('Wall of the Day tile'), findsOneWidget);
    expect(find.text('Random favourite tile'), findsOneWidget);
    expect(find.text('How to add a tile'), findsOneWidget);
    expect(find.text('Apply to'), findsNWidgets(3));
  });

  testWidgets('there is no Save button, choosing a target saves it at once', (tester) async {
    fakeChannel(sdkInt: 32);
    await pumpScreen(tester);
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.text('Lock').first);
    await tester.pumpAndSettle();

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PersistenceKeys.quickTileWotdTarget), isNotNull);
    expect(prefs.getString(PersistenceKeys.quickTileCategoryTarget), isNotNull);
  });

  testWidgets('opening the screen seeds a working config for every tile', (tester) async {
    fakeChannel(sdkInt: 32);
    await pumpScreen(tester);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(PersistenceKeys.quickTileCategoryTarget), isNotNull);
    expect(prefs.getString(PersistenceKeys.quickTileWotdTarget), isNotNull);
  });

  testWidgets('keeps a saved category that the category list no longer has', (tester) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      PersistenceKeys.quickTileCategoryName: 'Diwali',
      PersistenceKeys.quickTileCategorySource: 'pexels',
      PersistenceKeys.quickTileCategoryTarget: 'both',
    });
    fakeChannel(sdkInt: 32);
    await pumpScreen(tester);

    expect(tester.widget<PrismChip>(find.widgetWithText(PrismChip, 'Diwali')).selected, isTrue);
    expect(tester.widget<PrismChip>(find.widgetWithText(PrismChip, 'Nature')).selected, isFalse);
  });

  testWidgets('adds no extra chip for a category the list has', (tester) async {
    fakeChannel(sdkInt: 32);
    await pumpScreen(tester);

    expect(find.widgetWithText(PrismChip, 'AI Art'), findsOneWidget);
    expect(tester.widget<PrismChip>(find.widgetWithText(PrismChip, 'AI Art')).selected, isTrue);
  });

  testWidgets('shows one add button per tile on Android 13 and up', (tester) async {
    fakeChannel(sdkInt: 33);
    await pumpScreen(tester);

    expect(find.text('Add to Quick Settings'), findsNWidgets(3));
  });

  testWidgets('hides the add buttons below Android 13', (tester) async {
    fakeChannel(sdkInt: 32);
    await pumpScreen(tester);

    expect(find.text('Add to Quick Settings'), findsNothing);
  });

  testWidgets('tapping a button asks the system, shows a snackbar and tracks the result', (tester) async {
    fakeChannel(sdkInt: 34);
    await pumpScreen(tester);

    await tester.tap(find.text('Add to Quick Settings').at(1));
    await tester.pumpAndSettle();

    expect(calls.where((c) => c.method == 'requestAddTile').single.arguments, 'wotd');
    expect(find.text('Tile added to Quick Settings.'), findsOneWidget);
    final QuickTileAddRequestedEvent event = analytics.events.whereType<QuickTileAddRequestedEvent>().single;
    expect(event.tile, 'wotd');
    expect(event.result, 'added');
  });

  testWidgets('shows a calm message when the system declines', (tester) async {
    fakeChannel(sdkInt: 34, addResult: 0);
    await pumpScreen(tester);

    await tester.tap(find.text('Add to Quick Settings').first);
    await tester.pumpAndSettle();

    expect(find.text('Tile not added. You can add it any time.'), findsOneWidget);
    expect(analytics.events.whereType<QuickTileAddRequestedEvent>().single.result, 'notAdded');
  });
}
