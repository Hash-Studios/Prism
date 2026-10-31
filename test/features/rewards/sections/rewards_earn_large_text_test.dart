import 'package:Prism/core/widgets/prism/prism_row.dart';
import 'package:Prism/features/rewards/views/widgets/rewards_earn_section.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final locale in <Locale>[const Locale('en'), const Locale('pt')]) {
    for (final width in <double>[320, 393]) {
      for (final scale in <double>[2, 3]) {
        testWidgets('earn rows fit $locale at $width and ${scale}x text', (tester) async {
          tester.view.physicalSize = Size(width, 10000);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              locale: locale,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const Scaffold(body: SingleChildScrollView(child: RewardsEarnSection())),
            ),
          );
          expect(tester.takeException(), isNull);
          for (final row in tester.widgetList<PrismRow>(find.byType(PrismRow))) {
            expect(row.trailingBelow, isTrue);
            final rowFinder = find.byWidget(row);
            final title = find.descendant(of: rowFinder, matching: find.text(row.title));
            final subtitle = find.descendant(of: rowFinder, matching: find.text(row.subtitle!));
            final reward = find.descendant(of: rowFinder, matching: find.byKey(const ValueKey<String>('reward')));
            final textColumn = find.ancestor(of: title, matching: find.byType(Column)).first;
            expect(tester.getSize(textColumn).width, greaterThan(100));
            expect(tester.getTopLeft(reward).dy, greaterThanOrEqualTo(tester.getBottomLeft(subtitle).dy));
          }
        });
      }
    }
  }

  testWidgets('normal row keeps its trailing widget beside the text', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PrismRow(title: 'Title', subtitle: 'Description', trailing: Text('Reward')),
        ),
      ),
    );
    expect(tester.getTopLeft(find.text('Reward')).dx, greaterThan(tester.getTopRight(find.text('Title')).dx));
    expect(tester.takeException(), isNull);
  });
}
