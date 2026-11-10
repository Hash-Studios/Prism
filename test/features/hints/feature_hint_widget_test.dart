import 'dart:async';

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/core/widgets/prism_sheet/prism_sheet_route.dart';
import 'package:Prism/features/hints/data/feature_hints.dart';
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/features/hints/views/feature_hint.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

const String _copy = 'Tap a dot to see this wallpaper in another colour.';
const String _photoCopy = 'Find wallpapers that match a photo from your gallery.';
const String _gotIt = 'Got it';

late Map<String, Object?> _store;
late DateTime _now;
late int _sheets;
late String _uid;
late String Function(String key) _remote;
late FeatureHints _previous;
late FeatureHints _hints;

FeatureHints _build() => FeatureHints(
  read: <T>(String key, T defaultValue) => (_store.containsKey(key) ? _store[key] : defaultValue) as T,
  write: (String key, Object? value) async {
    if (value == null) {
      _store.remove(key);
    } else {
      _store[key] = value;
    }
  },
  clock: () => _now,
  session: () => 5,
  userId: () => _uid,
  remoteConfig: (String key) => _remote(key),
  openSheets: () => _sheets,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _store = <String, Object?>{};
    _now = DateTime(2026, 11, 9, 12);
    _sheets = 0;
    _uid = 'u1';
    _remote = (String key) => '';
    _previous = FeatureHints.instance;
    _hints = _build();
    FeatureHints.instance = _hints;
    _hints.attach();
    StartupModalSlot.reset();
    AnalyticsRuntime.instance = FakeAppAnalytics();
  });

  tearDown(() {
    _hints.dispose();
    FeatureHints.instance = _previous;
    StartupModalSlot.reset();
    AnalyticsRuntime.reset();
  });

  testWidgets('the callout text uses a theme style, not the missing-Material debug underline', (tester) async {
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    final TextStyle style = DefaultTextStyle.of(tester.element(find.text(_copy))).style;
    expect(style.decoration, isNot(TextDecoration.underline));
  });

  testWidgets('a control in the lower half with room under it gets the bubble below, not over the content above', (
    tester,
  ) async {
    await tester.pumpWidget(_app(_host(alignment: const Alignment(0, 0.3))));
    await _settle(tester);
    final Rect control = tester.getRect(find.byKey(const Key('control')));
    final Rect bubble = tester.getRect(
      find.ancestor(of: find.text(_copy), matching: find.byType(ScaleTransition)).first,
    );
    expect(control.center.dy, greaterThan(300));
    expect(bubble.top, greaterThan(control.bottom));
  });

  testWidgets('a tap on the bubble text closes the hint like Got it', (tester) async {
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    await tester.tap(find.text(_copy));
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsNothing);
    expect(_hints.active, isNull);
  });

  testWidgets('disabling restarts the full dwell interval', (tester) async {
    await tester.pumpWidget(_app(_host()));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(_app(_host(enabled: false)));
    await tester.pumpWidget(_app(_host()));
    await tester.pump(const Duration(milliseconds: 200));
    expect(_hints.record(HintId.variantDots).views, 0);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsOneWidget);
  });

  testWidgets('reusing the wrapper for another id counts its own view', (tester) async {
    await tester.pumpWidget(_app(_host(id: HintId.photoSearch)));
    await _settle(tester);
    expect(_hints.record(HintId.photoSearch).views, 1);
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    expect(find.text(_copy), findsOneWidget);
  });

  testWidgets('a clipped control counts a view but never shows a hint', (tester) async {
    await tester.pumpWidget(
      _app(
        const Scaffold(
          body: Center(
            child: SizedBox(
              width: 100,
              height: 20,
              child: SingleChildScrollView(
                child: FeatureHint(id: HintId.variantDots, child: SizedBox(width: 44, height: 44)),
              ),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(_hints.record(HintId.variantDots).views, 1);
    expect(find.text(_copy), findsNothing);
  });

  testWidgets('scrolling the control out of view interrupts its hint', (tester) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: SingleChildScrollView(
            controller: scroll,
            child: const Column(
              children: <Widget>[
                SizedBox(height: 100),
                FeatureHint(
                  id: HintId.variantDots,
                  child: SizedBox(key: Key('control'), width: 44, height: 44),
                ),
                SizedBox(height: 1500),
              ],
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text(_copy), findsOneWidget);
    scroll.jumpTo(500);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsNothing);
    expect(_hints.active, isNull);
  });

  testWidgets('offstage controls never show hints', (tester) async {
    await tester.pumpWidget(_app(Offstage(child: _host())));
    await _settle(tester);
    expect(_hints.record(HintId.variantDots).views, 1);
    expect(_hints.active, isNull);
  });

  testWidgets('a hint cannot appear during a slow route transition', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(body: Text('Start'))));
    Navigator.of(
      tester.element(find.text('Start')),
    ).push(PageRouteBuilder<void>(transitionDuration: const Duration(seconds: 2), pageBuilder: (_, _, _) => _host()));
    await tester.pump();
    await tester.pump(FeatureHint.settle);
    expect(_hints.record(HintId.variantDots).views, 1);
    expect(_hints.active, isNull);
    await tester.pumpAndSettle();
  });

  testWidgets('a sheet in a nested navigator interrupts the outer hint', (tester) async {
    await tester.pumpWidget(
      _app(
        _host(
          extra: Positioned(
            top: 0,
            left: 0,
            width: 100,
            height: 100,
            child: Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => const Text('Nested'))),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text(_copy), findsOneWidget);
    unawaited(showPrismSheet<void>(tester.element(find.text('Nested')), builder: (_) => const SizedBox(height: 44)));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsNothing);
    expect(_hints.active, isNull);
  });

  testWidgets('switching accounts interrupts the previous account hint', (tester) async {
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    expect(find.text(_copy), findsOneWidget);
    _uid = 'u2';
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsNothing);
    expect(_hints.record(HintId.variantDots).shownAt, isNull);
  });

  testWidgets('disabling a visible hint during build does not notify during build', (tester) async {
    bool enabled = true;
    late StateSetter rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (_, setState) {
            rebuild = setState;
            return _host(enabled: enabled);
          },
        ),
      ),
    );
    await _settle(tester);
    _hints.addListener(() => rebuild(() {}));
    rebuild(() => enabled = false);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text(_copy), findsNothing);
  });

  testWidgets('Got it can be reached and activated with a keyboard', (tester) async {
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsNothing);
  });

  testWidgets('iOS sends one announcement without an Android live region', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final List<Object?> messages = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(SystemChannels.accessibility, (
      message,
    ) async {
      messages.add(message);
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<Object?>(
        SystemChannels.accessibility,
        null,
      ),
    );
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    expect(messages.where((m) => m is Map && m['type'] == 'announce'), hasLength(1));
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('shows on its trigger after the settle delay, not before', (tester) async {
    await tester.pumpWidget(_app(_host()));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(_copy), findsNothing);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsOneWidget);
    expect(find.text(_gotIt), findsOneWidget);
  });

  testWidgets('a hint that needs three views shows only on the third', (tester) async {
    for (var view = 1; view <= 3; view++) {
      await tester.pumpWidget(_app(_host(id: HintId.photoSearch)));
      await _settle(tester);
      expect(find.text(_photoCopy), view == 3 ? findsOneWidget : findsNothing, reason: 'view $view');
      await tester.pumpWidget(_app(const SizedBox()));
    }
  });

  testWidgets('the bubble is centred under a control in the top half', (tester) async {
    await tester.pumpWidget(_app(_host(alignment: const Alignment(0, -0.6))));
    await _settle(tester);
    final Rect control = tester.getRect(find.byKey(const Key('control')));
    final Rect bubble = tester.getRect(_bubble());
    expect(control.center.dy, lessThan(300));
    expect((bubble.center.dx - control.center.dx).abs(), lessThan(1));
    expect(bubble.top - control.bottom, inInclusiveRange(0, 16));
  });

  testWidgets('the bubble sits above a control in the bottom half', (tester) async {
    await tester.pumpWidget(_app(_host(alignment: Alignment.bottomCenter)));
    await _settle(tester);
    final Rect control = tester.getRect(find.byKey(const Key('control')));
    final Rect bubble = tester.getRect(_bubble());
    expect(control.center.dy, greaterThan(300));
    expect((bubble.center.dx - control.center.dx).abs(), lessThan(1));
    expect(control.top - bubble.bottom, inInclusiveRange(0, 16));
  });

  testWidgets('Got it closes the hint, and the hint never shows again', (tester) async {
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    await tester.tap(find.text(_gotIt));
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsNothing);
    expect(FeatureHints.instance.active, isNull);
    expect(FeatureHints.instance.record(HintId.variantDots).shownAt, isNotNull);

    await tester.pumpWidget(_app(const SizedBox()));
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    expect(find.text(_copy), findsNothing);
    expect(FeatureHints.instance.active, isNull);
  });

  testWidgets('a tap outside closes the hint and still reaches the control under it', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      _app(
        _host(
          extra: Positioned(
            left: 0,
            top: 0,
            child: TextButton(
              onPressed: () {
                tapped++;
              },
              child: const Text('Corner'),
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(find.text(_copy), findsOneWidget);

    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsNothing);
    expect(FeatureHints.instance.active, isNull);
    expect(tapped, 1);
  });

  group('never shows next to another prompt', () {
    testWidgets('a prompt shown before the settle delay keeps the hint from showing', (tester) async {
      // The prompt stamp uses the real clock, so the fake clock must not sit more than 10 minutes behind it.
      _now = DateTime.now();
      StartupModalSlot.markPromptShown();
      await tester.pumpWidget(_app(_host()));
      await _settle(tester);
      expect(find.text(_copy), findsNothing);
    });

    testWidgets('a prompt that opens while the hint is visible hides it', (tester) async {
      await tester.pumpWidget(_app(_host()));
      await _settle(tester);
      expect(find.text(_copy), findsOneWidget);

      StartupModalSlot.markPromptShown();
      await tester.pumpAndSettle();
      expect(find.text(_copy), findsNothing);
      expect(FeatureHints.instance.active, isNull);
    });

    testWidgets('pushing a route over the host hides the hint', (tester) async {
      await tester.pumpWidget(_app(_host()));
      await _settle(tester);
      expect(find.text(_copy), findsOneWidget);

      Navigator.of(
        tester.element(find.byKey(const Key('control'))),
      ).push(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: SizedBox())));
      await tester.pumpAndSettle();
      expect(find.text(_copy), findsNothing);
      expect(FeatureHints.instance.active, isNull);
    });

    testWidgets('an open sheet blocks the hint', (tester) async {
      _sheets = 1;
      await tester.pumpWidget(_app(_host()));
      await _settle(tester);
      expect(find.text(_copy), findsNothing);
    });
  });

  testWidgets('with reduced motion the bubble is at full opacity after one pump', (tester) async {
    await tester.pumpWidget(_app(_host(), reduceMotion: true));
    await tester.pump(FeatureHint.settle);
    await tester.pump();
    final FadeTransition fade = tester.widget<FadeTransition>(
      find.ancestor(of: find.text(_copy), matching: find.byType(FadeTransition)).first,
    );
    expect(fade.opacity.value, 1);
  });

  testWidgets('at 2x text on a 360 by 740 screen the bubble stays inside 16 px gutters', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_app(_host(), textScale: 2));
    await _settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(_copy), findsOneWidget);

    final Rect bubble = tester.getRect(_bubble());
    expect(bubble.left, greaterThanOrEqualTo(16));
    expect(bubble.right, lessThanOrEqualTo(360 - 16));
  });

  testWidgets('in RTL Got it sits to the left of the copy', (tester) async {
    await tester.pumpWidget(_app(_host(), direction: TextDirection.rtl));
    await _settle(tester);
    expect(tester.getCenter(find.text(_gotIt)).dx, lessThan(tester.getCenter(find.text(_copy)).dx));
  });

  testWidgets('the copy is announced, Got it is a button, and focus is not moved', (tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final FocusNode focus = FocusNode();
    addTearDown(focus.dispose);

    await tester.pumpWidget(
      _app(
        _host(
          extra: Focus(focusNode: focus, child: const SizedBox()),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pump();
    await _settle(tester);
    expect(find.text(_copy), findsOneWidget);

    expect(tester.getSemantics(find.text(_copy)).label, contains(_copy));
    final Finder gotItButton = find.ancestor(
      of: find.text(_gotIt),
      matching: find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.button == true),
    );
    expect(gotItButton, findsOneWidget);
    expect(tester.getSemantics(gotItButton).flagsCollection.isButton, isTrue);
    expect(tester.getSemantics(gotItButton).getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    expect(FocusManager.instance.primaryFocus, same(focus));
    handle.dispose();
  });

  testWidgets('the Remote Config kill switch stops every hint', (tester) async {
    _remote = (String key) => key == 'hints_enabled' ? 'false' : '';
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    expect(find.text(_copy), findsNothing);
  });

  testWidgets('a hint listed in hints_disabled_ids does not show', (tester) async {
    _remote = (String key) => key == 'hints_disabled_ids' ? 'variant_dots' : '';
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    expect(find.text(_copy), findsNothing);
  });

  testWidgets('a surface with enabled false never shows its hint', (tester) async {
    await tester.pumpWidget(_app(_host(enabled: false)));
    await _settle(tester);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text(_copy), findsNothing);
    expect(FeatureHints.instance.record(HintId.variantDots).views, 0);
  });

  testWidgets('Got it has a 48 dp tap area on Android', (tester) async {
    await tester.pumpWidget(_app(_host()));
    await _settle(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    handle.dispose();
    final Rect rect = tester.getSemantics(_gotItButton()).rect;
    expect(rect.height, greaterThanOrEqualTo(48.0));
    expect(rect.width, greaterThanOrEqualTo(48.0));
  });

  testWidgets('Got it keeps a 44 pt tap area on iOS', (tester) async {
    await tester.pumpWidget(_app(_host(), platform: TargetPlatform.iOS));
    await _settle(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    handle.dispose();
    expect(tester.getSemantics(_gotItButton()).rect.height, 44.0);
  });

  testWidgets('the hint bubble meets the tap target, label and contrast guidelines in RTL at 2x text', (tester) async {
    await tester.pumpWidget(_app(_host(), textScale: 2, direction: TextDirection.rtl));
    await _settle(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  for (final TargetPlatform platform in <TargetPlatform>[TargetPlatform.android, TargetPlatform.iOS]) {
    for (final Size size in <Size>[const Size(360, 740), const Size(1024, 1366)]) {
      for (final TextDirection direction in TextDirection.values) {
        testWidgets('hint message precedes Got it and dismisses on $platform at 2x dark $direction $size', (
          tester,
        ) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final SemanticsHandle handle = tester.ensureSemantics();
          final FocusNode focus = FocusNode();
          addTearDown(focus.dispose);
          await tester.pumpWidget(
            _app(
              _host(
                extra: Focus(focusNode: focus, child: const SizedBox()),
              ),
              platform: platform,
              brightness: Brightness.dark,
              textScale: 2,
              direction: direction,
            ),
          );
          focus.requestFocus();
          await _settle(tester);
          expect(FocusManager.instance.primaryFocus, same(focus));
          expect(tester.takeException(), isNull);
          final SemanticsNode message = tester.getSemantics(find.text(_copy));
          final SemanticsNode button = tester.getSemantics(_gotItButton());
          expect(message.id, isNot(button.id));
          expect(message.label, contains(_copy));
          expect(button.label, _gotIt);
          expect(button.flagsCollection.isButton, isTrue);
          expect(button.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
          final List<String> traversalLabels = _traversalLabels(button);
          final int messageIndex = traversalLabels.indexWhere((label) => label.contains(_copy));
          final int buttonIndex = traversalLabels.indexWhere((label) => label.contains(_gotIt));
          expect(messageIndex, greaterThanOrEqualTo(0), reason: '$traversalLabels');
          expect(buttonIndex, greaterThan(messageIndex), reason: '$traversalLabels');
          final double minimum = platform == TargetPlatform.iOS ? 44 : 48;
          expect(button.rect.height, greaterThanOrEqualTo(minimum));
          expect(button.rect.width, greaterThanOrEqualTo(minimum));
          final Rect bubble = tester.getRect(_bubble());
          expect(bubble.left, greaterThanOrEqualTo(16));
          expect(bubble.right, lessThanOrEqualTo(size.width - 16));
          button.owner!.performAction(button.id, SemanticsAction.tap);
          await tester.pumpAndSettle();
          expect(_hints.active, isNull);
          expect(find.text(_gotIt), findsNothing);
          expect(FocusManager.instance.primaryFocus, same(focus));
          handle.dispose();
        });
      }
    }
  }

  for (final LogicalKeyboardKey key in <LogicalKeyboardKey>[LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets('Got it accepts keyboard $key after gaining focus', (tester) async {
      await tester.pumpWidget(_app(_host()));
      await _settle(tester);
      final Finder detector = find.descendant(of: _gotItButton(), matching: find.byType(GestureDetector)).first;
      final FocusNode gotItFocus = Focus.of(tester.element(detector));
      gotItFocus.requestFocus();
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, same(gotItFocus));
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(find.text(_gotIt), findsNothing);
      expect(_hints.active, isNull);
    });
  }
}

List<String> _traversalLabels(SemanticsNode node) {
  final SemanticsNode? root = node.owner?.rootSemanticsNode;
  if (root == null) return const <String>[];

  Iterable<String> labels(SemanticsNode node) sync* {
    if (node.label.isNotEmpty) yield node.label;
    for (final SemanticsNode child in node.debugListChildrenInOrder(DebugSemanticsDumpOrder.traversalOrder)) {
      yield* labels(child);
    }
  }

  return labels(root).toList();
}

Finder _gotItButton() => find.ancestor(
  of: find.text(_gotIt),
  matching: find.byWidgetPredicate((Widget w) => w is Semantics && w.properties.button == true),
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(FeatureHint.settle);
  await tester.pumpAndSettle();
}

Finder _bubble() => find.ancestor(of: find.text(_copy), matching: find.byType(ScaleTransition));

Widget _host({
  Alignment alignment = Alignment.center,
  bool enabled = true,
  HintId id = HintId.variantDots,
  Widget? extra,
}) => Scaffold(
  body: Stack(
    children: <Widget>[
      ?extra,
      Align(
        alignment: alignment,
        child: FeatureHint(
          id: id,
          enabled: enabled,
          child: const SizedBox(key: Key('control'), width: 44, height: 44),
        ),
      ),
    ],
  ),
);

Widget _app(
  Widget home, {
  bool reduceMotion = false,
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  TargetPlatform? platform,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: (brightness == Brightness.dark ? kDarkTheme : kLightTheme).copyWith(platform: platform),
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: home,
);
