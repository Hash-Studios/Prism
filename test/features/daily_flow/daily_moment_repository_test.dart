import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/daily_flow/data/coins_daily_moment_repository.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/coins_test_backend.dart';
import '../../support/fake_app_analytics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final backend = CoinsTestBackend();
  final service = CoinsService.instance;
  late List<(String, Map<String, dynamic>)> calls;

  setUp(() async {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    await backend.install();
    calls = <(String, Map<String, dynamic>)>[];
    backend.onCall = (name, params) async {
      calls.add((name, params));
      if (name == 'claimDailyStreak') return CoinsTestBackend.claimPayload;
      return <String, Object?>{'success': false, 'reason': 'test_refusal'};
    };
  });
  tearDown(() async {
    AnalyticsRuntime.reset();
    app_state.prismUser = app_constants.createGuestPrismUser();
    await service.refreshStreakStatus();
    await getIt.reset();
  });

  test('forwards claim preferences and purchase limits to production callables', () async {
    await getIt<SettingsLocalDataSource>().set(NotificationPrefKeys.streakReminders, false);
    final repository = CoinsDailyMomentRepository(coins: service);
    await repository.claimStreak();
    await repository.openChest(maxCost: 20);
    await repository.takeFreeSpin();
    final claim = calls.firstWhere((call) => call.$1 == 'claimDailyStreak').$2;
    expect(claim, <String, dynamic>{
      'timezoneOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
      'reminderEnabled': false,
    });
    final chest = calls.firstWhere((call) => call.$1 == 'openDailyChest').$2;
    expect(chest['maxCost'], 20);
    expect(chest['sourceTag'], 'coins.daily_chest');
    final spin = calls.firstWhere((call) => call.$1 == 'spinWheel').$2;
    expect(spin['maxCost'], 0);
    expect(spin['sourceTag'], 'coins.spin_wheel');
  });
}
