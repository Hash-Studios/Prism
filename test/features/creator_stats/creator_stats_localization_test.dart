import 'package:Prism/features/creator_stats/views/pages/creator_stats_page.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

void main() {
  const locales = <Locale>[
    Locale('en'),
    Locale('de'),
    Locale('es'),
    Locale('hi'),
    Locale('id'),
    Locale('pt'),
    Locale('pt', 'BR'),
  ];

  const expectedFormatting = <String, List<String>>{
    'en': ['+1,234 (+123%)', '-1,234 (-100%)', '1,234,567', '1.2K', 'Jan 5', 'Jan 5, 2026', '13:05'],
    'de': ['+1.234 (+123\u00a0%)', '-1.234 (-100\u00a0%)', '1.234.567', '1200', '5. Jan.', '5. Jan. 2026', '13:05'],
    'es': ['+1.234 (+123\u00a0%)', '-1.234 (-100\u00a0%)', '1.234.567', '1,2\u00a0mil', '5 ene', '5 ene 2026', '13:05'],
    'hi': ['+1,234 (+123%)', '-1,234 (-100%)', '12,34,567', '1.2\u00a0हज़ार', '5 जन॰', '5 जन॰ 2026', '13:05'],
    'id': ['+1.234 (+123%)', '-1.234 (-100%)', '1.234.567', '1,2\u00a0rb', '5 Jan', '5 Jan 2026', '13.05'],
    'pt': ['+1.234 (+123%)', '-1.234 (-100%)', '1.234.567', '1,2\u00a0mil', '5 de jan.', '5 de jan. de 2026', '13:05'],
    'pt-BR': [
      '+1.234 (+123%)',
      '-1.234 (-100%)',
      '1.234.567',
      '1,2\u00a0mil',
      '5 de jan.',
      '5 de jan. de 2026',
      '13:05',
    ],
  };

  setUpAll(initializeDateFormatting);

  for (final locale in locales) {
    testWidgets('creator stats use locale-specific formatting for ${locale.toLanguageTag()}', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final resolvedTag = Localizations.localeOf(context).toLanguageTag();
              final deltaUp = statsChange(context, 2234, 1000)!;
              final deltaDown = statsChange(context, 0, 1234)!;
              final heroNumber = statsNumber(context, 1234567);
              final compactAxis = NumberFormat.compact(locale: resolvedTag).format(1200);
              final monthDay = DateFormat.MMMd(resolvedTag).format(DateTime.utc(2026, 1, 5));
              final longDate = DateFormat.yMMMd(resolvedTag).format(DateTime.utc(2026, 1, 5));
              final time = DateFormat.Hm(resolvedTag).format(DateTime.utc(2026, 1, 5, 13, 5));
              expect(resolvedTag, locale.toLanguageTag());
              expect(
                [deltaUp, deltaDown, heroNumber, compactAxis, monthDay, longDate, time],
                expectedFormatting[locale.toLanguageTag()],
                reason: 'Creator stats formatting must use the exact locale tag $resolvedTag.',
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    });
  }

  testWidgets('a change that rounds to 0% shows only the difference', (tester) async {
    late String up;
    late String down;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            up = statsChange(context, 1001, 1000)!;
            down = statsChange(context, 1990, 2000)!;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(up, '+1');
    expect(down, '-10 (-1%)');
  });
}
