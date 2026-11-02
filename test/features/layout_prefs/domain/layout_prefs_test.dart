import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults are the four tabs in order, none hidden, comfortable grid, For you feed', () {
    const LayoutPrefs prefs = LayoutPrefs();

    expect(prefs.tabOrder, <NavTab>[NavTab.home, NavTab.search, NavTab.rewards, NavTab.collection]);
    expect(prefs.hiddenTabs, isEmpty);
    expect(prefs.density, WallGridDensity.comfortable);
    expect(prefs.feedTab, HomeFeedChip.forYou);
    expect(prefs.isDefaultLayout, isTrue);
  });

  test('home cannot be hidden', () {
    const LayoutPrefs prefs = LayoutPrefs();

    expect(prefs.canHide(NavTab.home), isFalse);
    expect(prefs.withTabVisible(NavTab.home, visible: false), equals(prefs));
  });

  test('a tab can be hidden while three tabs stay visible, and shown again', () {
    const LayoutPrefs prefs = LayoutPrefs();

    final LayoutPrefs hidden = prefs.withTabVisible(NavTab.search, visible: false);

    expect(hidden.visibleTabs, <NavTab>[NavTab.home, NavTab.rewards, NavTab.collection]);
    expect(hidden.hiddenInOrder, <NavTab>[NavTab.search]);
    expect(hidden.canHide(NavTab.rewards), isFalse);
    expect(hidden.withTabVisible(NavTab.rewards, visible: false), equals(hidden));
    expect(hidden.withTabVisible(NavTab.search, visible: true), equals(prefs));
  });

  test('withTabMoved moves a tab in the list order', () {
    const LayoutPrefs prefs = LayoutPrefs();

    expect(prefs.withTabMoved(0, 3).tabOrder, <NavTab>[NavTab.search, NavTab.rewards, NavTab.collection, NavTab.home]);
  });

  test('withTabMoved returns the same object for out-of-range indexes', () {
    const LayoutPrefs prefs = LayoutPrefs();

    expect(prefs.withTabMoved(-1, 0), same(prefs));
    expect(prefs.withTabMoved(0, 4), same(prefs));
    expect(prefs.withTabMoved(4, 0), same(prefs));
  });

  test('resetLayout restores the bar and density and keeps the feed tab', () {
    const LayoutPrefs changed = LayoutPrefs(
      tabOrder: <NavTab>[NavTab.collection, NavTab.home, NavTab.search, NavTab.rewards],
      hiddenTabs: <NavTab>{NavTab.search},
      density: WallGridDensity.compact,
      feedTab: HomeFeedChip.latest,
    );

    final LayoutPrefs reset = changed.resetLayout();

    expect(reset, equals(const LayoutPrefs(feedTab: HomeFeedChip.latest)));
    expect(reset.feedTab, HomeFeedChip.latest);
    expect(reset.isDefaultLayout, isTrue);
  });

  test('fromMap repairs an invalid stored copy', () {
    final LayoutPrefs prefs = LayoutPrefs.fromMap(const <Object?, Object?>{
      'tabs': <Object?>['collection', 'bogus', 'home'],
      'hidden': <Object?>['home', 'search', 'rewards'],
      'density': 'huge',
    });

    expect(prefs.tabOrder, <NavTab>[NavTab.collection, NavTab.home, NavTab.search, NavTab.rewards]);
    expect(prefs.hiddenInOrder, <NavTab>[NavTab.search]);
    expect(prefs.density, WallGridDensity.comfortable);
  });

  test('toLayoutMap and fromMap round trip to an equal object', () {
    final LayoutPrefs prefs = const LayoutPrefs(
      tabOrder: <NavTab>[NavTab.rewards, NavTab.home, NavTab.collection, NavTab.search],
      hiddenTabs: <NavTab>{NavTab.collection},
      density: WallGridDensity.large,
    ).copyWith(feedTab: HomeFeedChip.popular);

    final LayoutPrefs restored = LayoutPrefs.fromMap(prefs.toLayoutMap(), feedTab: HomeFeedChip.popular);

    expect(restored, equals(prefs));
  });

  test('WallGridDensity steps one size at a time and stops at the ends', () {
    expect(WallGridDensity.compact.larger, WallGridDensity.comfortable);
    expect(WallGridDensity.large.larger, isNull);
    expect(WallGridDensity.compact.smaller, isNull);
  });
}
