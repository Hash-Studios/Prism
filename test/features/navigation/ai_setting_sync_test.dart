import 'dart:async';

import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/wallpaper/ai_content_filter.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart';
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/session/views/pages/settings_screen.dart';
import 'package:Prism/features/wallpaper_history/data/history_wall_stores.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _MockCacheMaintenanceService extends Mock implements CacheMaintenanceService {}

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _MockSessionRepository extends Mock implements SessionRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SettingsLocalDataSource settings;
  late FakeAppAnalytics analytics;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  setUp(() async {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    await getIt.reset();
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(settings));
    getIt.registerSingleton<RecentlyViewedStore>(RecentlyViewedStore(settings));
    final cacheMaintenance = _MockCacheMaintenanceService();
    when(cacheMaintenance.retainedAssetBytes).thenAnswer((_) async => 0);
    getIt.registerSingleton<CacheMaintenanceService>(cacheMaintenance);
    final session = _MockSessionRepository();
    when(() => session.currentUser).thenReturn(
      PrismUsersV2(
        username: 'tester',
        email: 'tester@example.com',
        id: 'user-1',
        createdAt: '',
        premium: false,
        lastLoginAt: '',
        links: <String, String>{},
        followers: <String>[],
        following: <String>[],
        profilePhoto: '',
        bio: '',
        loggedIn: false,
        badges: [],
        subPrisms: <String>[],
        coins: 0,
        transactions: [],
        name: 'Tester',
      ),
    );
    getIt.registerSingleton<SessionRepository>(session);
  });

  tearDown(() async {
    LowDataMode.enabled.value = false;
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
    await tester.pump();
  }

  Future<void> pumpSettings(WidgetTester tester) {
    final bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(CategoryFeedState.initial());
    return pumpApp(tester, BlocProvider<CategoryFeedBloc>.value(value: bloc, child: const SettingsScreen()));
  }

  Future<void> openTune(WidgetTester tester) async {
    final bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(CategoryFeedState.initial());
    await pumpApp(
      tester,
      BlocProvider<CategoryFeedBloc>.value(
        value: bloc,
        child: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(openPersonalizedFeedSettingsBottomSheet(context)),
              child: const Text('Open tune'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open tune'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Hide AI'));
  }

  bool chipSelected(WidgetTester tester) =>
      tester
          .getSemantics(find.bySemanticsLabel('Hide AI'))
          .getSemanticsData()
          .flagsCollection
          .isSelected
          .toBoolOrNull() ==
      true;

  testWidgets('turning the Settings switch off selects the Hide AI chip in the Tune sheet', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpSettings(tester);
    await tester.tap(find.text('Show AI-generated wallpapers'));
    await tester.pump();
    expect(AiContentFilter.showsAi(settings), isFalse);

    await tester.pumpWidget(const SizedBox());
    await openTune(tester);

    expect(chipSelected(tester), isTrue);
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('saving the chip off in the Tune sheet turns the Settings switch back on', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await AiContentFilter.setShowsAi(settings, false);
    await openTune(tester);
    expect(chipSelected(tester), isTrue);

    await tester.tap(find.text('Hide AI'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(AiContentFilter.showsAi(settings), isTrue);

    await tester.pumpWidget(const SizedBox());
    await pumpSettings(tester);

    final row = find.ancestor(of: find.text('Show AI-generated wallpapers'), matching: find.byType(MergeSemantics));
    expect(tester.widget<Switch>(find.descendant(of: row.first, matching: find.byType(Switch))).value, isTrue);
    handle.dispose();
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('saving an AI setting change refreshes once and tracks one toggle', (tester) async {
    personalizedFeedSettingsRevision.value = 0;
    var revisionChanges = 0;
    void countRevision() => revisionChanges++;
    personalizedFeedSettingsRevision.addListener(countRevision);
    addTearDown(() => personalizedFeedSettingsRevision.removeListener(countRevision));

    await openTune(tester);
    await tester.tap(find.text('Hide AI'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(AiContentFilter.showsAi(settings), isFalse);
    expect(revisionChanges, 1);
    expect(analytics.events.where((event) => event.eventName == 'settings_toggle_changed'), hasLength(1));
  });

  testWidgets('a shared AI setting change updates an already-open Settings screen', (tester) async {
    personalizedFeedSettingsRevision.value = 0;
    await pumpSettings(tester);
    expect(
      tester
          .widget<Switch>(
            find.descendant(
              of: find
                  .ancestor(of: find.text('Show AI-generated wallpapers'), matching: find.byType(MergeSemantics))
                  .first,
              matching: find.byType(Switch),
            ),
          )
          .value,
      isTrue,
    );

    await setShowAiWallpapers(settings, false);
    await tester.pump();

    expect(AiContentFilter.showsAi(settings), isFalse);
    expect(
      tester
          .widget<Switch>(
            find.descendant(
              of: find
                  .ancestor(of: find.text('Show AI-generated wallpapers'), matching: find.byType(MergeSemantics))
                  .first,
              matching: find.byType(Switch),
            ),
          )
          .value,
      isFalse,
    );
    expect(personalizedFeedSettingsRevision.value, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('a no-op shared AI setting write does not publish a revision', () async {
    personalizedFeedSettingsRevision.value = 0;

    expect(await setShowAiWallpapers(settings, true), isFalse);
    expect(personalizedFeedSettingsRevision.value, 0);
  });

  testWidgets('Tune does not track an AI change already made by another caller', (tester) async {
    personalizedFeedSettingsRevision.value = 0;
    await openTune(tester);
    await tester.tap(find.text('Hide AI'));
    await tester.pumpAndSettle();

    await setShowAiWallpapers(settings, false);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(AiContentFilter.showsAi(settings), isFalse);
    expect(analytics.events.where((event) => event.eventName == 'settings_toggle_changed'), isEmpty);
  });

  testWidgets('Tune persists its selected AI value when the setting changes while the sheet is open', (tester) async {
    personalizedFeedSettingsRevision.value = 0;
    await openTune(tester);
    await setShowAiWallpapers(settings, false);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Save'));
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(AiContentFilter.showsAi(settings), isTrue);
    expect(analytics.events.where((event) => event.eventName == 'settings_toggle_changed'), hasLength(1));
  });
}
