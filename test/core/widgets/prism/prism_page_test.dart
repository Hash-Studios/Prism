import 'package:Prism/core/widgets/prism/prism_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the header uses the last metrics reported during a layout frame', (tester) async {
    bool sent = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PrismPage(
          title: 'Title',
          bottomBar: const SizedBox(height: 52, key: Key('pinned-action')),
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (!sent) {
                sent = true;
                for (final double offset in <double>[100, 0]) {
                  ScrollMetricsNotification(
                    metrics: FixedScrollMetrics(
                      minScrollExtent: 0,
                      maxScrollExtent: offset,
                      pixels: offset / 2,
                      viewportDimension: constraints.maxHeight,
                      axisDirection: AxisDirection.down,
                      devicePixelRatio: 1,
                    ),
                    context: context,
                  ).dispatch(context);
                }
              }
              return const SizedBox.expand();
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final AnimatedOpacity hairline = tester.widget<AnimatedOpacity>(
      find.ancestor(of: find.byType(Divider), matching: find.byType(AnimatedOpacity)),
    );
    expect(hairline.opacity, 0, reason: 'the final content has no scroll offset');
    final DecoratedBox bar = tester.widget<DecoratedBox>(
      find.ancestor(of: find.byKey(const Key('pinned-action')), matching: find.byType(DecoratedBox)).first,
    );
    expect(((bar.decoration as BoxDecoration).border! as Border).top.color, Colors.transparent);
  });
}
