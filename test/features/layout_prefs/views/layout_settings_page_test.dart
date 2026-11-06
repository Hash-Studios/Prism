import 'dart:ui' as ui;

import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/pages/layout_settings_page.dart';
import 'package:Prism/features/layout_prefs/views/widgets/one_handed_preview.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_app_analytics.dart';
import '../../../support/fake_firestore_client.dart';
import '../../../support/in_memory_local_store.dart';

/// The row's Semantics node that carries [action], found from the row title. Null when the row has no such action.
SemanticsNode? _rowNodeWithAction(WidgetTester tester, String rowTitle, String action) {
  final int actionId = CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: action));
  SemanticsNode? node = tester.getSemantics(find.text(rowTitle));
  while (node != null) {
    if (node.getSemanticsData().customSemanticsActionIds?.contains(actionId) ?? false) return node;
    node = node.parent;
  }
  return null;
}

void _performRowAction(WidgetTester tester, String rowTitle, String action) {
  final SemanticsNode? node = _rowNodeWithAction(tester, rowTitle, action);
  expect(node, isNotNull, reason: '$rowTitle has no $action action');
  node!.owner!.performAction(
    node.id,
    SemanticsAction.customAction,
    CustomSemanticsAction.getIdentifier(CustomSemanticsAction(label: action)),
  );
}

/// The Switch inside the row for [label], found by its Semantics label "Show {label}".
Finder _switchFor(String label) => find.descendant(
  of: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label == 'Show $label'),
  matching: find.byType(Switch),
);

/// The Switch in the one-handed card, found from its row title.
Finder _oneHandedSwitch() => find.descendant(
  of: find.ancestor(of: find.text('One-handed controls'), matching: find.byType(PrismCard)),
  matching: find.byType(Switch),
);

Future<void> _pumpPage(
  WidgetTester tester, {
  TextScaler textScaler = TextScaler.noScaling,
  Size size = const Size(390, 844),
  bool disableAnimations = false,
  TextDirection direction = TextDirection.ltr,
  EdgeInsets padding = EdgeInsets.zero,
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: withPrismAccent(prismLightThemes.first.theme, prismLightThemes.first.defaultAccentValue),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: textScaler,
          disableAnimations: disableAnimations,
          padding: padding,
          viewPadding: padding,
        ),
        child: child!,
      ),
      home: Directionality(textDirection: direction, child: const LayoutSettingsPage()),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAppAnalytics analytics;
  late LayoutPrefsStore store;

  setUp(() {
    analytics = FakeAppAnalytics();
    AnalyticsRuntime.instance = analytics;
    store = LayoutPrefsStore(SettingsLocalDataSource(InMemoryLocalStore()), FakeFirestoreClient());
    getIt.registerSingleton<LayoutPrefsStore>(store);
  });

  tearDown(() async {
    AnalyticsRuntime.reset();
    await getIt.unregister<LayoutPrefsStore>();
  });

  testWidgets('rows render in the store order with switches, and Home is always in the bar', (tester) async {
    await store.update(const LayoutPrefs(tabOrder: [NavTab.collection, NavTab.home, NavTab.search, NavTab.rewards]));
    await _pumpPage(tester);

    double centerOf(String label) => tester.getCenter(find.text(label)).dy;
    expect(centerOf('Collections'), lessThan(centerOf('Home')));
    expect(centerOf('Home'), lessThan(centerOf('Search')));
    expect(centerOf('Search'), lessThan(centerOf('Rewards')));

    expect(find.descendant(of: find.byType(ReorderableListView), matching: find.byType(Switch)), findsNWidgets(3));
    expect(find.text('Always in the bar'), findsOneWidget);
    // Home has a lock, not a dead switch.
    expect(
      find.descendant(of: find.byType(ReorderableListView), matching: find.byIcon(Icons.lock_rounded)),
      findsOneWidget,
    );
    expect(tester.widget<Switch>(_switchFor('Search')).onChanged, isNotNull);
  });

  testWidgets('hiding a tab moves it under More, and the 3-tab minimum locks the other switches', (tester) async {
    await _pumpPage(tester);

    await _tap(tester, _switchFor('Search'));

    expect(store.value.hiddenTabs, <NavTab>{NavTab.search});
    expect(find.text('Under More'), findsOneWidget);
    expect(tester.widget<Switch>(_switchFor('Rewards')).onChanged, isNull);
    expect(tester.widget<Switch>(_switchFor('Collections')).onChanged, isNull);
    expect(tester.widget<Switch>(_switchFor('Search')).onChanged, isNotNull);
  });

  testWidgets('Move up on Search puts it above Home', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPage(tester);

    _performRowAction(tester, 'Search', 'Move up');
    await tester.pumpAndSettle();

    expect(store.value.tabOrder, [NavTab.search, NavTab.home, NavTab.rewards, NavTab.collection]);
    handle.dispose();
  });

  testWidgets('Move down on Home puts it below Search, and the edge rows have no move past the list', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPage(tester);

    expect(_rowNodeWithAction(tester, 'Home', 'Move up'), isNull);
    expect(_rowNodeWithAction(tester, 'Collections', 'Move down'), isNull);

    _performRowAction(tester, 'Home', 'Move down');
    await tester.pumpAndSettle();

    expect(store.value.tabOrder, [NavTab.search, NavTab.home, NavTab.rewards, NavTab.collection]);
    handle.dispose();
  });

  testWidgets('density segments set the grid size', (tester) async {
    await _pumpPage(tester);

    await _tap(tester, find.text('Large'));
    expect(store.value.density, WallGridDensity.large);

    await _tap(tester, find.text('Compact'));
    expect(store.value.density, WallGridDensity.compact);
  });

  testWidgets('Reset layout is disabled on the default layout and restores it after changes', (tester) async {
    await _pumpPage(tester);
    await tester.scrollUntilVisible(find.text('Reset layout'), 200, scrollable: find.byType(Scrollable).first);

    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Reset layout')).onPressed, isNull);

    await tester.scrollUntilVisible(find.text('Large'), -200, scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.text('Large'));
    await tester.scrollUntilVisible(_switchFor('Search'), -200, scrollable: find.byType(Scrollable).first);
    await _tap(tester, _switchFor('Search'));
    expect(store.value.isDefaultLayout, isFalse);

    await tester.scrollUntilVisible(find.text('Reset layout'), 200, scrollable: find.byType(Scrollable).first);
    await _tap(tester, find.widgetWithText(PrismButton, 'Reset layout'));

    expect(store.value.isDefaultLayout, isTrue);
  });

  testWidgets('large text at 2x renders the page without exceptions and shows all four tab labels', (tester) async {
    await _pumpPage(tester, textScaler: const TextScaler.linear(2.0));

    expect(tester.takeException(), isNull);
    for (final label in ['Home', 'Search', 'Rewards', 'Collections']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('a tap on a tab row title toggles it, like the other switch rows in Settings', (tester) async {
    await _pumpPage(tester);

    await _tap(tester, find.text('Search'));
    expect(store.value.hiddenTabs, <NavTab>{NavTab.search});

    await _tap(tester, find.text('Search'));
    expect(store.value.hiddenTabs, isEmpty);

    // The first "Home" is the tab row; the second is the Home section header further down.
    await _tap(tester, find.text('Home').first);
    expect(store.value.hiddenTabs, isEmpty);
  });

  testWidgets('large text lists the grid sizes in full instead of truncating three segments', (tester) async {
    await _pumpPage(tester, textScaler: const TextScaler.linear(2.0));
    await tester.scrollUntilVisible(find.text('Large'), 200, scrollable: find.byType(Scrollable).first);

    expect(find.byType(PrismSegmented<WallGridDensity>), findsNothing);
    for (final label in ['Compact', 'Comfortable', 'Large']) {
      expect(find.text(label), findsOneWidget);
    }
    await _tap(tester, find.text('Compact'));
    expect(store.value.density, WallGridDensity.compact);
    expect(tester.getSemantics(find.text('Compact')), isSemantics(isSelected: true, isInMutuallyExclusiveGroup: true));
  });

  testWidgets('dragging a handle reorders the tabs', (tester) async {
    await _pumpPage(tester);

    final Finder handle = find.byTooltip('Reorder Collections');
    final TestGesture gesture = await tester.startGesture(tester.getCenter(handle));
    for (int i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, -15));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(store.value.tabOrder, <NavTab>[NavTab.collection, NavTab.home, NavTab.search, NavTab.rewards]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('controls section shows the one-handed switch off with its footnote', (tester) async {
    await _pumpPage(tester);

    expect(find.text('Controls'), findsOneWidget);
    expect(find.text('One-handed controls'), findsOneWidget);
    expect(find.text('Puts your profile and notifications in the bottom bar, in reach of your thumb.'), findsOneWidget);
    expect(tester.widget<Switch>(_oneHandedSwitch()).value, isFalse);
  });

  testWidgets('the one-handed switch sets oneHanded and tracks each change', (tester) async {
    await _pumpPage(tester);

    await _tap(tester, _oneHandedSwitch());
    expect(store.value.oneHanded, isTrue);
    expect(analytics.events.whereType<LayoutOneHandedToggledEvent>().map((e) => e.enabled).toList(), <bool>[true]);

    await _tap(tester, _oneHandedSwitch());
    expect(store.value.oneHanded, isFalse);
    expect(analytics.events.whereType<LayoutOneHandedToggledEvent>().map((e) => e.enabled).toList(), <bool>[
      true,
      false,
    ]);
  });

  testWidgets('a tap on the one-handed row title toggles it', (tester) async {
    await _pumpPage(tester);

    await _tap(tester, find.text('One-handed controls'));
    expect(store.value.oneHanded, isTrue);

    await _tap(tester, find.text('One-handed controls'));
    expect(store.value.oneHanded, isFalse);
  });

  testWidgets('the one-handed row reads as one toggle and the preview adds no semantics', (tester) async {
    final handle = tester.ensureSemantics();
    await _pumpPage(tester);

    await _tap(tester, _oneHandedSwitch());

    final SemanticsData row = tester.getSemantics(find.text('One-handed controls')).getSemanticsData();
    expect(row.flagsCollection.isToggled, ui.Tristate.isTrue);
    expect(
      find.descendant(
        of: find.byType(OneHandedPreview),
        matching: find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.label != null),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('the Show topics you follow switch turns the Home row off and back on', (tester) async {
    await _pumpPage(tester);

    await _tap(tester, find.byType(Switch).last);
    expect(store.value.followingRow, isFalse);

    await _tap(tester, find.byType(Switch).last);
    expect(store.value.followingRow, isTrue);
  });

  testWidgets('Reset layout turns one-handed controls back off', (tester) async {
    await store.update(const LayoutPrefs(oneHanded: true));
    await _pumpPage(tester);
    await tester.scrollUntilVisible(find.text('Reset layout'), 200, scrollable: find.byType(Scrollable).first);

    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Reset layout')).onPressed, isNotNull);

    await _tap(tester, find.widgetWithText(PrismButton, 'Reset layout'));

    expect(store.value.oneHanded, isFalse);
  });

  testWidgets('one-handed controls at 320 wide and 2x text render and the preview fits the card', (tester) async {
    await _pumpPage(tester, size: const Size(320, 640), textScaler: const TextScaler.linear(2.0));
    await tester.scrollUntilVisible(find.text('One-handed controls'), 200, scrollable: find.byType(Scrollable).first);

    expect(tester.takeException(), isNull);
    final double cardWidth = tester
        .getSize(find.ancestor(of: find.byType(OneHandedPreview), matching: find.byType(PrismCard)))
        .width;
    final double previewWidth = tester
        .getSize(find.descendant(of: find.byType(OneHandedPreview), matching: find.byType(FittedBox)))
        .width;
    expect(previewWidth, lessThanOrEqualTo(cardWidth));
  });

  testWidgets('reduced motion puts the preview in its end state after one frame', (tester) async {
    await _pumpPage(tester, disableAnimations: true);
    final Finder slides = find.descendant(
      of: find.byType(OneHandedPreview),
      matching: find.byType(AnimatedPositionedDirectional),
    );
    expect(slides, findsNWidgets(4));

    await tester.ensureVisible(_oneHandedSwitch());
    await tester.pumpAndSettle();
    await tester.tap(_oneHandedSwitch());
    await tester.pump();
    final List<Rect> afterOneFrame = [for (int i = 0; i < 4; i++) tester.getRect(slides.at(i))];

    await tester.pumpAndSettle();
    final List<Rect> settled = [for (int i = 0; i < 4; i++) tester.getRect(slides.at(i))];

    expect(afterOneFrame, settled);
  });

  testWidgets('right-to-left renders the one-handed row without exceptions', (tester) async {
    await _pumpPage(tester, direction: TextDirection.rtl);
    await tester.scrollUntilVisible(find.text('One-handed controls'), 200, scrollable: find.byType(Scrollable).first);

    expect(tester.takeException(), isNull);
    expect(_oneHandedSwitch(), findsOneWidget);
  });

  for (final double width in <double>[320, 360, 390]) {
    for (final TextDirection direction in TextDirection.values) {
      testWidgets('the one-handed preview matches the bar at $width in ${direction.name}', (tester) async {
        await store.update(const LayoutPrefs(oneHanded: true));
        await _pumpPage(tester, size: Size(width, 844), direction: direction);
        await tester.ensureVisible(find.byType(OneHandedPreview));
        await tester.pumpAndSettle();

        final Finder slides = find.descendant(
          of: find.byType(OneHandedPreview),
          matching: find.byType(AnimatedPositionedDirectional),
        );
        final Rect pill = tester.getRect(slides.at(0));
        final Rect create = tester.getRect(slides.at(1));
        final Rect bell = tester.getRect(slides.at(2));
        final Rect account = tester.getRect(slides.at(3));
        final bool ltr = direction == TextDirection.ltr;

        expect(ltr ? pill.right < create.left : create.right < pill.left, isTrue);
        if (width == 320) {
          expect(account.center.dx, closeTo(create.center.dx, 0.01));
          expect(account.bottom, lessThan(create.top));
        } else {
          expect(account.center.dy, closeTo(create.center.dy, 0.01));
          expect(ltr ? account.right < pill.left : pill.right < account.left, isTrue);
        }
        final AnimatedOpacity bellVisibility = tester.widget<AnimatedOpacity>(
          find.descendant(of: slides.at(2), matching: find.byType(AnimatedOpacity)),
        );
        expect(bellVisibility.opacity, width == 390 ? 1 : 0);
        if (width == 390) {
          expect(bell.center.dy, closeTo(create.center.dy, 0.01));
          expect(ltr ? create.right < bell.left : bell.right < create.left, isTrue);
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final double width in <double>[360, 390]) {
    testWidgets('the one-handed preview accounts for side safe areas at $width', (tester) async {
      await store.update(const LayoutPrefs(oneHanded: true));
      await _pumpPage(tester, size: Size(width, 844), padding: const EdgeInsets.symmetric(horizontal: 20));
      await tester.ensureVisible(find.byType(OneHandedPreview));
      await tester.pumpAndSettle();

      final Finder slides = find.descendant(
        of: find.byType(OneHandedPreview),
        matching: find.byType(AnimatedPositionedDirectional),
      );
      final Rect create = tester.getRect(slides.at(1));
      final Rect account = tester.getRect(slides.at(3));
      expect(
        tester
            .widget<AnimatedOpacity>(find.descendant(of: slides.at(2), matching: find.byType(AnimatedOpacity)))
            .opacity,
        0,
      );
      if (width == 360) {
        expect(account.center.dx, closeTo(create.center.dx, 0.01));
        expect(account.bottom, lessThan(create.top));
      } else {
        expect(account.center.dy, closeTo(create.center.dy, 0.01));
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final bool oneHanded in <bool>[false, true]) {
    for (final TextDirection direction in TextDirection.values) {
      testWidgets('the Duo preview matches its rail with one-handed $oneHanded in ${direction.name}', (tester) async {
        tester.view.viewPadding = const FakeViewPadding(right: 84, bottom: 34);
        addTearDown(tester.view.resetViewPadding);
        await store.update(LayoutPrefs(oneHanded: oneHanded));
        await _pumpPage(tester, direction: direction, padding: const EdgeInsets.only(right: 84, bottom: 34));
        await tester.ensureVisible(find.byType(OneHandedPreview));
        await tester.pumpAndSettle();

        final Finder preview = find.byType(OneHandedPreview);
        final Finder slides = find.descendant(of: preview, matching: find.byType(AnimatedPositionedDirectional));
        final Rect screen = tester.getRect(find.descendant(of: preview, matching: find.byType(Container)).first);
        final Rect pill = tester.getRect(slides.at(0));
        final Rect create = tester.getRect(slides.at(1));
        final Rect bell = tester.getRect(slides.at(2));
        final Rect avatar = tester.getRect(slides.at(3));

        expect(pill.height, greaterThan(pill.width));
        expect(
          pill.center.dx,
          oneHanded || direction == TextDirection.ltr ? greaterThan(screen.center.dx) : lessThan(screen.center.dx),
        );
        expect(create.center.dx, closeTo(pill.center.dx, 0.01));
        expect(pill.bottom, lessThan(create.top));
        expect(
          tester
              .widget<AnimatedOpacity>(find.descendant(of: slides.at(2), matching: find.byType(AnimatedOpacity)))
              .opacity,
          1,
        );
        if (oneHanded) {
          expect(avatar.center.dx, closeTo(pill.center.dx, 0.01));
          expect(bell.center.dx, closeTo(pill.center.dx, 0.01));
          expect(avatar.bottom, lessThan(bell.top));
          expect(bell.bottom, lessThan(pill.top));
        } else {
          expect(avatar.center.dy, closeTo(bell.center.dy, 0.01));
          expect(avatar.bottom, lessThan(pill.top));
          expect(bell.bottom, lessThan(pill.top));
        }
        expect(tester.takeException(), isNull);
      }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
    }
  }
}
