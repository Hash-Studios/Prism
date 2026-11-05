import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/core/widgets/prism_sheet/device_corner_radius.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smooth_sheets/smooth_sheets.dart';

Widget _app(void Function(BuildContext context) open) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: Builder(
      builder: (context) => TextButton(onPressed: () => open(context), child: const Text('open')),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

BorderRadius _surfaceRadius(WidgetTester tester) {
  final DecoratedBox box = tester
      .widgetList<DecoratedBox>(find.byType(DecoratedBox))
      .firstWhere((b) => (b.decoration as BoxDecoration?)?.boxShadow == PrismBottomSheet.shadow);
  return (box.decoration as BoxDecoration).borderRadius! as BorderRadius;
}

void main() {
  setUp(() => PrismDeviceCornerRadius.setValueForTesting(48));

  testWidgets('shows the title in the header and closes from the close button', (tester) async {
    await tester.pumpWidget(
      _app((context) => showPrismSheet<void>(context, builder: (_) => const PrismSheetBody(title: 'Sort by'))),
    );
    await _open(tester);
    expect(find.text('Sort by'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Sort by'), findsNothing);
  });

  testWidgets('closing moves the sheet at once instead of holding still', (tester) async {
    await tester.pumpWidget(
      _app((context) => showPrismSheet<void>(context, builder: (_) => const PrismSheetBody(title: 'Sort by'))),
    );
    await _open(tester);
    final double rest = tester.getTopLeft(find.text('Sort by')).dy;
    final double height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
    Navigator.of(tester.element(find.text('Sort by'))).pop();
    await tester.pump();
    await tester.pump(PrismDurations.sheet * 0.25);
    expect(tester.getTopLeft(find.text('Sort by')).dy - rest, greaterThan(height * 0.15));
    await tester.pumpAndSettle();
  });

  testWidgets('a released swipe settles from the finger position without a jump', (tester) async {
    await tester.pumpWidget(
      _app((context) => showPrismSheet<void>(context, builder: (_) => const PrismSheetBody(title: 'Sort by'))),
    );
    await _open(tester);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('Sort by')));
    await gesture.moveBy(const Offset(0, 100));
    await tester.pump();
    final double draggedTop = tester.getTopLeft(find.text('Sort by')).dy;

    await gesture.up();
    await tester.pump();
    final double releasedTop = tester.getTopLeft(find.text('Sort by')).dy;
    expect(releasedTop, closeTo(draggedTop, 1));

    await tester.pump(const Duration(milliseconds: 30));
    final double settledTop = tester.getTopLeft(find.text('Sort by')).dy;
    expect(settledTop, greaterThan(releasedTop));
    await tester.pumpAndSettle();
  });

  testWidgets('a close interrupted during a swipe keeps moving in the same direction', (tester) async {
    await tester.pumpWidget(
      _app((context) => showPrismSheet<void>(context, builder: (_) => const PrismSheetBody(title: 'Sort by'))),
    );
    await _open(tester);
    final TestGesture gesture = await tester.startGesture(tester.getCenter(find.text('Sort by')));
    await gesture.moveBy(const Offset(0, 80));
    await tester.pump();
    final double draggedTop = tester.getTopLeft(find.text('Sort by')).dy;

    Navigator.of(tester.element(find.text('Sort by'))).pop();
    await tester.pump();
    final double closeStart = tester.getTopLeft(find.text('Sort by')).dy;
    expect(closeStart, closeTo(draggedTop, 1));
    await tester.pump(const Duration(milliseconds: 30));
    final double closeProgress = tester.getTopLeft(find.text('Sort by')).dy;
    expect(closeProgress, greaterThan(closeStart));

    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Sort by'), findsNothing);
  });

  testWidgets('interrupting a close reverses from its current position without a jump', (tester) async {
    await tester.pumpWidget(
      _app((context) => showPrismSheet<void>(context, builder: (_) => const PrismSheetBody(title: 'Sort by'))),
    );
    await _open(tester);
    final ModalRoute<dynamic> route = ModalRoute.of(tester.element(find.text('Sort by')))!;
    final Animation<double> routeAnimation = route.animation!;
    final ProxyAnimation proxy = routeAnimation as ProxyAnimation;
    final AnimationController controller = proxy.parent! as AnimationController;

    Navigator.of(tester.element(find.text('Sort by'))).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    final double closingTop = tester.getTopLeft(find.text('Sort by')).dy;

    controller.forward();
    await tester.pump();
    final double reversedTop = tester.getTopLeft(find.text('Sort by')).dy;
    expect(reversedTop, closeTo(closingTop, 1));
    await tester.pump(const Duration(milliseconds: 30));
    expect(tester.getTopLeft(find.text('Sort by')).dy, lessThan(reversedTop));
    await tester.pumpAndSettle();
  });

  testWidgets('floats on an inset with concentric bottom corners', (tester) async {
    await tester.pumpWidget(
      _app((context) => showPrismSheet<void>(context, builder: (_) => const PrismSheetBody(title: 'Sort by'))),
    );
    await _open(tester);
    final Rect sheet = tester.getRect(find.byType(SheetContentScaffold));
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(sheet.left, PrismBottomSheet.inset);
    expect(sheet.right, screen.width - PrismBottomSheet.inset);
    expect(sheet.bottom, screen.height - PrismBottomSheet.inset);
    final BorderRadius radius = _surfaceRadius(tester);
    expect(radius.topLeft, const Radius.circular(PrismBottomSheet.topRadius));
    expect(radius.bottomLeft, const Radius.circular(48 - PrismBottomSheet.inset));
  });

  testWidgets('goes flush with the screen edges at full height', (tester) async {
    await tester.pumpWidget(
      _app(
        (context) => showPrismSheet<void>(
          context,
          initialDetent: PrismSheetDetent.large,
          builder: (_) => const PrismSheetBody(title: 'Tall'),
        ),
      ),
    );
    await _open(tester);
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect content = tester.getRect(find.byType(SheetContentScaffold));
    expect(content.width, screen.width);
    expect(_surfaceRadius(tester).bottomLeft, Radius.zero);
  });

  testWidgets('keeps the actions pinned below a body that scrolls', (tester) async {
    await tester.pumpWidget(
      _app(
        (context) => showPrismSheet<void>(
          context,
          builder: (_) => PrismSheetBody(
            title: 'Long',
            actions: <Widget>[PrismButton(label: 'Save', expand: true, onPressed: () {})],
            child: Column(children: <Widget>[for (int i = 0; i < 60; i++) SizedBox(height: 40, child: Text('row $i'))]),
          ),
        ),
      ),
    );
    await _open(tester);
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect save = tester.getRect(find.widgetWithText(PrismButton, 'Save'));
    expect(save.bottom, lessThanOrEqualTo(screen.height));
    expect(find.text('row 59').hitTestable(), findsNothing);
    expect(find.text('Save').hitTestable(), findsOneWidget);
  });

  testWidgets('a moment sheet shows its headline under Glint, not in the header', (tester) async {
    await tester.pumpWidget(
      _app(
        (context) => showPrismSheet<void>(
          context,
          builder: (_) => const PrismSheetBody(title: 'Nice', message: 'You did it', mood: GlintMood.celebrate),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final Rect headline = tester.getRect(find.text('Nice'));
    final Rect close = tester.getRect(find.byTooltip('Close'));
    expect(headline.top, greaterThan(close.bottom));
  });

  testWidgets('a trailing action runs without closing the sheet', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      _app(
        (context) => showPrismSheet<void>(
          context,
          builder: (_) => PrismSheetBody(
            title: 'Filters',
            trailingAction: PrismSheetAction(label: 'Clear', onTap: () => taps++),
          ),
        ),
      ),
    );
    await _open(tester);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(find.text('Filters'), findsOneWidget);
  });

  testWidgets('showPrismConfirm resolves true only from the confirm button', (tester) async {
    final List<bool> results = <bool>[];
    await tester.pumpWidget(
      _app(
        (context) async => results.add(await showPrismConfirm(context, title: 'Sign out?', confirmLabel: 'Sign out')),
      ),
    );
    await _open(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await _open(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(results, <bool>[true, false, false]);
  });

  testWidgets('a tall sheet at rest still floats, so wrapped text cannot loop the layout', (tester) async {
    await tester.pumpWidget(
      _app(
        (context) => showPrismSheet<void>(
          context,
          builder: (_) => PrismSheetBody(
            title: 'Tall',
            message: List<String>.filled(8, 'A long line of copy that wraps onto more than one row.').join(' '),
            child: Column(children: <Widget>[for (int i = 0; i < 10; i++) const SizedBox(height: 40)]),
          ),
        ),
      ),
    );
    await _open(tester);
    final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final Rect sheet = tester.getRect(find.byType(SheetContentScaffold));
    expect(sheet.height, greaterThan(screen.height * 0.6));
    expect(sheet.left, PrismBottomSheet.inset);
  });

  testWidgets('a sheet taller than the screen rests floating with round bottom corners', (tester) async {
    await tester.pumpWidget(
      _app(
        (context) => showPrismSheet<void>(
          context,
          builder: (_) => PrismSheetBody(
            title: 'Very tall',
            child: Column(children: <Widget>[for (int i = 0; i < 40; i++) const SizedBox(height: 40)]),
          ),
        ),
      ),
    );
    await _open(tester);
    expect(tester.getRect(find.byType(SheetContentScaffold)).left, PrismBottomSheet.inset);
    expect(_surfaceRadius(tester).bottomLeft, const Radius.circular(48 - PrismBottomSheet.inset));
  });

  testWidgets('a sheet the user must answer ignores the barrier', (tester) async {
    await tester.pumpWidget(
      _app(
        (context) => showPrismSheet<void>(
          context,
          barrierDismissible: false,
          swipeDismissible: false,
          builder: (_) => const PrismSheetBody(title: 'Required', showCloseButton: false, showHandle: false),
        ),
      ),
    );
    await _open(tester);
    expect(find.byTooltip('Close'), findsNothing);
    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('a zero-size viewport does not give the sheet a negative height', (tester) async {
    await tester.binding.setSurfaceSize(Size.zero);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox.shrink(),
      ),
    );

    const Key bodyKey = Key('sheet-body');
    showPrismSheet<void>(navigatorKey.currentContext!, builder: (_) => const SizedBox.shrink(key: bodyKey));
    await tester.pump();
    expect(find.byKey(bodyKey, skipOffstage: false), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a keyboard taller than the viewport does not give the sheet a negative height', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.viewPadding = const FakeViewPadding(top: 24);
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 900);
    addTearDown(tester.view.reset);
    final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SizedBox.shrink(),
      ),
    );

    const Key bodyKey = Key('sheet-body');
    showPrismSheet<void>(navigatorKey.currentContext!, builder: (_) => const SizedBox.shrink(key: bodyKey));
    await tester.pump();
    expect(find.byKey(bodyKey, skipOffstage: false), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('a keyboard that fits keeps the sheet above it', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    tester.view.viewPadding = const FakeViewPadding(top: 24);
    tester.view.padding = const FakeViewPadding(top: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);

    const Key bodyKey = Key('sheet-body');
    await tester.pumpWidget(
      _app((context) => showPrismSheet<void>(context, builder: (_) => const SizedBox(key: bodyKey, height: 80))),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(bodyKey)).bottom, lessThanOrEqualTo(500));
  });
}
