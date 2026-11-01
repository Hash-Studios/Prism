import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SheetObserver extends NavigatorObserver {
  Route<dynamic>? lastPushedRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    lastPushedRoute = route;
  }
}

void main() {
  Future<GlobalKey<NavigatorState>> pumpApp(WidgetTester tester, {NavigatorObserver? observer}) async {
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        navigatorObservers: observer == null ? const <NavigatorObserver>[] : <NavigatorObserver>[observer],
        builder: (context, child) =>
            MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: false), child: child!),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPrismSheet<void>(context, builder: (_) => const Text('sheet')),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    return navigatorKey;
  }

  testWidgets('counts install through reverse transition, then decrements on pop', (tester) async {
    final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester);
    expect(openPrismSheetCount, 0);

    await tester.tap(find.text('open'));
    await tester.pump();
    expect(openPrismSheetCount, 1);
    await tester.pump(const Duration(seconds: 1));

    navigatorKey.currentState!.pop();
    expect(openPrismSheetCount, 1);
    await tester.pump(const Duration(milliseconds: 16));
    expect(openPrismSheetCount, 1);
    await tester.pump(const Duration(seconds: 1));

    expect(openPrismSheetCount, 0);
  });

  testWidgets('decrements when Navigator removes a sheet route without pop', (tester) async {
    final _SheetObserver observer = _SheetObserver();
    final GlobalKey<NavigatorState> navigatorKey = await pumpApp(tester, observer: observer);
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(openPrismSheetCount, 1);

    navigatorKey.currentState!.removeRoute(observer.lastPushedRoute!);
    await tester.pump();

    expect(openPrismSheetCount, 0);
  });

  testWidgets('decrements when the owning Navigator is disposed', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('open'));
    await tester.pump();
    expect(openPrismSheetCount, 1);

    await tester.pumpWidget(const SizedBox.shrink());

    expect(openPrismSheetCount, 0);
  });
}
