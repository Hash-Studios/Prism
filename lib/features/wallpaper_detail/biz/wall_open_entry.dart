import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';

/// Where a wall detail page was opened from, for the wall open failure event (#557).
typedef WallOpenOrigin = ({WallOpenEntryValue entry, HomeFeedChip? homeTab});

const WallOpenOrigin unknownWallOpenOrigin = (entry: WallOpenEntryValue.other, homeTab: null);

/// The entry point, read off the root router: the page under the detail page, or the dashboard's active tab when
/// that page is the dashboard. Links say so themselves, because they open over any page.
WallOpenEntryValue wallOpenEntry({required String? below, String? activeTab}) => switch (below) {
  DashboardRoute.name => switch (activeTab) {
    HomeTabRoute.name => WallOpenEntryValue.home,
    SearchTabRoute.name => WallOpenEntryValue.search,
    _ => WallOpenEntryValue.other,
  },
  ProfileRoute.name => WallOpenEntryValue.profile,
  FolderRoute.name || FoldersDiscoverRoute.name => WallOpenEntryValue.folder,
  FavouriteWallpaperRoute.name => WallOpenEntryValue.favourites,
  WallpaperDetailRoute.name => WallOpenEntryValue.detail,
  _ => WallOpenEntryValue.other,
};
