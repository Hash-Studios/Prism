import 'package:Prism/core/constants/app_constants.dart' as app_constants;
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/updates/code_push_updater.dart';
import 'package:Prism/features/debug_panel/views/pages/app_info_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _RemoteConfig extends Mock implements FirebaseRemoteConfig {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> copied;
  setUp(() {
    copied = [];
    PackageInfo.setMockInitialValues(
      appName: 'Prism QA',
      packageName: 'com.prism.qa',
      version: '3.0',
      buildNumber: '30',
      buildSignature: 'qa-signature',
    );
    final config = _RemoteConfig();
    when(config.getAll).thenReturn({'safe_flag': RemoteConfigValue('enabled'.codeUnits, ValueSource.valueRemote)});
    when(() => config.getString('safe_flag')).thenReturn('enabled');
    getIt.registerSingleton<FirebaseRemoteConfig>(config);
    getIt.registerSingleton<CodePushUpdater>(ShorebirdCodePushUpdater(track: () => 'stable'));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      },
    );
    app_state.prismUser = app_constants.createGuestPrismUser()
      ..email = 'qa@example.test'
      ..id = 'qa-user'
      ..username = 'Tester'
      ..loggedIn = true
      ..coins = 71;
  });
  tearDown(() async {
    app_state.prismUser = app_constants.createGuestPrismUser();
    await getIt.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });

  testWidgets('diagnostic report combines package, active user, screen and remote config and refreshes values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: AppInfoPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy diagnostic report'));
    await tester.pump();
    expect(copied.single, contains('Prism QA'));
    expect(copied.single, contains('Version: 3.0'));
    expect(copied.single, contains('qa@example.test'));
    expect(copied.single, contains('Coins: 71'));
    expect(copied.single, contains('safe_flag: enabled'));
    expect(copied.single, contains('Physical Size:'));
    await tester.tap(find.text('Prism QA'));
    await tester.pump();
    expect(copied.last, 'Prism QA');
    PackageInfo.setMockInitialValues(
      appName: 'Prism Refreshed',
      packageName: 'com.prism.qa',
      version: '3.1',
      buildNumber: '31',
      buildSignature: '',
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(find.text('Prism Refreshed'), findsOneWidget);
    await tester.tap(find.text('Copy diagnostic report'));
    await tester.pump();
    expect(copied.last, contains('Version: 3.1'));
  });
}
