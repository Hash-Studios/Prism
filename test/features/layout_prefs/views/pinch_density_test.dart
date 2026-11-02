import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/widgets/pinch_density.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_firestore_client.dart';
import '../../../support/in_memory_local_store.dart';

const Offset _centre = Offset(400, 300);

/// Two fingers down, [apart] pixels between them.
Future<(TestGesture, TestGesture)> _touchDown(WidgetTester tester, double apart) async {
  final TestGesture left = await tester.startGesture(_centre - Offset(apart / 2, 0), pointer: 1);
  final TestGesture right = await tester.startGesture(_centre + Offset(apart / 2, 0), pointer: 2);
  return (left, right);
}

Future<void> _moveApart(TestGesture left, TestGesture right, double apart) async {
  await left.moveTo(_centre - Offset(apart / 2, 0));
  await right.moveTo(_centre + Offset(apart / 2, 0));
}

Future<void> _pinch(WidgetTester tester, {required double from, required double to}) async {
  final (TestGesture left, TestGesture right) = await _touchDown(tester, from);
  await _moveApart(left, right, to);
  await left.up();
  await right.up();
  await tester.pump();
}

void main() {
  late InMemoryLocalStore localStore;
  late LayoutPrefsStore store;

  setUp(() {
    AnalyticsRuntime.instance = FakeAppAnalytics();
    localStore = InMemoryLocalStore();
    store = LayoutPrefsStore(SettingsLocalDataSource(localStore), FakeFirestoreClient());
  });
  tearDown(AnalyticsRuntime.reset);

  Future<void> pumpPinch(WidgetTester tester, {Widget? child}) => tester.pumpWidget(
    MaterialApp(
      home: PinchDensity(
        store: store,
        child: child ?? const SizedBox.expand(child: ColoredBox(color: Colors.grey)),
      ),
    ),
  );

  testWidgets('spreading from 100 px to 200 px steps comfortable to large, once per gesture', (tester) async {
    await pumpPinch(tester);
    expect(store.value.density, WallGridDensity.comfortable);

    final (TestGesture left, TestGesture right) = await _touchDown(tester, 100);
    await _moveApart(left, right, 200);
    expect(store.value.density, WallGridDensity.large);

    await _moveApart(left, right, 300);
    expect(store.value.density, WallGridDensity.large);
    await left.up();
    await right.up();
  });

  testWidgets('pinching in steps large to comfortable to compact, then stays at compact', (tester) async {
    await pumpPinch(tester);
    await _pinch(tester, from: 100, to: 200);
    expect(store.value.density, WallGridDensity.large);

    await _pinch(tester, from: 200, to: 100);
    expect(store.value.density, WallGridDensity.comfortable);

    await _pinch(tester, from: 200, to: 100);
    expect(store.value.density, WallGridDensity.compact);

    await _pinch(tester, from: 200, to: 100);
    expect(store.value.density, WallGridDensity.compact);
  });

  testWidgets('a small spread from 100 px to 120 px changes nothing', (tester) async {
    await pumpPinch(tester);

    await _pinch(tester, from: 100, to: 120);

    expect(store.value.density, WallGridDensity.comfortable);
  });

  testWidgets('a single finger drag changes nothing and a one-finger tap still reaches the child', (tester) async {
    int taps = 0;
    await pumpPinch(
      tester,
      child: SizedBox.expand(
        child: GestureDetector(
          key: const ValueKey<String>('tap-target'),
          behavior: HitTestBehavior.opaque,
          onTap: () => taps++,
          child: const ColoredBox(color: Colors.grey),
        ),
      ),
    );

    final TestGesture finger = await tester.startGesture(_centre, pointer: 1);
    await finger.moveTo(_centre + const Offset(0, 400));
    await finger.moveTo(_centre + const Offset(0, -400));
    await finger.up();
    await tester.pump();
    expect(store.value.density, WallGridDensity.comfortable);

    await tester.tap(find.byKey(const ValueKey<String>('tap-target')));
    await tester.pump();
    expect(taps, 1);
    expect(store.value.density, WallGridDensity.comfortable);
  });

  testWidgets('the new density is saved and a new store on the same storage reads it', (tester) async {
    await pumpPinch(tester);
    await _pinch(tester, from: 100, to: 200);
    expect(store.value.density, WallGridDensity.large);

    final LayoutPrefsStore reopened = LayoutPrefsStore(SettingsLocalDataSource(localStore), FakeFirestoreClient());

    expect(reopened.value.density, WallGridDensity.large);
  });
}
