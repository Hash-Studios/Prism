import 'package:Prism/core/widgets/prism/prism_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PrismSlider semantics', () {
    late SemanticsHandle semantics;

    setUp(() {
      semantics = TestWidgetsFlutterBinding.ensureInitialized().ensureSemantics();
    });

    tearDown(() {
      semantics.dispose();
    });

    testWidgets('uses native continuous step size on iOS and reports ordered callbacks', (tester) async {
      final List<String> calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.iOS),
          home: Scaffold(
            body: PrismSlider(
              value: 15,
              min: 10,
              max: 20,
              label: 'Brightness',
              semanticFormatterCallback: (value) => value.toStringAsFixed(1),
              onChangeStart: (value) => calls.add('start:$value'),
              onChanged: (value) => calls.add('change:$value'),
              onChangeEnd: (value) => calls.add('end:$value'),
            ),
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(PrismSlider));
      expect(node.label, 'Brightness');
      expect(node.value, '15.0');
      expect(node.increasedValue, '16.0');
      expect(node.decreasedValue, '14.0');
      expect(node.getSemanticsData().flagsCollection.isFocused.toBoolOrNull(), isFalse);

      node.owner!.performAction(node.id, SemanticsAction.focus);
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(PrismSlider)).getSemanticsData().flagsCollection.isFocused.toBoolOrNull(),
        isTrue,
      );

      final SemanticsNode focusedNode = tester.getSemantics(find.byType(PrismSlider));
      focusedNode.owner!.performAction(focusedNode.id, SemanticsAction.increase);
      expect(calls, <String>['start:15.0', 'change:16.0', 'end:16.0']);
      calls.clear();
      focusedNode.owner!.performAction(focusedNode.id, SemanticsAction.decrease);
      expect(calls, <String>['start:15.0', 'change:14.0', 'end:14.0']);
    });

    testWidgets('snaps discrete semantic values and actions to normalized divisions', (tester) async {
      final List<String> calls = <String>[];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: PrismSlider(
              value: 4,
              max: 10,
              divisions: 4,
              semanticFormatterCallback: (value) => value.toStringAsFixed(1),
              onChangeStart: (value) => calls.add('start:$value'),
              onChanged: (value) => calls.add('change:$value'),
              onChangeEnd: (value) => calls.add('end:$value'),
            ),
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(PrismSlider));
      expect(node.value, '5.0');
      expect(node.increasedValue, '7.5');

      node.owner!.performAction(node.id, SemanticsAction.increase);
      expect(calls, <String>['start:5.0', 'change:7.5', 'end:7.5']);
    });

    testWidgets('uses a five percent continuous step on Android', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.android),
          home: Scaffold(
            body: PrismSlider(
              value: 15,
              min: 10,
              max: 20,
              semanticFormatterCallback: (value) => value.toStringAsFixed(1),
              onChanged: (_) {},
            ),
          ),
        ),
      );

      expect(tester.getSemantics(find.byType(PrismSlider)).increasedValue, '15.5');
    });

    testWidgets('Windows accessibility focus also gives the slider input focus', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(platform: TargetPlatform.windows),
          home: const Scaffold(body: PrismSlider(value: 0.5, onChanged: _ignoreValue)),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(PrismSlider));
      expect(node.getSemanticsData().flagsCollection.isFocused.toBoolOrNull(), isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.didGainAccessibilityFocus), isTrue);
      node.owner!.performAction(node.id, SemanticsAction.didGainAccessibilityFocus);
      await tester.pump();
      expect(
        tester.getSemantics(find.byType(PrismSlider)).getSemanticsData().flagsCollection.isFocused.toBoolOrNull(),
        isTrue,
      );
    });

    testWidgets('keeps the parent label and sibling semantics separate', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: <Widget>[
                const Text('Before'),
                Semantics(
                  label: 'Hue',
                  child: const SizedBox(width: 300, child: PrismSlider(value: 0.5, onChanged: _ignoreValue)),
                ),
                const Text('After'),
                Semantics(label: 'Next control', child: const SizedBox(width: 20, height: 20)),
              ],
            ),
          ),
        ),
      );

      expect(tester.getSemantics(find.byType(PrismSlider)).label, 'Hue');
      expect(find.bySemanticsLabel('Before'), findsOneWidget);
      expect(find.bySemanticsLabel('After'), findsOneWidget);
      expect(find.bySemanticsLabel('Next control'), findsOneWidget);
    });

    testWidgets('refreshes values, formatters, divisions, ranges, and disabled state after rebuild', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrismSlider(
              value: 0.25,
              divisions: 4,
              semanticFormatterCallback: (value) => 'old:$value',
              onChanged: _ignoreValue,
            ),
          ),
        ),
      );

      expect(tester.getSemantics(find.byType(PrismSlider)).value, 'old:0.25');

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrismSlider(
              value: 20,
              min: 10,
              max: 30,
              divisions: 2,
              semanticFormatterCallback: (value) => 'new:$value',
              onChanged: null,
            ),
          ),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(PrismSlider));
      expect(node.value, 'new:20.0');
      expect(node.increasedValue, 'new:30.0');
      expect(node.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isFalse);
    });

    for (final (double, SemanticsAction) bound in <(double, SemanticsAction)>[
      (1, SemanticsAction.increase),
      (0, SemanticsAction.decrease),
    ]) {
      testWidgets('does not report a value change for ${bound.$2} at ${bound.$1}', (tester) async {
        final List<String> calls = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PrismSlider(
                value: bound.$1,
                onChangeStart: (value) => calls.add('start:$value'),
                onChanged: (value) => calls.add('change:$value'),
                onChangeEnd: (value) => calls.add('end:$value'),
              ),
            ),
          ),
        );

        final SemanticsNode node = tester.getSemantics(find.byType(PrismSlider));
        node.owner!.performAction(node.id, bound.$2);
        expect(calls, <String>['start:${bound.$1}', 'end:${bound.$1}']);
      });
    }

    testWidgets('zero range is disabled and has a finite default value', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PrismSlider(value: 3, min: 3, max: 3, onChanged: (_) {})),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(PrismSlider));
      expect(node.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      expect(node.getSemanticsData().hasAction(SemanticsAction.increase), isFalse);
      expect(node.value, '0%');
      expect(node.getSemanticsData().traversalChildIdentifier, isNull);
    });
  });
}

void _ignoreValue(double _) {}
