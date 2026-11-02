import 'dart:convert';
import 'dart:io';

import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/pages/f0_auth_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

class _MockOnboardingBloc extends MockBloc<OnboardingV2Event, OnboardingV2State> implements OnboardingV2Bloc {}

void main() {
  test('Portuguese base fallback stays identical to the complete Brazilian catalogue', () {
    final base = jsonDecode(File('lib/l10n/app_pt.arb').readAsStringSync()) as Map<String, dynamic>;
    final brazilian = jsonDecode(File('lib/l10n/app_pt_BR.arb').readAsStringSync()) as Map<String, dynamic>;
    base.remove('@@locale');
    brazilian.remove('@@locale');

    expect(base, brazilian);
    expect(
      brazilian.entries
          .where((entry) => !entry.key.startsWith('@'))
          .every((entry) => entry.value is String && (entry.value as String).trim().isNotEmpty),
      isTrue,
    );
  });

  test('pt-BR resolves as a supported locale and context-free loader honors its region', () async {
    expect(AppLocalizations.supportedLocales, contains(const Locale('pt', 'BR')));

    final AppLocalizations messages = await loadAppLocalizations(const Locale('pt', 'BR'));

    expect(messages.localeName, 'pt_BR');
    expect(messages.onboardingRecoveryRetry, 'Tente novamente');
  });

  test('pt-BR messages interpolate names and apply all wallpaper plural branches', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('pt', 'BR'));

    expect(messages.onboardingWallpaperForInterest('natureza'), contains('natureza'));
    expect(messages.wallpaperCount(0), 'Nenhum papel de parede');
    expect(messages.wallpaperCount(1), '1 papel de parede');
    expect(messages.wallpaperCount(2), '2 papéis de parede');
    expect(messages.wallpaperCount(1234), '1.234 papéis de parede');
  });

  test('pt-BR decimal and date formatting use Brazilian conventions', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('pt', 'BR'));
    await initializeDateFormatting();

    expect(formatLocalizedNumber(1234, messages), '1.234');
    expect(NumberFormat.decimalPattern(messages.localeName).format(1234.56), '1.234,56');
    final String date = DateFormat.yMMMd(messages.localeName).format(DateTime(2024, 6, 15));
    expect(date, contains('15'));
    expect(date, contains('jun'));
    expect(date, contains('2024'));
  });

  test('pt-BR coin plurals distinguish zero from one and format large counts', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('pt', 'BR'));

    expect(messages.economyCoins(0), '0 moedas');
    expect(messages.economyCoins(1), '1 moeda');
    expect(messages.economyCoins(2), '2 moedas');
    expect(messages.economyNeedMoreCoins(0), 'Faltam 0 moedas.');
    expect(messages.economyNeedMoreCoins(1), 'Falta 1 moeda.');
    expect(messages.economyNeedMoreCoins(1234), 'Faltam 1.234 moedas.');
  });

  test('unsupported locales still resolve to the existing English fallback', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('fr', 'CA'));

    expect(messages.localeName, 'en');
    expect(messages.actionRetry, 'Try again');
  });

  testWidgets('real pt-BR messages render in PrismButton and PrismSheet at 320px with large text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int pressed = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
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
                  title: sheetContext.l10n.onboardingWelcomeHeadline,
                  message: sheetContext.l10n.onboardingWelcomeDescription,
                  actions: <Widget>[
                    PrismButton(
                      label: sheetContext.l10n.onboardingRecoveryRetry,
                      expand: true,
                      onPressed: () => pressed++,
                    ),
                  ],
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

    expect(find.text('Sua tela, reimaginada.'), findsOneWidget);
    expect(find.text('Tente novamente'), findsOneWidget);
    final Finder action = find.byType(PrismButton);
    await tester.ensureVisible(action);
    expect(action.hitTestable(), findsOneWidget);
    await tester.tap(action);
    expect(pressed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iOS onboarding welcome renders pt-BR copy and keeps its guest action reachable at 320px', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final _MockOnboardingBloc bloc = _MockOnboardingBloc();
    when(() => bloc.state).thenReturn(OnboardingV2State.initial());
    final TapGestureRecognizer legalTap = TapGestureRecognizer();
    final TapGestureRecognizer privacyTap = TapGestureRecognizer();
    addTearDown(legalTap.dispose);
    addTearDown(privacyTap.dispose);
    addTearDown(() => toasts.overlayResolver = null);
    int browseCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: prismLightThemes.first.theme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
          child: Scaffold(
            body: Builder(
              builder: (BuildContext context) {
                toasts.overlayResolver = () => Overlay.maybeOf(context);
                return BlocProvider<OnboardingV2Bloc>.value(
                  value: bloc,
                  child: F0AuthPage(
                    termsAccepted: true,
                    onTermsChanged: (_) {},
                    legalTap: legalTap,
                    privacyTap: privacyTap,
                    onGoogle: () {},
                    onApple: () {},
                    onBrowse: () => browseCount++,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sua tela, reimaginada.'), findsOneWidget);
    expect(find.text('Navegue sem uma conta'), findsOneWidget);
    final Finder browse = find.text('Navegue sem uma conta');
    await tester.ensureVisible(browse);
    expect(browse.hitTestable(), findsOneWidget);
    await tester.tap(browse);
    expect(browseCount, 1);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
