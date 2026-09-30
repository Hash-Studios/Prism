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

void main() {
  setUp(() async {
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

  tearDown(getIt.reset);

  testWidgets('account deletion copy describes wallpapers only', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.scrollUntilVisible(find.text('Delete Account'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('Delete Account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Account'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Your uploaded wallpapers will remain visible'), findsOneWidget);
    expect(find.textContaining('setups'), findsNothing);
  });
}
