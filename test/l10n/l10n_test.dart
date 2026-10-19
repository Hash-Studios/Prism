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
}
