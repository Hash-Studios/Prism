import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_app_analytics.dart';

class _FakeTabsRouter extends ChangeNotifier implements TabsRouter {
  int _active = 1;

  @override
  int get activeIndex => _active;

  @override
  void setActiveIndex(int index, {bool notify = true}) {
    _active = index;
    if (notify) notifyListeners();
  }

  @override
  StackRouter? stackRouterOfIndex(int index) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(
  _FakeTabsRouter router, {
  double textScaleFactor = 1,
  Widget body = const SizedBox.expand(),
  ScrollController? bodyScrollController,
}) {
  Widget bottomBar = BottomBar(child: body);
  if (bodyScrollController != null) {
    bottomBar = PrimaryScrollController(controller: bodyScrollController, child: bottomBar);
  }
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScaleFactor)),
      child: child!,
    ),
    home: TabsRouterScope(
      controller: router,
      stateHash: 0,
      child: Scaffold(body: bottomBar),
    ),
  );
}

void main() {
  late FakeAppAnalytics analytics;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
  });
  tearDown(AnalyticsRuntime.reset);

  Future<void> setDuoViewport(WidgetTester tester, {bool keyboardVisible = false}) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(466 * 3, 678 * 3)
      ..viewPadding = const FakeViewPadding(right: 84 * 3, bottom: 34 * 3)
      ..padding = const FakeViewPadding(right: 84 * 3, bottom: 34 * 3)
      ..viewInsets = FakeViewPadding(bottom: keyboardVisible ? 440 * 3 : 0);
    tester.view.display
      ..devicePixelRatio = 3
      ..size = const Size(466 * 3, 678 * 3);
    addTearDown(tester.view.reset);
    addTearDown(tester.view.display.reset);
  }

  testWidgets('short Duo keyboard viewport keeps rail controls reachable', (tester) async {
    await setDuoViewport(tester, keyboardVisible: true);

    final router = _FakeTabsRouter();
    final bodyController = ScrollController();
    addTearDown(bodyController.dispose);
    await tester.pumpWidget(
      _host(
        router,
        textScaleFactor: 3,
        bodyScrollController: bodyController,
        body: ListView.builder(
          primary: true,
          itemCount: 100,
          itemBuilder: (_, index) => SizedBox(height: 80, child: Text('row $index')),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(tester.widget<PrismBottomNav>(find.byType(PrismBottomNav)).axis, Axis.vertical);

    final railScroll = find.ancestor(of: find.byType(PrismBottomNav), matching: find.byType(Scrollable));
    expect(railScroll, findsOneWidget);
    final ScrollPosition railPosition = tester.state<ScrollableState>(railScroll).position;
    expect(bodyController.positions, hasLength(1));
    expect(identical(railPosition, bodyController.position), isFalse);

    await tester.drag(railScroll, const Offset(0, 180));
    await tester.pumpAndSettle();
    final home = find.byTooltip('Home');
    await tester.tap(home);
    await tester.pump();
    expect(router.activeIndex, 0);

    await tester.drag(railScroll, const Offset(0, -180));
    await tester.pumpAndSettle();
    final upload = find.bySemanticsLabel('Upload');
    final Rect uploadRect = tester.getRect(upload);
    expect(uploadRect.top, greaterThanOrEqualTo(0));
    final double keyboardTop = tester.view.physicalSize.height / 3 - tester.view.viewInsets.bottom / 3;
    expect(uploadRect.bottom, lessThanOrEqualTo(keyboardTop));
    expect(upload.hitTestable(), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('full-height Duo rail stays fixed and does not need to scroll at large text', (tester) async {
    await setDuoViewport(tester);

    final router = _FakeTabsRouter();
    await tester.pumpWidget(_host(router, textScaleFactor: 3));
    await tester.pump();

    expect(tester.takeException(), isNull);
    final railScroll = find.ancestor(of: find.byType(PrismBottomNav), matching: find.byType(Scrollable));
    expect(railScroll, findsOneWidget);
    expect(tester.state<ScrollableState>(railScroll).position.maxScrollExtent, 0);
    expect(tester.getRect(find.byType(PrismBottomNav)).bottom, lessThan(tester.view.physicalSize.height / 3));
    expect(tester.getRect(find.bySemanticsLabel('Upload')).bottom, lessThan(tester.view.physicalSize.height / 3));

    await tester.tap(find.byTooltip('Home'));
    await tester.pump();
    expect(router.activeIndex, 0);

    await tester.tap(find.bySemanticsLabel('Upload'));
    await tester.pump();
    expect(find.text('Sign in to Prism'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
