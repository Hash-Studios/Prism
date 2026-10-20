import 'package:Prism/features/debug_panel/views/pages/app_info_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Prism test',
      packageName: 'com.hash.prism.test',
      version: '1.2.3',
      buildNumber: '123',
      buildSignature: '',
    );
  });

  const localeCases = <({Locale locale, String label, String decimal})>[
    (locale: Locale('de'), label: 'Geräte-Pixelverhältnis', decimal: '2,75'),
    (locale: Locale('es'), label: 'Relación de píxeles del dispositivo', decimal: '2,75'),
    (locale: Locale('en'), label: 'Device Pixel Ratio', decimal: '2.75'),
  ];

  for (final ({Locale locale, String label, String decimal}) localeCase in localeCases) {
    final locale = localeCase.locale;
    testWidgets('formats device pixel ratio with ${locale.languageCode} decimal separator', (tester) async {
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: AppInfoPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text(localeCase.label), 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text(localeCase.decimal), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  for (final ({Locale locale, String label}) localeCase in <({Locale locale, String label})>[
    (locale: Locale('de'), label: 'Geräte-Pixelverhältnis'),
    (locale: Locale('es'), label: 'Relación de píxeles del dispositivo'),
  ]) {
    testWidgets('updates decimal separator from ${localeCase.locale.languageCode} to English on the same page', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetDevicePixelRatio);
      var locale = localeCase.locale;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) => MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Column(
                children: [
                  TextButton(onPressed: () => setState(() => locale = const Locale('en')), child: const Text('Switch')),
                  const Expanded(child: AppInfoPage()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final State<AppInfoPage> pageState = tester.state(find.byType(AppInfoPage));
      expect(Localizations.localeOf(tester.element(find.byType(AppInfoPage))), localeCase.locale);
      await tester.scrollUntilVisible(find.text(localeCase.label), 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('2,75'), findsOneWidget);

      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();
      expect(identical(tester.state(find.byType(AppInfoPage)), pageState), isTrue);
      expect(Localizations.localeOf(tester.element(find.byType(AppInfoPage))), const Locale('en'));
      await tester.scrollUntilVisible(find.text('Device Pixel Ratio'), 250, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('2.75'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
