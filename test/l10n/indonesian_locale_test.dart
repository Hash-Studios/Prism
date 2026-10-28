import 'dart:math';

import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_prompt_pools.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/upload_preview_row.dart';
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
    expect(
      language.accountPurchasesRestoredPending,
      'Pembelian dipulihkan. Pro mungkin perlu waktu satu menit untuk aktif.',
    );
    expect(
      language.premiumPurchasePending,
      'Pembelian Anda tersimpan. Pro mungkin perlu waktu satu menit untuk aktif.',
    );
    expect(
      language.premiumPurchaseUnconfirmed,
      'Pembelian Anda tidak dapat dikonfirmasi. Coba Pulihkan pembelian di Pengaturan.',
    );
  });

  test('unsupported preferred locales fall through to Indonesian', () async {
    final Locale resolvedLocale = basicLocaleListResolution(const <Locale>[
      Locale('fr'),
      Locale('id', 'ID'),
    ], AppLocalizations.supportedLocales);
    final AppLocalizations messages = await loadAppLocalizations(resolvedLocale);

    expect(messages.localeName, 'id');
    expect(messages.actionRetry, 'Coba lagi');
    expect(messages.economyExportFailedLabel, 'Ekspor gagal');
  });

  testWidgets('context-free messages resolve from the platform locale list', (WidgetTester tester) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('fr'), Locale('id', 'ID')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    final AppLocalizations messages = await loadDeviceAppLocalizations();

    expect(messages.localeName, 'id');
    expect(messages.actionRetry, 'Coba lagi');
    expect(messages.economyExportFailedLabel, 'Ekspor gagal');

    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('fr')];
    final AppLocalizations fallbackMessages = await loadDeviceAppLocalizations();

    expect(fallbackMessages.localeName, 'en');
    expect(fallbackMessages.actionRetry, 'Try again');
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

  test('AI suggestions and upload sizes use Indonesian at their production boundaries', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('id'));

    expect(
      AiPromptPools.sceneIdea(messages, AiStylePreset.minimal, 0),
      'satu perahu kertas di atas air tenang yang pucat, wallpaper ponsel vertikal tanpa teks',
    );
    for (final AiStylePreset style in AiStylePreset.values) {
      expect(AiPromptPools.scenesByStyle(messages, style), hasLength(8));
      final String prompt = AiPromptPools.randomPrompt(messages, style, Random(0));
      expect(prompt, contains(', palet '));
      expect(prompt, endsWith('wallpaper ponsel vertikal tanpa teks'));
    }
    expect(formatFileSize('0.25MB', messages.localeName), '0,25 MB');
    expect(messages.coreSignInFeatureTitle(messages.coreSignInCreatorSearchFeature), contains('pencarian kreator'));
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
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showPrismSheet<void>(
                context,
                builder: (BuildContext sheetContext) => PrismSheetBody(
                  title: sheetContext.l10n.wallpaperFeedEmptyTitle,
                  message: sheetContext.l10n.wallpaperFeedEmptyBody,
                  actions: <Widget>[PrismButton(label: sheetContext.l10n.actionRetry, onPressed: () {})],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Coba lagi'), findsOneWidget);
    expect(find.byType(PrismButton), findsOneWidget);
    await tester.ensureVisible(find.byType(PrismButton));
    await tester.pumpAndSettle();
    expect(find.byType(PrismButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
