import 'dart:math' as math;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/features/theme_mode/seasonal_themes.dart';
import 'package:Prism/features/theme_mode/views/widgets/winter_decor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

Widget _winterApp(
  ThemeData theme, {
  bool reduceMotion = false,
  Future<bool> Function()? powerSaver,
  TextScaler textScaler = TextScaler.noScaling,
  bool tickersEnabled = true,
  Widget? child,
}) => MaterialApp(
  theme: theme,
  themeAnimationDuration: Duration.zero,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  builder: (context, child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion, textScaler: textScaler),
    child: child!,
  ),
  home: Scaffold(
    body: TickerMode(
      enabled: tickersEnabled,
      child: WinterSnowfall(
        headerHeight: 120,
        powerSaver: powerSaver ?? () async => false,
        child:
            child ??
            ListView(children: List<Widget>.generate(40, (int i) => SizedBox(height: 80, child: Text('row $i')))),
      ),
    ),
  ),
);

/// The snow layer: the only CustomPaint under WinterSnowfall whose painter is the private _SnowPainter.
Finder _snow() => find.descendant(
  of: find.byType(WinterSnowfall),
  matching: find.byWidgetPredicate(
    (Widget widget) => widget is CustomPaint && widget.painter?.runtimeType.toString() == '_SnowPainter',
  ),
);

double _greetingOpacity(WidgetTester tester) => tester
    .widget<AnimatedOpacity>(find.ancestor(of: find.text('Happy New Year'), matching: find.byType(AnimatedOpacity)))
    .opacity;

class _CircleRecordingCanvas implements Canvas {
  final List<Offset> centers = <Offset>[];

  @override
  void drawCircle(Offset center, double radius, Paint paint) => centers.add(center);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() => AnalyticsRuntime.instance = FakeAppAnalytics());
  tearDown(AnalyticsRuntime.reset);

  testWidgets('snow paints on the Winter dark theme', (tester) async {
    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump(const Duration(milliseconds: 100));

    expect(_snow(), findsOneWidget);
    expect(find.text('row 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('snow paints on the Winter light theme', (tester) async {
    await tester.pumpWidget(_winterApp(kLightTheme5));
    await tester.pump(const Duration(milliseconds: 100));

    expect(_snow(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('snow moves continuously across the minute loop boundary', (tester) async {
    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump(const Duration(milliseconds: 100));
    final CustomPainter painter = tester.widget<CustomPaint>(_snow()).painter!;
    final AnimationController clock = (painter as dynamic).clock as AnimationController;
    final Size size = tester.getSize(_snow());
    final _CircleRecordingCanvas before = _CircleRecordingCanvas();
    final _CircleRecordingCanvas after = _CircleRecordingCanvas();

    clock.value = 1 - 0.00001;
    painter.paint(before, size);
    clock.value = 0.00001;
    painter.paint(after, size);

    expect(before.centers, isNotEmpty);
    expect(after.centers, hasLength(before.centers.length));
    final double fall = size.height + 8;
    for (int i = 0; i < before.centers.length; i++) {
      final double verticalDistance = (after.centers[i].dy - before.centers[i].dy).abs();
      expect(math.min(verticalDistance, fall - verticalDistance), lessThan(1), reason: 'flake $i vertical jump');
      expect((after.centers[i].dx - before.centers[i].dx).abs(), lessThan(1), reason: 'flake $i horizontal jump');
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the Material dark theme draws no snow', (tester) async {
    await tester.pumpWidget(_winterApp(kDarkTheme));
    await tester.pump(const Duration(milliseconds: 100));

    expect(_snow(), findsNothing);
    expect(find.text('row 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduce motion draws no snow and the list still shows', (tester) async {
    await tester.pumpWidget(_winterApp(kDarkTheme11, reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 100));

    expect(_snow(), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('row 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('reduce motion on Winter records one decor disabled event', (tester) async {
    final FakeAppAnalytics fake = FakeAppAnalytics();
    AnalyticsRuntime.instance = fake;
    await tester.pumpWidget(_winterApp(kDarkTheme11, reduceMotion: true));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpWidget(_winterApp(kDarkTheme11, reduceMotion: true, textScaler: const TextScaler.linear(1.5)));
    await tester.pump();

    final List<SeasonalDecorDisabledEvent> disabled = fake.events.whereType<SeasonalDecorDisabledEvent>().toList();
    expect(disabled, hasLength(1));
    expect(disabled.single.season, 'winter');
    expect(disabled.single.reason, SeasonalDecorDisabledReasonValue.reducedMotion);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Winter with motion on records no decor disabled event', (tester) async {
    final FakeAppAnalytics fake = FakeAppAnalytics();
    AnalyticsRuntime.instance = fake;
    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump(const Duration(milliseconds: 100));

    expect(fake.events.whereType<SeasonalDecorDisabledEvent>(), isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('power saver draws no snow', (tester) async {
    await tester.pumpWidget(_winterApp(kDarkTheme11, powerSaver: () async => true));
    await tester.pump();
    await tester.pump();

    expect(_snow(), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    expect(find.text('row 0'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('snow repaints inside its own boundary without rebuilding the feed on each tick', (tester) async {
    int childBuilds = 0;
    await tester.pumpWidget(
      _winterApp(
        kDarkTheme11,
        child: Builder(
          builder: (context) {
            childBuilds++;
            return const SizedBox.expand();
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    final CustomPaint snow = tester.widget<CustomPaint>(_snow());
    final int initialBuilds = childBuilds;
    int repaintRequests = 0;
    void onRepaint() => repaintRequests++;
    snow.painter!.addListener(onRepaint);

    for (int frame = 0; frame < 3; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(repaintRequests, greaterThan(0));
    expect(childBuilds, initialBuilds);
    expect(tester.widget<CustomPaint>(_snow()), same(snow));
    expect(tester.renderObject<RenderCustomPaint>(_snow()).parent, isA<RenderRepaintBoundary>());
    snow.painter!.removeListener(onRepaint);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a hidden tab stops the snow clock and showing it starts the clock again', (tester) async {
    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_winterApp(kDarkTheme11, tickersEnabled: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isFalse);
    expect(_snow(), findsOneWidget);

    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resuming rechecks power saver and stops the snow clock', (tester) async {
    bool lowPower = false;
    await tester.pumpWidget(_winterApp(kDarkTheme11, powerSaver: () async => lowPower));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    lowPower = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.pump();

    expect(_snow(), findsNothing);
    expect(tester.hasRunningAnimations, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a scroll stops the snow clock until the list settles', (tester) async {
    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.byType(ListView)));
    await gesture.moveBy(const Offset(0, -200));
    await tester.pump();
    expect(_snow(), findsOneWidget);
    expect(tester.hasRunningAnimations, isFalse);

    await gesture.up();
    await tester.pump(const Duration(seconds: 5));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the New Year greeting shows on 31 December and fades after its visible time', (tester) async {
    seasonClock = () => DateTime(2026, 12, 31, 10);
    addTearDown(() => seasonClock = () => DateTime(2027, 2));
    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Happy New Year'), findsOneWidget);
    expect(_greetingOpacity(tester), 1);

    await tester.pump(WinterNewYearGreeting.visibleFor + const Duration(seconds: 1));

    expect(_greetingOpacity(tester), 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('resuming after the New Year boundary refreshes the greeting', (tester) async {
    DateTime now = DateTime(2026, 12, 30, 23, 59);
    seasonClock = () => now;
    addTearDown(() => seasonClock = () => DateTime(2027, 2));
    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump();

    expect(find.text('Happy New Year'), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = DateTime(2026, 12, 31, 0, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Happy New Year'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('no New Year greeting on 20 December', (tester) async {
    seasonClock = () => DateTime(2026, 12, 20);
    addTearDown(() => seasonClock = () => DateTime(2027, 2));
    await tester.pumpWidget(_winterApp(kDarkTheme11));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Happy New Year'), findsNothing);
    expect(_snow(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the New Year greeting fits at 2x text on a 320 px phone', (tester) async {
    seasonClock = () => DateTime(2026, 12, 31, 10);
    addTearDown(() => seasonClock = () => DateTime(2027, 2));
    tester.view
      ..physicalSize = const Size(320, 640)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_winterApp(kDarkTheme11, textScaler: const TextScaler.linear(2)));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Happy New Year'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  test('Winter light and dark text pass 4.5:1 on the surface', () {
    for (final ThemeData theme in <ThemeData>[kLightTheme5, kDarkTheme11]) {
      final ColorScheme colors = theme.colorScheme;
      expect(contrastRatio(colors.onSurface, colors.surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(colors.onSurfaceVariant, colors.surface), greaterThanOrEqualTo(4.5));
    }
  });
}
