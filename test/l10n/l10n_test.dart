import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('BuildContext exposes generated messages and unsupported locales resolve to English', (
    WidgetTester tester,
  ) async {
    late String title;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            title = context.l10n.appTitle;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(title, 'Prism');
  });

  test('context-free loading requires and uses the explicit locale', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('en'));

    expect(messages.wallpaperCount(1), '1 wallpaper');
    expect(messages.wallpaperCount(3), '3 wallpapers');
    expect(messages.wallpaperCount(1234), '1,234 wallpapers');
    expect(messages.wallpaperAutoRotatePreparing(2), 'Preparing 2 wallpapers');
    expect(messages.wallpaperViewCount(1234), '1,234 views');
  });

  test('context-free loading resolves an unsupported locale with app locale rules', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('fr'));

    expect(AppLocalizations.supportedLocales.first, const Locale('en'));
    expect(messages.localeName, 'en');
    expect(messages.actionRetry, 'Try again');
  });

  testWidgets('localizationsFor prefers inherited non-English messages over the device locale', (tester) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('de')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    late BuildContext localizedContext;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          localizedContext = context;
          return child!;
        },
        home: const SizedBox.shrink(),
      ),
    );

    final AppLocalizations messages = await localizationsFor(localizedContext);

    expect(messages, same(localizedContext.l10n));
    expect(messages.localeName, 'es');
    expect(messages.actionRetry, 'Intentar de nuevo');
  });

  testWidgets('localizationsFor above MaterialApp uses the supported preferred device locale', (tester) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('fr'), Locale('es', 'MX')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    late BuildContext aboveAppContext;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          aboveAppContext = context;
          return const MaterialApp(home: SizedBox.shrink());
        },
      ),
    );

    final AppLocalizations messages = await localizationsFor(aboveAppContext);

    expect(messages.localeName, 'es');
    expect(messages.actionRetry, 'Intentar de nuevo');
  });

  testWidgets('localizationsFor above MaterialApp falls back to English for unsupported device locales', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('fr'), Locale('ja')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    late BuildContext aboveAppContext;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          aboveAppContext = context;
          return const MaterialApp(home: SizedBox.shrink());
        },
      ),
    );

    final AppLocalizations messages = await localizationsFor(aboveAppContext);

    expect(messages.localeName, 'en');
    expect(messages.actionRetry, 'Try again');
  });
}
