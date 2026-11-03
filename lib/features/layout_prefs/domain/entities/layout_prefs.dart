import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:flutter/foundation.dart';

/// The bottom bar destinations. The order here is the dashboard's route order, which never changes; [LayoutPrefs]
/// only changes the order the bar draws them in.
enum NavTab { home, search, rewards, collection }

/// How big the tiles of every wallpaper grid are. [minColumns] is the phone count, and [tileWidth] adds a column for
/// each extra width step on a tablet or in landscape.
enum WallGridDensity {
  compact(minColumns: 3, tileWidth: 120),
  comfortable(minColumns: 2, tileWidth: 180),
  large(minColumns: 1, tileWidth: 360);

  const WallGridDensity({required this.minColumns, required this.tileWidth});

  final int minColumns;
  final double tileWidth;

  /// Columns for a grid [width] logical pixels wide.
  int columnsFor(double width) => (width / tileWidth).floor().clamp(minColumns, 8);

  /// One step toward bigger tiles, or null at [large].
  WallGridDensity? get larger => index == values.length - 1 ? null : values[index + 1];

  /// One step toward smaller tiles, or null at [compact].
  WallGridDensity? get smaller => index == 0 ? null : values[index - 1];
}

/// The user's layout of the app: the bottom bar, the wallpaper grid, the place of the profile and notifications
/// controls, and the Home feed tab to open on.
///
/// Every value is legal: [tabOrder] holds each [NavTab] once, [hiddenTabs] never holds [NavTab.home], and at least
/// [minVisibleTabs] tabs stay visible. [LayoutPrefs.fromMap] repairs a stored copy that breaks a rule.
@immutable
class LayoutPrefs {
  const LayoutPrefs({
    this.tabOrder = NavTab.values,
    this.hiddenTabs = const <NavTab>{},
    this.density = WallGridDensity.comfortable,
    this.feedTab = HomeFeedChip.forYou,
    this.oneHanded = false,
  });

  static const int minVisibleTabs = 3;

  final List<NavTab> tabOrder;
  final Set<NavTab> hiddenTabs;
  final WallGridDensity density;

  /// The profile and the notifications sit in the bottom bar, in thumb reach, instead of the top bar.
  final bool oneHanded;

  /// The Home feed tab the user saw last. It stays on this device and does not sync.
  final HomeFeedChip feedTab;

  List<NavTab> get visibleTabs => tabOrder.where((tab) => !hiddenTabs.contains(tab)).toList(growable: false);

  /// Hidden tabs in bar order, for the More entry.
  List<NavTab> get hiddenInOrder => tabOrder.where(hiddenTabs.contains).toList(growable: false);

  bool canHide(NavTab tab) => tab != NavTab.home && !hiddenTabs.contains(tab) && visibleTabs.length > minVisibleTabs;

  /// The bar, grid and controls parts equal the defaults. [feedTab] is not a setting, so it does not count.
  bool get isDefaultLayout =>
      listEquals(tabOrder, NavTab.values) && hiddenTabs.isEmpty && density == WallGridDensity.comfortable && !oneHanded;

  /// [tab] shown or hidden. A change that breaks a rule returns this object unchanged.
  LayoutPrefs withTabVisible(NavTab tab, {required bool visible}) {
    if (visible) {
      return hiddenTabs.contains(tab) ? copyWith(hiddenTabs: {...hiddenTabs}..remove(tab)) : this;
    }
    return canHide(tab) ? copyWith(hiddenTabs: {...hiddenTabs, tab}) : this;
  }

  /// The tab at [from] moved to [to], both indexes into [tabOrder] after the move, as in a list reorder.
  LayoutPrefs withTabMoved(int from, int to) {
    if (from == to || from < 0 || to < 0 || from >= tabOrder.length || to >= tabOrder.length) return this;
    final List<NavTab> order = [...tabOrder];
    order.insert(to, order.removeAt(from));
    return copyWith(tabOrder: order);
  }

  /// The bar, grid and controls back to the defaults. The feed tab stays.
  LayoutPrefs resetLayout() => LayoutPrefs(feedTab: feedTab);

  LayoutPrefs copyWith({
    List<NavTab>? tabOrder,
    Set<NavTab>? hiddenTabs,
    WallGridDensity? density,
    HomeFeedChip? feedTab,
    bool? oneHanded,
  }) => LayoutPrefs(
    tabOrder: List<NavTab>.unmodifiable(tabOrder ?? this.tabOrder),
    hiddenTabs: Set<NavTab>.unmodifiable(hiddenTabs ?? this.hiddenTabs),
    density: density ?? this.density,
    feedTab: feedTab ?? this.feedTab,
    oneHanded: oneHanded ?? this.oneHanded,
  );

  /// The synced part: `{tabs, hidden, density}`, plus `oneHanded: true` when it is on. The store adds `changedAt`.
  Map<String, Object> toLayoutMap() => <String, Object>{
    'tabs': [for (final NavTab tab in tabOrder) tab.name],
    'hidden': [for (final NavTab tab in hiddenInOrder) tab.name],
    'density': density.name,
    // Written only when on, so builds without the rules change still accept an off copy.
    if (oneHanded) 'oneHanded': true,
  };

  /// Reads [toLayoutMap] output over [feedTab]. Unknown names are dropped, missing tabs are added at the end, and a
  /// hidden set that breaks a rule shows tabs again until the rules hold.
  factory LayoutPrefs.fromMap(Map<Object?, Object?> raw, {HomeFeedChip feedTab = HomeFeedChip.forYou}) {
    List<NavTab> names(Object? value) => value is List
        ? value.map((name) => NavTab.values.asNameMap()[name]).whereType<NavTab>().toSet().toList()
        : <NavTab>[];
    final List<NavTab> order = names(raw['tabs']);
    for (final NavTab tab in NavTab.values) {
      if (!order.contains(tab)) order.add(tab);
    }
    final List<NavTab> hidden = names(raw['hidden'])..remove(NavTab.home);
    while (NavTab.values.length - hidden.length < minVisibleTabs) {
      hidden.removeLast();
    }
    return LayoutPrefs(
      tabOrder: List<NavTab>.unmodifiable(order),
      hiddenTabs: Set<NavTab>.unmodifiable(hidden),
      density: WallGridDensity.values.asNameMap()[raw['density']] ?? WallGridDensity.comfortable,
      feedTab: feedTab,
      oneHanded: raw['oneHanded'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is LayoutPrefs &&
      listEquals(other.tabOrder, tabOrder) &&
      setEquals(other.hiddenTabs, hiddenTabs) &&
      other.density == density &&
      other.feedTab == feedTab &&
      other.oneHanded == oneHanded;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(tabOrder), Object.hashAllUnordered(hiddenTabs), density, feedTab, oneHanded);
}
