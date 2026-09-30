import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget host(ShakeController c, {bool reduce = false}) => MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        children: <Widget>[
          ShakeOnce(
            controller: c,
            target: 1,
            child: const SizedBox(key: Key('a'), width: 50, height: 50),
          ),
          ShakeOnce(
            controller: c,
            target: 2,
            child: const SizedBox(key: Key('b'), width: 50, height: 50),
          ),
        ],
      ),
    ),
  );

  testWidgets('only the targeted widget insets, then settles back', (tester) async {
    final ShakeController c = ShakeController();
    await tester.pumpWidget(host(c));
    final Rect a0 = tester.getRect(find.byKey(const Key('a')));
    final Rect b0 = tester.getRect(find.byKey(const Key('b')));

    c.shake(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(find.byKey(const Key('a'))), isNot(a0));
    expect(tester.getRect(find.byKey(const Key('b'))).size, b0.size);

    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getRect(find.byKey(const Key('a'))), a0);
  });

  testWidgets('does nothing under reduce motion', (tester) async {
    final ShakeController c = ShakeController();
    await tester.pumpWidget(host(c, reduce: true));
    final Rect a0 = tester.getRect(find.byKey(const Key('a')));
    c.shake(1);
    await tester.pump(const Duration(milliseconds: 120));
    expect(tester.getRect(find.byKey(const Key('a'))), a0);
  });
}
