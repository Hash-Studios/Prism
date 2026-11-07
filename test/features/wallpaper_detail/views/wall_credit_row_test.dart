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

  // The summary above the details names the creator, so the credit says only where the wall is from.
  testWidgets('a creator credit shows Prism exclusive, not the name again', (tester) async {
    await _pump(tester, credits['creator']!);

    expect(find.text('Prism exclusive'), findsOneWidget);
    expect(find.textContaining('Ana'), findsNothing);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
  });

  testWidgets('a Studio credit shows Prism exclusive, not Hash Studios again', (tester) async {
    await _pump(tester, credits['studio']!);

    expect(find.text('Prism exclusive'), findsOneWidget);
    expect(find.textContaining('Hash Studios'), findsNothing);
  });

  testWidgets('a Pexels credit with no link shows its source as plain text', (tester) async {
    await _pump(tester, credits['pexels']!);

    expect(find.text('From Pexels'), findsOneWidget);
    expect(find.textContaining('Lee'), findsNothing);
    expect(find.byIcon(Icons.open_in_new_rounded), findsNothing);
  });

  testWidgets('a Wallhaven credit shows its source as a link that opens outside the app', (tester) async {
    await _pump(
      tester,
      WallCredit(
        provenance: WallProvenance.wallhaven,
        name: 'kit',
        externalUrl: Uri.https('wallhaven.cc', '/user/kit'),
      ),
    );

    expect(find.text('From Wallhaven'), findsOneWidget);
    expect(find.textContaining('kit'), findsNothing);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    expect(find.ancestor(of: find.text('From Wallhaven'), matching: find.byType(InkWell)), findsOneWidget);
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
