import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';

enum WallpaperTargetValue {
  both,
  lock,
  home;

  String get wireValue => _snakeCase(name);
}

enum BinaryResultValue {
  success,
  failure;

  String get wireValue => _snakeCase(name);
}

enum RcOrFallbackValue {
  rcAttempt,
  fallbackOnly,
  rc;

  String get wireValue => _snakeCase(name);
}

enum PaywallResultValue {
  placementOverriddenToV3,
  noOffering,
  notPresented,
  error,
  cancelled,
  purchased,
  restored,
  rcError,
  unknown;

  String get wireValue => _snakeCase(name);

  bool get indicatesPurchase => this == PaywallResultValue.purchased;
}

enum SubscriptionEntitlementRefreshResultValue {
  success,
  failure;

  String get wireValue => _snakeCase(name);
}

enum CoinEarnActionValue {
  rewardedAd,
  dailyLogin,
  streakBonus,
  firstWallpaperUpload,
  referral,
  profileCompletion,
  proDailyBonus,
  refund;

  String get wireValue => _snakeCase(name);
}

enum CoinSpendActionValue {
  wallpaperDownload('wallpaper_download'),
  premiumWallpaperDownload('premium_wallpaper_download'),
  aiGeneration('ai_generation'),
  premiumFilter('premium_filter'),
  premiumPreview24h('premium_preview_24h');

  const CoinSpendActionValue(this.wireValue);

  final String wireValue;
}

enum AiChargeModeValue {
  freeTrial,
  proIncluded,
  coinSpend,
  insufficient;

  String get wireValue => _snakeCase(name);
}

enum SettingValue {
  animeWallpapers,
  sketchyWallpapers,
  recommendationsNotifications;

  String get wireValue => _snakeCase(name);
}

enum AnalyticsActionValue {
  buyPremiumTapped,
  clearCacheTapped,
  restartAppTapped,
  restorePurchaseTapped,
  signInTapped,
  logoutTapped,
  clearFavouriteWallsTapped,
  clearFavouriteWallsConfirmed,
  uploadSheetOpened,
  uploadWallpaperSelected,
  uploadAiSelected,
  notificationSettingsOpened,
  quickActionFollowFeed,
  quickActionCollections,
  quickActionAiWallpapers,
  quickActionDownloads,
  quickActionUnknown,
  backTapped,
  clockOverlayOpened,
  panelOpened,
  panelClosed,
  panelCollapseTapped,
  paletteCycleTapped,
  paletteResetLongPressed,
  followTapped,
  unfollowTapped,
  editProfileTapped,
  openDrawerTapped,
  drawerFavWallsTapped,
  drawerFavSetupsTapped,
  drawerDownloadsTapped,
  drawerSharePrismTapped,
  drawerLogoutTapped,
  openDownloadedWallpaperTapped,
  openTransactionLinkTapped,
  actionChipTapped,
  contributorProfileTapped,
  bannerTapped,
  carouselItemOpened,
  tileOpened,
  seeMoreTapped;

  String get wireValue => _snakeCase(name);
}

enum EventResultValue {
  success,
  failure,
  cancelled,
  blocked,
  navigated,
  empty;

  String get wireValue => _snakeCase(name);
}

enum AnalyticsReasonValue {
  userCancelled,
  error,
  missingData,
  notSignedIn,
  emptyInput,
  unknown;

  String get wireValue => _snakeCase(name);
}

enum SearchProviderValue {
  wallhaven,
  pexels;

  String get wireValue => _snakeCase(name);
}

enum ItemTypeValue {
  wallpaper,
  user;

  String get wireValue => _snakeCase(name);
}

enum TargetTypeValue {
  share,
  user,
  setup,
  refer,
  shortCode,
  unknown;

  String get wireValue => _snakeCase(name);
}

enum EntryPointValue {
  bottomNav;

  String get wireValue => _snakeCase(name);
}

enum LaunchStateValue {
  initialLaunch,
  foreground;

  String get wireValue => _snakeCase(name);
}

enum ShareChannelValue {
  shareSheet,
  link;

  String get wireValue => _snakeCase(name);
}

enum DismissModeValue {
  swipe;

  String get wireValue => _snakeCase(name);
}

enum NotificationTypeValue {
  route,
  externalUrl,
  unknown;

  String get wireValue => _snakeCase(name);
}

enum AuthMethodValue {
  google,
  apple;

  String get wireValue => _snakeCase(name);
}

enum NavTabValue {
  home,
  search,
  streak,
  collection;

  String get wireValue => _snakeCase(name);
}

enum NotificationPreferenceValue {
  followers,
  posts,
  inApp,
  recommendations,
  streakReminders;

  String get wireValue => _snakeCase(name);
}

enum DeepLinkSourceValue {
  appLinks;

  String get wireValue => _snakeCase(name);
}

enum ShareTypeValue {
  wallpaper,
  user,
  setup,
  refer;

  String get wireValue => _snakeCase(name);
}

enum AnalyticsSurfaceValue {
  wallpaperScreen,
  shareWallpaperView,
  shareSetupViewScreen,
  searchWallpaperScreen,
  favouriteWallpaperView,
  profileWallpaperView,
  downloadWallpaperScreen,
  profileScreen,
  profileDrawer,
  profilePrismList,
  aboutScreen,
  coinTransactionsScreen,
  downloadScreen,
  homeWallpaperGrid,
  homeWallhavenGrid,
  homePexelsGrid,
  homeColorGrid,
  homeCollectionsViewGrid,
  favouriteWallsGrid,
  favouriteSetupsGrid;

  String get wireValue => _snakeCase(name);
}

enum ScrollListNameValue {
  wallpaperGrid,
  wallhavenGrid,
  pexelsGrid,
  colorGrid,
  collectionsViewGrid,
  favouriteWallsGrid,
  favouriteSetupsGrid;

  String get wireValue => _snakeCase(name);
}

enum ScrollDepthPercentValue {
  p25,
  p50,
  p75,
  p100;

  String get wireValue => _snakeCase(name);
}

enum LinkDestinationValue {
  github,
  playStore,
  twitter,
  instagram,
  telegram,
  email,
  external;

  String get wireValue => _snakeCase(name);
}

String _snakeCase(String name) => name.replaceAllMapped(RegExp('[A-Z]'), (Match m) => '_${m[0]!.toLowerCase()}');

CoinEarnActionValue coinEarnActionValueFromDomain(CoinEarnAction action) =>
    CoinEarnActionValue.values.byName(action.name);

CoinSpendActionValue coinSpendActionValueFromDomain(CoinSpendAction action) =>
    CoinSpendActionValue.values.byName(action.name);

AiChargeModeValue aiChargeModeValueFromDomain(AiChargeMode mode) => AiChargeModeValue.values.byName(mode.name);

PaywallResultValue paywallResultValueFromSdkName(String rawResult) {
  final PaywallResultValue? result = PaywallResultValue.values.asNameMap()[rawResult.trim()];
  return result ?? PaywallResultValue.unknown;
}
