import 'package:Prism/core/utils/side_safe_column.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SideSafeColumnProbe extends StatelessWidget {
  const _SideSafeColumnProbe();

  @override
  Widget build(BuildContext context) => Text('${sideSafeColumnWidth(context)}');
}

Future<double> _widthFor(
  WidgetTester tester, {
  required Size mediaQuerySize,
  required Size nativeViewSize,
  required Size nativeDisplaySize,
  required EdgeInsets nativePadding,
  required EdgeInsets nativeViewPadding,
  bool removeRight = false,
  bool removeTop = false,
}) async {
  tester.view.display.devicePixelRatio = 1;
  tester.view.devicePixelRatio = 1;
  tester.view.display.size = nativeDisplaySize;
  tester.view.physicalSize = nativeViewSize;
  tester.view.padding = FakeViewPadding(
    top: nativePadding.top,
    right: nativePadding.right,
    bottom: nativePadding.bottom,
    left: nativePadding.left,
  );
  tester.view.viewPadding = FakeViewPadding(
    top: nativeViewPadding.top,
    right: nativeViewPadding.right,
    bottom: nativeViewPadding.bottom,
    left: nativeViewPadding.left,
  );
  addTearDown(tester.view.reset);
  addTearDown(tester.view.display.reset);

  var width = -1.0;
  final MediaQueryData nativeData = MediaQueryData.fromView(tester.view);
  await tester.pumpWidget(
    MediaQuery(
      data: nativeData.copyWith(size: mediaQuerySize),
      child: Builder(
        builder: (context) => MediaQuery.removePadding(
          context: context,
          removeRight: removeRight,
          removeTop: removeTop,
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
  testWidgets('iOS: reported outer-screen signature has a side column', (tester) async {
    expect(
      await _widthFor(
        tester,
        mediaQuerySize: const Size(466, 678),
        nativeViewSize: const Size(466, 678),
        nativeDisplaySize: const Size(466, 678),
        nativePadding: const EdgeInsets.only(right: 84),
        nativeViewPadding: const EdgeInsets.only(right: 84),
      ),
      84,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: an ordinary portrait iPhone inset does not match the reported right inset', (tester) async {
    expect(
      await _widthFor(
        tester,
        mediaQuerySize: const Size(390, 844),
        nativeViewSize: const Size(390, 844),
        nativeDisplaySize: const Size(390, 844),
        nativePadding: const EdgeInsets.only(top: 59),
        nativeViewPadding: const EdgeInsets.only(top: 59),
      ),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: a phone view with a nonmatching right inset has no side column', (tester) async {
    expect(
      await _widthFor(
        tester,
        mediaQuerySize: const Size(390, 844),
        nativeViewSize: const Size(390, 844),
        nativeDisplaySize: const Size(390, 844),
        nativePadding: const EdgeInsets.only(right: 20),
        nativeViewPadding: const EdgeInsets.only(right: 20),
      ),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: removing right padding removes the side column from nested content', (tester) async {
    expect(
      await _widthFor(
        tester,
        mediaQuerySize: const Size(466, 678),
        nativeViewSize: const Size(466, 678),
        nativeDisplaySize: const Size(466, 678),
        nativePadding: const EdgeInsets.only(right: 84),
        nativeViewPadding: const EdgeInsets.only(right: 84),
        removeRight: true,
      ),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: a native landscape view cannot be made eligible by portrait-scoped metrics', (tester) async {
    expect(
      await _widthFor(
        tester,
        mediaQuerySize: const Size(466, 678),
        nativeViewSize: const Size(844, 390),
        nativeDisplaySize: const Size(844, 390),
        nativePadding: const EdgeInsets.only(top: 24, right: 84),
        nativeViewPadding: const EdgeInsets.only(top: 24, right: 84),
        removeTop: true,
      ),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: native landscape orientation is rejected with no top inset', (tester) async {
    expect(
      await _widthFor(
        tester,
        mediaQuerySize: const Size(466, 678),
        nativeViewSize: const Size(844, 390),
        nativeDisplaySize: const Size(844, 390),
        nativePadding: const EdgeInsets.only(right: 84),
        nativeViewPadding: const EdgeInsets.only(right: 84),
      ),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: removing the scoped top inset cannot hide the native top inset', (tester) async {
    expect(
      await _widthFor(
        tester,
        mediaQuerySize: const Size(466, 678),
        nativeViewSize: const Size(466, 678),
        nativeDisplaySize: const Size(466, 678),
        nativePadding: const EdgeInsets.only(top: 24, right: 84),
        nativeViewPadding: const EdgeInsets.only(top: 24, right: 84),
        removeTop: true,
      ),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS: a const caller rebuilds when the native right inset changes to the reported signature', (
    tester,
  ) async {
    tester.view.display.devicePixelRatio = 1;
    tester.view.devicePixelRatio = 1;
    tester.view.display.size = const Size(466, 678);
    tester.view.physicalSize = const Size(466, 678);
    tester.view.padding = FakeViewPadding.zero;
    tester.view.viewPadding = FakeViewPadding.zero;
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);

    await tester.pumpWidget(
      MediaQuery.fromView(
        view: tester.view,
        child: const Directionality(textDirection: TextDirection.ltr, child: _SideSafeColumnProbe()),
      ),
    );
    expect(find.text('0.0'), findsOneWidget);

    tester.view.padding = const FakeViewPadding(right: 84);
    tester.view.viewPadding = const FakeViewPadding(right: 84);
    await tester.pump();
    expect(find.text('84.0'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  for (final ({String name, Size mediaQuerySize, Size nativeViewSize}) configuration in [
    (name: 'full-screen iPad', mediaQuerySize: const Size(1024, 1366), nativeViewSize: const Size(1024, 1366)),
    (name: 'split-view iPad', mediaQuerySize: const Size(507, 1366), nativeViewSize: const Size(507, 1366)),
    (name: 'Stage Manager iPad', mediaQuerySize: const Size(700, 900), nativeViewSize: const Size(700, 900)),
  ]) {
    testWidgets('iOS: ${configuration.name} display has no side column', (tester) async {
      expect(
        await _widthFor(
          tester,
          mediaQuerySize: configuration.mediaQuerySize,
          nativeViewSize: configuration.nativeViewSize,
          nativeDisplaySize: const Size(2048, 2732),
          nativePadding: const EdgeInsets.only(right: 84),
          nativeViewPadding: const EdgeInsets.only(right: 84),
        ),
        0,
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  }

  testWidgets('other platforms never have a side column', (tester) async {
    expect(
      await _widthFor(
        tester,
        mediaQuerySize: const Size(466, 678),
        nativeViewSize: const Size(466, 678),
        nativeDisplaySize: const Size(466, 678),
        nativePadding: const EdgeInsets.only(right: 84),
        nativeViewPadding: const EdgeInsets.only(right: 84),
      ),
      0,
    );
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
