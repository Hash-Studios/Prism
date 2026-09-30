import 'package:Prism/auth/badge_model.dart' as prism;
import 'package:Prism/auth/transaction_model.dart';
import 'package:Prism/auth/user_model.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/cache_maintenance_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/session/views/pages/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../support/in_memory_local_store.dart';

class _MockCacheMaintenanceService extends Mock implements CacheMaintenanceService {}

class _MockSessionRepository extends Mock implements SessionRepository {}

PrismUsersV2 _user({required bool loggedIn, bool premium = false}) => PrismUsersV2(
  username: 'tester',
  email: loggedIn ? 'tester@example.com' : '',
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

void main() {
  late InMemoryLocalStore store;

  Future<void> register(PrismUsersV2 user) async {
    await getIt.reset();
    store = InMemoryLocalStore();
    getIt.registerSingleton<SettingsLocalDataSource>(SettingsLocalDataSource(store));
    getIt.registerSingleton<CacheMaintenanceService>(_MockCacheMaintenanceService());
    final sessionRepository = _MockSessionRepository();
    when(() => sessionRepository.currentUser).thenReturn(user);
    getIt.registerSingleton<SessionRepository>(sessionRepository);
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1000, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump();
  }

  tearDown(getIt.reset);

  testWidgets('a signed-in user sees the account card and the grouped settings', (tester) async {
    await register(_user(loggedIn: true));
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
      'About',
    ]) {
      expect(find.text(header), findsOneWidget, reason: header);
    }
    expect(find.text('APPEARANCE'), findsNothing);
    expect(find.text('Review status'), findsOneWidget);
    expect(find.text('Clear favourites'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
    expect(find.text('Delete account'), findsOneWidget);
    expect(find.text('Original'), findsOneWidget);
  });

  testWidgets('a guest sees a sign-in card and no account actions', (tester) async {
    await register(_user(loggedIn: false));
    await pumpSettings(tester);

    expect(find.text('Sign in to Prism'), findsOneWidget);
    expect(find.text('Log out'), findsNothing);
    expect(find.text('Delete account'), findsNothing);
    expect(find.text('Restore purchases'), findsNothing);
    expect(find.text('Buy Premium'), findsOneWidget);
    expect(find.text('Themes'), findsOneWidget);
  });

  testWidgets('a Pro user sees the Pro tag and no Buy Premium row', (tester) async {
    await register(_user(loggedIn: true, premium: true));
    await pumpSettings(tester);

    expect(find.text('Pro'), findsOneWidget);
    expect(find.text('Buy Premium'), findsNothing);
  });

  testWidgets('download quality opens a sheet and saves the choice', (tester) async {
    await register(_user(loggedIn: true));
    await pumpSettings(tester);

    await tester.tap(find.text('Download quality'));
    await tester.pumpAndSettle();
    expect(find.text('Smaller file size, slightly reduced quality'), findsOneWidget);

    await tester.tap(find.text('Compressed'));
    await tester.pumpAndSettle();

    expect(store.data.values, contains('compressed'));
    expect(find.text('Compressed'), findsOneWidget);
    expect(find.text('Original'), findsNothing);
  });

  testWidgets('log out asks first', (tester) async {
    await register(_user(loggedIn: true));
    await pumpSettings(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of Prism?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Log out of Prism?'), findsNothing);
  });

  testWidgets('account deletion copy describes wallpapers only', (tester) async {
    await register(_user(loggedIn: true));
    await pumpSettings(tester);

    await tester.tap(find.text('Delete account'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Delete your account?'), findsOneWidget);
    expect(find.textContaining('Your uploaded wallpapers stay visible'), findsOneWidget);
    expect(find.textContaining('setups'), findsNothing);
  });
}
