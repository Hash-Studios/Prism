import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/l10n/generated/app_localizations_en.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TestMessages extends AppLocalizationsEn {
  _TestMessages(super.locale);

  @override
  String get actionRetry => localeName == 'ar' ? 'حاول مرة أخرى مع نص طويل للتحقق من مساحة الزر' : 'Try again';
}

class _TestMessagesDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _TestMessagesDelegate();

  @override
  bool isSupported(Locale locale) => <String>{'en', 'ar'}.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture<AppLocalizations>(_TestMessages(locale.languageCode));

  @override
  bool shouldReload(_TestMessagesDelegate old) => false;
}

void main() {
  testWidgets('locale changes rebuild visible copy and mirror a real Prism button', (WidgetTester tester) async {
    final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('en'));
    addTearDown(locale.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<Locale>(
        valueListenable: locale,
        builder: (BuildContext context, Locale value, Widget? child) => MaterialApp(
          locale: value,
          supportedLocales: const <Locale>[Locale('en'), Locale('ar')],
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            _TestMessagesDelegate(),
            ...AppLocalizations.localizationsDelegates,
          ],
          home: Scaffold(
            body: Builder(
              builder: (BuildContext context) => Center(
                child: SizedBox(
                  width: 280,
                  child: PrismButton(label: context.l10n.actionRetry, icon: Icons.refresh, onPressed: () {}),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.getCenter(find.byIcon(Icons.refresh)).dx, lessThan(tester.getCenter(find.text('Try again')).dx));

    locale.value = const Locale('ar');
    await tester.pumpAndSettle();
    final Finder label = find.text('حاول مرة أخرى مع نص طويل للتحقق من مساحة الزر');
    expect(label, findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(Directionality.of(tester.element(label)), TextDirection.rtl);
    expect(tester.getCenter(find.byIcon(Icons.refresh)).dx, greaterThan(tester.getCenter(label).dx));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow sheet keeps long localized copy and actions reachable at large text scale', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: PrismSheetBody(
              scrollable: true,
              title: 'An intentionally extended translated confirmation title',
              message: List<String>.filled(
                10,
                'A translated explanation can need more space than the English text.',
              ).join(' '),
              actions: <Widget>[PrismButton(label: 'Confirm the translated action', onPressed: () {})],
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
    expect(tester.takeException(), isNull);
  });
}
