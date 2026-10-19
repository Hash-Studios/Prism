import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  test('Hindi localization contract checker passes', () async {
    final ProcessResult result = await Process.run('python3', <String>['tool/check_hi_l10n.py']);

    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
  });

  test('Hindi is registered and unsupported locales resolve to English', () async {
    expect(AppLocalizations.supportedLocales, contains(const Locale('hi')));

    final AppLocalizations hindi = await loadAppLocalizations(const Locale('hi', 'IN'));
    expect(hindi.localeName, 'hi');
    expect(hindi.actionRetry, 'फिर कोशिश करें');

    final AppLocalizations english = await loadAppLocalizations(const Locale('fr'));
    expect(AppLocalizations.supportedLocales.first, const Locale('en'));
    expect(english.localeName, 'en');
    expect(english.actionRetry, 'Try again');
  });

  test('Hindi messages cover key journeys and preserve placeholders', () async {
    await initializeDateFormatting('hi');
    final AppLocalizations hindi = await loadAppLocalizations(const Locale('hi', 'IN'));

    expect(hindi.onboardingWelcomeHeadline, 'आपकी स्क्रीन, नए अंदाज़ में।');
    expect(hindi.premiumPageTitle, 'Prism Premium');
    expect(hindi.accountSignIn, 'साइन इन करें');
    expect(hindi.coreProfileUpdated, 'प्रोफ़ाइल अपडेट की गई');
    expect(hindi.accountBlockThisUserTitle('Asha'), 'Asha को ब्लॉक करें?');
    expect(hindi.coreWallpaperBySemanticLabel('Asha'), 'Asha का वॉलपेपर');
    expect(hindi.coreRelativeTimeMinutesAgo(5), '5 मिनट पहले');
    expect(hindi.coreRelativeTimeHoursAgo(0), '0 घंटे पहले');
    expect(hindi.coreRelativeTimeHoursAgo(1), '1 घंटे पहले');
    expect(hindi.coreRelativeTimeHoursAgo(3), '3 घंटे पहले');
    expect(hindi.coreRelativeTimeJustNow, 'अभी-अभी');
    expect(hindi.notifYesterday, 'कल');
    expect(hindi.economyAiMatchingScreenSize, 'आपकी स्क्रीन के आकार से मेल बिठा रहे हैं…');
    expect(hindi.economyAiApplyingStyle, 'आपकी शैली लागू कर रहे हैं…');
    expect(hindi.economyAiFinalizingWallpaper, 'आपके वॉलपेपर को अंतिम रूप दे रहे हैं…');
    expect(hindi.economyAiRemixHint, 'गहरा आसमान, गर्म रंग, किनारे थोड़े नरम…');
    expect(hindi.economyNeedMoreCoins(0), 'अभी 0 कॉइन और चाहिए।');
    expect(hindi.economyNeedMoreCoins(1), 'अभी 1 कॉइन और चाहिए।');
    expect(hindi.economyNeedMoreCoins(1234567), 'अभी 12,34,567 कॉइन और चाहिए।');
    expect(DateFormat.yMMMMd(hindi.localeName).format(DateTime(2025, 1, 5)), '5 जनवरी 2025');
    expect(formatLocalizedNumber(1234567, hindi), '12,34,567');
  });

  test('Hindi wallpaper plural has explicit zero, one, and many forms', () async {
    final AppLocalizations hindi = await loadAppLocalizations(const Locale('hi', 'IN'));

    expect(hindi.wallpaperCount(0), 'कोई वॉलपेपर नहीं');
    expect(hindi.wallpaperCount(1), '1 वॉलपेपर');
    expect(hindi.wallpaperCount(3), '3 वॉलपेपर');
  });

  test('Hindi quest semantics cover nested selectors and optional false branches', () async {
    final AppLocalizations hindi = await loadAppLocalizations(const Locale('hi', 'IN'));

    expect(
      hindi.economyQuestTileSemantics('मिशन', 'false', 3, 10, 0, 0, 'false', 'false', 'false', '', 'false'),
      'मिशन, 10 में से 3',
    );
    expect(
      hindi.economyQuestTileSemantics('मिशन', 'true', 3, 10, 0, 0, 'false', 'false', 'true', '', 'false'),
      'मिशन, पूरा. साप्ताहिक मिशन',
    );
  });

  testWidgets('real Hindi button and sheet remain usable at narrow width and 2x text', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(640, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('hi', 'IN'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: PrismSheetBody(
                scrollable: true,
                title: context.l10n.premiumPageTitle,
                message: context.l10n.accountAccountDeletionSubscriptionWarning,
                actions: <Widget>[PrismButton(label: context.l10n.premiumPageTryAgain, onPressed: () {})],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder button = find.byType(PrismButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    expect(find.text('फिर कोशिश करें'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
