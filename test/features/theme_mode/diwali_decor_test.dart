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

  testWidgets('fireworks play twice, then rest on the still pose', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: kDarkTheme10,
        themeAnimationDuration: Duration.zero,
        home: const Scaffold(body: Stack(children: <Widget>[DiwaliFireworks()])),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pump(const Duration(milliseconds: 4200));
    await tester.pump(const Duration(milliseconds: 4200));
    await tester.pump();
    await tester.pump();

    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(find.byType(SvgPicture), findsNWidgets(3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion settles fireworks until Diwali is toggled off and on', (tester) async {
    ThemeData theme = kDarkTheme10;
    bool reduceMotion = false;
    Widget app() => MaterialApp(
      theme: theme,
      themeAnimationDuration: Duration.zero,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Scaffold(body: DiwaliFireworks()),
      ),
    );

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 500));
    reduceMotion = true;
    await tester.pumpWidget(app());
    final AnimationController bloom =
        tester
                .widget<AnimatedBuilder>(
                  find.descendant(of: find.byType(DiwaliFireworks), matching: find.byType(AnimatedBuilder)),
                )
                .animation
            as AnimationController;
    expect(bloom.value, 0);
    reduceMotion = false;
    await tester.pumpWidget(app());
    await tester.pump(const Duration(seconds: 2));
    expect(tester.binding.transientCallbackCount, 0);

    theme = kDarkTheme;
    await tester.pumpWidget(app());
    theme = kDarkTheme10;
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
  });

  testWidgets('diya and fireworks stop while their ticker mode is disabled', (tester) async {
    bool tickerEnabled = true;
    StateSetter? rebuild;

    Widget app() => MaterialApp(
      theme: kDarkTheme10,
      home: StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return Scaffold(
            body: TickerMode(
              enabled: tickerEnabled,
              child: const Stack(children: <Widget>[DiwaliDiya(), DiwaliFireworks()]),
            ),
          );
        },
      ),
    );

    AnimationController diyaController() =>
        tester
                .widget<AnimatedBuilder>(
                  find.descendant(of: find.byType(DiwaliDiya), matching: find.byType(AnimatedBuilder)),
                )
                .animation
            as AnimationController;

    AnimationController fireworksController() =>
        tester
                .widget<AnimatedBuilder>(
                  find.descendant(of: find.byType(DiwaliFireworks), matching: find.byType(AnimatedBuilder)),
                )
                .animation
            as AnimationController;

    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(diyaController().isAnimating, isTrue);
    expect(fireworksController().isAnimating, isTrue);
    final double pausedValue = fireworksController().value;

    rebuild!(() => tickerEnabled = false);
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(diyaController().isAnimating, isFalse);
    expect(fireworksController().value, pausedValue);
    await tester.pump(const Duration(seconds: 20));
    expect(fireworksController().value, pausedValue);

    rebuild!(() => tickerEnabled = true);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    expect(diyaController().isAnimating, isTrue);
    expect(fireworksController().isAnimating, isTrue);
    expect(fireworksController().value, greaterThan(pausedValue));
    await tester.pump(Duration(milliseconds: ((1 - fireworksController().value) * 8400).ceil() + 100));
    await tester.pump();
    expect(fireworksController().isAnimating, isFalse);
    expect(fireworksController().value, 1);

    rebuild!(() => tickerEnabled = false);
    await tester.pump();
    await tester.pump(const Duration(seconds: 20));
    rebuild!(() => tickerEnabled = true);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(fireworksController().isAnimating, isFalse);
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
