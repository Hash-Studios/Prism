import 'package:Prism/features/theme_mode/seasonal_themes.dart';
import 'package:Prism/features/theme_mode/views/widgets/diwali_decor.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _decorApp(ThemeData theme, {bool disableAnimations = false}) => MaterialApp(
  theme: theme,
  themeAnimationDuration: Duration.zero,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: disableAnimations),
    child: const Scaffold(body: Stack(children: <Widget>[DiwaliDiya(), DiwaliFireworks()])),
  ),
);

int _semanticsNodeCount(SemanticsNode node) {
  int count = 1;
  node.visitChildren((child) {
    count += _semanticsNodeCount(child);
    return true;
  });
  return count;
}

void main() {
  test('Diwali season ends on 12 November 2026', () {
    expect(diwaliSeason.inSeason(DateTime(2026, 11, 11, 23, 59)), isTrue);
    expect(diwaliSeason.inSeason(DateTime(2026, 11, 12)), isFalse);
  });

  testWidgets('Diwali decor draws nothing on the Material theme', (tester) async {
    await tester.pumpWidget(_decorApp(kDarkTheme));
    await tester.pump();
    expect(find.byType(SvgPicture), findsNothing);
  });

  testWidgets('Diwali decor draws on the Diwali theme', (tester) async {
    await tester.pumpWidget(_decorApp(kDarkTheme10));
    await tester.pump();
    expect(find.byType(DiwaliDiya), findsOneWidget);
    expect(find.byType(DiwaliFireworks), findsOneWidget);
    expect(find.byType(SvgPicture), findsNWidgets(5));
  });

  testWidgets('diya and fireworks let taps reach the button underneath', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme10,
        home: Scaffold(
          body: Stack(
            children: <Widget>[
              Center(
                child: TextButton(onPressed: () => taps++, child: const Text('Tap')),
              ),
              const Center(child: DiwaliDiya()),
              const Center(child: DiwaliFireworks()),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Tap'));

    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('diya and fireworks add no semantics nodes', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    await tester.pumpWidget(_decorApp(kDarkTheme10));
    await tester.pump();
    final int withDecor = _semanticsNodeCount(
      tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme10,
        themeAnimationDuration: Duration.zero,
        home: const Scaffold(body: Stack(children: <Widget>[SizedBox.shrink(), SizedBox.shrink()])),
      ),
    );
    await tester.pump();
    final int withoutDecor = _semanticsNodeCount(
      tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!,
    );

    expect(withDecor, withoutDecor);
    handle.dispose();
  });

  testWidgets('diya and fireworks stop animating when motion is reduced', (tester) async {
    await tester.pumpWidget(_decorApp(kDarkTheme10));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(_decorApp(kDarkTheme10, disableAnimations: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DiwaliBannerArt builds in a sized box under the light theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.light(),
        home: const Scaffold(
          body: Center(child: SizedBox(width: 300, height: 180, child: DiwaliBannerArt())),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(DiwaliBannerArt), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
