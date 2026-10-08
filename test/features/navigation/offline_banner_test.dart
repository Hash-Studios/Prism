import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _slide = find.descendant(of: find.byType(ConnectivityWidget), matching: find.byType(SlideTransition));

void main() {
  testWidgets('rebuilds reuse the curve and disposal releases its listener', (tester) async {
    final key = GlobalKey();
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(offline: true, key: key)),
      ),
    );
    await pump();
    final position = tester.widget<SlideTransition>(_slide).position;
    final curve = (position as AnimationWithParentMixin<double>).parent as CurvedAnimation;
    await pump();
    final rebuiltPosition = tester.widget<SlideTransition>(_slide).position;
    expect((rebuiltPosition as AnimationWithParentMixin<double>).parent, same(curve));
    await tester.pumpWidget(const SizedBox());
    expect(curve.isDisposed, isTrue);
  });

  testWidgets('enabling reduced motion settles an in-flight banner immediately', (tester) async {
    final key = GlobalKey();
    Future<void> pump(bool reduce) => tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduce),
          child: Scaffold(body: ConnectivityWidget(offline: true, key: key)),
        ),
      ),
    );
    await pump(false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, greaterThan(0));
    await pump(true);
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('the banner slides in after a second while offline and stays', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget(offline: true))));
    expect(find.text('No Internet'), findsOneWidget);
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, 1);

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);

    await tester.pump(const Duration(seconds: 30));
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);
  });

  testWidgets('the banner hides on recovery and shows again when the connection drops', (tester) async {
    Future<void> pump({required bool offline}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(offline: offline)),
      ),
    );

    await pump(offline: true);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);

    await pump(offline: false);
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, 1);

    await pump(offline: true);
    await tester.pumpAndSettle();
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);
  });

  testWidgets('an online start never shows the banner', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget(offline: false))));
    await tester.pump(const Duration(seconds: 12));

    expect(tester.widget<SlideTransition>(_slide).position.value.dy, 1);
  });

  testWidgets('leaving the screen before the timer fires cancels it', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget(offline: true))));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

    await tester.pump(const Duration(seconds: 12));

    expect(tester.takeException(), isNull);
  });
}
