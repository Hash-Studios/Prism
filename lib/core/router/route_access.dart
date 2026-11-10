import 'package:Prism/core/router/app_router.dart';

/// Who can open a route. `PlatformAccountGuard` reads [routeAccess] for guarded stack navigation.
enum RouteAccess {
  /// Anyone, also a signed-out Android user: startup, sign-in and legal pages.
  open,

  /// Guests can view it where guest browsing is allowed (iOS). The content is public; actions on it still ask for
  /// sign-in with `requireSignedInAction`.
  public,

  /// Any signed-in account.
  account,

  /// The signed-in user's own data. The guard needs an account; the rules and the page check the owner.
  owner,

  /// Admins only. The route also keeps its `AdminGuard`.
  admin,
}

/// The access rule of every page route in [AppRouter], by route name. A route that is not here needs an account, and
/// `test/core/router/route_access_test.dart` fails until it gets a row.
///
/// "Needs rules change" rows show public content, but firestore.rules lets only signed-in users read it. Make them
/// [RouteAccess.public] only after the rules let a signed-out user read that content.
const Map<String, RouteAccess> routeAccess = <String, RouteAccess>{
  SplashWidgetRoute.name: RouteAccess.open,
  OnboardingV2ShellRoute.name: RouteAccess.open,
  AboutRoute.name: RouteAccess.open,
  NotFoundRoute.name: RouteAccess.open,

  DashboardRoute.name: RouteAccess.public,
  HomeTabRoute.name: RouteAccess.public,
  SearchTabRoute.name: RouteAccess.public,
  SearchRoute.name: RouteAccess.public,
  CollectionTabRoute.name: RouteAccess.public,
  WallpaperDetailRoute.name: RouteAccess.public,
  WotdArchiveRoute.name: RouteAccess.public,
  ShareInRoute.name: RouteAccess.public,
  PremiumRoute.name: RouteAccess.public,
  ClockPreviewRoute.name: RouteAccess.public,
  SettingsRoute.name: RouteAccess.public,
  LayoutSettingsRoute.name: RouteAccess.public,
  ThemeViewRoute.name: RouteAccess.public,
  CollectionViewRoute.name: RouteAccess.public,
  MoodRoute.name: RouteAccess.public,
  EditorsChoiceRoute.name: RouteAccess.public,
  GalleryRoute.name: RouteAccess.public,
  WallRequestsRoute.name: RouteAccess.public,
  WeeklyChallengeRoute.name: RouteAccess.public,
  DropsRoute.name: RouteAccess.public,
  DropDetailRoute.name: RouteAccess.public,
  DropPreviewRoute.name: RouteAccess.public,
  // Needs rules change: profiles needs sign-in, so both pages show their own sign-in prompt to a guest.
  UserSearchRoute.name: RouteAccess.public,
  ProfileRoute.name: RouteAccess.public,

  // Needs rules change: profiles/*/followers and profiles/*/following need sign-in.
  FollowersRoute.name: RouteAccess.account,
  FollowingListRoute.name: RouteAccess.account,
  // Needs rules change: creatorDirectory needs sign-in.
  CreatorsRoute.name: RouteAccess.account,
  // Needs rules change: folderTrending and publicFolders need sign-in.
  FoldersDiscoverRoute.name: RouteAccess.account,
  FolderInviteRoute.name: RouteAccess.account,
  AiTabRoute.name: RouteAccess.account,
  DownloadWallpaperRoute.name: RouteAccess.account,
  WallpaperFilterRoute.name: RouteAccess.account,
  DeepLinkInputRoute.name: RouteAccess.account,
  ReviewPhotoPreviewRoute.name: RouteAccess.account,
  UploadWallRoute.name: RouteAccess.account,
  QuickTileSettingsRoute.name: RouteAccess.account,
  AutoRotateRoute.name: RouteAccess.account,
  IosShortcutsGuideRoute.name: RouteAccess.account,
  WallpaperPositionRoute.name: RouteAccess.account,
  LiveWallpaperRoute.name: RouteAccess.account,
  DailyMomentRoute.name: RouteAccess.account,
  DailyChestRoute.name: RouteAccess.account,
  SpinWheelRoute.name: RouteAccess.account,
  ShopRoute.name: RouteAccess.account,
  LeaderboardRoute.name: RouteAccess.account,
  DrawRoute.name: RouteAccess.account,

  // Needs rules change for a public folder: publicFolders needs sign-in. A private folder stays owner or member only.
  FolderRoute.name: RouteAccess.owner,
  RewardsTabRoute.name: RouteAccess.owner,
  RewardsRoute.name: RouteAccess.owner,
  CoinHistoryRoute.name: RouteAccess.owner,
  EditProfilePanelRoute.name: RouteAccess.owner,
  SharePrismRoute.name: RouteAccess.owner,
  BlockedAccountsRoute.name: RouteAccess.owner,
  FavouriteWallpaperRoute.name: RouteAccess.owner,
  DownloadRoute.name: RouteAccess.owner,
  LibraryRoute.name: RouteAccess.owner,
  EditWallRoute.name: RouteAccess.owner,
  CreatorStatsRoute.name: RouteAccess.owner,
  ReviewRoute.name: RouteAccess.owner,
  NotificationRoute.name: RouteAccess.owner,
  PrismWrappedRoute.name: RouteAccess.owner,

  AdminReviewRoute.name: RouteAccess.admin,
  SwipeReviewRoute.name: RouteAccess.admin,
  FullScreenImageRoute.name: RouteAccess.admin,
  FirestoreTelemetryRoute.name: RouteAccess.admin,
  PromoCodesAdminRoute.name: RouteAccess.admin,
  DebugPanelRoute.name: RouteAccess.admin,
};
