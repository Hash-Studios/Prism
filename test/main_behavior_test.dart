import 'package:Prism/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Counter extends StatefulWidget {
  const _Counter({required this.onDispose});
  final VoidCallback onDispose;

  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int count = 0;

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      TextButton(onPressed: () => setState(() => count++), child: Text('Count $count')),
      TextButton(onPressed: () => RestartWidget.restartApp(context), child: const Text('Restart')),
    ],
  );
}

void main() {
  testWidgets('restart discards descendant state and disposes the old subtree on every restart', (tester) async {
    int disposals = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RestartWidget(child: _Counter(onDispose: () => disposals++)),
      ),
    );

    for (int restart = 1; restart <= 2; restart++) {
      await tester.tap(find.text('Count 0'));
      await tester.pump();
      expect(find.text('Count 1'), findsOneWidget);
      await tester.tap(find.text('Restart'));
      await tester.pump();
      expect(find.text('Count 0'), findsOneWidget);
      expect(find.text('Count 1'), findsNothing);
      expect(disposals, restart);
    }
  });
}
