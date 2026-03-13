import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';

enum WallpaperTargetValue { both, lock, home }

enum BinaryResultValue { success, failure }

enum SubscriptionResultValue { success, notEntitled, failure }

enum RcOrFallbackValue { rcAttempt, fallbackOnly, fallback, rc }

enum PaywallResultValue {
  placementOverriddenToV3,
  noOffering,
  notPresented,
  error,
  cancelled,
  purchased,
  restored,
  rcError,
  unknown,
}

enum SubscriptionEntitlementRefreshResultValue { success, failure }

enum CoinEarnActionValue {
  rewardedAd,
  dailyLogin,
  streakBonus,
  firstWallpaperUpload,
  referral,
  profileCompletion,
  proDailyBonus,
  refund,
}

enum CoinSpendActionValue {
  wallpaperDownload,
  premiumWallpaperDownload,
  aiGeneration,
  premiumFilter,
  premiumPreview24h,
}

enum AiChargeModeValue { freeTrial, proIncluded, coinSpend, insufficient }

enum SettingValue {
  followersFeed,
  animeWallpapers,
  sketchyWallpapers,
  followersNotifications,
  postsNotifications,
  inAppNotifications,
  recommendationsNotifications,
}

enum AnalyticsActionValue {
  buyPremiumTapped,
  clearCacheTapped,
  restartAppTapped,
  signInTapped,
  logoutTapped,
  clearFavouriteWallsTapped,
  clearFavouriteWallsConfirmed,
  clearFavouriteSetupsTapped,
  clearFavouriteSetupsConfirmed,
  nextTapped,
  skipTapped,
  finishTapped,
  uploadSheetOpened,
  uploadWallpaperSelected,
  uploadSetupSelected,
  uploadAiSelected,
  notificationSettingsOpened,
  notificationItemOpened,
  notificationItemDismissed,
  quickActionFollowFeed,
  quickActionCollections,
  quickActionSetups,
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
  drawerBuyPremiumTapped,
  drawerFavWallsTapped,
  drawerFavSetupsTapped,
  drawerDownloadsTapped,
  drawerClearDownloadsTapped,
  drawerClearDownloadsConfirmed,
  drawerReviewStatusTapped,
  drawerEnterCodeTapped,
  drawerSharePrismTapped,
  drawerContactSupportTapped,
  drawerLogoutTapped,
  drawerRestartTapped,
  openThemeTapped,
  openDownloadedWallpaperTapped,
  openTransactionLinkTapped,
  actionChipTapped,
  contributorProfileTapped,
  bannerTapped,
  carouselItemOpened,
  tileOpened,
  seeMoreTapped,
}

enum EventResultValue { success, failure, cancelled, blocked, navigated, ignored, empty }

enum AnalyticsReasonValue {
  userCancelled,
  error,
  missingData,
  notSignedIn,
  alreadySignedIn,
  emptyInput,
  unknown,
  notEligible,
}

enum SearchProviderValue { wallhaven, pexels, user }

enum ItemTypeValue { wallpaper, user, notification }

enum TargetTypeValue { share, user, setup, refer, shortCode, unknown }

enum EntryPointValue { bottomNav, quickAction }

enum LaunchStateValue { initialLaunch, foreground }

enum ShareChannelValue { shareSheet, clipboard, link }

enum DismissModeValue { swipe, clearAll }

enum NotificationTypeValue { route, externalUrl, unknown }

enum AuthMethodValue { google, apple }

enum NavTabValue { home, search, setups, ai, profile }

enum NotificationPreferenceValue { followers, posts, inApp, recommendations, streakReminders }

enum DeepLinkSourceValue { appLinks, shortLinkResolver }

enum ShareTypeValue { wallpaper, user, setup, refer }

enum AnalyticsSurfaceValue {
  wallpaperScreen,
  shareWallpaperView,
  searchWallpaperScreen,
  favouriteWallpaperView,
  profileWallpaperView,
  userProfileWallpaperView,
  downloadWallpaperScreen,
  profileScreen,
  profileDrawer,
  profileUserList,
  profileGeneralList,
  profilePrismList,
  profileAboutList,
  profilePremiumList,
  profileDownloadList,
  aboutScreen,
  coinTransactionsScreen,
  downloadScreen,
  homeWallpaperGrid,
  homeWallhavenGrid,
  homePexelsGrid,
  homeColorGrid,
  homeCollectionsViewGrid,
  followingScreen,
  favouriteWallsGrid,
  favouriteSetupsGrid,
}

enum ScrollListNameValue {
  wallpaperGrid,
  wallhavenGrid,
  pexelsGrid,
  colorGrid,
  collectionsViewGrid,
  followingGrid,
  favouriteWallsGrid,
  favouriteSetupsGrid,
  profileNestedScroll,
}

enum ScrollDepthPercentValue { p25, p50, p75, p100 }

enum LinkDestinationValue { github, playStore, twitter, instagram, telegram, email, external, unknown }

extension WallpaperTargetValueX on WallpaperTargetValue {
  String get wireValue {
    switch (this) {
      case WallpaperTargetValue.both:
        return 'both';
      case WallpaperTargetValue.lock:
        return 'lock';
      case WallpaperTargetValue.home:
        return 'home';
    }
  }
}

extension BinaryResultValueX on BinaryResultValue {
  String get wireValue {
    switch (this) {
      case BinaryResultValue.success:
        return 'success';
      case BinaryResultValue.failure:
        return 'failure';
    }
  }
}

extension SubscriptionResultValueX on SubscriptionResultValue {
  String get wireValue {
    switch (this) {
      case SubscriptionResultValue.success:
        return 'success';
      case SubscriptionResultValue.notEntitled:
        return 'not_entitled';
      case SubscriptionResultValue.failure:
        return 'failure';
    }
  }
}

extension RcOrFallbackValueX on RcOrFallbackValue {
  String get wireValue {
    switch (this) {
      case RcOrFallbackValue.rcAttempt:
        return 'rc_attempt';
      case RcOrFallbackValue.fallbackOnly:
        return 'fallback_only';
      case RcOrFallbackValue.fallback:
        return 'fallback';
      case RcOrFallbackValue.rc:
        return 'rc';
    }
  }
}

extension PaywallResultValueX on PaywallResultValue {
  String get wireValue {
    switch (this) {
      case PaywallResultValue.placementOverriddenToV3:
        return 'placement_overridden_to_v3';
      case PaywallResultValue.noOffering:
        return 'no_offering';
      case PaywallResultValue.notPresented:
        return 'not_presented';
      case PaywallResultValue.error:
        return 'error';
      case PaywallResultValue.cancelled:
        return 'cancelled';
      case PaywallResultValue.purchased:
        return 'purchased';
      case PaywallResultValue.restored:
        return 'restored';
      case PaywallResultValue.rcError:
        return 'rc_error';
      case PaywallResultValue.unknown:
        return 'unknown';
    }
  }
}

extension SubscriptionEntitlementRefreshResultValueX on SubscriptionEntitlementRefreshResultValue {
  String get wireValue {
    switch (this) {
      case SubscriptionEntitlementRefreshResultValue.success:
        return 'success';
      case SubscriptionEntitlementRefreshResultValue.failure:
        return 'failure';
    }
  }
}

extension CoinEarnActionValueX on CoinEarnActionValue {
  String get wireValue {
    switch (this) {
      case CoinEarnActionValue.rewardedAd:
        return 'rewarded_ad';
      case CoinEarnActionValue.dailyLogin:
        return 'daily_login';
      case CoinEarnActionValue.streakBonus:
        return 'streak_bonus';
      case CoinEarnActionValue.firstWallpaperUpload:
        return 'first_wallpaper_upload';
      case CoinEarnActionValue.referral:
        return 'referral';
      case CoinEarnActionValue.profileCompletion:
        return 'profile_completion';
      case CoinEarnActionValue.proDailyBonus:
        return 'pro_daily_bonus';
      case CoinEarnActionValue.refund:
        return 'refund';
    }
  }
}

extension CoinSpendActionValueX on CoinSpendActionValue {
  String get wireValue {
    switch (this) {
      case CoinSpendActionValue.wallpaperDownload:
        return 'wallpaper_download';
      case CoinSpendActionValue.premiumWallpaperDownload:
        return 'premium_wallpaper_download';
      case CoinSpendActionValue.aiGeneration:
        return 'ai_generation';
      case CoinSpendActionValue.premiumFilter:
        return 'premium_filter';
      case CoinSpendActionValue.premiumPreview24h:
        return 'premium_preview_24h';
    }
  }
}

extension AiChargeModeValueX on AiChargeModeValue {
  String get wireValue {
    switch (this) {
      case AiChargeModeValue.freeTrial:
        return 'free_trial';
      case AiChargeModeValue.proIncluded:
        return 'pro_included';
      case AiChargeModeValue.coinSpend:
        return 'coin_spend';
      case AiChargeModeValue.insufficient:
        return 'insufficient';
    }
  }
}

extension SettingValueX on SettingValue {
  String get wireValue {
    switch (this) {
      case SettingValue.followersFeed:
        return 'followers_feed';
      case SettingValue.animeWallpapers:
        return 'anime_wallpapers';
      case SettingValue.sketchyWallpapers:
        return 'sketchy_wallpapers';
      case SettingValue.followersNotifications:
        return 'followers_notifications';
      case SettingValue.postsNotifications:
        return 'posts_notifications';
      case SettingValue.inAppNotifications:
        return 'in_app_notifications';
      case SettingValue.recommendationsNotifications:
        return 'recommendations_notifications';
    }
  }
}

extension AnalyticsActionValueX on AnalyticsActionValue {
  String get wireValue {
    switch (this) {
      case AnalyticsActionValue.buyPremiumTapped:
        return 'buy_premium_tapped';
      case AnalyticsActionValue.clearCacheTapped:
        return 'clear_cache_tapped';
      case AnalyticsActionValue.restartAppTapped:
        return 'restart_app_tapped';
      case AnalyticsActionValue.signInTapped:
        return 'sign_in_tapped';
      case AnalyticsActionValue.logoutTapped:
        return 'logout_tapped';
      case AnalyticsActionValue.clearFavouriteWallsTapped:
        return 'clear_favourite_walls_tapped';
      case AnalyticsActionValue.clearFavouriteWallsConfirmed:
        return 'clear_favourite_walls_confirmed';
      case AnalyticsActionValue.clearFavouriteSetupsTapped:
        return 'clear_favourite_setups_tapped';
      case AnalyticsActionValue.clearFavouriteSetupsConfirmed:
        return 'clear_favourite_setups_confirmed';
      case AnalyticsActionValue.nextTapped:
        return 'next_tapped';
      case AnalyticsActionValue.skipTapped:
        return 'skip_tapped';
      case AnalyticsActionValue.finishTapped:
        return 'finish_tapped';
      case AnalyticsActionValue.uploadSheetOpened:
        return 'upload_sheet_opened';
      case AnalyticsActionValue.uploadWallpaperSelected:
        return 'upload_wallpaper_selected';
      case AnalyticsActionValue.uploadSetupSelected:
        return 'upload_setup_selected';
      case AnalyticsActionValue.uploadAiSelected:
        return 'upload_ai_selected';
      case AnalyticsActionValue.notificationSettingsOpened:
        return 'notification_settings_opened';
      case AnalyticsActionValue.notificationItemOpened:
        return 'notification_item_opened';
      case AnalyticsActionValue.notificationItemDismissed:
        return 'notification_item_dismissed';
      case AnalyticsActionValue.quickActionFollowFeed:
        return 'quick_action_follow_feed';
      case AnalyticsActionValue.quickActionCollections:
        return 'quick_action_collections';
      case AnalyticsActionValue.quickActionSetups:
        return 'quick_action_setups';
      case AnalyticsActionValue.quickActionAiWallpapers:
        return 'quick_action_ai_wallpapers';
      case AnalyticsActionValue.quickActionDownloads:
        return 'quick_action_downloads';
      case AnalyticsActionValue.quickActionUnknown:
        return 'quick_action_unknown';
      case AnalyticsActionValue.backTapped:
        return 'back_tapped';
      case AnalyticsActionValue.clockOverlayOpened:
        return 'clock_overlay_opened';
      case AnalyticsActionValue.panelOpened:
        return 'panel_opened';
      case AnalyticsActionValue.panelClosed:
        return 'panel_closed';
      case AnalyticsActionValue.panelCollapseTapped:
        return 'panel_collapse_tapped';
      case AnalyticsActionValue.paletteCycleTapped:
        return 'palette_cycle_tapped';
      case AnalyticsActionValue.paletteResetLongPressed:
        return 'palette_reset_long_pressed';
      case AnalyticsActionValue.followTapped:
        return 'follow_tapped';
      case AnalyticsActionValue.unfollowTapped:
        return 'unfollow_tapped';
      case AnalyticsActionValue.editProfileTapped:
        return 'edit_profile_tapped';
      case AnalyticsActionValue.openDrawerTapped:
        return 'open_drawer_tapped';
      case AnalyticsActionValue.drawerBuyPremiumTapped:
        return 'drawer_buy_premium_tapped';
      case AnalyticsActionValue.drawerFavWallsTapped:
        return 'drawer_fav_walls_tapped';
      case AnalyticsActionValue.drawerFavSetupsTapped:
        return 'drawer_fav_setups_tapped';
      case AnalyticsActionValue.drawerDownloadsTapped:
        return 'drawer_downloads_tapped';
      case AnalyticsActionValue.drawerClearDownloadsTapped:
        return 'drawer_clear_downloads_tapped';
      case AnalyticsActionValue.drawerClearDownloadsConfirmed:
        return 'drawer_clear_downloads_confirmed';
      case AnalyticsActionValue.drawerReviewStatusTapped:
        return 'drawer_review_status_tapped';
      case AnalyticsActionValue.drawerEnterCodeTapped:
        return 'drawer_enter_code_tapped';
      case AnalyticsActionValue.drawerSharePrismTapped:
        return 'drawer_share_prism_tapped';
      case AnalyticsActionValue.drawerContactSupportTapped:
        return 'drawer_contact_support_tapped';
      case AnalyticsActionValue.drawerLogoutTapped:
        return 'drawer_logout_tapped';
      case AnalyticsActionValue.drawerRestartTapped:
        return 'drawer_restart_tapped';
      case AnalyticsActionValue.openThemeTapped:
        return 'open_theme_tapped';
      case AnalyticsActionValue.openDownloadedWallpaperTapped:
        return 'open_downloaded_wallpaper_tapped';
      case AnalyticsActionValue.openTransactionLinkTapped:
        return 'open_transaction_link_tapped';
      case AnalyticsActionValue.actionChipTapped:
        return 'action_chip_tapped';
      case AnalyticsActionValue.contributorProfileTapped:
        return 'contributor_profile_tapped';
      case AnalyticsActionValue.bannerTapped:
        return 'banner_tapped';
      case AnalyticsActionValue.carouselItemOpened:
        return 'carousel_item_opened';
      case AnalyticsActionValue.tileOpened:
        return 'tile_opened';
      case AnalyticsActionValue.seeMoreTapped:
        return 'see_more_tapped';
    }
  }
}

extension EventResultValueX on EventResultValue {
  String get wireValue {
    switch (this) {
      case EventResultValue.success:
        return 'success';
      case EventResultValue.failure:
        return 'failure';
      case EventResultValue.cancelled:
        return 'cancelled';
      case EventResultValue.blocked:
        return 'blocked';
      case EventResultValue.navigated:
        return 'navigated';
      case EventResultValue.ignored:
        return 'ignored';
      case EventResultValue.empty:
        return 'empty';
    }
  }
}

extension AnalyticsReasonValueX on AnalyticsReasonValue {
  String get wireValue {
    switch (this) {
      case AnalyticsReasonValue.userCancelled:
        return 'user_cancelled';
      case AnalyticsReasonValue.error:
        return 'error';
      case AnalyticsReasonValue.missingData:
        return 'missing_data';
      case AnalyticsReasonValue.notSignedIn:
        return 'not_signed_in';
      case AnalyticsReasonValue.alreadySignedIn:
        return 'already_signed_in';
      case AnalyticsReasonValue.emptyInput:
        return 'empty_input';
      case AnalyticsReasonValue.unknown:
        return 'unknown';
      case AnalyticsReasonValue.notEligible:
        return 'not_eligible';
    }
  }
}

extension SearchProviderValueX on SearchProviderValue {
  String get wireValue {
    switch (this) {
      case SearchProviderValue.wallhaven:
        return 'wallhaven';
      case SearchProviderValue.pexels:
        return 'pexels';
      case SearchProviderValue.user:
        return 'user';
    }
  }
}

extension ItemTypeValueX on ItemTypeValue {
  String get wireValue {
    switch (this) {
      case ItemTypeValue.wallpaper:
        return 'wallpaper';
      case ItemTypeValue.user:
        return 'user';
      case ItemTypeValue.notification:
        return 'notification';
    }
  }
}

extension TargetTypeValueX on TargetTypeValue {
  String get wireValue {
    switch (this) {
      case TargetTypeValue.share:
        return 'share';
      case TargetTypeValue.user:
        return 'user';
      case TargetTypeValue.setup:
        return 'setup';
      case TargetTypeValue.refer:
        return 'refer';
      case TargetTypeValue.shortCode:
        return 'short_code';
      case TargetTypeValue.unknown:
        return 'unknown';
    }
  }
}

extension EntryPointValueX on EntryPointValue {
  String get wireValue {
    switch (this) {
      case EntryPointValue.bottomNav:
        return 'bottom_nav';
      case EntryPointValue.quickAction:
        return 'quick_action';
    }
  }
}

extension LaunchStateValueX on LaunchStateValue {
  String get wireValue {
    switch (this) {
      case LaunchStateValue.initialLaunch:
        return 'initial_launch';
      case LaunchStateValue.foreground:
        return 'foreground';
    }
  }
}

extension ShareChannelValueX on ShareChannelValue {
  String get wireValue {
    switch (this) {
      case ShareChannelValue.shareSheet:
        return 'share_sheet';
      case ShareChannelValue.clipboard:
        return 'clipboard';
      case ShareChannelValue.link:
        return 'link';
    }
  }
}

extension DismissModeValueX on DismissModeValue {
  String get wireValue {
    switch (this) {
      case DismissModeValue.swipe:
        return 'swipe';
      case DismissModeValue.clearAll:
        return 'clear_all';
    }
  }
}

extension NotificationTypeValueX on NotificationTypeValue {
  String get wireValue {
    switch (this) {
      case NotificationTypeValue.route:
        return 'route';
      case NotificationTypeValue.externalUrl:
        return 'external_url';
      case NotificationTypeValue.unknown:
        return 'unknown';
    }
  }
}

extension AuthMethodValueX on AuthMethodValue {
  String get wireValue {
    switch (this) {
      case AuthMethodValue.google:
        return 'google';
      case AuthMethodValue.apple:
        return 'apple';
    }
  }
}

extension NavTabValueX on NavTabValue {
  String get wireValue {
    switch (this) {
      case NavTabValue.home:
        return 'home';
      case NavTabValue.search:
        return 'search';
      case NavTabValue.setups:
        return 'setups';
      case NavTabValue.ai:
        return 'ai';
      case NavTabValue.profile:
        return 'profile';
    }
  }
}

extension NotificationPreferenceValueX on NotificationPreferenceValue {
  String get wireValue {
    switch (this) {
      case NotificationPreferenceValue.followers:
        return 'followers';
      case NotificationPreferenceValue.posts:
        return 'posts';
      case NotificationPreferenceValue.inApp:
        return 'in_app';
      case NotificationPreferenceValue.recommendations:
        return 'recommendations';
      case NotificationPreferenceValue.streakReminders:
        return 'streak_reminders';
    }
  }
}

extension DeepLinkSourceValueX on DeepLinkSourceValue {
  String get wireValue {
    switch (this) {
      case DeepLinkSourceValue.appLinks:
        return 'app_links';
      case DeepLinkSourceValue.shortLinkResolver:
        return 'short_link_resolver';
    }
  }
}

extension ShareTypeValueX on ShareTypeValue {
  String get wireValue {
    switch (this) {
      case ShareTypeValue.wallpaper:
        return 'wallpaper';
      case ShareTypeValue.user:
        return 'user';
      case ShareTypeValue.setup:
        return 'setup';
      case ShareTypeValue.refer:
        return 'refer';
    }
  }
}

extension AnalyticsSurfaceValueX on AnalyticsSurfaceValue {
  String get wireValue {
    switch (this) {
      case AnalyticsSurfaceValue.wallpaperScreen:
        return 'wallpaper_screen';
      case AnalyticsSurfaceValue.shareWallpaperView:
        return 'share_wallpaper_view';
      case AnalyticsSurfaceValue.searchWallpaperScreen:
        return 'search_wallpaper_screen';
      case AnalyticsSurfaceValue.favouriteWallpaperView:
        return 'favourite_wallpaper_view';
      case AnalyticsSurfaceValue.profileWallpaperView:
        return 'profile_wallpaper_view';
      case AnalyticsSurfaceValue.userProfileWallpaperView:
        return 'user_profile_wallpaper_view';
      case AnalyticsSurfaceValue.downloadWallpaperScreen:
        return 'download_wallpaper_screen';
      case AnalyticsSurfaceValue.profileScreen:
        return 'profile_screen';
      case AnalyticsSurfaceValue.profileDrawer:
        return 'profile_drawer';
      case AnalyticsSurfaceValue.profileUserList:
        return 'profile_user_list';
      case AnalyticsSurfaceValue.profileGeneralList:
        return 'profile_general_list';
      case AnalyticsSurfaceValue.profilePrismList:
        return 'profile_prism_list';
      case AnalyticsSurfaceValue.profileAboutList:
        return 'profile_about_list';
      case AnalyticsSurfaceValue.profilePremiumList:
        return 'profile_premium_list';
      case AnalyticsSurfaceValue.profileDownloadList:
        return 'profile_download_list';
      case AnalyticsSurfaceValue.aboutScreen:
        return 'about_screen';
      case AnalyticsSurfaceValue.coinTransactionsScreen:
        return 'coin_transactions_screen';
      case AnalyticsSurfaceValue.downloadScreen:
        return 'download_screen';
      case AnalyticsSurfaceValue.homeWallpaperGrid:
        return 'home_wallpaper_grid';
      case AnalyticsSurfaceValue.homeWallhavenGrid:
        return 'home_wallhaven_grid';
      case AnalyticsSurfaceValue.homePexelsGrid:
        return 'home_pexels_grid';
      case AnalyticsSurfaceValue.homeColorGrid:
        return 'home_color_grid';
      case AnalyticsSurfaceValue.homeCollectionsViewGrid:
        return 'home_collections_view_grid';
      case AnalyticsSurfaceValue.followingScreen:
        return 'following_screen';
      case AnalyticsSurfaceValue.favouriteWallsGrid:
        return 'favourite_walls_grid';
      case AnalyticsSurfaceValue.favouriteSetupsGrid:
        return 'favourite_setups_grid';
    }
  }
}

extension ScrollListNameValueX on ScrollListNameValue {
  String get wireValue {
    switch (this) {
      case ScrollListNameValue.wallpaperGrid:
        return 'wallpaper_grid';
      case ScrollListNameValue.wallhavenGrid:
        return 'wallhaven_grid';
      case ScrollListNameValue.pexelsGrid:
        return 'pexels_grid';
      case ScrollListNameValue.colorGrid:
        return 'color_grid';
      case ScrollListNameValue.collectionsViewGrid:
        return 'collections_view_grid';
      case ScrollListNameValue.followingGrid:
        return 'following_grid';
      case ScrollListNameValue.favouriteWallsGrid:
        return 'favourite_walls_grid';
      case ScrollListNameValue.favouriteSetupsGrid:
        return 'favourite_setups_grid';
      case ScrollListNameValue.profileNestedScroll:
        return 'profile_nested_scroll';
    }
  }
}

extension ScrollDepthPercentValueX on ScrollDepthPercentValue {
  String get wireValue {
    switch (this) {
      case ScrollDepthPercentValue.p25:
        return 'p25';
      case ScrollDepthPercentValue.p50:
        return 'p50';
      case ScrollDepthPercentValue.p75:
        return 'p75';
      case ScrollDepthPercentValue.p100:
        return 'p100';
    }
  }
}

extension LinkDestinationValueX on LinkDestinationValue {
  String get wireValue {
    switch (this) {
      case LinkDestinationValue.github:
        return 'github';
      case LinkDestinationValue.playStore:
        return 'play_store';
      case LinkDestinationValue.twitter:
        return 'twitter';
      case LinkDestinationValue.instagram:
        return 'instagram';
      case LinkDestinationValue.telegram:
        return 'telegram';
      case LinkDestinationValue.email:
        return 'email';
      case LinkDestinationValue.external:
        return 'external';
      case LinkDestinationValue.unknown:
        return 'unknown';
    }
  }
}

CoinEarnActionValue coinEarnActionValueFromDomain(CoinEarnAction action) {
  switch (action) {
    case CoinEarnAction.rewardedAd:
      return CoinEarnActionValue.rewardedAd;
    case CoinEarnAction.dailyLogin:
      return CoinEarnActionValue.dailyLogin;
    case CoinEarnAction.streakBonus:
      return CoinEarnActionValue.streakBonus;
    case CoinEarnAction.firstWallpaperUpload:
      return CoinEarnActionValue.firstWallpaperUpload;
    case CoinEarnAction.referral:
      return CoinEarnActionValue.referral;
    case CoinEarnAction.profileCompletion:
      return CoinEarnActionValue.profileCompletion;
    case CoinEarnAction.proDailyBonus:
      return CoinEarnActionValue.proDailyBonus;
    case CoinEarnAction.refund:
      return CoinEarnActionValue.refund;
  }
}

CoinSpendActionValue coinSpendActionValueFromDomain(CoinSpendAction action) {
  switch (action) {
    case CoinSpendAction.wallpaperDownload:
      return CoinSpendActionValue.wallpaperDownload;
    case CoinSpendAction.premiumWallpaperDownload:
      return CoinSpendActionValue.premiumWallpaperDownload;
    case CoinSpendAction.aiGeneration:
      return CoinSpendActionValue.aiGeneration;
    case CoinSpendAction.premiumFilter:
      return CoinSpendActionValue.premiumFilter;
    case CoinSpendAction.premiumPreview24h:
      return CoinSpendActionValue.premiumPreview24h;
  }
}

AiChargeModeValue aiChargeModeValueFromDomain(AiChargeMode mode) {
  switch (mode) {
    case AiChargeMode.freeTrial:
      return AiChargeModeValue.freeTrial;
    case AiChargeMode.proIncluded:
      return AiChargeModeValue.proIncluded;
    case AiChargeMode.coinSpend:
      return AiChargeModeValue.coinSpend;
    case AiChargeMode.insufficient:
      return AiChargeModeValue.insufficient;
  }
}

PaywallResultValue paywallResultValueFromSdkName(String rawResult) {
  switch (rawResult.trim()) {
    case 'notPresented':
      return PaywallResultValue.notPresented;
    case 'error':
      return PaywallResultValue.error;
    case 'cancelled':
      return PaywallResultValue.cancelled;
    case 'purchased':
      return PaywallResultValue.purchased;
    case 'restored':
      return PaywallResultValue.restored;
    default:
      return PaywallResultValue.unknown;
  }
}
