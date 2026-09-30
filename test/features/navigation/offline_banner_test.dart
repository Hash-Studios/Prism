import 'package:Prism/features/navigation/views/widgets/offline_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _slide = find.descendant(of: find.byType(ConnectivityWidget), matching: find.byType(SlideTransition));

void main() {
  testWidgets('rebuilds reuse the curve and disposal releases its listener', (tester) async {
    final key = GlobalKey();
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConnectivityWidget(key: key)),
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
          child: Scaffold(body: ConnectivityWidget(key: key)),
        ),
      ),
    );
    await pump(false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.widget<SlideTransition>(_slide).position.value.dy, lessThan(0));
    await pump(true);
    expect(tester.widget<SlideTransition>(_slide).position.value, Offset.zero);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('the pill slides down after a second and out after ten', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget())));
    expect(find.text('You are offline'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 12));

    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving the screen before the timers fire cancels them', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: ConnectivityWidget())));
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: SizedBox())));

    await tester.pump(const Duration(seconds: 12));

    expect(tester.takeException(), isNull);
  });
}
