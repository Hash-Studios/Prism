import 'dart:async';

import 'package:Prism/auth/badge_model.dart' as prism;
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/session/views/pages/settings_screen.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';

class _MockCacheMaintenanceService extends Mock implements CacheMaintenanceService {}

class _MockSessionRepository extends Mock implements SessionRepository {}

class _MockCategoryFeedBloc extends MockBloc<CategoryFeedEvent, CategoryFeedState> implements CategoryFeedBloc {}

class _MockFavouriteWallsBloc extends MockBloc<FavouriteWallsEvent, FavouriteWallsState>
    implements FavouriteWallsBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final haptics = <Object?>[];
  final messages = <String>[];
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  const purchasesChannel = MethodChannel('purchases_flutter');

  setUp(() async {
    haptics.clear();
    messages.clear();
    PrismHaptics.enabled = true;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate') haptics.add(call.arguments);
      return null;
    });
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      messages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    getIt.registerSingleton<CacheMaintenanceService>(_MockCacheMaintenanceService());
    final user = PrismUsersV2(
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
      loggedIn: true,
      badges: <prism.Badge>[],
      subPrisms: <String>[],
      coins: 0,
      transactions: <PrismTransaction>[],
      name: 'Tester',
    );
    final sessionRepository = _MockSessionRepository();
    when(() => sessionRepository.currentUser).thenReturn(user);
    getIt.registerSingleton<SessionRepository>(sessionRepository);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    messenger.setMockMethodCallHandler(purchasesChannel, null);
    PrismHaptics.enabled = true;
    debugDefaultTargetPlatformOverride = null;
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  testWidgets('haptics switch persists off and enabling it plays one selection', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    expect(haptics, isEmpty);
    await tester.tap(find.text('Haptic Feedback'));
    await tester.pump();

    final settings = getIt<SettingsLocalDataSource>();
    expect(settings.get<bool>('hapticsEnabled', defaultValue: true), isFalse);
    expect(PrismHaptics.enabled, isFalse);
    expect(haptics, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    final tile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Haptic Feedback'));
    expect(tile.value, isFalse);
    await tester.tap(find.text('Haptic Feedback'));
    await tester.pump();
    expect(settings.get<bool>('hapticsEnabled', defaultValue: false), isTrue);
    expect(PrismHaptics.enabled, isTrue);
    expect(haptics, <String>['HapticFeedbackType.selectionClick']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('restore progress is silent and a failed restore plays only error', (tester) async {
    final pendingRestore = Completer<Object?>();
    messenger.setMockMethodCallHandler(purchasesChannel, (call) => pendingRestore.future);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.scrollUntilVisible(find.text('Restore Purchases'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Restore Purchases'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore Purchases'));
    await tester.pump();

    expect(messages, <String>['Restoring purchases…']);
    expect(haptics, isEmpty);
    pendingRestore.completeError(PlatformException(code: 'restore_failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(messages.last, 'Could not restore purchases. Please try again.');
    expect(haptics, <String>['HapticFeedbackType.errorNotification']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final succeeds in <bool>[true, false]) {
    testWidgets('clear favourites reports the ${succeeds ? 'success' : 'failure'} outcome once', (tester) async {
      registerFallbackValue(const FavouriteWallsEvent.refreshRequested());
      final bloc = _MockFavouriteWallsBloc();
      final states = StreamController<FavouriteWallsState>.broadcast();
      addTearDown(states.close);
      final loaded = FavouriteWallsState.initial().copyWith(status: LoadStatus.success, userId: 'user-1');
      when(() => bloc.state).thenReturn(loaded);
      when(() => bloc.stream).thenAnswer((_) => states.stream);
      when(() => bloc.add(any(that: isA<FavouriteWallsEvent>()))).thenAnswer((invocation) {
        final event = invocation.positionalArguments.first as FavouriteWallsEvent;
        final outcome = loaded.copyWith(
          actionStatus: succeeds ? ActionStatus.success : ActionStatus.failure,
          completedOperationId: event.whenOrNull(clearRequested: (int operationId) => operationId) ?? 0,
        );
        when(() => bloc.state).thenReturn(outcome);
        states.add(outcome);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider<FavouriteWallsBloc>.value(value: bloc, child: const SettingsScreen()),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Clear favourite walls'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Clear favourite walls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear favourite walls'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('YES'));
      await tester.pumpAndSettle();

      expect(messages, <String>[
        if (succeeds)
          'Cleared all favourite wallpapers!'
        else
          'Could not clear favourite wallpapers. Please try again.',
      ]);
      expect(haptics, <String>[
        if (succeeds) 'HapticFeedbackType.successNotification' else 'HapticFeedbackType.errorNotification',
      ]);
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('account deletion copy describes wallpapers only', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.scrollUntilVisible(find.text('Delete Account'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your uploaded wallpapers will remain visible'), findsOneWidget);
    expect(find.textContaining('setups'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('personalise section lists the Android rows and no dead download quality row', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('PERSONALISE'), findsOneWidget);
    expect(find.text('Auto-rotate wallpapers'), findsOneWidget);
    expect(find.text('Live wallpapers'), findsOneWidget);
    expect(find.text('Quick tiles'), findsOneWidget);
    expect(find.text('Wallpaper history'), findsOneWidget);
    expect(find.text('Default action for Set'), findsOneWidget);
    expect(find.text('ANDROID WIDGETS'), findsNothing);
    expect(find.text('Download Quality'), findsNothing);
    expect(find.text('Promotional Alerts'), findsNothing);
    expect(find.text('Notification preferences'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS hides the whole personalise section, including wallpaper history', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    expect(find.text('PERSONALISE'), findsNothing);
    expect(find.text('Wallpaper history'), findsNothing);
    expect(find.text('Live wallpapers'), findsNothing);
    expect(find.text('Quick tiles'), findsNothing);
    expect(find.text('Default action for Set'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the default action for Set is saved from the sheet', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    final settings = getIt<SettingsLocalDataSource>();
    expect(settings.get<String>(PersistenceKeys.defaultApplyTarget, defaultValue: 'ask'), 'ask');
    expect(find.text('Ask every time'), findsOneWidget);

    await tester.tap(find.text('Default action for Set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lock screen'));
    await tester.pumpAndSettle();

    expect(settings.get<String>(PersistenceKeys.defaultApplyTarget, defaultValue: 'ask'), 'lock');
    expect(find.text('Lock screen'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  test('anime wallpapers map to 110 and any value from 110 reads as on', () {
    expect(categoriesForAnime(true), 110);
    expect(categoriesForAnime(false), 100);
    expect(animeEnabledFromCategories(100), isFalse);
    expect(animeEnabledFromCategories(110), isTrue);
    expect(animeEnabledFromCategories(111), isTrue);
  });

  testWidgets('the anime switch writes 110 and refreshes the category feed', (tester) async {
    useTallSurface(tester);
    final bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(CategoryFeedState.initial());
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<CategoryFeedBloc>.value(value: bloc, child: const SettingsScreen()),
      ),
    );

    await tester.tap(find.text('Show Anime Wallpapers'));
    await tester.pump();

    expect(getIt<SettingsLocalDataSource>().get<int>('WHcategories', defaultValue: 100), 110);
    verify(() => bloc.add(const CategoryFeedEvent.refreshRequested())).called(1);
    final tile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Show Anime Wallpapers'));
    expect(tile.value, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('storage sizes read in B, KB, MB and GB', () {
    expect(formatStorageBytes(512), '512 B');
    expect(formatStorageBytes(2048), '2 KB');
    expect(formatStorageBytes(5 * 1024 * 1024 + 512 * 1024), '5.5 MB');
    expect(formatStorageBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
  });

  testWidgets('logout asks first and does nothing on Cancel', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsNothing);
    expect(messages, isEmpty);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
