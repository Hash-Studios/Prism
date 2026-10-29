import 'dart:async';

import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/prism_bottom_nav.dart';
import 'package:Prism/features/navigation/views/widgets/prism_fab.dart';
import 'package:Prism/l10n/generated/app_localizations_de.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/theme.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTabsRouter extends ChangeNotifier implements TabsRouter {
  @override
  int get activeIndex => 0;

  @override
  StackRouter? stackRouterOfIndex(int index) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const cardKey = Key('snackbar');
  late GlobalKey<ScaffoldMessengerState> messenger;
  late _FakeTabsRouter tabs;
  late BuildContext tabContext;

  setUpAll(() async {
    for (final asset in <String>['assets/fonts/ProximaNova-Regular.otf', 'assets/fonts/Proxima Nova Bold.otf']) {
      await (FontLoader('Proxima Nova')..addFont(rootBundle.load(asset))).load();
    }
  });

  setUp(() {
    messenger = GlobalKey<ScaffoldMessengerState>();
    tabs = _FakeTabsRouter();
  });
  tearDown(() => tabs.dispose());

  Future<void> pumpBar(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double bottom = 34,
    double right = 0,
    double left = 0,
    double keyboard = 0,
    double? snackbarWidth,
    EdgeInsets snackbarInsets = const EdgeInsets.fromLTRB(15, 5, 15, 10),
    bool nestedTabNavigator = false,
    bool usePrismTheme = false,
    double textScale = 1,
    ScrollController? scrollController,
  }) async {
    tester.view
      ..devicePixelRatio = 1
      ..physicalSize = size
      ..viewPadding = FakeViewPadding(bottom: bottom, right: right, left: left)
      ..padding = FakeViewPadding(bottom: keyboard == 0 ? bottom : 0, right: right, left: left)
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    Widget tabPage(BuildContext context) {
      tabContext = context;
      return Scaffold(
        body: ListView.builder(
          controller: scrollController,
          itemCount: 100,
          itemBuilder: (_, index) => SizedBox(height: 80, child: Text('row $index')),
        ),
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messenger,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kDarkTheme.copyWith(
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            width: snackbarWidth,
            insetPadding: snackbarInsets,
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true, textScaler: TextScaler.linear(textScale)),
          child: Builder(
            builder: (context) => usePrismTheme
                ? Theme(
                    data: Theme.of(
                      context,
                    ).copyWith(snackBarTheme: prismSnackBarThemeFor(context, Theme.of(context).snackBarTheme)),
                    child: child!,
                  )
                : child!,
          ),
        ),
        home: TabsRouterScope(
          controller: tabs,
          stateHash: 0,
          child: BottomBar(
            child: nestedTabNavigator
                ? Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: tabPage))
                : Builder(builder: tabPage),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> showMessage(WidgetTester tester, {String? actionLabel, VoidCallback? onPressed}) async {
    messenger.currentState!.showSnackBar(
      SnackBar(
        key: cardKey,
        duration: const Duration(minutes: 1),
        content: const Text('Wallpaper set'),
        action: actionLabel == null ? null : SnackBarAction(label: actionLabel, onPressed: onPressed!),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect cardRect(WidgetTester tester) =>
      tester.getRect(find.descendant(of: find.byKey(cardKey), matching: find.byType(Material)).first);

  void expectReadableMessage(WidgetTester tester) {
    final RenderParagraph message = tester.renderObject(find.text('Wallpaper set'));
    final boxes = message.getBoxesForSelection(const TextSelection(baseOffset: 0, extentOffset: 13));
    expect(boxes, isNotEmpty);
    expect(boxes.length, lessThanOrEqualTo(2));
    expect(message.didExceedMaxLines, isFalse);
    for (final box in boxes) {
      expect(box.left, greaterThanOrEqualTo(0));
      expect(box.right, lessThanOrEqualTo(message.size.width));
      expect(box.bottom, lessThanOrEqualTo(message.size.height));
    }
  }

  for (final bottom in <double>[0, 34]) {
    testWidgets('a global messenger keeps tab feedback above both 56px controls with bottom inset $bottom', (
      tester,
    ) async {
      await pumpBar(tester, bottom: bottom);
      await showMessage(tester);

      final Rect pill = tester.getRect(find.byType(PrismBottomNav));
      final Rect fab = tester.getRect(find.byType(PrismFab));
      expect(pill.height, 56);
      expect(fab.height, 56);
      expect(pill.bottom, closeTo(844 - bottom - 10, 0.01));
      expect(fab.top, pill.top);
      expect(cardRect(tester).bottom, closeTo(pill.top - 8, 0.01));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('keyboard feedback clears the lifted pill instead of applying its inset twice', (tester) async {
    await pumpBar(tester, keyboard: 300);
    await showMessage(tester);

    final Rect pill = tester.getRect(find.byType(PrismBottomNav));
    expect(pill.bottom, closeTo(844 - 300 - 10, 0.01));
    expect(cardRect(tester).bottom, closeTo(pill.top - 8, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a hidden pill leaves feedback above the scroll-to-top action', (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await pumpBar(tester, scrollController: controller);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final Finder scrollToTop = find.bySemanticsLabel('Scroll to top');
    expect(scrollToTop, findsOneWidget);
    await showMessage(tester);

    expect(cardRect(tester).bottom, lessThan(tester.getRect(scrollToTop).top));
    expect(scrollToTop.hitTestable(), findsOneWidget);
    expect(controller.offset, greaterThan(0));
    await tester.tap(scrollToTop);
    await tester.pumpAndSettle();
    expect(controller.offset, 0);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('a width-constrained wide snackbar retains the vertical pill clearance', (tester) async {
    await pumpBar(tester, size: const Size(900, 900), snackbarWidth: 420);
    await showMessage(tester);

    final Rect card = cardRect(tester);
    final Rect pill = tester.getRect(find.byType(PrismBottomNav));
    expect(card.width, 420);
    expect(card.center.dx, 450);
    expect(card.bottom, closeTo(pill.top - 8, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the tab override preserves the wide screen theme horizontal insets', (tester) async {
    await pumpBar(tester, size: const Size(1440, 900), snackbarInsets: const EdgeInsets.fromLTRB(440, 5, 440, 10));
    await showMessage(tester);

    final Rect card = cardRect(tester);
    expect(card.width, 560);
    expect(card.center.dx, 720);
    expect(card.bottom, closeTo(tester.getRect(find.byType(PrismBottomNav)).top - 8, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide tab feedback measures a scaled action against its rendered panel', (tester) async {
    await pumpBar(tester, size: const Size(1440, 900), usePrismTheme: true, textScale: 2);
    final l10n = AppLocalizationsDe();
    final String label = l10n.coreRetryOnScreen(l10n.coreBothScreens);
    var tapped = false;
    await showMessage(tester, actionLabel: label, onPressed: () => tapped = true);

    final Rect card = cardRect(tester);
    final Finder action = find.widgetWithText(TextButton, label);
    expect(card.width, 560);
    expectReadableMessage(tester);
    expect(tester.getRect(action).left, greaterThanOrEqualTo(card.left));
    expect(tester.getRect(action).right, lessThanOrEqualTo(card.right));
    expect(tester.takeException(), isNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets('the side rail leaves feedback in the content column at its normal bottom inset', (tester) async {
    await pumpBar(tester, size: const Size(466, 678), right: 84);
    await showMessage(tester);

    final Rect card = cardRect(tester);
    expect(tester.widget<PrismBottomNav>(find.byType(PrismBottomNav)).axis, Axis.vertical);
    expect(card.right, lessThanOrEqualTo(466 - 84));
    expect(card.bottom, closeTo(678 - 34 - 10, 0.01));
    expect(Theme.of(tabContext).snackBarTheme.insetPadding!.bottom, 10);
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('the wide side rail centers a full panel within its actual content column', (tester) async {
    await pumpBar(tester, size: const Size(900, 900), right: 84, usePrismTheme: true);
    await showMessage(tester);

    final Rect card = cardRect(tester);
    expect(tester.widget<PrismBottomNav>(find.byType(PrismBottomNav)).axis, Axis.vertical);
    expect(card.width, 560);
    expect(card.center.dx, (900 - 84) / 2);
    expect(card.bottom, closeTo(900 - 34 - 10, 0.01));
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('wide floating feedback keeps its panel width inside horizontal safe areas', (tester) async {
    await pumpBar(tester, size: const Size(900, 900), left: 44, right: 44, usePrismTheme: true);
    await showMessage(tester);

    final Rect card = cardRect(tester);
    expect(card.width, 560);
    expect(card.left, greaterThanOrEqualTo(44));
    expect(card.right, lessThanOrEqualTo(900 - 44));
    expect(card.bottom, closeTo(tester.getRect(find.byType(PrismBottomNav)).top - 8, 0.01));
    expect(tester.takeException(), isNull);
  });

  Future<void> expectNarrowAction(WidgetTester tester, {required bool rail}) async {
    await pumpBar(
      tester,
      size: Size(rail ? 466 : 480, 900),
      left: rail ? 0 : 44,
      right: rail ? 84 : 44,
      usePrismTheme: true,
      textScale: 2,
    );
    final String label = AppLocalizationsDe().coreUndo;
    var tapped = false;
    await showMessage(tester, actionLabel: label, onPressed: () => tapped = true);

    final Rect card = cardRect(tester);
    final Finder action = find.widgetWithText(TextButton, label);
    final Rect target = tester.getRect(action);
    expectReadableMessage(tester);
    expect(target.left, greaterThanOrEqualTo(card.left));
    expect(target.right, lessThanOrEqualTo(card.right));
    expect(target.height, greaterThanOrEqualTo(kMinInteractiveDimension));
    expect(action.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  }

  testWidgets('narrow rail feedback keeps the scaled Undo action readable and tappable', (tester) async {
    await expectNarrowAction(tester, rail: true);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('narrow safe-area feedback keeps the scaled Undo action readable and tappable', (tester) async {
    await expectNarrowAction(tester, rail: false);
  });

  testWidgets('pushing outside the tab shell does not carry its raised snackbar inset', (tester) async {
    await pumpBar(tester);
    unawaited(
      Navigator.of(
        tabContext,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Outside tabs')))),
    );
    await tester.pumpAndSettle();
    await showMessage(tester);

    expect(find.text('Outside tabs'), findsOneWidget);
    expect(cardRect(tester).bottom, closeTo(844 - 34 - 10, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a route pushed within a tab keeps feedback above the shell controls', (tester) async {
    await pumpBar(tester, nestedTabNavigator: true);
    unawaited(
      Navigator.of(
        tabContext,
      ).push<void>(MaterialPageRoute<void>(builder: (_) => const Scaffold(body: Text('Inside tab')))),
    );
    await tester.pumpAndSettle();
    await showMessage(tester);

    expect(find.text('Inside tab'), findsOneWidget);
    expect(cardRect(tester).bottom, closeTo(tester.getRect(find.byType(PrismBottomNav)).top - 8, 0.01));
    expect(tester.takeException(), isNull);
  });
}
