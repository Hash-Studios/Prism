import 'dart:math';

import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_style_preset.dart';
import 'package:Prism/features/ai_wallpaper/views/ai_prompt_pools.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/wallpaper_upload/views/widgets/upload_preview_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

Future<void> _loadBundledFont() async {
  final List<(String, String)> fonts = <(String, String)>[
    ('Satoshi', 'assets/fonts/Satoshi-Regular.otf'),
    ('Fraunces', 'assets/fonts/Fraunces-Variable.ttf'),
    ('Proxima Nova', 'assets/fonts/ProximaNova-Regular.otf'),
  ];
  for (final (String family, String asset) in fonts) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

Future<void> _pumpAt320(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(320, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('de', 'DE'),
      theme: ThemeData(fontFamily: 'Proxima Nova'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
          child: home,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadBundledFont);

  testWidgets('de-DE and de-AT resolve to German while an unsupported locale falls back to English', (
    WidgetTester tester,
  ) async {
    for (final Locale locale in <Locale>[const Locale('de', 'DE'), const Locale('de', 'AT')]) {
      late String label;
      late String resolvedLocale;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (BuildContext context) {
              resolvedLocale = context.l10n.localeName;
              label = context.l10n.actionRetry;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(resolvedLocale, 'de');
      expect(label, 'Erneut versuchen');
    }

    late String fallback;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zz', 'ZZ'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            fallback = context.l10n.actionRetry;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(fallback, 'Try again');
  });

  testWidgets('visible widgets rebuild from English to German without restarting', (WidgetTester tester) async {
    final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('en'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (BuildContext context, Locale value, Widget? child) => MaterialApp(
          locale: value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(builder: (BuildContext context) => Scaffold(body: Text(context.l10n.onboardingContinueGoogle))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Continue with Google'), findsOneWidget);

    locale.value = const Locale('de', 'DE');
    await tester.pumpAndSettle();
    expect(find.text('Mit Google fortfahren'), findsOneWidget);
    expect(find.text('Continue with Google'), findsNothing);
  });

  test('German plurals, grouped numbers, dates, and interpolated names use real German messages', () async {
    await initializeDateFormatting('de');
    final AppLocalizations de = await loadAppLocalizations(const Locale('de', 'DE'));

    expect(de.wallpaperCount(0), 'Keine Hintergrundbilder');
    expect(de.wallpaperCount(1), '1 Hintergrundbild');
    expect(de.wallpaperCount(2), '2 Hintergrundbilder');
    expect(de.wallpaperCount(1234), '1.234 Hintergrundbilder');
    expect(de.economyNeedMoreCoins(1), 'Dir fehlt noch 1 Coin.');
    expect(de.economyNeedMoreCoins(1234), 'Dir fehlen noch 1.234 Coins.');
    expect(de.economyAiApplyingStyle, 'Dein Stil wird angewendet…');
    expect(formatLocalizedNumber(1234, de), '1.234');
    expect(DateFormat.yMMMMd(de.localeName).format(DateTime(2025, 3, 8)), '8. März 2025');

    const String userName = 'Åke “<script>&”';
    final String notification = de.notifGroupFollowerSummary(userName, 2);
    expect(notification, contains(userName));
    expect(notification, contains('2 weitere Personen folgen dir.'));
  });

  test('known categories and wire protocol values map without changing stable values', () async {
    final AppLocalizations de = await loadAppLocalizations(const Locale('de'));

    expect(categoryDisplayName('Nature', de), 'Natur');
    expect(categoryDisplayName('unknown server category', de), 'unknown server category');
    expect(de.wallpaperFilterTabFilters, 'Filter');
    expect(de.wallpaperAutoRotateSourceCategory, 'Kategorie');
    expect(WallpaperSourceX.fromWire('wall_of_the_day'), WallpaperSource.prism);
    expect(WallpaperSourceX.fromWire('downloads'), WallpaperSource.downloaded);
    expect(WallpaperSource.prism.wireValue, 'prism');
  });

  test('AI examples and upload sizes use German at their presentation boundaries', () async {
    final AppLocalizations de = await loadAppLocalizations(const Locale('de'));
    final AppLocalizations en = await loadAppLocalizations(const Locale('en'));

    expect(
      AiPromptPools.sceneIdea(de, AiStylePreset.nature, 0),
      'Eine neblige Bergkette im Morgenlicht, Hintergrundbild im Hochformat fürs Smartphone, ohne Text',
    );
    for (final AiStylePreset style in AiStylePreset.values) {
      final List<String> scenes = AiPromptPools.scenesByStyle(de, style);
      final List<String> onboarding = OnboardingV2Config.aiOnboardingPrompts(de, style);
      expect(scenes, hasLength(5));
      expect(onboarding, hasLength(5));
      expect(scenes.toSet().intersection(AiPromptPools.scenesByStyle(en, style).toSet()), isEmpty);
      expect(onboarding.toSet().intersection(OnboardingV2Config.aiOnboardingPrompts(en, style).toSet()), isEmpty);
      final String prompt = AiPromptPools.randomPrompt(de, style, Random(0));
      expect(prompt, contains('Hintergrundbild im Hochformat fürs Smartphone, ohne Text'));
      expect(prompt, isNot(contains('lighting')));
      expect(prompt, isNot(contains('mood')));
    }
    expect(formatFileSize('12.50MB', de.localeName), '12,50 MB');
    expect(de.coreSignInFeatureTitle(de.coreSignInCreatorSearchFeature), 'Melde dich für „Suche nach Kreativen“ an');
  });

  testWidgets('PrismButton keeps a long German action reachable at 320px and 2x text', (WidgetTester tester) async {
    late String label;
    await _pumpAt320(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            label = context.l10n.wallpaperUploadDeletePermissionError;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: PrismButton(label: label, onPressed: () {}),
              ),
            );
          },
        ),
      ),
    );

    final Finder button = find.byType(PrismButton);
    expect(find.text(label), findsOneWidget);
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('PrismSheetBody scrolls long German content to its reachable action at 320px and 2x text', (
    WidgetTester tester,
  ) async {
    late String title;
    late String message;
    late String action;
    await _pumpAt320(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            title = context.l10n.accountRemoveSavedOfflineQuestion;
            message = context.l10n.accountDeleteAccountConfirmation;
            action = context.l10n.accountDeleteAccount;
            return PrismSheetBody(
              scrollable: true,
              title: title,
              message: List<String>.filled(3, message).join(' '),
              actions: <Widget>[PrismButton(label: action, onPressed: () {})],
            );
          },
        ),
      ),
    );

    expect(find.text(title), findsOneWidget);
    expect(find.text(action), findsOneWidget);
    final Finder button = find.byType(PrismButton);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('OnboardingPrimaryButton remains tappable with an actual German label at 320px and 2x text', (
    WidgetTester tester,
  ) async {
    late String label;
    await _pumpAt320(
      tester,
      Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            label = context.l10n.onboardingContinueSelected(1234);
            return Center(
              child: SizedBox(
                width: 288,
                height: 56,
                child: OnboardingPrimaryButton(label: label, onPressed: () {}),
              ),
            );
          },
        ),
      ),
    );

    expect(label, 'Weiter (1.234 ausgewählt)');
    expect(find.byType(OnboardingPrimaryButton).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
