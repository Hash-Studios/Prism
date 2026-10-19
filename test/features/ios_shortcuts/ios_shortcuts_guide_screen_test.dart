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

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(800, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
