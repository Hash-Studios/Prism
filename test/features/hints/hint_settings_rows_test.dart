import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/startup/startup_sheet.dart';
import 'package:Prism/features/hints/data/feature_hints.dart';
import 'package:Prism/features/hints/domain/feature_hint.dart';
import 'package:Prism/features/hints/views/feature_hint.dart';
import 'package:Prism/features/hints/views/hint_settings_rows.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

const String _copy = 'Tap a dot to see this wallpaper in another colour.';
const MethodChannel _toastChannel = MethodChannel('PonnamKarthik/fluttertoast');

late Map<String, Object?> _store;
late DateTime _now;
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
  remoteConfig: (String key) => '',
  openSheets: () => 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _store = <String, Object?>{};
    _now = DateTime(2026, 11, 9, 12);
    _previous = FeatureHints.instance;
    _hints = _build();
    FeatureHints.instance = _hints;
    _hints.attach();
    StartupModalSlot.reset();
    AnalyticsRuntime.instance = FakeAppAnalytics();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, (
      MethodCall call,
    ) async {
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_toastChannel, null);
    _hints.dispose();
    FeatureHints.instance = _previous;
    StartupModalSlot.reset();
    AnalyticsRuntime.reset();
  });

  testWidgets('Show tips starts on, and turning it off stops hints from showing', (tester) async {
    await tester.pumpWidget(_app(Scaffold(body: ListView(children: const <Widget>[ShowTipsRow(), ResetTipsRow()]))));
    expect(find.text('Show tips'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(FeatureHints.instance.enabled, isFalse);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);

    await tester.pumpWidget(_app(const Scaffold(body: Center(child: _Control()))));
    await tester.pump(FeatureHint.settle);
    await tester.pumpAndSettle();
    expect(find.text(_copy), findsNothing);
  });

  testWidgets('Reset tips clears the shown time of a hint', (tester) async {
    expect(FeatureHints.instance.view(HintId.variantDots), isTrue);
    expect(FeatureHints.instance.record(HintId.variantDots).shownAt, isNotNull);

    await tester.pumpWidget(_app(Scaffold(body: ListView(children: const <Widget>[ShowTipsRow(), ResetTipsRow()]))));
    await tester.tap(find.text('Reset tips'));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 2));

    expect(FeatureHints.instance.record(HintId.variantDots).shownAt, isNull);
  });
}

class _Control extends StatelessWidget {
  const _Control();

  @override
  Widget build(BuildContext context) => const FeatureHint(
    id: HintId.variantDots,
    child: SizedBox(key: Key('control'), width: 44, height: 44),
  );
}

Widget _app(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: kLightTheme,
  home: home,
);
