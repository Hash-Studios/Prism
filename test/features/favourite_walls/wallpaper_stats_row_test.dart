import 'package:Prism/features/favourite_walls/views/widgets/wallpaper_stats_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compact totals use one decimal and locale separators', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: WallpaperStatsRow(favourites: 999, views: 1234)),
      ),
    );
    expect(find.text('999'), findsOneWidget);
    expect(find.text('1.2K'), findsOneWidget);

    for (final (int count, String expected) in <(int, String)>[(1000, '1K'), (12345, '12.3K'), (1000000, '1M')]) {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Center(child: WallpaperStatsRow(views: count)),
        ),
      );
      expect(find.text(expected), findsOneWidget, reason: '$count in en');
    }

    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('hi'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: WallpaperStatsRow(views: 1234)),
      ),
    );
    expect(find.text('1.2 हज़ार'), findsOneWidget);
  });

  testWidgets('zero counts are hidden, the heart and its label stay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: WallpaperStatsRow(favourites: 0, views: 0)),
      ),
    );
    expect(find.byIcon(Icons.bar_chart_rounded), findsNothing);
    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.bySemanticsLabel('No favourites'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: WallpaperStatsRow(views: 0)),
      ),
    );
    expect(find.byType(Icon), findsNothing);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('detail totals are read-only and expose exact accessible counts', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: WallpaperStatsRow(favourites: 12345, views: 65432)),
      ),
    );
    for (final String label in <String>['12,345 favourites', '65,432 views']) {
      final SemanticsNode node = tester.getSemantics(find.bySemanticsLabel(label));
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    }
    expect(find.byType(GestureDetector), findsNothing);
    expect(find.byType(Tooltip), findsNothing);
    semantics.dispose();
  });

  testWidgets('counts use a 13 w600 caption and 17 pt icons', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Center(child: WallpaperStatsRow(favourites: 3, views: 12)),
      ),
    );
    for (final String count in <String>['3', '12']) {
      final TextStyle style = tester.widget<Text>(find.text(count)).style!;
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w600);
    }
    for (final Icon icon in tester.widgetList<Icon>(find.byType(Icon))) {
      expect(icon.size, 17);
    }
  });
}
