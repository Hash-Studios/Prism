import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/features/hints/data/feature_hints.dart';
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/features/hints/views/feature_hint.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

const String _copy = 'Tap a dot to see this wallpaper in another colour.';
const String _photoCopy = 'Find wallpapers that match a photo from your gallery.';
const String _gotIt = 'Got it';

late Map<String, Object?> _store;
late DateTime _now;
late int _sheets;
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
  userId: () => 'u1',
  remoteConfig: (String key) => _remote(key),
  openSheets: () => _sheets,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _store = <String, Object?>{};
    _now = DateTime(2026, 11, 9, 12);
    _sheets = 0;
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
}

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
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: kLightTheme,
  builder: (BuildContext context, Widget? child) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion, textScaler: TextScaler.linear(textScale)),
    child: Directionality(textDirection: direction, child: child!),
  ),
  home: home,
);
