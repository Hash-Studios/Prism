// Reproduction from https://github.com/flutter/flutter/issues/195316.
// Run explicitly when evaluating an SDK fix. Flutter 3.47.8 fails this test.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a node that becomes invisible while its branch is blocked does not '
      'crash when an ancestor geometry cache is stale', (WidgetTester tester) async {
    final blocked = ValueNotifier<bool>(false);
    addTearDown(blocked.dispose);
    final outerLabel = ValueNotifier<String>('outer');
    addTearDown(outerLabel.dispose);
    final offset = ValueNotifier<double>(0.0);
    addTearDown(offset.dispose);
    final middleLabel = ValueNotifier<String>('middle');
    addTearDown(middleLabel.dispose);
    final innerLabel = ValueNotifier<String>('inner');
    addTearDown(innerLabel.dispose);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<bool>(
          valueListenable: blocked,
          builder: (BuildContext context, bool isBlocked, Widget? page) {
            return Stack(
              children: <Widget>[
                page!,
                if (isBlocked) const BlockSemantics(child: SizedBox.expand()),
              ],
            );
          },
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200.0,
              height: 200.0,
              // "outer" is a semantics boundary and a relayout boundary.
              child: ValueListenableBuilder<String>(
                valueListenable: outerLabel,
                builder: (BuildContext context, String label, Widget? child) {
                  return Semantics(container: true, explicitChildNodes: true, label: label, child: child);
                },
                // The transform does not contribute to the semantics tree, so
                // changing it clears the geometry of "middle".
                child: ValueListenableBuilder<double>(
                  valueListenable: offset,
                  builder: (BuildContext context, double dx, Widget? child) {
                    return Transform.translate(offset: Offset(dx, 0.0), child: child);
                  },
                  child: Align(
                    alignment: Alignment.topLeft,
                    // "middle" forms a semantics node but is not a boundary.
                    child: ValueListenableBuilder<String>(
                      valueListenable: middleLabel,
                      builder: (BuildContext context, String label, Widget? child) {
                        return Semantics(label: label, child: child);
                      },
                      // "inner" is a semantics boundary with an empty rect.
                      child: ValueListenableBuilder<String>(
                        valueListenable: innerLabel,
                        builder: (BuildContext context, String label, Widget? child) {
                          return Semantics(container: true, label: label, child: const SizedBox.shrink());
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    blocked.value = true;
    await tester.pump();

    offset.value = 1.0;
    middleLabel.value = 'middle 2';
    await tester.pump();

    outerLabel.value = 'outer 2';
    offset.value = 2.0;
    innerLabel.value = 'inner 2';
    await tester.pump();
    expect(tester.takeException(), isNull);

    blocked.value = false;
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('outer 2'), findsOneWidget);
    expect(find.bySemanticsLabel('middle 2'), findsOneWidget);
  });
}
