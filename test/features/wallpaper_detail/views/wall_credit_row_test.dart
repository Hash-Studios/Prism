import 'package:Prism/features/wallpaper_detail/domain/entities/wall_credit.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wall_credit_row.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, WallCredit credit, {TextScaler textScaler = TextScaler.noScaling}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.centerRight,
          child: SizedBox(width: 180, child: WallCreditRow(credit: credit)),
        ),
      ),
    ),
  );
}

void main() {
  const Map<String, WallCredit> credits = <String, WallCredit>{
    'creator': WallCredit(provenance: WallProvenance.creator, name: 'Ana', profileUid: 'ana-uid'),
    'studio': WallCredit(provenance: WallProvenance.studio, profileUid: WallCredit.studioProfileUid),
    'pexels': WallCredit(provenance: WallProvenance.pexels, name: 'Lee'),
    'wallhaven': WallCredit(provenance: WallProvenance.wallhaven, name: 'kit'),
  };

  testWidgets('a creator credit shows the name and Prism exclusive', (tester) async {
    await _pump(tester, credits['creator']!);

    expect(find.text('By Ana'), findsOneWidget);
    expect(find.text('Prism exclusive'), findsOneWidget);
  });

  testWidgets('a Studio credit shows Hash Studios and Prism exclusive', (tester) async {
    await _pump(tester, credits['studio']!);

    expect(find.text('By Hash Studios'), findsOneWidget);
    expect(find.text('Prism exclusive'), findsOneWidget);
  });

  testWidgets('a Pexels credit shows the photographer and its source', (tester) async {
    await _pump(tester, credits['pexels']!);

    expect(find.text('Photo by Lee'), findsOneWidget);
    expect(find.text('From Pexels'), findsOneWidget);
  });

  testWidgets('a Wallhaven credit shows the uploader and its source', (tester) async {
    await _pump(tester, credits['wallhaven']!);

    expect(find.text('By kit'), findsOneWidget);
    expect(find.text('From Wallhaven'), findsOneWidget);
  });

  testWidgets('a creator credit is a button that opens the profile', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester, credits['creator']!);

    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.hint == 'Opens the profile'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('a source credit with no link is not a button', (tester) async {
    await _pump(tester, credits['pexels']!);

    expect(find.byType(InkWell), findsNothing);
  });

  for (final String source in credits.keys) {
    testWidgets('the $source credit does not overflow at 2.0 text scale in 180 px', (tester) async {
      await _pump(tester, credits[source]!, textScaler: const TextScaler.linear(2.0));

      expect(tester.takeException(), isNull);
    });
  }
}
