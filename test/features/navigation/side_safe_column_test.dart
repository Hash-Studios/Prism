import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SideColumnProbe extends StatelessWidget {
  const _SideColumnProbe();

  @override
  Widget build(BuildContext context) => Text('${sideSafeColumnWidth(context)}');
}

class _ScreenSideColumnProbe extends StatelessWidget {
  const _ScreenSideColumnProbe();

  @override
  Widget build(BuildContext context) => Text('${screenSideSafeColumnWidth(context)}');
}

Future<double> _widthFor(WidgetTester tester, {required Size size, required EdgeInsets viewPadding}) async {
  tester.view.display
    ..devicePixelRatio = 1
    ..size = size;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = size
    ..viewPadding = FakeViewPadding(
      top: viewPadding.top,
      right: viewPadding.right,
      bottom: viewPadding.bottom,
      left: viewPadding.left,
    )
    ..padding = FakeViewPadding(
      top: viewPadding.top,
      right: viewPadding.right,
      bottom: viewPadding.bottom,
      left: viewPadding.left,
    );
  addTearDown(tester.view.reset);
  addTearDown(tester.view.display.reset);

  var width = -1.0;
  await tester.pumpWidget(
    MediaQuery.fromView(
      view: tester.view,
      child: Builder(
        builder: (context) {
          width = sideSafeColumnWidth(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return width;
}

Future<double> _widthAfterRemovingPadding(
  WidgetTester tester, {
  required EdgeInsets nativeViewPadding,
  required bool removeTop,
  required bool removeLeft,
}) async {
  tester.view.display
    ..devicePixelRatio = 1
    ..size = const Size(874, 402);
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = const Size(874, 402)
    ..viewPadding = FakeViewPadding(
      top: nativeViewPadding.top,
      right: nativeViewPadding.right,
      bottom: nativeViewPadding.bottom,
      left: nativeViewPadding.left,
    )
    ..padding = FakeViewPadding(
      top: nativeViewPadding.top,
      right: nativeViewPadding.right,
      bottom: nativeViewPadding.bottom,
      left: nativeViewPadding.left,
    );
  addTearDown(tester.view.reset);
  addTearDown(tester.view.display.reset);

  var width = -1.0;
  await tester.pumpWidget(
    MediaQuery.fromView(
      view: tester.view,
      child: Builder(
        builder: (context) => MediaQuery.removePadding(
          context: context,
          removeTop: removeTop,
          removeLeft: removeLeft,
          child: Builder(
            builder: (context) {
              width = sideSafeColumnWidth(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    ),
  );
  return width;
}

void main() {
  testWidgets('iOS: only a right column with no top or left inset is a side column', (tester) async {
    // iPhone Duo outer screen.
    expect(await _widthFor(tester, size: const Size(466, 678), viewPadding: const EdgeInsets.only(right: 84)), 84);
    // The recognition uses the inset shape, not a fixed width.
    expect(await _widthFor(tester, size: const Size(466, 678), viewPadding: const EdgeInsets.only(right: 100)), 100);
    // A portrait screen with a status bar on top, even with a right inset.
    expect(
      await _widthFor(tester, size: const Size(820, 1180), viewPadding: const EdgeInsets.only(top: 24, right: 20)),
      0,
    );
    // iPhone Duo inner screen in landscape.
    expect(await _widthFor(tester, size: const Size(951, 669), viewPadding: const EdgeInsets.only(right: 84)), 84);
    // Another iPhone in landscape has an inset on both sides.
    expect(
      await _widthFor(tester, size: const Size(874, 402), viewPadding: const EdgeInsets.only(left: 62, right: 62)),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('other platforms never have a side column', (tester) async {
    expect(await _widthFor(tester, size: const Size(466, 678), viewPadding: const EdgeInsets.only(right: 84)), 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('iOS: native top or left inset rejects a matching scoped right-column signature', (tester) async {
    expect(
      await _widthAfterRemovingPadding(
        tester,
        nativeViewPadding: const EdgeInsets.only(top: 82, right: 84),
        removeTop: true,
        removeLeft: false,
      ),
      0,
    );
    expect(
      await _widthAfterRemovingPadding(
        tester,
        nativeViewPadding: const EdgeInsets.only(left: 62, right: 62),
        removeTop: false,
        removeLeft: true,
      ),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: const caller tracks a native inset change without a size change', (tester) async {
    tester.view.display
      ..devicePixelRatio = 1
      ..size = const Size(466, 678);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(466, 678)
      ..viewPadding = FakeViewPadding.zero
      ..padding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery.fromView(view: tester.view, child: const _SideColumnProbe()),
      ),
    );
    expect(find.text('0.0'), findsOneWidget);

    tester.view
      ..viewPadding = const FakeViewPadding(right: 84)
      ..padding = const FakeViewPadding(right: 84);
    await tester.pump();

    expect(find.text('84.0'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: const whole-screen caller tracks an unmasked native inset change', (tester) async {
    tester.view.display
      ..devicePixelRatio = 1
      ..size = const Size(951, 669);
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = const Size(951, 669)
      ..viewPadding = const FakeViewPadding(right: 84)
      ..padding = const FakeViewPadding(right: 84);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery.fromView(view: tester.view, child: const _ScreenSideColumnProbe()),
      ),
    );
    expect(find.text('84.0'), findsOneWidget);

    tester.view
      ..viewPadding = const FakeViewPadding(right: 100)
      ..padding = const FakeViewPadding(right: 100);
    await tester.pump();

    expect(find.text('100.0'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
