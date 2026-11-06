import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fromMap repairs missing or wrongly typed tab lists', () {
    for (final raw in <Map<Object?, Object?>>[
      {},
      {'tabs': false, 'hidden': 'search'},
    ]) {
      expect(LayoutPrefs.fromMap(raw), const LayoutPrefs());
    }
  });

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

  test('oneHanded defaults to off and is not synced until it is on', () {
    const LayoutPrefs prefs = LayoutPrefs();

    expect(prefs.oneHanded, isFalse);
    expect(prefs.toLayoutMap().containsKey('oneHanded'), isFalse);
  });

  test('copyWith oneHanded is written to the synced map', () {
    expect(const LayoutPrefs().copyWith(oneHanded: true).toLayoutMap()['oneHanded'], isTrue);
  });

  test('fromMap reads oneHanded only when it is true', () {
    const Map<Object?, Object?> map = <Object?, Object?>{};

    expect(LayoutPrefs.fromMap(const {'oneHanded': true}).oneHanded, isTrue);
    expect(LayoutPrefs.fromMap(const {'oneHanded': 'yes'}).oneHanded, isFalse);
    expect(LayoutPrefs.fromMap(map).oneHanded, isFalse);
  });

  test('toLayoutMap and fromMap round trip oneHanded', () {
    final LayoutPrefs prefs = const LayoutPrefs().copyWith(oneHanded: true);

    expect(LayoutPrefs.fromMap(prefs.toLayoutMap()), equals(prefs));
  });

  test('oneHanded makes the layout non-default, and resetLayout turns it off', () {
    final LayoutPrefs prefs = const LayoutPrefs().copyWith(oneHanded: true);

    expect(prefs.isDefaultLayout, isFalse);
    expect(prefs.resetLayout().oneHanded, isFalse);
  });

  test('prefs that differ only in oneHanded are not equal', () {
    expect(const LayoutPrefs().copyWith(oneHanded: true), isNot(equals(const LayoutPrefs())));
  });

  test('followingRow is on by default and reads as off only when stored off', () {
    expect(const LayoutPrefs().followingRow, isTrue);
    expect(LayoutPrefs.fromMap(const <Object?, Object?>{}).followingRow, isTrue);
    expect(LayoutPrefs.fromMap(const {'followingRow': false}).followingRow, isFalse);
  });

  test('toLayoutMap leaves followingRow out when on and writes false when off', () {
    expect(const LayoutPrefs().toLayoutMap().containsKey('followingRow'), isFalse);
    expect(const LayoutPrefs(followingRow: false).toLayoutMap()['followingRow'], isFalse);
  });

  test('followingRow off makes the layout non-default, and resetLayout turns it on', () {
    final LayoutPrefs prefs = const LayoutPrefs().copyWith(followingRow: false);

    expect(prefs.isDefaultLayout, isFalse);
    expect(prefs.resetLayout().followingRow, isTrue);
  });

  test('WallGridDensity steps one size at a time and stops at the ends', () {
    expect(WallGridDensity.compact.larger, WallGridDensity.comfortable);
    expect(WallGridDensity.large.larger, isNull);
    expect(WallGridDensity.compact.smaller, isNull);
  });
}
