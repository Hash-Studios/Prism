import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the generated delegate loads Indonesian for id and id_ID', () async {
    final AppLocalizations language = await AppLocalizations.delegate.load(const Locale('id'));
    final AppLocalizations country = await AppLocalizations.delegate.load(const Locale('id', 'ID'));

    expect(language.localeName.split('_').first, 'id');
    expect(country.localeName.split('_').first, 'id');
    expect(language.actionRetry, 'Coba lagi');
    expect(country.actionRetry, 'Coba lagi');
  });

  test('Indonesian plurals, number formatting, and interpolation use translated messages', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('id'));

    expect(messages.wallpaperCount(0), 'Tidak ada wallpaper');
    expect(messages.wallpaperCount(1), '1 wallpaper');
    expect(messages.wallpaperCount(3), '3 wallpaper');
    expect(formatLocalizedNumber(1234, messages), '1.234');
    expect(messages.onboardingContinueSelected(2), 'Lanjutkan (2 dipilih)');
    expect(messages.economyNeedMoreCoins(1), 'Perlu 1 koin lagi.');
    expect(messages.economyNeedMoreCoins(1234), 'Perlu 1.234 koin lagi.');
    expect(messages.economyAiFailureWithRefund('Gagal.', 'refunded'), 'Gagal. Koin dikembalikan.');
    expect(
      messages.economyQuestTileSemantics('Jelajahi', 'false', 2, 5, 3, 10, 'true', 'true', 'true', '2 hari', 'true'),
      'Jelajahi, 2 dari 5. Hadiah 3 koin. Hadiah 10 XP. Misi mingguan, berakhir dalam 2 hari',
    );
  });

  test('unsupported locales resolve to the English generated messages', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('fr'));

    expect(messages.localeName, 'en');
    expect(messages.actionRetry, 'Try again');
  });

  testWidgets('localized Prism button and sheet fit a narrow screen at large text scale', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('id'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) => Scaffold(
            body: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: PrismSheetBody(
                scrollable: true,
                title: context.l10n.wallpaperFeedEmptyTitle,
                message: context.l10n.wallpaperFeedEmptyBody,
                actions: <Widget>[PrismButton(label: context.l10n.actionRetry, onPressed: () {})],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.byType(PrismButton), findsOneWidget);
    await tester.ensureVisible(find.byType(PrismButton));
    await tester.pumpAndSettle();
    expect(find.byType(PrismButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
