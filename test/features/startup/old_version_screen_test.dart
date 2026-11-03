import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/startup/views/pages/old_version_screen.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../support/fake_app_analytics.dart';

const MethodChannel _urlLauncherChannel = MethodChannel('plugins.flutter.io/url_launcher');
final List<String> _launchedUrls = <String>[];

void _mockUrlLauncher() {
  _launchedUrls.clear();
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_urlLauncherChannel, (
    MethodCall call,
  ) async {
    final Object? url = (call.arguments as Map<Object?, Object?>?)?['url'];
    if (call.method == 'launch' && url is String) _launchedUrls.add(url);
    return true;
  });
}

void _mockInstaller(String? installerStore) {
  PackageInfo.setMockInitialValues(
    appName: 'Prism',
    packageName: 'com.hash.prism',
    version: '3.18.2',
    buildNumber: '359',
    buildSignature: '',
    installerStore: installerStore,
  );
}

Future<void> _pumpOldVersion(WidgetTester tester, {TransitionBuilder? builder}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: prismLightThemes.first.theme,
      builder: builder,
      home: const OldVersion(),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  setUp(() {
    _mockInstaller('com.android.vending');
    _mockUrlLauncher();
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      _urlLauncherChannel,
      null,
    );
  });

  testWidgets('the update wall shows Glint, the reason and one primary action on every theme', (tester) async {
    for (final option in <PrismThemeOption>[...prismLightThemes, ...prismDarkThemes]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: option.theme,
          home: const OldVersion(),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Time to update'), findsOneWidget, reason: prismThemeDisplayName(option, AppLocalizationsEn()));
      expect(find.byType(Glint), findsOneWidget, reason: prismThemeDisplayName(option, AppLocalizationsEn()));
      expect(
        find.textContaining('${app_state.currentAppVersion}+${app_state.currentAppVersionCode}'),
        findsOneWidget,
        reason: prismThemeDisplayName(option, AppLocalizationsEn()),
      );
      expect(
        find.widgetWithText(FilledButton, 'Update Prism'),
        findsOneWidget,
        reason: prismThemeDisplayName(option, AppLocalizationsEn()),
      );
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, option.theme.colorScheme.surface);
    }
  });

  group('APK link', () {
    late FakeAppAnalytics analytics;

    setUp(() {
      analytics = FakeAppAnalytics();
      AnalyticsRuntime.instance = analytics;
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      AnalyticsRuntime.reset();
    });

    testWidgets('a sideloaded install offers the APK page', (tester) async {
      _mockInstaller(null);
      await _pumpOldVersion(tester);

      expect(find.widgetWithText(FilledButton, 'Download the latest version'), findsOneWidget);
      expect(find.text('Update Prism'), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'Download the latest version'));
      await tester.pump();

      expect(_launchedUrls, <String>['https://prismwalls.com/download']);
      final List<Object?> shown = analytics.events
          .where((event) => event.eventName == 'apk_link_shown')
          .map((event) => event.toWireParameters()['source'])
          .toList();
      final List<Object?> tapped = analytics.events
          .where((event) => event.eventName == 'apk_link_tapped')
          .map((event) => event.toWireParameters()['source'])
          .toList();
      expect(shown, <Object?>['old_version']);
      expect(tapped, <Object?>['old_version']);
    });

    testWidgets('a Play install never shows the APK link', (tester) async {
      _mockInstaller('com.android.vending');
      await _pumpOldVersion(tester);

      expect(find.text('Download the latest version'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Update Prism'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Update Prism'));
      await tester.pump();

      expect(_launchedUrls, <String>['https://play.google.com/store/apps/details?id=com.hash.prism']);
      expect(analytics.events.where((event) => event.eventName.startsWith('apk_link')), isEmpty);
    });

    testWidgets('iOS never shows the APK link', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      _mockInstaller(null);
      await _pumpOldVersion(tester);

      expect(find.text('Download the latest version'), findsNothing);
      expect(find.text('Update Prism'), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('the APK button fits at 2x text on a narrow phone', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      _mockInstaller(null);
      await _pumpOldVersion(
        tester,
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
      );

      expect(find.text('Download the latest version'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
