import 'package:Prism/core/account/local_account_data_cleaner.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/in_memory_local_store.dart';
import '../../support/profile_user_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    app_state.prismUser = profileUser(id: '', loggedIn: false);
  });

  tearDown(() async {
    app_state.prismUser = profileUser(id: '', loggedIn: false);
    await getIt.reset();
  });

  test('deleting an old account does not clear the current account snapshot', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    await settings.set('dayNight.pair', '{"ownerId":"account-b"}');
    await prefs.setString('shortcuts.day_night', 'account-b snapshot');
    app_state.prismUser = profileUser(id: '', loggedIn: false);

    await LocalAccountDataCleaner.clearDayNightSnapshotForUser('account-a');

    expect(prefs.getString('shortcuts.day_night'), 'account-b snapshot');
  });

  test('deleting another account does not clear the snapshot of the active account', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    app_state.prismUser = profileUser(id: 'account-b');
    await prefs.setString('shortcuts.day_night', 'account-b snapshot');

    await LocalAccountDataCleaner.clearDayNightSnapshotForUser('account-a');

    expect(prefs.getString('shortcuts.day_night'), 'account-b snapshot');
  });

  test('deleting the snapshot owner clears its snapshot', () async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final SettingsLocalDataSource settings = SettingsLocalDataSource(InMemoryLocalStore());
    getIt.registerSingleton<SettingsLocalDataSource>(settings);
    await settings.set('dayNight.pair', '{"ownerId":"account-a"}');
    await prefs.setString('shortcuts.day_night', 'account-a snapshot');

    await LocalAccountDataCleaner.clearDayNightSnapshotForUser('account-a');

    expect(prefs.getString('shortcuts.day_night'), isNull);
    expect(settings.get<String?>('dayNight.pair'), isNull);
    expect(prefs.getString('${NativeAssetPathsStore.preferenceKey}.daynight'), '{}');
  });
}
