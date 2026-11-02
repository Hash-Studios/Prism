import 'package:Prism/features/public_profile/views/widgets/pro_profile_badge.dart';
import 'package:Prism/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, {required TextScaler scaler, required double boxSize}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: scaler),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(width: boxSize, height: boxSize, child: const ProProfileBadge()),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('shows Pro with the member label', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();

    await _pump(tester, scaler: TextScaler.noScaling, boxSize: 200);

    expect(find.text('Pro'), findsOneWidget);
    expect(find.bySemanticsLabel('Prism Pro member'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('does not throw at 2x text in a 100px box', (tester) async {
    await _pump(tester, scaler: const TextScaler.linear(2), boxSize: 100);

    expect(find.text('Pro'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
