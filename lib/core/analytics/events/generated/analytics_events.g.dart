// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Run: dart run tool/generate_analytics_schema.dart

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';

class ReportSetupEvent extends AnalyticsEvent {
  const ReportSetupEvent();

  @override
  String get eventName => 'report_setup';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class ReportWallEvent extends AnalyticsEvent {
  const ReportWallEvent();

  @override
  String get eventName => 'report_wall';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class SetupFavStatusChangedEvent extends AnalyticsEvent {
  const SetupFavStatusChangedEvent({required this.setupId});

  final String setupId;

  @override
  String get eventName => 'setup_fav_status_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'id': setupId};
  }
}

class DownloadOwnSetupEvent extends AnalyticsEvent {
  const DownloadOwnSetupEvent({required this.link});

  final String link;

  @override
  String get eventName => 'download_own_setup';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'link': link};
  }
}

class DownloadOwnWallEvent extends AnalyticsEvent {
  const DownloadOwnWallEvent({required this.link});

  final String link;

  @override
  String get eventName => 'download_own_wall';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'link': link};
  }
}

class SetWallEvent extends AnalyticsEvent {
  const SetWallEvent({required this.wallpaperTarget, required this.result});

  final WallpaperTargetValue wallpaperTarget;
  final BinaryResultValue result;

  @override
  String get eventName => 'set_wall';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wallpaper_target': wallpaperTarget.wireValue, 'result': result.wireValue};
  }
}

class CoinPremiumFilterSpendAttemptEvent extends AnalyticsEvent {
  const CoinPremiumFilterSpendAttemptEvent({required this.sourceTag, required this.filter});

  final String sourceTag;
  final String filter;

  @override
  String get eventName => 'coin_premium_filter_spend_attempt';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_tag': sourceTag, 'filter': filter};
  }
}

class CoinPremiumFilterSpendSuccessEvent extends AnalyticsEvent {
  const CoinPremiumFilterSpendSuccessEvent({required this.sourceTag, required this.coinsSpent, required this.filter});

  final String sourceTag;
  final int coinsSpent;
  final String filter;

  @override
  String get eventName => 'coin_premium_filter_spend_success';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_tag': sourceTag, 'coins_spent': coinsSpent, 'filter': filter};
  }
}

class CoinFilterWatchAndRetryUsedEvent extends AnalyticsEvent {
  const CoinFilterWatchAndRetryUsedEvent({required this.sourceTag, required this.filter});

  final String sourceTag;
  final String filter;

  @override
  String get eventName => 'coin_filter_watch_and_retry_used';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_tag': sourceTag, 'filter': filter};
  }
}

class DownloadWallpaperEvent extends AnalyticsEvent {
  const DownloadWallpaperEvent({required this.link, this.sourceContext, this.premiumContent});

  final String link;
  final String? sourceContext;
  final bool? premiumContent;

  @override
  String get eventName => 'download_wallpaper';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'link': link,
      if (sourceContext != null) 'source_context': sourceContext,
      if (premiumContent != null) 'premium_content': premiumContent,
    };
  }
}

class UploadWallpaperEvent extends AnalyticsEvent {
  const UploadWallpaperEvent({required this.assetId, required this.link});

  final String assetId;
  final String link;

  @override
  String get eventName => 'upload_wallpaper';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'id': assetId, 'link': link};
  }
}

class AccentChangedEvent extends AnalyticsEvent {
  const AccentChangedEvent({required this.color});

  final String color;

  @override
  String get eventName => 'accent_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'color': color};
  }
}

class PaywallImpressionEvent extends AnalyticsEvent {
  const PaywallImpressionEvent({required this.source, required this.placement, required this.rcOrFallback});

  final String source;
  final String placement;
  final RcOrFallbackValue rcOrFallback;

  @override
  String get eventName => 'paywall_impression';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'placement': placement, 'rc_or_fallback': rcOrFallback.wireValue};
  }
}

class PaywallResultEvent extends AnalyticsEvent {
  const PaywallResultEvent({
    required this.source,
    required this.placement,
    required this.result,
    required this.rcOrFallback,
    this.placementOffering,
    this.selectedOffering,
    this.entitlementSynced,
    this.entitlement,
    this.error,
  });

  final String source;
  final String placement;
  final PaywallResultValue result;
  final RcOrFallbackValue rcOrFallback;
  final String? placementOffering;
  final String? selectedOffering;
  final int? entitlementSynced;
  final String? entitlement;
  final String? error;

  @override
  String get eventName => 'paywall_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source': source,
      'placement': placement,
      'result': result.wireValue,
      'rc_or_fallback': rcOrFallback.wireValue,
      if (placementOffering != null) 'placement_offering': placementOffering,
      if (selectedOffering != null) 'selected_offering': selectedOffering,
      if (entitlementSynced != null) 'entitlement_synced': entitlementSynced,
      if (entitlement != null) 'entitlement': entitlement,
      if (error != null) 'error': error,
    };
  }
}

class SubscriptionTriggerLowBalanceEvent extends AnalyticsEvent {
  const SubscriptionTriggerLowBalanceEvent({required this.source, required this.placement});

  final String source;
  final String placement;

  @override
  String get eventName => 'subscription_trigger_low_balance';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'placement': placement};
  }
}

class SubscriptionTriggerAfterAdWatch3Event extends AnalyticsEvent {
  const SubscriptionTriggerAfterAdWatch3Event({required this.source, required this.placement});

  final String source;
  final String placement;

  @override
  String get eventName => 'subscription_trigger_after_ad_watch_3';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'placement': placement};
  }
}

class SubscriptionTriggerSetupCreateBlockEvent extends AnalyticsEvent {
  const SubscriptionTriggerSetupCreateBlockEvent({required this.source, required this.placement});

  final String source;
  final String placement;

  @override
  String get eventName => 'subscription_trigger_setup_create_block';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'placement': placement};
  }
}

class SubscriptionTriggerUploadLimitBlockEvent extends AnalyticsEvent {
  const SubscriptionTriggerUploadLimitBlockEvent({required this.source, required this.placement});

  final String source;
  final String placement;

  @override
  String get eventName => 'subscription_trigger_upload_limit_block';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'placement': placement};
  }
}

class SubscriptionPackageSelectedEvent extends AnalyticsEvent {
  const SubscriptionPackageSelectedEvent({
    required this.source,
    required this.productId,
    required this.packageType,
    required this.price,
    required this.currency,
  });

  final String source;
  final String productId;
  final String packageType;
  final num price;
  final String currency;

  @override
  String get eventName => 'subscription_package_selected';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source': source,
      'product_id': productId,
      'package_type': packageType,
      'price': price,
      'currency': currency,
    };
  }
}

class SubscriptionRestoreStartedEvent extends AnalyticsEvent {
  const SubscriptionRestoreStartedEvent({required this.source});

  final String source;

  @override
  String get eventName => 'subscription_restore_started';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source};
  }
}

class SubscriptionRestoreResultEvent extends AnalyticsEvent {
  const SubscriptionRestoreResultEvent({required this.source, required this.result, this.errorCode, this.errorMessage});

  final String source;
  final SubscriptionResultValue result;
  final String? errorCode;
  final String? errorMessage;

  @override
  String get eventName => 'subscription_restore_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source': source,
      'result': result.wireValue,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }
}

class SubscriptionPurchaseStartedEvent extends AnalyticsEvent {
  const SubscriptionPurchaseStartedEvent({
    required this.source,
    required this.productId,
    required this.packageType,
    required this.price,
    required this.currency,
  });

  final String source;
  final String productId;
  final String packageType;
  final num price;
  final String currency;

  @override
  String get eventName => 'subscription_purchase_started';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source': source,
      'product_id': productId,
      'package_type': packageType,
      'price': price,
      'currency': currency,
    };
  }
}

class SubscriptionPurchaseResultEvent extends AnalyticsEvent {
  const SubscriptionPurchaseResultEvent({
    required this.source,
    required this.productId,
    required this.packageType,
    required this.result,
    this.errorCode,
    this.errorMessage,
  });

  final String source;
  final String productId;
  final String packageType;
  final SubscriptionResultValue result;
  final String? errorCode;
  final String? errorMessage;

  @override
  String get eventName => 'subscription_purchase_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source': source,
      'product_id': productId,
      'package_type': packageType,
      'result': result.wireValue,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }
}

class SubscriptionEntitlementRefreshEvent extends AnalyticsEvent {
  const SubscriptionEntitlementRefreshEvent({
    required this.result,
    this.subscriptionTier,
    this.isPremium,
    this.activeEntitlements,
    this.errorCode,
    this.errorMessage,
  });

  final SubscriptionEntitlementRefreshResultValue result;
  final String? subscriptionTier;
  final int? isPremium;
  final String? activeEntitlements;
  final String? errorCode;
  final String? errorMessage;

  @override
  String get eventName => 'subscription_entitlement_refresh';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'result': result.wireValue,
      if (subscriptionTier != null) 'subscription_tier': subscriptionTier,
      if (isPremium != null) 'is_premium': isPremium,
      if (activeEntitlements != null) 'active_entitlements': activeEntitlements,
      if (errorCode != null) 'error_code': errorCode,
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }
}

class SubscriptionConversionEvent extends AnalyticsEvent {
  const SubscriptionConversionEvent({
    required this.source,
    required this.productId,
    required this.packageType,
    required this.subscriptionTier,
    required this.price,
    required this.currency,
  });

  final String source;
  final String productId;
  final String packageType;
  final String subscriptionTier;
  final num price;
  final String currency;

  @override
  String get eventName => 'subscription_conversion';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source': source,
      'product_id': productId,
      'package_type': packageType,
      'subscription_tier': subscriptionTier,
      'price': price,
      'currency': currency,
    };
  }
}

class AiChargeReservedEvent extends AnalyticsEvent {
  const AiChargeReservedEvent({
    required this.mode,
    required this.coinsSpent,
    required this.balance,
    required this.sourceTag,
  });

  final AiChargeModeValue mode;
  final int coinsSpent;
  final int balance;
  final String sourceTag;

  @override
  String get eventName => 'ai_charge_reserved';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'mode': mode.wireValue,
      'coins_spent': coinsSpent,
      'balance': balance,
      'source_tag': sourceTag,
    };
  }
}

class AiChargeRolledBackEvent extends AnalyticsEvent {
  const AiChargeRolledBackEvent({
    required this.mode,
    required this.balance,
    required this.sourceTag,
    this.coinsRefunded,
  });

  final AiChargeModeValue mode;
  final int balance;
  final String sourceTag;
  final int? coinsRefunded;

  @override
  String get eventName => 'ai_charge_rolled_back';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'mode': mode.wireValue,
      'balance': balance,
      'source_tag': sourceTag,
      if (coinsRefunded != null) 'coins_refunded': coinsRefunded,
    };
  }
}

class AiChargeCommittedEvent extends AnalyticsEvent {
  const AiChargeCommittedEvent({
    required this.mode,
    required this.coinsSpent,
    required this.balance,
    required this.sourceTag,
  });

  final AiChargeModeValue mode;
  final int coinsSpent;
  final int balance;
  final String sourceTag;

  @override
  String get eventName => 'ai_charge_committed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'mode': mode.wireValue,
      'coins_spent': coinsSpent,
      'balance': balance,
      'source_tag': sourceTag,
    };
  }
}

class CoinEarnedEvent extends AnalyticsEvent {
  const CoinEarnedEvent({
    required this.action,
    required this.amount,
    required this.balance,
    required this.sourceTag,
    this.reason,
  });

  final CoinEarnActionValue action;
  final int amount;
  final int balance;
  final String sourceTag;
  final String? reason;

  @override
  String get eventName => 'coin_earned';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'action': action.wireValue,
      'amount': amount,
      'balance': balance,
      'source_tag': sourceTag,
      if (reason != null) 'reason': reason,
    };
  }
}

class CoinSpentEvent extends AnalyticsEvent {
  const CoinSpentEvent({
    required this.action,
    required this.amount,
    required this.balance,
    required this.sourceTag,
    this.reason,
  });

  final CoinSpendActionValue action;
  final int amount;
  final int balance;
  final String sourceTag;
  final String? reason;

  @override
  String get eventName => 'coin_spent';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'action': action.wireValue,
      'amount': amount,
      'balance': balance,
      'source_tag': sourceTag,
      if (reason != null) 'reason': reason,
    };
  }
}

class CoinLowBalanceNudgeShownEvent extends AnalyticsEvent {
  const CoinLowBalanceNudgeShownEvent({required this.sourceTag, required this.requiredCoins, required this.balance});

  final String sourceTag;
  final int requiredCoins;
  final int balance;

  @override
  String get eventName => 'coin_low_balance_nudge_shown';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_tag': sourceTag, 'required_coins': requiredCoins, 'balance': balance};
  }
}

class CoinWatchAndDownloadUsedEvent extends AnalyticsEvent {
  const CoinWatchAndDownloadUsedEvent({required this.isPremiumContent, required this.sourceTag});

  final bool isPremiumContent;
  final String sourceTag;

  @override
  String get eventName => 'coin_watch_and_download_used';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'is_premium_content': isPremiumContent, 'source_tag': sourceTag};
  }
}

class AiPromptShuffledEvent extends AnalyticsEvent {
  const AiPromptShuffledEvent({required this.style});

  final String style;

  @override
  String get eventName => 'ai_prompt_shuffled';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'style': style};
  }
}

class AiHistoryOpenedEvent extends AnalyticsEvent {
  const AiHistoryOpenedEvent({required this.count});

  final int count;

  @override
  String get eventName => 'ai_history_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count': count};
  }
}

class AiGenerateStartedEvent extends AnalyticsEvent {
  const AiGenerateStartedEvent({required this.style, required this.quality, required this.mode});

  final String style;
  final String quality;
  final AiChargeModeValue mode;

  @override
  String get eventName => 'ai_generate_started';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'style': style, 'quality': quality, 'mode': mode.wireValue};
  }
}

class AiGenerateSuccessEvent extends AnalyticsEvent {
  const AiGenerateSuccessEvent({required this.provider, required this.mode, required this.coinsSpent});

  final String provider;
  final AiChargeModeValue mode;
  final int coinsSpent;

  @override
  String get eventName => 'ai_generate_success';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'provider': provider, 'mode': mode.wireValue, 'coins_spent': coinsSpent};
  }
}

class AiVariationUsedEvent extends AnalyticsEvent {
  const AiVariationUsedEvent({required this.provider, required this.mode, required this.coinsSpent});

  final String provider;
  final AiChargeModeValue mode;
  final int coinsSpent;

  @override
  String get eventName => 'ai_variation_used';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'provider': provider, 'mode': mode.wireValue, 'coins_spent': coinsSpent};
  }
}

class AiGenerateFailedEvent extends AnalyticsEvent {
  const AiGenerateFailedEvent({required this.error, required this.mode});

  final String error;
  final AiChargeModeValue mode;

  @override
  String get eventName => 'ai_generate_failed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'error': error, 'mode': mode.wireValue};
  }
}

class AiShareTappedEvent extends AnalyticsEvent {
  const AiShareTappedEvent({required this.generationId});

  final String generationId;

  @override
  String get eventName => 'ai_share_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'generation_id': generationId};
  }
}

class AiSubmitStartedEvent extends AnalyticsEvent {
  const AiSubmitStartedEvent({required this.generationId});

  final String generationId;

  @override
  String get eventName => 'ai_submit_started';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'generation_id': generationId};
  }
}

class AiSubmitSuccessEvent extends AnalyticsEvent {
  const AiSubmitSuccessEvent({required this.generationId});

  final String generationId;

  @override
  String get eventName => 'ai_submit_success';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'generation_id': generationId};
  }
}

class CoinPreviewUnlockAttemptEvent extends AnalyticsEvent {
  const CoinPreviewUnlockAttemptEvent({required this.collection, required this.sourceTag});

  final String collection;
  final String sourceTag;

  @override
  String get eventName => 'coin_preview_unlock_attempt';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'collection': collection, 'source_tag': sourceTag};
  }
}

class CoinPreviewUnlockSuccessEvent extends AnalyticsEvent {
  const CoinPreviewUnlockSuccessEvent({required this.collection, required this.sourceTag, required this.coinsSpent});

  final String collection;
  final String sourceTag;
  final int coinsSpent;

  @override
  String get eventName => 'coin_preview_unlock_success';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'collection': collection, 'source_tag': sourceTag, 'coins_spent': coinsSpent};
  }
}

class CoinPreviewWatchAndUnlockUsedEvent extends AnalyticsEvent {
  const CoinPreviewWatchAndUnlockUsedEvent({required this.collection, required this.sourceTag});

  final String collection;
  final String sourceTag;

  @override
  String get eventName => 'coin_preview_watch_and_unlock_used';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'collection': collection, 'source_tag': sourceTag};
  }
}

class CategoriesCheckedEvent extends AnalyticsEvent {
  const CategoriesCheckedEvent();

  @override
  String get eventName => 'categories_checked';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class CollectionsCheckedEvent extends AnalyticsEvent {
  const CollectionsCheckedEvent();

  @override
  String get eventName => 'collections_checked';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class EditSetupEvent extends AnalyticsEvent {
  const EditSetupEvent({required this.setupId, required this.link});

  final String setupId;
  final String link;

  @override
  String get eventName => 'edit_setup';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'id': setupId, 'link': link};
  }
}

class UploadSetupEvent extends AnalyticsEvent {
  const UploadSetupEvent({required this.setupId, required this.link});

  final String setupId;
  final String link;

  @override
  String get eventName => 'upload_setup';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'id': setupId, 'link': link};
  }
}

class FavStatusChangedEvent extends AnalyticsEvent {
  const FavStatusChangedEvent({required this.wallId, required this.provider});

  final String wallId;
  final String provider;

  @override
  String get eventName => 'fav_status_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'id': wallId, 'provider': provider};
  }
}
