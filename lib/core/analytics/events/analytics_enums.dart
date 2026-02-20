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
