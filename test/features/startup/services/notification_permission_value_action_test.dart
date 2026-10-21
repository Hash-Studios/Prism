import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart' as constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/persistence/persistence_keys.dart';
import 'package:Prism/core/startup/firebase_init.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/startup/services/notification_permission_prompt_service.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/in_memory_local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/firebase_messaging');
  late SettingsLocalDataSource settings;
  late FakeAppAnalytics analytics;
  late AuthorizationStatus current;
  late AuthorizationStatus requested;
  late List<MethodCall> calls;

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
    FirebaseInit.setFuture(Future<bool>.value(false));
  });

  setUp(() {
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    app_state.prismUser = constants.createGuestPrismUser();
    StartupModalSlot.reset();
    current = AuthorizationStatus.notDetermined;
    requested = AuthorizationStatus.authorized;
    calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'Messaging#getNotificationSettings' || call.method == 'Messaging#requestPermission') {
        return <String, int>{
          'authorizationStatus': switch (call.method == 'Messaging#requestPermission' ? requested : current) {
            AuthorizationStatus.authorized => 1,
            AuthorizationStatus.denied => 0,
            AuthorizationStatus.notDetermined => -1,
            AuthorizationStatus.provisional => 2,
            AuthorizationStatus.deniedPermanently => 3,
          },
        };
      }
      return null;
    });
  });

  tearDown(() async {
    await getIt.reset();
    AnalyticsRuntime.reset();
    app_state.prismUser = constants.createGuestPrismUser();
    debugDefaultTargetPlatformOverride = null;
    StartupModalSlot.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  Future<BuildContext> host(WidgetTester tester) async {
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    late BuildContext result;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            result = context;
            return const Scaffold(body: SizedBox());
          },
        ),
      ),
    );
    return result;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  TomorrowHookPermissionResultEvent event() => analytics.events.whereType<TomorrowHookPermissionResultEvent>().single;

  testWidgets('already authorized subscribes opted-in topics and records completion once', (tester) async {
    current = AuthorizationStatus.authorized;
    app_state.prismUser = constants.createGuestPrismUser()
      ..loggedIn = true
      ..id = 'creator-123'
      ..email = 'creator@example.com';
    final context = await host(tester);
    await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(context, sourceTag: 'download');
    await settle(tester);

    expect(settings.get<bool>('notificationPermissionPromptedV2'), isTrue);
    expect(event().result, EventResultValue.success);
    expect(event().subscribedToWotd, isTrue);
    final topics = calls
        .where((call) => call.method == 'Messaging#subscribeToTopic')
        .map((call) => (call.arguments as Map<Object?, Object?>)['topic']);
    expect(topics, containsAll(<String>['drops_loc_v1', 'creator_loc_v1']));
    expect(topics.any((topic) => topic.toString().contains('creator-123')), isTrue);
    expect(find.text('Turn on notifications'), findsNothing);
    final before = calls.length;
    await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(context, sourceTag: 'download');
    expect(calls.length, before);
    expect(analytics.events.whereType<TomorrowHookPermissionResultEvent>(), hasLength(1));
  });

  testWidgets('authorized guest respects disabled topic preferences', (tester) async {
    current = AuthorizationStatus.authorized;
    await settings.set(PersistenceKeys.notifWotd, false);
    await settings.set(NotificationPrefKeys.drops, false);
    await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(
      await host(tester),
      sourceTag: 'save',
    );
    await settle(tester);
    expect(event().subscribedToWotd, isFalse);
    expect(event().result, EventResultValue.success);
    expect(calls.where((call) => call.method == 'Messaging#subscribeToTopic'), isEmpty);
  });

  testWidgets('iOS denial is final and records cancellation without showing a prompt', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    current = AuthorizationStatus.denied;
    await NotificationPermissionPromptService.instance.maybePromptAfterValueAction(
      await host(tester),
      sourceTag: 'save',
    );
    await settle(tester);
    expect(settings.get<bool>('notificationPermissionPromptedV2'), isTrue);
    expect(event().result, EventResultValue.failure);
    expect(event().reason, AnalyticsReasonValue.userCancelled);
    expect(calls.map((call) => call.method), <String>['Messaging#getNotificationSettings']);
    expect(find.text('Turn on notifications'), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final status in <AuthorizationStatus>[AuthorizationStatus.authorized, AuthorizationStatus.denied]) {
    testWidgets('accepting soft prompt records system ${status.name} result', (tester) async {
      requested = status;
      final context = await host(tester);
      final result = NotificationPermissionPromptService.instance.maybePromptAfterValueAction(
        context,
        sourceTag: 'save',
      );
      await settle(tester);
      expect(find.text('Turn on notifications'), findsOneWidget);
      expect(settings.get<bool>('notificationPermissionPromptedV2', defaultValue: false), isFalse);
      await tester.tap(find.text('Turn on notifications'));
      await settle(tester);
      await result;
      expect(settings.get<bool>('notificationPermissionPromptedV2'), isTrue);
      expect(
        event().result,
        status == AuthorizationStatus.authorized ? EventResultValue.success : EventResultValue.failure,
      );
      expect(event().subscribedToWotd, status == AuthorizationStatus.authorized);
      expect(calls.where((call) => call.method == 'Messaging#requestPermission'), hasLength(1));
    });
  }

  testWidgets('declining soft prompt leaves permission eligible for another session', (tester) async {
    final context = await host(tester);
    final result = NotificationPermissionPromptService.instance.maybePromptAfterValueAction(context, sourceTag: 'save');
    await settle(tester);
    await tester.tap(find.text('Not now'));
    await settle(tester);
    await result;
    expect(settings.get<bool>('notificationPermissionPromptedV2', defaultValue: false), isFalse);
    expect(analytics.events, isEmpty);
    expect(calls.where((call) => call.method == 'Messaging#requestPermission'), isEmpty);
  });
}
