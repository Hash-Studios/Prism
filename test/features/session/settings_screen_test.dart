import 'dart:async';
import 'dart:io';

import 'package:Prism/auth/badge_model.dart' as prism;
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/account/delete_account_service.dart';
import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
import 'package:Prism/core/platform/pigeon/prism_media_api.g.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism/prism_card.dart';
import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/features/ads/data/ad_consent.dart';
import 'package:Prism/features/category_feed/biz/bloc/category_feed_bloc.j.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/features/navigation/views/widgets/personalized_feed_settings_bottom_sheet.dart'
    show personalizedFeedSettingsRevision;
import 'package:Prism/features/session/data/low_data_mode.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/session/views/pages/settings_screen.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/main.dart' as app_main;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/wait_for_real_io.dart';

class _MockCacheMaintenanceService extends Mock implements CacheMaintenanceService {}

class _MockSessionRepository extends Mock implements SessionRepository {}

class _RecordingUrlLauncher extends UrlLauncherPlatform {
  _RecordingUrlLauncher({required this.opens});

  final bool opens;
  final List<String> urls = <String>[];

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    urls.add(url);
    return opens;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

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

  late _MockSessionRepository sessionRepository;
  late Future<bool> Function() originalSignOut;
  late DeleteAccountService originalDeleteService;

  PrismUsersV2 testUser({bool loggedIn = true, bool premium = false}) => PrismUsersV2(
    username: 'tester',
    email: 'tester@example.com',
    id: 'user-1',
    createdAt: '',
    premium: premium,
    lastLoginAt: '',
    links: <String, String>{},
    followers: <String>[],
    following: <String>[],
    profilePhoto: '',
    bio: '',
    loggedIn: loggedIn,
    badges: <prism.Badge>[],
    subPrisms: <String>[],
    coins: 0,
    transactions: <PrismTransaction>[],
    name: 'Tester',
  );

  void signInAs({bool loggedIn = true, bool premium = false}) {
    when(() => sessionRepository.currentUser).thenReturn(testUser(loggedIn: loggedIn, premium: premium));
  }

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
      if (call.method == 'showToast') messages.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    await getIt.reset();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(InMemoryLocalStore()));
    final cacheMaintenance = _MockCacheMaintenanceService();
    when(cacheMaintenance.retainedAssetBytes).thenAnswer((_) async => 0);
    getIt.registerSingleton<CacheMaintenanceService>(cacheMaintenance);
    sessionRepository = _MockSessionRepository();
    when(() => sessionRepository.currentUser).thenReturn(testUser());
    getIt.registerSingleton<SessionRepository>(sessionRepository);
    originalSignOut = settingsSignOut;
    originalDeleteService = DeleteAccountService.instance;
  });

  tearDown(() async {
    settingsSignOut = originalSignOut;
    DeleteAccountService.instance = originalDeleteService;
    AdConsent.instance = AdConsent();
    LowDataMode.enabled.value = false;
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    messenger.setMockMethodCallHandler(toastChannel, null);
    messenger.setMockMethodCallHandler(purchasesChannel, null);
    PrismHaptics.enabled = true;
    debugDefaultTargetPlatformOverride = null;
    AnalyticsRuntime.reset();
    await getIt.reset();
  });

  Switch switchOf(WidgetTester tester, String label) => tester.widget<Switch>(
    find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(PrismRow)).first,
      matching: find.byType(Switch),
    ),
  );

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('haptics switch persists off and enabling it plays one selection', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
    expect(haptics, isEmpty);
    await tester.tap(find.text('Haptic feedback'));
    await tester.pump();

    final settings = getIt<SettingsLocalDataSource>();
    expect(settings.get<bool>('hapticsEnabled', defaultValue: true), isFalse);
    expect(PrismHaptics.enabled, isFalse);
    expect(haptics, isEmpty);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
    expect(switchOf(tester, 'Haptic feedback').value, isFalse);
    await tester.tap(find.text('Haptic feedback'));
    await tester.pump();
    expect(settings.get<bool>('hapticsEnabled', defaultValue: false), isTrue);
    expect(PrismHaptics.enabled, isTrue);
    expect(haptics, <String>['HapticFeedbackType.selectionClick']);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('restore progress is silent and a failed restore plays only error', (tester) async {
    final pendingRestore = Completer<Object?>();
    messenger.setMockMethodCallHandler(purchasesChannel, (call) => pendingRestore.future);
    useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
    await tester.scrollUntilVisible(find.text('Restore purchases'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Restore purchases'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => tester.tap(find.text('Restore purchases')));
    await tester.pump();

    expect(messages, <String>['Restoring purchases…']);
    expect(haptics, isEmpty);
    pendingRestore.completeError(PlatformException(code: 'restore_failed'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(messages.last, 'Could not restore purchases. Try again.');
    expect(haptics, <String>['HapticFeedbackType.errorNotification']);
    await tester.pump(const Duration(seconds: 1));
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final disposed in <bool>[false, true]) {
    testWidgets('restore failure is silent after ${disposed ? 'leaving settings' : 'changing accounts'}', (
      tester,
    ) async {
      final pendingRestore = Completer<Object?>();
      unawaited(pendingRestore.future.catchError((Object _) => null));
      messenger.setMockMethodCallHandler(purchasesChannel, (call) => pendingRestore.future);
      useTallSurface(tester);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      );
      await tester.scrollUntilVisible(find.text('Restore purchases'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Restore purchases'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Restore purchases')));
      await tester.pump();
      if (disposed) {
        await tester.pumpWidget(const SizedBox());
      } else {
        when(() => sessionRepository.currentUser).thenReturn(testUser()..id = 'different-user');
      }
      pendingRestore.completeError(PlatformException(code: 'restore_failed'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      expect(messages, <String>['Restoring purchases…']);
      expect(haptics, isEmpty);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  for (final outcome in <String>['confirmed', 'pending', 'empty']) {
    testWidgets('restore reports the $outcome store result', (tester) async {
      await getIt.unregister<SessionRepository>();
      final backend = CoinsTestBackend();
      await backend.install();
      final paid = outcome != 'empty';
      final entitlement = <String, Object?>{
        'identifier': 'prism_v3_pro_access',
        'isActive': true,
        'willRenew': true,
        'latestPurchaseDate': '2026-10-01T00:00:00Z',
        'originalPurchaseDate': '2026-10-01T00:00:00Z',
        'productIdentifier': 'prism_pro_yearly',
        'isSandbox': false,
        'expirationDate': '2027-10-01T00:00:00Z',
      };
      final customer = <String, Object?>{
        'entitlements': <String, Object?>{
          'all': <String, Object?>{if (paid) 'prism_v3_pro_access': entitlement},
          'active': <String, Object?>{if (paid) 'prism_v3_pro_access': entitlement},
        },
        'allPurchaseDates': <String, Object?>{},
        'activeSubscriptions': <String>[],
        'allPurchasedProductIdentifiers': <String>[],
        'nonSubscriptionTransactions': <Object?>[],
        'firstSeen': '',
        'originalAppUserId': backend.userId,
        'allExpirationDates': <String, Object?>{},
        'requestDate': '',
      };
      var restoreCalls = 0;
      messenger.setMockMethodCallHandler(purchasesChannel, (call) async {
        switch (call.method) {
          case 'logIn':
            return <String, Object?>{'customerInfo': customer, 'created': false};
          case 'restorePurchases':
            restoreCalls++;
            return customer;
          case 'getCustomerInfo':
            throw StateError('Restore must use the store result.');
          default:
            return null;
        }
      });
      messenger.setMockDecodedMessageHandler<Object?>(
        const BasicMessageChannel<Object?>(
          'dev.flutter.pigeon.cloud_functions_platform_interface.CloudFunctionsHostApi.call',
          StandardMessageCodec(),
        ),
        (_) async => <Object?>[
          if (outcome == 'pending')
            <String, Object?>{}
          else
            <String, Object?>{'premium': paid, 'subscriptionTier': paid ? 'pro' : 'free'},
        ],
      );
      useTallSurface(tester);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      );
      await tester.scrollUntilVisible(find.text('Restore purchases'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Restore purchases'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester.tap(find.text('Restore purchases')));
      await waitForRealIo(tester, () => messages.length > 1, reason: '$outcome restore result');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(seconds: 1));

      final expected = switch (outcome) {
        'confirmed' => 'Purchases restored.',
        'pending' => 'Purchases restored. Pro can take a minute to unlock.',
        _ => 'No purchases to restore for this account.',
      };
      expect(restoreCalls, 1);
      expect(messages, <String>['Restoring purchases…', expected]);
      expect(haptics, <String>[
        if (outcome == 'empty') 'HapticFeedbackType.errorNotification' else 'HapticFeedbackType.successNotification',
      ]);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

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
      useTallSurface(tester);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,

          home: BlocProvider<FavouriteWallsBloc>.value(value: bloc, child: const SettingsScreen()),
        ),
      );
      await tester.scrollUntilVisible(
        find.text('Clear favourite wallpapers'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Clear favourite wallpapers'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear favourite wallpapers'));
      await tester.pumpAndSettle();
      expect(find.text('Clear all favourites?'), findsOneWidget);
      expect(find.textContaining('This cannot be undone.'), findsOneWidget);
      await tester.tap(find.widgetWithText(PrismButton, 'Clear favourites'));
      await tester.pumpAndSettle();

      expect(messages, <String>[
        if (succeeds) 'Cleared all favourite wallpapers.' else "Couldn't clear favourite wallpapers. Try again.",
      ]);
      // The confirm button plays its own tap haptic. This test is about the outcome haptic.
      expect(haptics.where((h) => h != 'HapticFeedbackType.lightImpact'), <String>[
        if (succeeds) 'HapticFeedbackType.successNotification' else 'HapticFeedbackType.errorNotification',
      ]);
      await tester.pump(const Duration(seconds: 1));
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('personalise section lists the Android rows and no dead download quality row', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );

    expect(find.text('Personalise'), findsOneWidget);
    expect(find.text('Auto-rotate wallpapers'), findsOneWidget);
    expect(find.text('Change automatically'), findsNothing);
    expect(find.text('Live wallpapers'), findsOneWidget);
    expect(find.text('Quick tiles'), findsOneWidget);
    expect(find.text('Wallpaper history'), findsOneWidget);
    expect(find.text('Default action for Set'), findsOneWidget);
    expect(find.text('ANDROID WIDGETS'), findsNothing);
    expect(find.text('Download Quality'), findsNothing);
    expect(find.text('Promotional Alerts'), findsNothing);
    expect(find.text('Notification preferences'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS 16 personalise section has only Change automatically, no Android rows', (tester) async {
    useTallSurface(tester);
    final Future<int?> Function() originalVersion = iosMajorVersion;
    iosMajorVersion = () async => 16;
    addTearDown(() => iosMajorVersion = originalVersion);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Personalise'), findsOneWidget);
    expect(find.text('Change automatically'), findsOneWidget);
    expect(find.text('Auto-rotate wallpapers'), findsNothing);
    expect(find.text('Wallpaper history'), findsNothing);
    expect(find.text('Live wallpapers'), findsNothing);
    expect(find.text('Quick tiles'), findsNothing);
    expect(find.text('Default action for Set'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS 15 hides Change automatically', (tester) async {
    useTallSurface(tester);
    final Future<int?> Function() originalVersion = iosMajorVersion;
    iosMajorVersion = () async => 15;
    addTearDown(() => iosMajorVersion = originalVersion);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('Personalise'), findsNothing);
    expect(find.text('Change automatically'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS hides Change automatically until the version resolves', (tester) async {
    useTallSurface(tester);
    final Completer<int?> version = Completer<int?>();
    final Future<int?> Function() originalVersion = iosMajorVersion;
    iosMajorVersion = () => version.future;
    addTearDown(() => iosMajorVersion = originalVersion);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
    await tester.pump();
    expect(find.text('Change automatically'), findsNothing);

    version.complete(17);
    await tester.pump();
    await tester.pump();
    expect(find.text('Change automatically'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the default action for Set is saved from the sheet', (tester) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SettingsScreen(),
      ),
    );
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
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<CategoryFeedBloc>.value(value: bloc, child: const SettingsScreen()),
      ),
    );

    await tester.tap(find.text('Show anime wallpapers'));
    await tester.pump();

    expect(getIt<SettingsLocalDataSource>().get<int>('WHcategories', defaultValue: 100), 110);
    verify(() => bloc.add(const CategoryFeedEvent.refreshRequested())).called(1);
    expect(switchOf(tester, 'Show anime wallpapers').value, isTrue);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('storage sizes read in B, KB, MB and GB', () {
    final AppLocalizationsEn l10n = AppLocalizationsEn();
    expect(formatStorageBytes(l10n, 512), '512 B');
    expect(formatStorageBytes(l10n, 2048), '2 KB');
    expect(formatStorageBytes(l10n, 5 * 1024 * 1024 + 512 * 1024), '5.5 MB');
    expect(formatStorageBytes(l10n, 3 * 1024 * 1024 * 1024), '3.00 GB');
  });

  Future<void> pumpSettings(WidgetTester tester, {ThemeData? theme}) async {
    useTallSurface(tester);
    await tester.pumpWidget(
      app_main.RestartWidget(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await tester.ensureVisible(find.widgetWithText(PrismRow, 'Delete account'));
    await tester.tap(find.widgetWithText(PrismRow, 'Delete account'));
    // Glint loops, so pump a bounded time instead of settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('account deletion', () {
    testWidgets('the dialog keeps the wallpaper promise and says a Google or Apple prompt follows', (tester) async {
      await pumpSettings(tester);
      await openDeleteDialog(tester);

      expect(find.textContaining('Your uploaded wallpapers will remain visible as "Deleted Account"'), findsOneWidget);
      expect(find.text(AppLocalizationsEn().accountDeleteAccountReauthNote), findsOneWidget);
      expect(find.text('You will confirm with Google or Apple next.'), findsOneWidget);
      expect(find.textContaining('setups'), findsNothing);
      expect(find.textContaining('This action cannot be undone.'), findsOneWidget);
    });

    testWidgets('closing the Google or Apple prompt is silent and keeps the account', (tester) async {
      final calls = <String>[];
      DeleteAccountService.instance = DeleteAccountService(
        reauthenticate: () async => throw const GoogleSignInException(code: GoogleSignInExceptionCode.canceled),
        deleteOnServer: () async => calls.add('server'),
      );
      await pumpSettings(tester);
      await openDeleteDialog(tester);

      await tester.tap(find.widgetWithText(PrismButton, 'Delete account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(calls, isEmpty);
      expect(messages, isEmpty);
      // The confirm button plays its own selection tap. A cancelled prompt adds no outcome haptic.
      expect(haptics.where((h) => h != 'HapticFeedbackType.selectionClick'), isEmpty);
      expect(find.text('Deleting your account'), findsNothing);
      expect(find.widgetWithText(PrismRow, 'Delete account'), findsOneWidget);
    });

    testWidgets('a real failure shows one error toast and closes the loader', (tester) async {
      DeleteAccountService.instance = DeleteAccountService(
        reauthenticate: () async {},
        deleteOnServer: () async => throw StateError('server down'),
      );
      await pumpSettings(tester);
      await openDeleteDialog(tester);

      await tester.tap(find.widgetWithText(PrismButton, 'Delete account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(messages, <String>['Something went wrong. Try again.']);
      expect(find.text('Deleting your account'), findsNothing);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('after success the loader closes first and the app restarts', (tester) async {
      final cleared = <String>[];
      var signedOut = false;
      final server = Completer<void>();
      DeleteAccountService.instance = DeleteAccountService(
        reauthenticate: () async {},
        deleteOnServer: () => server.future,
        signOut: () async => signedOut = true,
        clearLocalData: (userId) async => cleared.add(userId),
      );
      await pumpSettings(tester);
      await openDeleteDialog(tester);

      await tester.tap(find.widgetWithText(PrismButton, 'Delete account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Deleting your account'), findsOneWidget);

      server.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Deleting your account'), findsNothing);
      expect(signedOut, isTrue);
      expect(cleared, <String>['user-1']);
      expect(messages, isEmpty);
    });
  });

  group('log out', () {
    testWidgets('the dialog says what is cleared and what stays', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsOneWidget);
      expect(
        find.text(
          'Signing out clears history and learned taste on this device. Favourites, coins and profile stay with your account.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('You can sign in again'), findsNothing);
    });

    testWidgets('a failed sign out shows the same error toast as the drawer', (tester) async {
      settingsSignOut = () async => false;
      await pumpSettings(tester);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrismButton, 'Log out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(messages, <String>[AppLocalizationsEn().accountLogoutFailed]);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('an exception while signing out shows the error toast too', (tester) async {
      settingsSignOut = () async => throw StateError('no network');
      await pumpSettings(tester);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrismButton, 'Log out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(messages, <String>[AppLocalizationsEn().accountLogoutFailed]);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('a good sign out shows no success toast and leaves the screen to the restart', (tester) async {
      var signOuts = 0;
      settingsSignOut = () async {
        signOuts += 1;
        return true;
      };
      await pumpSettings(tester);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrismButton, 'Log out'));
      await tester.pumpAndSettle();

      expect(signOuts, 1);
      expect(messages, isEmpty);
    });

    testWidgets('Cancel does nothing', (tester) async {
      var signOuts = 0;
      settingsSignOut = () async {
        signOuts += 1;
        return true;
      };
      await pumpSettings(tester);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Log out?'), findsNothing);
      expect(signOuts, 0);
      expect(messages, isEmpty);
    });
  });

  group('guest', () {
    testWidgets('the sign in row names what an account keeps, and Restore purchases stays visible', (tester) async {
      signInAs(loggedIn: false);
      await pumpSettings(tester);

      expect(find.text('Sign in to keep your favourites, coins and profile'), findsOneWidget);
      expect(find.textContaining('sync data across devices'), findsNothing);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Delete account'), findsNothing);
      expect(find.text('Log out'), findsNothing);
    });

    testWidgets('Restore purchases does not sit in the account card', (tester) async {
      await pumpSettings(tester);

      final account = find.ancestor(of: find.text('Log out'), matching: find.byType(PrismGroup));
      expect(find.descendant(of: account, matching: find.text('Restore purchases')), findsNothing);
      expect(find.text('Restore purchases'), findsOneWidget);
    });

    testWidgets('a premium user sees Manage subscription next to Restore purchases', (tester) async {
      signInAs(premium: true);
      await pumpSettings(tester);

      expect(find.text('Manage subscription'), findsOneWidget);
      expect(find.text('Buy premium'), findsNothing);
      expect(find.text('Restore purchases'), findsOneWidget);
    });
  });

  group('privacy and data', () {
    testWidgets('lists the policy, terms, learned taste and delete account', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Privacy and data'), findsOneWidget);
      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Terms of use'), findsOneWidget);
      expect(find.text('Clear learned taste'), findsOneWidget);
      expect(find.widgetWithText(PrismRow, 'Delete account'), findsOneWidget);
    });

    testWidgets('a guest has no Delete account row', (tester) async {
      signInAs(loggedIn: false);
      await pumpSettings(tester);

      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.text('Delete account'), findsNothing);
    });

    testWidgets('Ad privacy choices is hidden when consent options are not required', (tester) async {
      AdConsent.instance = AdConsent(privacyOptionsRequired: () async => false);
      await pumpSettings(tester);
      await tester.pump();

      expect(find.text('Ad privacy choices'), findsNothing);
    });

    testWidgets('Ad privacy choices shows when required and opens the privacy options form', (tester) async {
      var shown = 0;
      AdConsent.instance = AdConsent(privacyOptionsRequired: () async => true, showPrivacyOptions: () async => shown++);
      await pumpSettings(tester);
      await tester.pump();

      expect(find.text('Ad privacy choices'), findsOneWidget);
      await tester.tap(find.text('Ad privacy choices'));
      await tester.pump();

      expect(shown, 1);
    });

    testWidgets('Privacy policy and Terms open in the browser', (tester) async {
      final launcher = _RecordingUrlLauncher(opens: true);
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = launcher;
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      await pumpSettings(tester);

      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      await tester.tap(find.text('Terms of use'));
      await tester.pump();

      expect(launcher.urls, <String>['https://prismwalls.com/privacy', 'https://prismwalls.com/terms']);
      expect(messages, isEmpty);
    });

    testWidgets('a link that cannot open shows one error toast', (tester) async {
      final previous = UrlLauncherPlatform.instance;
      UrlLauncherPlatform.instance = _RecordingUrlLauncher(opens: false);
      addTearDown(() => UrlLauncherPlatform.instance = previous);
      await pumpSettings(tester);

      await tester.tap(find.text('Privacy policy'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(messages, <String>["Couldn't open the link. Try again."]);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Clear learned taste says so when nothing was learned', (tester) async {
      getIt.registerSingleton<TasteSignalStore>(TasteSignalStore(getIt<SettingsLocalDataSource>()));
      await pumpSettings(tester);

      await tester.tap(find.text('Clear learned taste'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(BottomSheet), findsNothing);
      expect(messages, <String>['Prism has not learned anything yet.']);
      await tester.pump(const Duration(seconds: 1));
    });

    Future<TasteSignalStore> storeWithSignals() async {
      final store = TasteSignalStore(getIt<SettingsLocalDataSource>());
      await store.recordAll(<TasteSignal>[
        TasteSignal(action: TasteAction.open, at: DateTime.utc(2026), terms: const <String>['forest']),
        TasteSignal(action: TasteAction.favourite, at: DateTime.utc(2026, 1, 2), terms: const <String>['sea']),
      ]);
      getIt.registerSingleton<TasteSignalStore>(store);
      return store;
    }

    testWidgets('Clear learned taste asks first, with the count, and Cancel keeps it', (tester) async {
      final store = await storeWithSignals();
      await pumpSettings(tester);

      await tester.tap(find.text('Clear learned taste'));
      await tester.pumpAndSettle();

      expect(find.text('Clear learned taste?'), findsOneWidget);
      expect(find.textContaining('the 2 things'), findsOneWidget);
      expect(find.textContaining('This cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(store.read(), hasLength(2));
      expect(messages, isEmpty);
    });

    testWidgets('confirming clears the taste and refreshes the home feed', (tester) async {
      final store = await storeWithSignals();
      final revision = personalizedFeedSettingsRevision.value;
      await pumpSettings(tester);

      await tester.tap(find.text('Clear learned taste'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrismButton, 'Clear'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(store.read(), isEmpty);
      expect(personalizedFeedSettingsRevision.value, revision + 1);
      expect(messages, <String>['Learned taste cleared.']);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('help', () {
    testWidgets('Report a problem replaces Restart App', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Report a problem'), findsOneWidget);
      expect(find.text('Restart App'), findsNothing);
      expect(find.text('Restart app'), findsNothing);
    });

    testWidgets('Report a problem opens the preview sheet', (tester) async {
      messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), (call) async {
        return <String, Object?>{
          'appName': 'Prism',
          'packageName': 'com.hash.prism',
          'version': '3.4.0',
          'buildNumber': '340',
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(const MethodChannel('dev.fluttercommunity.plus/package_info'), null),
      );
      await pumpSettings(tester);

      await tester.tap(find.text('Report a problem'));
      await tester.pumpAndSettle();

      expect(find.textContaining('It has no email address or sign-in tokens.'), findsOneWidget);
      expect(find.byKey(const Key('report_problem_preview')), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
    });
  });

  group('storage', () {
    Future<void> openSavedOfflineDialog(WidgetTester tester) async {
      final Finder savedOffline = find.text('Saved offline');
      await tester.scrollUntilVisible(savedOffline, 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(savedOffline);
      await tester.tap(savedOffline);
      await tester.pumpAndSettle();
    }

    testWidgets('Data saver is off by default and saves the choice', (tester) async {
      await pumpSettings(tester);

      expect(switchOf(tester, 'Data saver').value, isFalse);
      expect(find.textContaining('carousels do not autoplay'), findsOneWidget);

      await tester.tap(find.text('Data saver'));
      await tester.pump();

      expect(LowDataMode.enabled.value, isTrue);
      expect(getIt<SettingsLocalDataSource>().get<bool>(LowDataMode.settingsKey, defaultValue: false), isTrue);
      expect(switchOf(tester, 'Data saver').value, isTrue);
    });

    testWidgets('the cache size counts tinted wallpapers', (tester) async {
      const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
      const downloadsChannel = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.Prism.PrismMediaHostApi.listDownloads',
        PrismMediaHostApi.pigeonChannelCodec,
      );
      final cacheScanned = Completer<void>();
      messenger.setMockDecodedMessageHandler<Object?>(downloadsChannel, (_) async {
        if (!cacheScanned.isCompleted) cacheScanned.complete();
        return <Object?>[DownloadItemsResult(success: true, items: <String>[])];
      });
      final temp = Directory.systemTemp.createTempSync('prism_settings_temp');
      File('${temp.path}/prism_tint/1_0.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(List<int>.filled(2048, 7));
      messenger.setMockMethodCallHandler(pathChannel, (_) async => temp.path);
      addTearDown(() {
        messenger.setMockMethodCallHandler(pathChannel, null);
        messenger.setMockDecodedMessageHandler<Object?>(downloadsChannel, null);
        temp.deleteSync(recursive: true);
      });

      await pumpSettings(tester);
      // Storage stats request downloads only after the asynchronous cache scan finishes.
      await waitForRealIo(tester, () => cacheScanned.isCompleted, reason: 'settings cache size scan');
      await tester.pump();

      expect(find.text('2 KB of cached images'), findsOneWidget);
    });

    testWidgets('Clear cache asks first, with the size, and Cancel keeps the cache', (tester) async {
      final cache = getIt<CacheMaintenanceService>();
      when(cache.clearTransientCache).thenAnswer((_) async {});
      await pumpSettings(tester);

      await tester.tap(find.text('Clear cache'));
      await tester.pumpAndSettle();
      expect(find.text('Clear cache?'), findsOneWidget);
      expect(find.textContaining('They load again when you need them.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(cache.clearTransientCache);
    });

    testWidgets('confirming Clear cache clears it', (tester) async {
      final cache = getIt<CacheMaintenanceService>();
      when(cache.clearTransientCache).thenAnswer((_) async {});
      await pumpSettings(tester);

      await tester.tap(find.text('Clear cache'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(PrismButton, 'Clear cache'));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 100));
      }

      verify(cache.clearTransientCache).called(1);
      expect(messages, <String>['Cache cleared.']);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Clear all downloads asks first and says it cannot be undone', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Clear all downloads'));
      await tester.pumpAndSettle();

      expect(find.text('Delete all downloads?'), findsOneWidget);
      expect(find.textContaining('This cannot be undone.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(messages, isEmpty);
    });

    testWidgets('Saved offline shows retained size and limit, and cancel preserves retained originals', (tester) async {
      final cache = getIt<CacheMaintenanceService>();
      final Completer<void> retainedReadStarted = Completer<void>();
      final Completer<int> retainedBytes = Completer<int>();
      when(cache.retainedAssetBytes).thenAnswer((_) {
        if (!retainedReadStarted.isCompleted) retainedReadStarted.complete();
        return retainedBytes.future;
      });
      await pumpSettings(tester);

      await waitForRealIo(tester, () => retainedReadStarted.isCompleted, reason: 'retained offline storage size');
      retainedBytes.complete(12 * 1024 * 1024);
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Saved offline'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Saved offline'));
      await waitForRealIo(
        tester,
        () => find.text('12.0 MB used · 512 MiB limit').evaluate().isNotEmpty,
        reason: 'the retained offline storage label',
      );
      expect(find.text('12.0 MB used · 512 MiB limit'), findsOneWidget);

      await openSavedOfflineDialog(tester);
      expect(find.text('Remove saved offline wallpapers?'), findsOneWidget);
      expect(find.textContaining('Downloads, drafts and catalog data stay untouched.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      verifyNever(() => cache.clearRetainedAssets());
    });

    testWidgets('confirming Saved offline removes retained assets and refreshes its size', (tester) async {
      final cache = getIt<CacheMaintenanceService>();
      var retainedBytes = 2048;
      when(cache.retainedAssetBytes).thenAnswer((_) async => retainedBytes);
      when(() => cache.clearRetainedAssets()).thenAnswer((_) {
        retainedBytes = 0;
        return Future<void>.value();
      });
      await pumpSettings(tester);

      await openSavedOfflineDialog(tester);
      await tester.tap(find.text('Remove saved offline'));
      await tester.pumpAndSettle();

      verify(() => cache.clearRetainedAssets()).called(1);
      expect(find.text('0 B used · 512 MiB limit'), findsOneWidget);
      expect(messages, <String>['Saved offline wallpapers removed.']);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('failed Saved offline removal shows an error and keeps the known size', (tester) async {
      final cache = getIt<CacheMaintenanceService>();
      when(cache.retainedAssetBytes).thenAnswer((_) async => 2048);
      when(() => cache.clearRetainedAssets()).thenThrow(StateError('disk unavailable'));
      await pumpSettings(tester);

      await openSavedOfflineDialog(tester);
      await tester.tap(find.text('Remove saved offline'));
      await tester.pumpAndSettle();

      expect(find.text('2 KB used · 512 MiB limit'), findsOneWidget);
      expect(messages, <String>["Couldn't remove saved offline wallpapers. Try again."]);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Clear all downloads copy distinguishes Downloads from saved offline originals', (tester) async {
      await pumpSettings(tester);

      expect(find.textContaining('saved offline copies stay'), findsOneWidget);
      await tester.tap(find.text('Clear all downloads'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Saved offline copies are not affected.'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('copy and theme', () {
    testWidgets('rows use sentence case and say wallpaper, not wall', (tester) async {
      await pumpSettings(tester);

      for (final label in <String>[
        'Haptic feedback',
        'Show anime wallpapers',
        'Clear cache',
        'Clear all downloads',
        'Review status',
        'Share your profile',
        'Clear favourite wallpapers',
        'Buy premium',
        'Restore purchases',
        'Log out',
        'Delete account',
      ]) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      for (final old in <String>['Clear Cache', 'Clear all Downloads', 'Delete Account', 'Logout', 'Review Status']) {
        expect(find.text(old), findsNothing, reason: old);
      }
      expect(find.textContaining('walls'), findsNothing);
    });
  });

  testWidgets('a content filter switch refreshes the home feed settings', (tester) async {
    final bloc = _MockCategoryFeedBloc();
    when(() => bloc.state).thenReturn(CategoryFeedState.initial());
    final revision = personalizedFeedSettingsRevision.value;
    useTallSurface(tester);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,

        home: BlocProvider<CategoryFeedBloc>.value(value: bloc, child: const SettingsScreen()),
      ),
    );

    await tester.tap(find.text('Show anime wallpapers'));
    await tester.pump();

    expect(personalizedFeedSettingsRevision.value, revision + 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  group('grouped layout', () {
    testWidgets('a signed-in user sees the account card and the grouped settings', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Tester'), findsOneWidget);
      expect(find.text('tester@example.com'), findsOneWidget);
      for (final String header in <String>[
        'Account',
        'Appearance',
        'Content',
        'Notifications',
        'Storage',
        'Purchases',
        'Privacy and data',
        'Help',
      ]) {
        expect(find.text(header), findsOneWidget, reason: header);
      }
      expect(find.text('APPEARANCE'), findsNothing);
      expect(find.text('Review status'), findsOneWidget);
      expect(find.text('Clear favourite wallpapers'), findsOneWidget);
      expect(find.text('Restore purchases'), findsOneWidget);
      expect(find.text('Log out'), findsOneWidget);
      expect(find.text('Delete account'), findsOneWidget);
    });

    testWidgets('a guest sees a sign-in card and no account actions', (tester) async {
      signInAs(loggedIn: false);
      await pumpSettings(tester);

      expect(find.text('Sign in to Prism'), findsOneWidget);
      expect(find.text('Log out'), findsNothing);
      expect(find.text('Delete account'), findsNothing);
      expect(find.text('Buy premium'), findsOneWidget);
      expect(find.text('Themes'), findsOneWidget);
    });

    testWidgets('a Pro user sees the Pro tag and no Buy premium row', (tester) async {
      signInAs(premium: true);
      await pumpSettings(tester);

      expect(find.text('Pro'), findsOneWidget);
      expect(find.text('Buy premium'), findsNothing);
    });

    testWidgets('log out asks first', (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Log out?'), findsNothing);
    });

    testWidgets('account deletion copy describes wallpapers only', (tester) async {
      await pumpSettings(tester);
      await openDeleteDialog(tester);

      expect(find.text('Delete your account?'), findsOneWidget);
      expect(find.textContaining('Your uploaded wallpapers will remain visible'), findsOneWidget);
      expect(find.textContaining('setups'), findsNothing);
    });
  });
}
