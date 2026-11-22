import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/features/creator_walls/creator_walls.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(
  WidgetTester tester, {
  required int value,
  ValueChanged<int>? onChanged,
  TextScaler textScaler = TextScaler.noScaling,
  Size? surface,
}) async {
  if (surface != null) {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }
  await tester.pumpWidget(
    MaterialApp(
      theme: kLightTheme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (BuildContext context, Widget? child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        // Both screens show the picker inside a scrolling list.
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: CreatorPricePicker(value: value, onChanged: onChanged),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    EconomyConfig.resetForTest();
  });

  tearDown(() {
    EconomyConfig.resetForTest();
  });

  testWidgets('shows Free and the default prices', (tester) async {
    await _pump(tester, value: 0, onChanged: (_) {});
    expect(find.text('Sell this wall'), findsOneWidget);
    expect(find.text('Free'), findsOneWidget);
    expect(find.text('20'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('75'), findsOneWidget);
  });

  testWidgets('tapping 40 calls onChanged with 40', (tester) async {
    final List<int> picked = <int>[];
    await _pump(tester, value: 0, onChanged: picked.add);
    await tester.tap(find.text('40'));
    await tester.pump();
    expect(picked, <int>[40]);
  });

  testWidgets('tapping Free calls onChanged with 0', (tester) async {
    final List<int> picked = <int>[];
    await _pump(tester, value: 20, onChanged: picked.add);
    await tester.tap(find.text('Free'));
    await tester.pump();
    expect(picked, <int>[0]);
  });

  testWidgets('the selected chip reports selected in semantics', (tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pump(tester, value: 40, onChanged: (_) {});
    expect(
      tester.getSemantics(find.bySemanticsLabel('40 coins')),
      matchesSemantics(label: '40 coins', isButton: true, hasSelectedState: true, isSelected: true, hasTapAction: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('20 coins')),
      matchesSemantics(
        label: '20 coins',
        isButton: true,
        hasSelectedState: true,
        isSelected: false,
        hasTapAction: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('wraps at text scale 2.0 on a 320 wide screen without overflow', (tester) async {
    await _pump(
      tester,
      value: 75,
      onChanged: (_) {},
      textScaler: const TextScaler.linear(2.0),
      surface: const Size(320, 640),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('75'), findsOneWidget);
  });
}
