import 'package:Prism/core/analytics/analytics_runtime.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/layout_prefs/data/layout_prefs_store.dart';
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/layout_prefs/views/pages/layout_settings_page.dart';
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

Future<void> _pumpPage(WidgetTester tester, {TextScaler textScaler = TextScaler.noScaling}) async {
  tester.view
    ..physicalSize = const Size(390, 844)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: withPrismAccent(prismLightThemes.first.theme, prismLightThemes.first.defaultAccentValue),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: const LayoutSettingsPage(),
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

    expect(find.byType(Switch), findsNWidgets(4));
    expect(find.text('Always in the bar'), findsOneWidget);
    expect(tester.widget<Switch>(_switchFor('Home')).onChanged, isNull);
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

    expect(tester.widget<PrismButton>(find.widgetWithText(PrismButton, 'Reset layout')).onPressed, isNull);

    await _tap(tester, find.text('Large'));
    await _tap(tester, _switchFor('Search'));
    expect(store.value.isDefaultLayout, isFalse);

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

    await _tap(tester, find.text('Home'));
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
    expect(
      tester.getSemantics(find.text('Compact')),
      containsSemantics(isSelected: true, isInMutuallyExclusiveGroup: true),
    );
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

    expect(store.value.tabOrder.first, NavTab.collection);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
