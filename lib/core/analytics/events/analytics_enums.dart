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
  notificationSettingsOpened,
  notificationItemOpened,
  notificationItemDismissed,
  quickActionFollowFeed,
  quickActionCollections,
  quickActionSetups,
  quickActionAiWallpapers,
  quickActionDownloads,
  quickActionUnknown,
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

enum AuthMethodValue { google }

enum NavTabValue { home, search, setups, ai, profile }

enum NotificationPreferenceValue { followers, posts, inApp, recommendations }

enum DeepLinkSourceValue { appLinks, shortLinkResolver }

enum ShareTypeValue { wallpaper, user, setup, refer }

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
