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
      if (sourceContext != null) 'source_context': sourceContext!,
      if (premiumContent != null) 'premium_content': premiumContent! ? 1 : 0,
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
      if (placementOffering != null) 'placement_offering': placementOffering!,
      if (selectedOffering != null) 'selected_offering': selectedOffering!,
      if (entitlementSynced != null) 'entitlement_synced': entitlementSynced!,
      if (entitlement != null) 'entitlement': entitlement!,
      if (error != null) 'error': error!,
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
      if (errorCode != null) 'error_code': errorCode!,
      if (errorMessage != null) 'error_message': errorMessage!,
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
      if (errorCode != null) 'error_code': errorCode!,
      if (errorMessage != null) 'error_message': errorMessage!,
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
      if (subscriptionTier != null) 'subscription_tier': subscriptionTier!,
      if (isPremium != null) 'is_premium': isPremium!,
      if (activeEntitlements != null) 'active_entitlements': activeEntitlements!,
      if (errorCode != null) 'error_code': errorCode!,
      if (errorMessage != null) 'error_message': errorMessage!,
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
      if (coinsRefunded != null) 'coins_refunded': coinsRefunded!,
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
      if (reason != null) 'reason': reason!,
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
      if (reason != null) 'reason': reason!,
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
    return <String, Object?>{'is_premium_content': isPremiumContent ? 1 : 0, 'source_tag': sourceTag};
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

class SettingsActionTappedEvent extends AnalyticsEvent {
  const SettingsActionTappedEvent({required this.action, required this.isSignedIn, required this.sourceContext});

  final AnalyticsActionValue action;
  final bool isSignedIn;
  final String sourceContext;

  @override
  String get eventName => 'settings_action_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'action': action.wireValue,
      'is_signed_in': isSignedIn ? 1 : 0,
      'source_context': sourceContext,
    };
  }
}

class SettingsToggleChangedEvent extends AnalyticsEvent {
  const SettingsToggleChangedEvent({required this.setting, required this.value});

  final SettingValue setting;
  final bool value;

  @override
  String get eventName => 'settings_toggle_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'setting': setting.wireValue, 'value': value ? 1 : 0};
  }
}

class SettingsAuthActionResultEvent extends AnalyticsEvent {
  const SettingsAuthActionResultEvent({required this.action, required this.result, this.reason});

  final AnalyticsActionValue action;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;

  @override
  String get eventName => 'settings_auth_action_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'action': action.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
    };
  }
}

class SearchSubmittedEvent extends AnalyticsEvent {
  const SearchSubmittedEvent({
    required this.provider,
    required this.queryLength,
    required this.queryWordCount,
    required this.sourceContext,
    required this.fromSuggestion,
  });

  final SearchProviderValue provider;
  final int queryLength;
  final int queryWordCount;
  final String sourceContext;
  final bool fromSuggestion;

  @override
  String get eventName => 'search_submitted';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'provider': provider.wireValue,
      'query_length': queryLength,
      'query_word_count': queryWordCount,
      'source_context': sourceContext,
      'from_suggestion': fromSuggestion ? 1 : 0,
    };
  }
}

class SearchProviderChangedEvent extends AnalyticsEvent {
  const SearchProviderChangedEvent({required this.fromProvider, required this.toProvider});

  final SearchProviderValue fromProvider;
  final SearchProviderValue toProvider;

  @override
  String get eventName => 'search_provider_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'from_provider': fromProvider.wireValue, 'to_provider': toProvider.wireValue};
  }
}

class SearchTagSelectedEvent extends AnalyticsEvent {
  const SearchTagSelectedEvent({required this.provider, required this.tag});

  final SearchProviderValue provider;
  final String tag;

  @override
  String get eventName => 'search_tag_selected';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'provider': provider.wireValue, 'tag': tag};
  }
}

class SearchResultsLoadedEvent extends AnalyticsEvent {
  const SearchResultsLoadedEvent({
    required this.provider,
    required this.queryLength,
    required this.resultCount,
    required this.page,
    required this.result,
  });

  final SearchProviderValue provider;
  final int queryLength;
  final int resultCount;
  final int page;
  final EventResultValue result;

  @override
  String get eventName => 'search_results_loaded';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'provider': provider.wireValue,
      'query_length': queryLength,
      'result_count': resultCount,
      'page': page,
      'result': result.wireValue,
    };
  }
}

class SearchResultOpenedEvent extends AnalyticsEvent {
  const SearchResultOpenedEvent({
    required this.provider,
    required this.itemType,
    required this.itemId,
    required this.index,
    required this.queryLength,
  });

  final SearchProviderValue provider;
  final ItemTypeValue itemType;
  final String itemId;
  final int index;
  final int queryLength;

  @override
  String get eventName => 'search_result_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'provider': provider.wireValue,
      'item_type': itemType.wireValue,
      'item_id': itemId,
      'index': index,
      'query_length': queryLength,
    };
  }
}

class SearchPaginationRequestedEvent extends AnalyticsEvent {
  const SearchPaginationRequestedEvent({required this.provider, required this.queryLength, required this.page});

  final SearchProviderValue provider;
  final int queryLength;
  final int page;

  @override
  String get eventName => 'search_pagination_requested';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'provider': provider.wireValue, 'query_length': queryLength, 'page': page};
  }
}

class UserSearchSubmittedEvent extends AnalyticsEvent {
  const UserSearchSubmittedEvent({required this.queryLength, required this.sourceContext});

  final int queryLength;
  final String sourceContext;

  @override
  String get eventName => 'user_search_submitted';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'query_length': queryLength, 'source_context': sourceContext};
  }
}

class UserSearchResultOpenedEvent extends AnalyticsEvent {
  const UserSearchResultOpenedEvent({required this.resultUserId, required this.index, required this.queryLength});

  final String resultUserId;
  final int index;
  final int queryLength;

  @override
  String get eventName => 'user_search_result_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'result_user_id': resultUserId, 'index': index, 'query_length': queryLength};
  }
}

class NotificationItemOpenedEvent extends AnalyticsEvent {
  const NotificationItemOpenedEvent({required this.type, required this.destination, required this.hasExternalUrl});

  final NotificationTypeValue type;
  final String destination;
  final bool hasExternalUrl;

  @override
  String get eventName => 'notification_item_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'type': type.wireValue,
      'destination': destination,
      'has_external_url': hasExternalUrl ? 1 : 0,
    };
  }
}

class NotificationItemDismissedEvent extends AnalyticsEvent {
  const NotificationItemDismissedEvent({required this.type, required this.dismissMode});

  final NotificationTypeValue type;
  final DismissModeValue dismissMode;

  @override
  String get eventName => 'notification_item_dismissed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'type': type.wireValue, 'dismiss_mode': dismissMode.wireValue};
  }
}

class NotificationClearAllConfirmedEvent extends AnalyticsEvent {
  const NotificationClearAllConfirmedEvent({required this.count});

  final int count;

  @override
  String get eventName => 'notification_clear_all_confirmed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count': count};
  }
}

class NotificationPreferenceChangedEvent extends AnalyticsEvent {
  const NotificationPreferenceChangedEvent({required this.preference, required this.value});

  final NotificationPreferenceValue preference;
  final bool value;

  @override
  String get eventName => 'notification_preference_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'preference': preference.wireValue, 'value': value ? 1 : 0};
  }
}

class NotificationActionBlockedEvent extends AnalyticsEvent {
  const NotificationActionBlockedEvent({required this.action, required this.reason});

  final AnalyticsActionValue action;
  final AnalyticsReasonValue reason;

  @override
  String get eventName => 'notification_action_blocked';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'action': action.wireValue, 'reason': reason.wireValue};
  }
}

class OnboardingStepViewedEvent extends AnalyticsEvent {
  const OnboardingStepViewedEvent({required this.step});

  final int step;

  @override
  String get eventName => 'onboarding_step_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'step': step};
  }
}

class OnboardingActionTappedEvent extends AnalyticsEvent {
  const OnboardingActionTappedEvent({required this.step, required this.action});

  final int step;
  final AnalyticsActionValue action;

  @override
  String get eventName => 'onboarding_action_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'step': step, 'action': action.wireValue};
  }
}

class OnboardingAuthResultEvent extends AnalyticsEvent {
  const OnboardingAuthResultEvent({required this.method, required this.result, this.reason});

  final AuthMethodValue method;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;

  @override
  String get eventName => 'onboarding_auth_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'method': method.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
    };
  }
}

class TomorrowHookViewedEvent extends AnalyticsEvent {
  const TomorrowHookViewedEvent({required this.sourceContext});

  final String sourceContext;

  @override
  String get eventName => 'tomorrow_hook_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_context': sourceContext};
  }
}

class TomorrowHookActionTappedEvent extends AnalyticsEvent {
  const TomorrowHookActionTappedEvent({required this.action});

  final String action;

  @override
  String get eventName => 'tomorrow_hook_action_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'action': action};
  }
}

class TomorrowHookPermissionResultEvent extends AnalyticsEvent {
  const TomorrowHookPermissionResultEvent({required this.result, this.reason, required this.subscribedToWotd});

  final EventResultValue result;
  final AnalyticsReasonValue? reason;
  final bool subscribedToWotd;

  @override
  String get eventName => 'tomorrow_hook_permission_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
      'subscribed_to_wotd': subscribedToWotd ? 1 : 0,
    };
  }
}

class WotdViewedEvent extends AnalyticsEvent {
  const WotdViewedEvent({required this.wallId});

  final String wallId;

  @override
  String get eventName => 'wotd_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wall_id': wallId};
  }
}

class WotdOpenedEvent extends AnalyticsEvent {
  const WotdOpenedEvent({required this.wallId, required this.source});

  final String wallId;
  final String source;

  @override
  String get eventName => 'wotd_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wall_id': wallId, 'source': source};
  }
}

class WotdSetAsWallpaperEvent extends AnalyticsEvent {
  const WotdSetAsWallpaperEvent({required this.wallId});

  final String wallId;

  @override
  String get eventName => 'wotd_set_as_wallpaper';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wall_id': wallId};
  }
}

class WotdOpenedFromPushEvent extends AnalyticsEvent {
  const WotdOpenedFromPushEvent({required this.wallId});

  final String wallId;

  @override
  String get eventName => 'wotd_opened_from_push';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wall_id': wallId};
  }
}

class NavTabSelectedEvent extends AnalyticsEvent {
  const NavTabSelectedEvent({required this.fromTab, required this.toTab});

  final NavTabValue fromTab;
  final NavTabValue toTab;

  @override
  String get eventName => 'nav_tab_selected';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'from_tab': fromTab.wireValue, 'to_tab': toTab.wireValue};
  }
}

class UploadActionSelectedEvent extends AnalyticsEvent {
  const UploadActionSelectedEvent({required this.action, required this.entrypoint});

  final AnalyticsActionValue action;
  final EntryPointValue entrypoint;

  @override
  String get eventName => 'upload_action_selected';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'action': action.wireValue, 'entrypoint': entrypoint.wireValue};
  }
}

class QuickActionInvokedEvent extends AnalyticsEvent {
  const QuickActionInvokedEvent({required this.action, required this.launchState});

  final AnalyticsActionValue action;
  final LaunchStateValue launchState;

  @override
  String get eventName => 'quick_action_invoked';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'action': action.wireValue, 'launch_state': launchState.wireValue};
  }
}

class DeepLinkReceivedEvent extends AnalyticsEvent {
  const DeepLinkReceivedEvent({required this.source, required this.targetType, required this.hasPayload});

  final DeepLinkSourceValue source;
  final TargetTypeValue targetType;
  final bool hasPayload;

  @override
  String get eventName => 'deep_link_received';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source': source.wireValue,
      'target_type': targetType.wireValue,
      'has_payload': hasPayload ? 1 : 0,
    };
  }
}

class DeepLinkResolvedEvent extends AnalyticsEvent {
  const DeepLinkResolvedEvent({required this.targetType, required this.result, this.reason});

  final TargetTypeValue targetType;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;

  @override
  String get eventName => 'deep_link_resolved';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'target_type': targetType.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
    };
  }
}

class DeepLinkNavigationResultEvent extends AnalyticsEvent {
  const DeepLinkNavigationResultEvent({required this.targetType, required this.result, this.reason});

  final TargetTypeValue targetType;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;

  @override
  String get eventName => 'deep_link_navigation_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'target_type': targetType.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
    };
  }
}

class InviteShareTappedEvent extends AnalyticsEvent {
  const InviteShareTappedEvent({required this.sourceContext});

  final String sourceContext;

  @override
  String get eventName => 'invite_share_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_context': sourceContext};
  }
}

class InviteShareResultEvent extends AnalyticsEvent {
  const InviteShareResultEvent({required this.channel, required this.result, this.reason, this.sourceContext});

  final ShareChannelValue channel;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;
  final String? sourceContext;

  @override
  String get eventName => 'invite_share_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'channel': channel.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
      if (sourceContext != null) 'source_context': sourceContext!,
    };
  }
}

class DynamicLinkCreateResultEvent extends AnalyticsEvent {
  const DynamicLinkCreateResultEvent({required this.shareType, required this.result, this.reason});

  final ShareTypeValue shareType;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;

  @override
  String get eventName => 'dynamic_link_create_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'share_type': shareType.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
    };
  }
}

class AuthLoginResultEvent extends AnalyticsEvent {
  const AuthLoginResultEvent({required this.method, required this.result, this.reason, this.sourceContext});

  final AuthMethodValue method;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;
  final String? sourceContext;

  @override
  String get eventName => 'auth_login_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'method': method.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
      if (sourceContext != null) 'source_context': sourceContext!,
    };
  }
}

class SurfaceActionTappedEvent extends AnalyticsEvent {
  const SurfaceActionTappedEvent({
    required this.surface,
    required this.action,
    required this.sourceContext,
    this.itemType,
    this.itemId,
    this.index,
  });

  final AnalyticsSurfaceValue surface;
  final AnalyticsActionValue action;
  final String sourceContext;
  final ItemTypeValue? itemType;
  final String? itemId;
  final int? index;

  @override
  String get eventName => 'surface_action_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'surface': surface.wireValue,
      'action': action.wireValue,
      'source_context': sourceContext,
      if (itemType != null) 'item_type': itemType!.wireValue,
      if (itemId != null) 'item_id': itemId!,
      if (index != null) 'index': index!,
    };
  }
}

class SurfaceContentLoadedEvent extends AnalyticsEvent {
  const SurfaceContentLoadedEvent({
    required this.surface,
    required this.result,
    required this.loadTimeMs,
    required this.sourceContext,
    this.itemCount,
    this.reason,
  });

  final AnalyticsSurfaceValue surface;
  final EventResultValue result;
  final int loadTimeMs;
  final String sourceContext;
  final int? itemCount;
  final AnalyticsReasonValue? reason;

  @override
  String get eventName => 'surface_content_loaded';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'surface': surface.wireValue,
      'result': result.wireValue,
      'load_time_ms': loadTimeMs,
      'source_context': sourceContext,
      if (itemCount != null) 'item_count': itemCount!,
      if (reason != null) 'reason': reason!.wireValue,
    };
  }
}

class ScrollMilestoneReachedEvent extends AnalyticsEvent {
  const ScrollMilestoneReachedEvent({
    required this.surface,
    required this.listName,
    required this.depth,
    required this.sourceContext,
    this.itemCount,
  });

  final AnalyticsSurfaceValue surface;
  final ScrollListNameValue listName;
  final ScrollDepthPercentValue depth;
  final String sourceContext;
  final int? itemCount;

  @override
  String get eventName => 'scroll_milestone_reached';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'surface': surface.wireValue,
      'list_name': listName.wireValue,
      'depth': depth.wireValue,
      'source_context': sourceContext,
      if (itemCount != null) 'item_count': itemCount!,
    };
  }
}

class ExternalLinkOpenResultEvent extends AnalyticsEvent {
  const ExternalLinkOpenResultEvent({
    required this.surface,
    required this.destination,
    required this.result,
    this.reason,
    this.sourceContext,
  });

  final AnalyticsSurfaceValue surface;
  final LinkDestinationValue destination;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;
  final String? sourceContext;

  @override
  String get eventName => 'external_link_open_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'surface': surface.wireValue,
      'destination': destination.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
      if (sourceContext != null) 'source_context': sourceContext!,
    };
  }
}

class RevenueRecordedEvent extends AnalyticsEvent {
  const RevenueRecordedEvent({required this.amountUsd, required this.source});

  final double amountUsd;
  final String source;

  @override
  String get eventName => 'revenue_recorded';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'amount_usd': amountUsd, 'source': source};
  }
}

class AppCrashFatalEvent extends AnalyticsEvent {
  const AppCrashFatalEvent();

  @override
  String get eventName => 'app_crash_fatal';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class QualityDailySnapshotEvent extends AnalyticsEvent {
  const QualityDailySnapshotEvent({required this.crashFreeUsersPct});

  final double crashFreeUsersPct;

  @override
  String get eventName => 'quality_daily_snapshot';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'crash_free_users_pct': crashFreeUsersPct};
  }
}
