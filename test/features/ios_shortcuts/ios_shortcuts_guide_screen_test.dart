import 'package:Prism/features/ios_shortcuts/views/pages/ios_shortcuts_guide_screen.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

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

Future<void> _pump(WidgetTester tester, {Size size = const Size(800, 1800), double textScale = 1}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const IosShortcutsGuideScreen(),
    ),
  );
}

void main() {
  late UrlLauncherPlatform original;

  setUp(() => original = UrlLauncherPlatform.instance);
  tearDown(() => UrlLauncherPlatform.instance = original);

  testWidgets('shows the four steps and both sources', (tester) async {
    await _pump(tester);

    expect(find.text('Change your wallpaper automatically'), findsOneWidget);
    final List<String> steps = shortcutsGuideSteps(tester.element(find.byType(IosShortcutsGuideScreen)).l10n);
    expect(steps, hasLength(4));
    for (final String step in steps) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.textContaining('Get Prism Wallpaper'), findsOneWidget);
    expect(find.textContaining('Ask Before Running'), findsOneWidget);
    expect(find.text('Wall of the Day'), findsOneWidget);
    expect(find.text('Random favourite'), findsOneWidget);
    expect(find.text('Open Shortcuts'), findsOneWidget);
  });

  testWidgets('explains both setup routes and makes the old confirmation switch conditional', (tester) async {
    await _pump(tester);
    final l10n = tester.element(find.byType(IosShortcutsGuideScreen)).l10n;
    expect(l10n.wallpaperShortcutsOpenAutomationSteps, contains('If there is an Automation tab'));
    expect(l10n.wallpaperShortcutsOpenAutomationSteps, contains('New Automation'));
    expect(l10n.wallpaperShortcutsOpenAutomationSteps, contains('Otherwise, tap Add (+), then Edit if shown'));
    expect(l10n.wallpaperShortcutsChooseTriggerSteps, contains('Choose and configure a trigger'));
    expect(l10n.wallpaperShortcutsDisableConfirmationSteps, contains('If "Ask Before Running" appears'));
    expect(find.text('Turn off "Ask Before Running". Tap Done.'), findsNothing);
  });

  test('every supported locale explains the routes, conditional confirmation and original prerequisite', () async {
    const cases = <(Locale, String, String, String)>[
      (Locale('en'), 'New Automation', 'If "Ask Before Running" appears', "Download today's original"),
      (Locale('hi'), 'नया ऑटोमेशन', 'अगर "चलाने से पहले पूछें" दिखे', 'आज का मूल वॉलपेपर डाउनलोड'),
      (
        Locale('de'),
        'Neue Automation',
        'Falls "Vor Ausführen bestätigen" erscheint',
        'Lade zuerst das heutige Original',
      ),
      (Locale('id'), 'Automasi Baru', 'Jika "Tanya Sebelum Menjalankan" muncul', 'Unduh gambar asli hari ini'),
      (
        Locale('es'),
        'Nueva automatización',
        'Si aparece "Preguntar antes de ejecutar"',
        'Descarga primero el original de hoy',
      ),
      (
        Locale('pt'),
        'Nova automação',
        'Se aparecer "Perguntar antes de executar"',
        'Baixe primeiro o original de hoje',
      ),
      (
        Locale('pt', 'BR'),
        'Nova automação',
        'Se aparecer "Perguntar antes de executar"',
        'Baixe primeiro o original de hoje',
      ),
    ];
    expect(cases.map((entry) => entry.$1).toSet(), AppLocalizations.supportedLocales.toSet());
    for (final (locale, automation, conditional, prerequisite) in cases) {
      final l10n = await AppLocalizations.delegate.load(locale);
      expect(l10n.wallpaperShortcutsOpenAutomationSteps, contains(automation), reason: '$locale legacy route');
      expect(l10n.wallpaperShortcutsOpenAutomationSteps, contains('(+)'), reason: '$locale Add route');
      expect(l10n.wallpaperShortcutsDisableConfirmationSteps, contains(conditional), reason: '$locale confirmation');
      expect(l10n.wallpaperShortcutsSourceWotdDescription, contains(prerequisite), reason: '$locale original');
    }
  });

  for (final double textScale in <double>[1, 2]) {
    testWidgets('source prerequisites can be read on a phone at text scale $textScale', (tester) async {
      await _pump(tester, size: const Size(402, 874), textScale: textScale);
      final l10n = tester.element(find.byType(IosShortcutsGuideScreen)).l10n;
      expect(find.text('Open Shortcuts').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.wallpaperShortcutsSourceWotdDescription),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(l10n.wallpaperShortcutsSourceWotdDescription, contains("Download today's original"));
      expect(l10n.wallpaperShortcutsSourceWotdDescription, contains('daily pick changes'));
      expect(find.text(l10n.wallpaperShortcutsSourceWotdDescription).hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text(l10n.wallpaperShortcutsSourceFavouriteDescription),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(
        l10n.wallpaperShortcutsSourceFavouriteDescription,
        contains('Some protected wallpapers may not be available'),
      );
      expect(find.text(l10n.wallpaperShortcutsSourceFavouriteDescription).hitTestable(), findsOneWidget);
      expect(find.text('Open Shortcuts').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Open Shortcuts launches shortcuts://', (tester) async {
    final launcher = _RecordingUrlLauncher(opens: true);
    UrlLauncherPlatform.instance = launcher;
    await _pump(tester);

    await tester.tap(find.text('Open Shortcuts'));
    await tester.pump();

    expect(launcher.urls, <String>['shortcuts://']);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Open Shortcuts shows a snackbar when it cannot open', (tester) async {
    final launcher = _RecordingUrlLauncher(opens: false);
    UrlLauncherPlatform.instance = launcher;
    await _pump(tester);

    await tester.tap(find.text('Open Shortcuts'));
    await tester.pump();
    await tester.pump();

    expect(launcher.urls, <String>['shortcuts://']);
    expect(find.text('Could not open Shortcuts. Open the app yourself.'), findsOneWidget);
  });
}
