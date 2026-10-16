import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  testWidgets('PrismButton blocks taps and shows a spinner while loading', (tester) async {
    int taps = 0;
    await tester.pumpWidget(_host(PrismButton(label: 'Save', loading: true, onPressed: () => taps++)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tester.tap(find.byType(PrismButton));
    expect(taps, 0);
  });

  testWidgets('PrismButton calls onPressed when enabled', (tester) async {
    int taps = 0;
    await tester.pumpWidget(_host(PrismButton(label: 'Save', onPressed: () => taps++)));
    await tester.tap(find.text('Save'));
    expect(taps, 1);
  });

  testWidgets('PrismSwitchRow toggles from a tap anywhere on the row', (tester) async {
    bool value = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) =>
              PrismSwitchRow(title: 'Notifications', value: value, onChanged: (v) => setState(() => value = v)),
        ),
      ),
    );
    await tester.tap(find.text('Notifications'));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('showPrismConfirm resolves true only on the confirm action', (tester) async {
    bool? result;
    await tester.pumpWidget(
      _host(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showPrismConfirm(
              context,
              title: 'Delete it?',
              confirmLabel: 'Delete',
              destructive: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('PrismPage shows the title and a back button with a tooltip', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PrismPage(title: 'Settings', body: SizedBox()),
      ),
    );
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
  });
}
