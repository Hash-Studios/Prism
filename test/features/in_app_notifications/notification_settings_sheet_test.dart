import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/in_app_notifications/views/widgets/notification_settings_sheet.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';
import '../../support/fake_firebase_messaging.dart';
import '../../support/fake_firestore_client.dart';
import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

class _FakePermissions extends NotificationPermissionGateway {
  _FakePermissions({required this.granted, this.grantsOnRequest = false});

  bool granted;
  final bool grantsOnRequest;
  int requests = 0;
  final FakeFirebaseMessaging fakeMessaging = FakeFirebaseMessaging();

  @override
  FirebaseMessaging get messaging => fakeMessaging;

  int settingsOpened = 0;

  @override
  Future<bool> isGranted() async => granted;

  @override
  Future<bool> request() async {
    requests++;
    return granted = grantsOnRequest;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const toastChannel = MethodChannel('PonnamKarthik/fluttertoast');
  late SettingsLocalDataSource settings;
  final toasts = <String>[];
  late FakeFirestoreClient firestore;

  setUp(() async {
    toasts.clear();
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    firestore = FakeFirestoreClient();
    PrismHaptics.enabled = false;
    AnalyticsRuntime.instance = FakeAppAnalytics();
    messenger.setMockMethodCallHandler(toastChannel, (call) async {
      if (call.method == 'showToast') toasts.add((call.arguments as Map<Object?, Object?>)['msg']! as String);
      return true;
    });
    settings = SettingsLocalDataSource(InMemoryLocalStore());
    await getIt.reset();
    getIt
      ..registerSingleton<SettingsLocalDataSource>(settings)
      ..registerSingleton<FirestoreClient>(firestore);
  });

  tearDown(() async {
    messenger.setMockMethodCallHandler(toastChannel, null);
    AnalyticsRuntime.reset();
    PrismHaptics.enabled = true;
    await getIt.reset();
  });

  Future<void> pumpSheet(WidgetTester tester, _FakePermissions permissions) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NotificationSettingsSheet(permissions: permissions)),
      ),
    );
    await tester.pump();
  }

  testWidgets('one list: Wall of the Day is in, the dead Prism updates switch is out', (tester) async {
    await pumpSheet(tester, _FakePermissions(granted: true));

    expect(find.text('Wall of the Day'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Recommendations'), findsOneWidget);
    expect(find.text('Streak reminders'), findsOneWidget);
    expect(find.text('Prism updates'), findsNothing);
    expect(find.text('Notifications are off for Prism.'), findsNothing);
  });

  testWidgets('a denied permission shows a banner that opens system settings', (tester) async {
    final permissions = _FakePermissions(granted: false);
    await pumpSheet(tester, permissions);

    expect(find.text('Notifications are off for Prism.'), findsOneWidget);
    await tester.tap(find.text('Open settings'));
    expect(permissions.settingsOpened, 1);
  });

  testWidgets('turning a switch on asks for permission and keeps it off when refused', (tester) async {
    final permissions = _FakePermissions(granted: false);
    await settings.set('recommendationsSubscriber', false);
    await pumpSheet(tester, permissions);

    await tester.tap(find.text('Recommendations'));
    await tester.pump();

    expect(permissions.requests, 1);
    expect(settings.get<bool>('recommendationsSubscriber', defaultValue: false), isFalse);
    expect(toasts, isNotEmpty);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('turning a switch on after the user grants permission saves it', (tester) async {
    final permissions = _FakePermissions(granted: false, grantsOnRequest: true);
    await settings.set('notif.wotd', false);
    await pumpSheet(tester, permissions);

    await tester.tap(find.text('Wall of the Day'));
    await tester.pump();
    await tester.pump();

    expect(permissions.requests, 1);
    expect(settings.get<bool>('notif.wotd', defaultValue: false), isTrue);
    expect(find.text('Notifications are off for Prism.'), findsNothing);
  });

  testWidgets('turning a switch off never asks for permission', (tester) async {
    final permissions = _FakePermissions(granted: false);
    await pumpSheet(tester, permissions);

    await tester.tap(find.text('Wall of the Day'));
    await tester.pump();
    await tester.pump();

    expect(permissions.requests, 0);
    expect(settings.get<bool>('notif.wotd', defaultValue: true), isFalse);
  });

  group('guests', () {
    testWidgets('see the switches that need an account as off, disabled, with a hint', (tester) async {
      await settings.set('followersSubscriber', false);
      await settings.set('postsSubscriber', false);
      await settings.set('streakReminderSubscriber', false);
      await pumpSheet(tester, _FakePermissions(granted: true));

      expect(find.text('Sign in to turn on'), findsNWidgets(3));
      final List<SwitchListTile> tiles = tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)).toList();
      expect(tiles.where((SwitchListTile tile) => tile.onChanged == null), hasLength(3));

      await tester.tap(find.text('Followers'));
      await tester.pump();
      expect(settings.get<bool>('followersSubscriber', defaultValue: false), isFalse);
      expect(toasts, isEmpty);
    });

    testWidgets('can still turn a switch off on this device, and then see the hint', (tester) async {
      await pumpSheet(tester, _FakePermissions(granted: true));
      expect(find.text('Sign in to turn on'), findsNothing);

      await tester.tap(find.text('Streak reminders'));
      await tester.pump();
      await tester.pump();

      expect(settings.get<bool>('streakReminderSubscriber', defaultValue: true), isFalse);
      expect(toasts, isEmpty);
      expect(find.text('Sign in to turn on'), findsOneWidget);
    });

    testWidgets('keep Wall of the Day and Recommendations available', (tester) async {
      await settings.set('recommendationsSubscriber', false);
      await pumpSheet(tester, _FakePermissions(granted: true));

      await tester.tap(find.text('Recommendations'));
      await tester.pump();
      await tester.pump();

      expect(settings.get<bool>('recommendationsSubscriber', defaultValue: false), isTrue);
    });
  });

  group('signed-in users', () {
    setUp(() => app_state.prismUser = profileUser(id: 'uid1'));

    testWidgets('can turn the account switches on without a hint', (tester) async {
      await settings.set('followersSubscriber', false);
      await pumpSheet(tester, _FakePermissions(granted: true));

      expect(find.text('Sign in to turn on'), findsNothing);
      await tester.tap(find.text('Followers'));
      await tester.pump();
      await tester.pump();

      expect(settings.get<bool>('followersSubscriber', defaultValue: false), isTrue);
    });

    testWidgets('the Recommendations switch is saved as marketingPushes next to followerAlerts', (tester) async {
      await pumpSheet(tester, _FakePermissions(granted: true));

      await tester.tap(find.text('Recommendations'));
      await tester.pump();
      await tester.pump();

      expect(settings.get<bool>('recommendationsSubscriber', defaultValue: true), isFalse);
      final write = firestore.writes.singleWhere((w) => w.data?.containsKey('marketingPushes') ?? false);
      expect((write.collection, write.id), ('usersv2/uid1/private', 'session'));
      expect(write.data, <String, dynamic>{'marketingPushes': false});
    });
  });

  testWidgets('the sheet title uses the secondary colour, not the titleMedium colour', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ThemeData theme = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(secondary: Colors.orange),
      textTheme: ThemeData.dark().textTheme.copyWith(titleMedium: const TextStyle(color: Color(0xFF2F2F2F))),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(body: NotificationSettingsSheet(permissions: _FakePermissions(granted: true))),
      ),
    );
    await tester.pump();

    expect(tester.widget<Text>(find.text('Notification preferences')).style?.color, Colors.orange);
  });
}
