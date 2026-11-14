import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/wallpaper_detail/biz/wall_open_entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final List<({String name, String? below, String? activeTab, WallOpenEntryValue expected})>
  cases = <({String name, String? below, String? activeTab, WallOpenEntryValue expected})>[
    (
      name: 'dashboard home tab',
      below: DashboardRoute.name,
      activeTab: HomeTabRoute.name,
      expected: WallOpenEntryValue.home,
    ),
    (
      name: 'dashboard search tab',
      below: DashboardRoute.name,
      activeTab: SearchTabRoute.name,
      expected: WallOpenEntryValue.search,
    ),
    (
      name: 'dashboard collection tab',
      below: DashboardRoute.name,
      activeTab: CollectionTabRoute.name,
      expected: WallOpenEntryValue.other,
    ),
    (name: 'dashboard without tab', below: DashboardRoute.name, activeTab: null, expected: WallOpenEntryValue.other),
    (name: 'profile', below: ProfileRoute.name, activeTab: null, expected: WallOpenEntryValue.profile),
    (name: 'folder', below: FolderRoute.name, activeTab: null, expected: WallOpenEntryValue.folder),
    (name: 'folders discover', below: FoldersDiscoverRoute.name, activeTab: null, expected: WallOpenEntryValue.folder),
    (name: 'favourites', below: FavouriteWallpaperRoute.name, activeTab: null, expected: WallOpenEntryValue.favourites),
    (name: 'wallpaper detail', below: WallpaperDetailRoute.name, activeTab: null, expected: WallOpenEntryValue.detail),
    (name: 'settings', below: SettingsRoute.name, activeTab: null, expected: WallOpenEntryValue.other),
    (name: 'no page below', below: null, activeTab: null, expected: WallOpenEntryValue.other),
  ];

  group('wallOpenEntry', () {
    for (final c in cases) {
      test(c.name, () {
        expect(wallOpenEntry(below: c.below, activeTab: c.activeTab), c.expected);
      });
    }
  });
}
