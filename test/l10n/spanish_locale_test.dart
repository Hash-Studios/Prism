import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('uses Spanish for the device locale', (WidgetTester tester) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('es')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    late String title;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            title = context.l10n.actionRetry;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(title, 'Intentar de nuevo');
  });

  testWidgets('context-free device localization matches MaterialApp preferred locale resolution', (
    WidgetTester tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const <Locale>[Locale('fr'), Locale('es', 'MX')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    final AppLocalizations deviceMessages = await loadDeviceAppLocalizations();
    late String appLocaleName;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (BuildContext context) {
            appLocaleName = AppLocalizations.of(context).localeName;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(deviceMessages.localeName, 'es');
    expect(appLocaleName, deviceMessages.localeName);
  });

  test('uses the Spanish translation for regional Spanish locales', () async {
    for (final Locale locale in <Locale>[const Locale('es', 'MX'), const Locale('es', 'ES')]) {
      final AppLocalizations messages = await loadAppLocalizations(locale);

      expect(messages.localeName, 'es');
      expect(messages.actionRetry, 'Intentar de nuevo');
    }
  });

  test('unsupported locales fall back to English', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('fr'));

    expect(messages.localeName, 'en');
    expect(messages.actionRetry, 'Try again');
  });

  testWidgets('locale changes update visible copy on a real Prism button', (WidgetTester tester) async {
    final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('en'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (BuildContext context, Locale value, Widget? child) => MaterialApp(
          locale: value,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: Builder(
                builder: (BuildContext context) =>
                    PrismButton(label: context.l10n.actionRetry, icon: Icons.refresh, onPressed: () {}),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);

    locale.value = const Locale('es');
    await tester.pumpAndSettle();

    expect(find.text('Intentar de nuevo'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  test('Spanish plurals, number grouping, and interpolation use the generated messages', () async {
    final AppLocalizations messages = await loadAppLocalizations(const Locale('es'));

    expect(messages.wallpaperCount(1), '1 fondo de pantalla');
    expect(messages.wallpaperCount(12345), '12.345 fondos de pantalla');
    expect(messages.wallpaperViewCount(12345), '12.345 visualizaciones');
    expect(messages.wallpaperAutoRotatePreparing(2), 'Preparando 2 fondos de pantalla');
  });

  testWidgets('long Spanish confirmation keeps its actions reachable at 320px and 2x text scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Builder(
              builder: (BuildContext context) => PrismSheetBody(
                scrollable: true,
                title: context.l10n.accountDeleteYourAccountQuestion,
                message: context.l10n.accountDeleteAccountConfirmation,
                actions: <Widget>[
                  PrismButton(label: context.l10n.accountDeleteAccount, onPressed: () {}),
                  PrismButton(label: context.l10n.accountCancel, onPressed: () {}),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder confirm = find.text('Eliminar cuenta');
    final Finder cancel = find.text('Cancelar');
    expect(find.text('¿Eliminar tu cuenta?'), findsOneWidget);
    expect(find.textContaining('Esto eliminará tu cuenta de forma permanente'), findsOneWidget);
    await tester.ensureVisible(confirm);
    expect(confirm.hitTestable(), findsOneWidget);
    await tester.ensureVisible(cancel);
    expect(cancel.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
