// GENERATED CODE - DO NOT MODIFY BY HAND.
//
// Run: dart run tool/generate_analytics_schema.dart

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/analytics/events/analytics_event.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/taste_quiz/domain/entities/taste_quiz.dart';
import 'package:Prism/features/wall_remix/domain/wall_remix.dart';
import 'package:Prism/features/weekly_challenges/domain/entities/weekly_challenge.dart';

Map<String, List<String>> analyticsEnumWireValues() => <String, List<String>>{
  'daily_moment_step': DailyMomentStepValue.values.map((value) => value.wireValue).toList(),
  'challenge_entry_source': ChallengeEntrySource.values.map((value) => value.wireValue).toList(),
  'wallpaper_target': WallpaperTarget.values.map((value) => value.wireValue).toList(),
  'taste_quiz_source': TasteQuizSource.values.map((value) => value.wireValue).toList(),
  'quiz_side': QuizSide.values.map((value) => value.wireValue).toList(),
  'binary_result': BinaryResultValue.values.map((value) => value.wireValue).toList(),
  'ai_apply_from': AiApplyFromValue.values.map((value) => value.wireValue).toList(),
  'ai_style_pick_source': AiStylePickSource.values.map((value) => value.wireValue).toList(),
  'rc_or_fallback': RcOrFallbackValue.values.map((value) => value.wireValue).toList(),
  'live_wallpaper_style': LiveWallpaperStyleValue.values.map((value) => value.wireValue).toList(),
  'paywall_result': PaywallResultValue.values.map((value) => value.wireValue).toList(),
  'subscription_entitlement_refresh_result': SubscriptionEntitlementRefreshResultValue.values
      .map((value) => value.wireValue)
      .toList(),
  'coin_earn_action': CoinEarnAction.values.map((value) => value.wireValue).toList(),
  'coin_spend_action': CoinSpendAction.values.map((value) => value.wireValue).toList(),
  'ai_charge_mode': AiChargeMode.values.map((value) => value.wireValue).toList(),
  'setting': SettingValue.values.map((value) => value.wireValue).toList(),
  'analytics_action': AnalyticsActionValue.values.map((value) => value.wireValue).toList(),
  'event_result': EventResultValue.values.map((value) => value.wireValue).toList(),
  'analytics_reason': AnalyticsReasonValue.values.map((value) => value.wireValue).toList(),
  'search_provider': SearchProviderValue.values.map((value) => value.wireValue).toList(),
  'item_type': ItemTypeValue.values.map((value) => value.wireValue).toList(),
  'target_type': TargetTypeValue.values.map((value) => value.wireValue).toList(),
  'entrypoint': EntryPointValue.values.map((value) => value.wireValue).toList(),
  'launch_state': LaunchStateValue.values.map((value) => value.wireValue).toList(),
  'share_channel': ShareChannelValue.values.map((value) => value.wireValue).toList(),
  'share_format': ShareFormatValue.values.map((value) => value.wireValue).toList(),
  'share_target': ShareTargetValue.values.map((value) => value.wireValue).toList(),
  'dismiss_mode': DismissModeValue.values.map((value) => value.wireValue).toList(),
  'notification_type': NotificationTypeValue.values.map((value) => value.wireValue).toList(),
  'auth_method': AuthMethodValue.values.map((value) => value.wireValue).toList(),
  'nav_tab': NavTabValue.values.map((value) => value.wireValue).toList(),
  'notification_preference': NotificationPreferenceValue.values.map((value) => value.wireValue).toList(),
  'deep_link_source': DeepLinkSourceValue.values.map((value) => value.wireValue).toList(),
  'widget_kind': WidgetKindValue.values.map((value) => value.wireValue).toList(),
  'widget_guide_source': WidgetGuideSourceValue.values.map((value) => value.wireValue).toList(),
  'share_type': ShareTypeValue.values.map((value) => value.wireValue).toList(),
  'analytics_surface': AnalyticsSurfaceValue.values.map((value) => value.wireValue).toList(),
  'scroll_list_name': ScrollListNameValue.values.map((value) => value.wireValue).toList(),
  'scroll_depth_percent': ScrollDepthPercentValue.values.map((value) => value.wireValue).toList(),
  'link_destination': LinkDestinationValue.values.map((value) => value.wireValue).toList(),
  'push_kind': PushKindValue.values.map((value) => value.wireValue).toList(),
  'immersive_toggle_source': ImmersiveToggleSourceValue.values.map((value) => value.wireValue).toList(),
  'favourite_pin_surface': FavouritePinSurfaceValue.values.map((value) => value.wireValue).toList(),
  'wall_request_source': WallRequestSourceValue.values.map((value) => value.wireValue).toList(),
  'wall_request_filler': WallRequestFillerValue.values.map((value) => value.wireValue).toList(),
  'remix_source_type': RemixSourceType.values.map((value) => value.wireValue).toList(),
};

class ContentReportSubmitEvent extends AnalyticsEvent {
  const ContentReportSubmitEvent({required this.contentType, required this.result, this.reason});

  final String contentType;
  final BinaryResultValue result;
  final String? reason;

  @override
  String get eventName => 'content_report_submit';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'content_type': contentType,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!,
    };
  }
}

class UserBlockActionEvent extends AnalyticsEvent {
  const UserBlockActionEvent({required this.action, this.result});

  final String action;
  final String? result;

  @override
  String get eventName => 'user_block_action';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'action': action, if (result != null) 'result': result!};
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
  const SetWallEvent({
    this.requestId,
    required this.wallpaperTarget,
    required this.result,
    this.errorCode,
    this.fit,
    this.entryPoint,
    this.usedDefault,
    this.targetChanged,
    this.operationId,
    this.itemId,
    this.provider,
    this.source,
  });

  final String? requestId;
  final WallpaperTarget wallpaperTarget;
  final BinaryResultValue result;
  final String? errorCode;
  final String? fit;
  final String? entryPoint;
  final bool? usedDefault;
  final bool? targetChanged;
  final String? operationId;
  final String? itemId;
  final String? provider;
  final String? source;

  @override
  String get eventName => 'set_wall';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (requestId != null) 'request_id': requestId!,
      'wallpaper_target': wallpaperTarget.wireValue,
      'result': result.wireValue,
      if (errorCode != null) 'error_code': errorCode!,
      if (fit != null) 'fit': fit!,
      if (entryPoint != null) 'entry_point': entryPoint!,
      if (usedDefault != null) 'used_default': usedDefault! ? 1 : 0,
      if (targetChanged != null) 'target_changed': targetChanged! ? 1 : 0,
      if (operationId != null) 'operation_id': operationId!,
      if (itemId != null) 'item_id': itemId!,
      if (provider != null) 'provider': provider!,
      if (source != null) 'source': source!,
    };
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
  const DownloadWallpaperEvent({
    this.requestId,
    required this.link,
    this.sourceContext,
    this.premiumContent,
    this.operationId,
    this.itemId,
    this.provider,
    this.source,
  });

  final String? requestId;
  final String link;
  final String? sourceContext;
  final bool? premiumContent;
  final String? operationId;
  final String? itemId;
  final String? provider;
  final String? source;

  @override
  String get eventName => 'download_wallpaper';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (requestId != null) 'request_id': requestId!,
      'link': link,
      if (sourceContext != null) 'source_context': sourceContext!,
      if (premiumContent != null) 'premium_content': premiumContent! ? 1 : 0,
      if (operationId != null) 'operation_id': operationId!,
      if (itemId != null) 'item_id': itemId!,
      if (provider != null) 'provider': provider!,
      if (source != null) 'source': source!,
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

class ThemeChangedEvent extends AnalyticsEvent {
  const ThemeChangedEvent({required this.themeId});

  final String themeId;

  @override
  String get eventName => 'theme_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'theme_id': themeId};
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
    this.priceType,
    required this.source,
    required this.productId,
    required this.packageType,
    required this.subscriptionTier,
    required this.price,
    required this.currency,
    this.transactionId,
    this.restored,
  });

  final String? priceType;
  final String source;
  final String productId;
  final String packageType;
  final String subscriptionTier;
  final num price;
  final String currency;
  final String? transactionId;
  final bool? restored;

  @override
  String get eventName => 'subscription_conversion';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (priceType != null) 'price_type': priceType!,
      'source': source,
      'product_id': productId,
      'package_type': packageType,
      'subscription_tier': subscriptionTier,
      'price': price,
      'currency': currency,
      if (transactionId != null) 'transaction_id': transactionId!,
      if (restored != null) 'restored': restored! ? 1 : 0,
    };
  }
}

class AiChargeReservedEvent extends AnalyticsEvent {
  const AiChargeReservedEvent({
    required this.mode,
    required this.coinsSpent,
    required this.balance,
    required this.sourceTag,
    this.operationId,
    this.durationMs,
    this.chargeTransactionId,
    this.generationId,
    this.errorCategory,
    this.refundResult,
  });

  final AiChargeMode mode;
  final int coinsSpent;
  final int balance;
  final String sourceTag;
  final String? operationId;
  final int? durationMs;
  final String? chargeTransactionId;
  final String? generationId;
  final String? errorCategory;
  final String? refundResult;

  @override
  String get eventName => 'ai_charge_reserved';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'mode': mode.wireValue,
      'coins_spent': coinsSpent,
      'balance': balance,
      'source_tag': sourceTag,
      if (operationId != null) 'operation_id': operationId!,
      if (durationMs != null) 'duration_ms': durationMs!,
      if (chargeTransactionId != null) 'charge_transaction_id': chargeTransactionId!,
      if (generationId != null) 'generation_id': generationId!,
      if (errorCategory != null) 'error_category': errorCategory!,
      if (refundResult != null) 'refund_result': refundResult!,
    };
  }
}

class AiChargeRolledBackEvent extends AnalyticsEvent {
  const AiChargeRolledBackEvent({
    required this.mode,
    required this.balance,
    required this.sourceTag,
    this.coinsRefunded,
    this.operationId,
    this.durationMs,
    this.chargeTransactionId,
    this.generationId,
    this.errorCategory,
    this.refundResult,
  });

  final AiChargeMode mode;
  final int balance;
  final String sourceTag;
  final int? coinsRefunded;
  final String? operationId;
  final int? durationMs;
  final String? chargeTransactionId;
  final String? generationId;
  final String? errorCategory;
  final String? refundResult;

  @override
  String get eventName => 'ai_charge_rolled_back';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'mode': mode.wireValue,
      'balance': balance,
      'source_tag': sourceTag,
      if (coinsRefunded != null) 'coins_refunded': coinsRefunded!,
      if (operationId != null) 'operation_id': operationId!,
      if (durationMs != null) 'duration_ms': durationMs!,
      if (chargeTransactionId != null) 'charge_transaction_id': chargeTransactionId!,
      if (generationId != null) 'generation_id': generationId!,
      if (errorCategory != null) 'error_category': errorCategory!,
      if (refundResult != null) 'refund_result': refundResult!,
    };
  }
}

class AiChargeCommittedEvent extends AnalyticsEvent {
  const AiChargeCommittedEvent({
    required this.mode,
    required this.coinsSpent,
    required this.balance,
    required this.sourceTag,
    this.operationId,
    this.durationMs,
    this.chargeTransactionId,
    this.generationId,
    this.errorCategory,
    this.refundResult,
  });

  final AiChargeMode mode;
  final int coinsSpent;
  final int balance;
  final String sourceTag;
  final String? operationId;
  final int? durationMs;
  final String? chargeTransactionId;
  final String? generationId;
  final String? errorCategory;
  final String? refundResult;

  @override
  String get eventName => 'ai_charge_committed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'mode': mode.wireValue,
      'coins_spent': coinsSpent,
      'balance': balance,
      'source_tag': sourceTag,
      if (operationId != null) 'operation_id': operationId!,
      if (durationMs != null) 'duration_ms': durationMs!,
      if (chargeTransactionId != null) 'charge_transaction_id': chargeTransactionId!,
      if (generationId != null) 'generation_id': generationId!,
      if (errorCategory != null) 'error_category': errorCategory!,
      if (refundResult != null) 'refund_result': refundResult!,
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

  final CoinEarnAction action;
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

  final CoinSpendAction action;
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

class AiStyleSheetOpenedEvent extends AnalyticsEvent {
  const AiStyleSheetOpenedEvent({required this.style});

  final String style;

  @override
  String get eventName => 'ai_style_sheet_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'style': style};
  }
}

class AiStylePickedEvent extends AnalyticsEvent {
  const AiStylePickedEvent({required this.style, required this.source});

  final String style;
  final AiStylePickSource source;

  @override
  String get eventName => 'ai_style_picked';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'style': style, 'source': source.wireValue};
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
  const AiGenerateStartedEvent({
    required this.style,
    required this.quality,
    required this.mode,
    this.operationId,
    this.durationMs,
    this.chargeTransactionId,
    this.generationId,
    this.errorCategory,
    this.refundResult,
  });

  final String style;
  final String quality;
  final AiChargeMode mode;
  final String? operationId;
  final int? durationMs;
  final String? chargeTransactionId;
  final String? generationId;
  final String? errorCategory;
  final String? refundResult;

  @override
  String get eventName => 'ai_generate_started';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'style': style,
      'quality': quality,
      'mode': mode.wireValue,
      if (operationId != null) 'operation_id': operationId!,
      if (durationMs != null) 'duration_ms': durationMs!,
      if (chargeTransactionId != null) 'charge_transaction_id': chargeTransactionId!,
      if (generationId != null) 'generation_id': generationId!,
      if (errorCategory != null) 'error_category': errorCategory!,
      if (refundResult != null) 'refund_result': refundResult!,
    };
  }
}

class AiGenerateSuccessEvent extends AnalyticsEvent {
  const AiGenerateSuccessEvent({
    required this.provider,
    required this.mode,
    required this.coinsSpent,
    this.operationId,
    this.durationMs,
    this.chargeTransactionId,
    this.generationId,
    this.errorCategory,
    this.refundResult,
  });

  final String provider;
  final AiChargeMode mode;
  final int coinsSpent;
  final String? operationId;
  final int? durationMs;
  final String? chargeTransactionId;
  final String? generationId;
  final String? errorCategory;
  final String? refundResult;

  @override
  String get eventName => 'ai_generate_success';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'provider': provider,
      'mode': mode.wireValue,
      'coins_spent': coinsSpent,
      if (operationId != null) 'operation_id': operationId!,
      if (durationMs != null) 'duration_ms': durationMs!,
      if (chargeTransactionId != null) 'charge_transaction_id': chargeTransactionId!,
      if (generationId != null) 'generation_id': generationId!,
      if (errorCategory != null) 'error_category': errorCategory!,
      if (refundResult != null) 'refund_result': refundResult!,
    };
  }
}

class AiVariationUsedEvent extends AnalyticsEvent {
  const AiVariationUsedEvent({
    required this.provider,
    required this.mode,
    required this.coinsSpent,
    this.operationId,
    this.durationMs,
    this.chargeTransactionId,
    this.generationId,
    this.errorCategory,
    this.refundResult,
  });

  final String provider;
  final AiChargeMode mode;
  final int coinsSpent;
  final String? operationId;
  final int? durationMs;
  final String? chargeTransactionId;
  final String? generationId;
  final String? errorCategory;
  final String? refundResult;

  @override
  String get eventName => 'ai_variation_used';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'provider': provider,
      'mode': mode.wireValue,
      'coins_spent': coinsSpent,
      if (operationId != null) 'operation_id': operationId!,
      if (durationMs != null) 'duration_ms': durationMs!,
      if (chargeTransactionId != null) 'charge_transaction_id': chargeTransactionId!,
      if (generationId != null) 'generation_id': generationId!,
      if (errorCategory != null) 'error_category': errorCategory!,
      if (refundResult != null) 'refund_result': refundResult!,
    };
  }
}

class AiGenerateFailedEvent extends AnalyticsEvent {
  const AiGenerateFailedEvent({
    required this.error,
    required this.mode,
    this.operationId,
    this.durationMs,
    this.chargeTransactionId,
    this.generationId,
    this.errorCategory,
    this.refundResult,
  });

  final String error;
  final AiChargeMode mode;
  final String? operationId;
  final int? durationMs;
  final String? chargeTransactionId;
  final String? generationId;
  final String? errorCategory;
  final String? refundResult;

  @override
  String get eventName => 'ai_generate_failed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'error': error,
      'mode': mode.wireValue,
      if (operationId != null) 'operation_id': operationId!,
      if (durationMs != null) 'duration_ms': durationMs!,
      if (chargeTransactionId != null) 'charge_transaction_id': chargeTransactionId!,
      if (generationId != null) 'generation_id': generationId!,
      if (errorCategory != null) 'error_category': errorCategory!,
      if (refundResult != null) 'refund_result': refundResult!,
    };
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

class AiResultAppliedEvent extends AnalyticsEvent {
  const AiResultAppliedEvent({required this.platform, required this.from});

  final String platform;
  final AiApplyFromValue from;

  @override
  String get eventName => 'ai_result_applied';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'platform': platform, 'from': from.wireValue};
  }
}

class AiFollowUpUsedEvent extends AnalyticsEvent {
  const AiFollowUpUsedEvent({required this.chipId});

  final String chipId;

  @override
  String get eventName => 'ai_follow_up_used';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'chip_id': chipId};
  }
}

class AiStripSwappedEvent extends AnalyticsEvent {
  const AiStripSwappedEvent({required this.position, required this.count});

  final int position;
  final int count;

  @override
  String get eventName => 'ai_strip_swapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'position': position, 'count': count};
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

class CollectionsCheckedEvent extends AnalyticsEvent {
  const CollectionsCheckedEvent();

  @override
  String get eventName => 'collections_checked';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class FavStatusChangedEvent extends AnalyticsEvent {
  const FavStatusChangedEvent({required this.wallId, required this.provider, required this.isFavourite});

  final String wallId;
  final String provider;
  final bool isFavourite;

  @override
  String get eventName => 'fav_status_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'id': wallId, 'provider': provider, 'is_favourite': isFavourite ? 1 : 0};
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
    this.searchId,
  });

  final SearchProviderValue provider;
  final int queryLength;
  final int queryWordCount;
  final String sourceContext;
  final bool fromSuggestion;
  final String? searchId;

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
      if (searchId != null) 'search_id': searchId!,
    };
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
    this.reason,
    required this.provider,
    required this.queryLength,
    required this.resultCount,
    required this.page,
    required this.result,
    this.searchId,
  });

  final String? reason;
  final SearchProviderValue provider;
  final int queryLength;
  final int resultCount;
  final int page;
  final EventResultValue result;
  final String? searchId;

  @override
  String get eventName => 'search_results_loaded';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (reason != null) 'reason': reason!,
      'provider': provider.wireValue,
      'query_length': queryLength,
      'result_count': resultCount,
      'page': page,
      'result': result.wireValue,
      if (searchId != null) 'search_id': searchId!,
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
    this.searchId,
  });

  final SearchProviderValue provider;
  final ItemTypeValue itemType;
  final String itemId;
  final int index;
  final int queryLength;
  final String? searchId;

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
      if (searchId != null) 'search_id': searchId!,
    };
  }
}

class SearchPaginationRequestedEvent extends AnalyticsEvent {
  const SearchPaginationRequestedEvent({
    required this.provider,
    required this.queryLength,
    required this.page,
    this.searchId,
  });

  final SearchProviderValue provider;
  final int queryLength;
  final int page;
  final String? searchId;

  @override
  String get eventName => 'search_pagination_requested';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'provider': provider.wireValue,
      'query_length': queryLength,
      'page': page,
      if (searchId != null) 'search_id': searchId!,
    };
  }
}

class UserSearchSubmittedEvent extends AnalyticsEvent {
  const UserSearchSubmittedEvent({required this.queryLength, required this.sourceContext, this.searchId});

  final int queryLength;
  final String sourceContext;
  final String? searchId;

  @override
  String get eventName => 'user_search_submitted';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'query_length': queryLength,
      'source_context': sourceContext,
      if (searchId != null) 'search_id': searchId!,
    };
  }
}

class UserSearchResultOpenedEvent extends AnalyticsEvent {
  const UserSearchResultOpenedEvent({
    required this.resultUserId,
    required this.index,
    required this.queryLength,
    this.searchId,
  });

  final String resultUserId;
  final int index;
  final int queryLength;
  final String? searchId;

  @override
  String get eventName => 'user_search_result_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'result_user_id': resultUserId,
      'index': index,
      'query_length': queryLength,
      if (searchId != null) 'search_id': searchId!,
    };
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

class ProfileCompletenessNudgeViewedEvent extends AnalyticsEvent {
  const ProfileCompletenessNudgeViewedEvent({
    required this.sourceContext,
    required this.progressPercent,
    required this.missingStepsCount,
  });

  final String sourceContext;
  final int progressPercent;
  final int missingStepsCount;

  @override
  String get eventName => 'profile_completeness_nudge_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source_context': sourceContext,
      'progress_percent': progressPercent,
      'missing_steps_count': missingStepsCount,
    };
  }
}

class ProfileCompletenessActionTappedEvent extends AnalyticsEvent {
  const ProfileCompletenessActionTappedEvent({
    required this.sourceContext,
    required this.action,
    required this.progressPercent,
  });

  final String sourceContext;
  final String action;
  final int progressPercent;

  @override
  String get eventName => 'profile_completeness_action_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_context': sourceContext, 'action': action, 'progress_percent': progressPercent};
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

class AutoRotateEnabledEvent extends AnalyticsEvent {
  const AutoRotateEnabledEvent({
    required this.intervalMinutes,
    required this.target,
    required this.shuffle,
    required this.wallpaperCount,
    required this.source,
    this.category,
  });

  final int intervalMinutes;
  final WallpaperTarget target;
  final bool shuffle;
  final int wallpaperCount;
  final String source;
  final String? category;

  @override
  String get eventName => 'auto_rotate_enabled';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'interval_minutes': intervalMinutes,
      'target': target.wireValue,
      'shuffle': shuffle ? 1 : 0,
      'wallpaper_count': wallpaperCount,
      'source': source,
      if (category != null) 'category': category!,
    };
  }
}

class AutoRotateDisabledEvent extends AnalyticsEvent {
  const AutoRotateDisabledEvent();

  @override
  String get eventName => 'auto_rotate_disabled';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class AutoRotateFolderSetEvent extends AnalyticsEvent {
  const AutoRotateFolderSetEvent({required this.itemCountBucket});

  final String itemCountBucket;

  @override
  String get eventName => 'auto_rotate_folder_set';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'item_count_bucket': itemCountBucket};
  }
}

class AutoRotateFolderTappedEvent extends AnalyticsEvent {
  const AutoRotateFolderTappedEvent({required this.itemCountBucket});

  final String itemCountBucket;

  @override
  String get eventName => 'auto_rotate_folder_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'item_count_bucket': itemCountBucket};
  }
}

class AutoRotateStoppedEvent extends AnalyticsEvent {
  const AutoRotateStoppedEvent({required this.reason});

  final String reason;

  @override
  String get eventName => 'auto_rotate_stopped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'reason': reason};
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
  const DeepLinkResolvedEvent({this.source, required this.targetType, required this.result, this.reason});

  final DeepLinkSourceValue? source;
  final TargetTypeValue targetType;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;

  @override
  String get eventName => 'deep_link_resolved';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (source != null) 'source': source!.wireValue,
      'target_type': targetType.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
    };
  }
}

class DeepLinkNavigationResultEvent extends AnalyticsEvent {
  const DeepLinkNavigationResultEvent({this.source, required this.targetType, required this.result, this.reason});

  final DeepLinkSourceValue? source;
  final TargetTypeValue targetType;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;

  @override
  String get eventName => 'deep_link_navigation_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (source != null) 'source': source!.wireValue,
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
  const InviteShareResultEvent({
    required this.channel,
    required this.result,
    this.reason,
    this.sourceContext,
    this.format,
    this.target,
  });

  final ShareChannelValue channel;
  final EventResultValue result;
  final AnalyticsReasonValue? reason;
  final String? sourceContext;
  final ShareFormatValue? format;
  final ShareTargetValue? target;

  @override
  String get eventName => 'invite_share_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'channel': channel.wireValue,
      'result': result.wireValue,
      if (reason != null) 'reason': reason!.wireValue,
      if (sourceContext != null) 'source_context': sourceContext!,
      if (format != null) 'format': format!.wireValue,
      if (target != null) 'target': target!.wireValue,
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
    this.requestId,
    this.provider,
  });

  final AnalyticsSurfaceValue surface;
  final AnalyticsActionValue action;
  final String sourceContext;
  final ItemTypeValue? itemType;
  final String? itemId;
  final int? index;
  final String? requestId;
  final String? provider;

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
      if (requestId != null) 'request_id': requestId!,
      if (provider != null) 'provider': provider!,
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
  const RevenueRecordedEvent({
    this.amountUsd,
    required this.source,
    this.amount,
    this.currency,
    this.productId,
    this.transactionId,
  });

  final double? amountUsd;
  final String source;
  final num? amount;
  final String? currency;
  final String? productId;
  final String? transactionId;

  @override
  String get eventName => 'revenue_recorded';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (amountUsd != null) 'amount_usd': amountUsd!,
      'source': source,
      if (amount != null) 'amount': amount!,
      if (currency != null) 'currency': currency!,
      if (productId != null) 'product_id': productId!,
      if (transactionId != null) 'transaction_id': transactionId!,
    };
  }
}

class OnboardingV2InterestsCompletedEvent extends AnalyticsEvent {
  const OnboardingV2InterestsCompletedEvent({required this.selectedCount});

  final int selectedCount;

  @override
  String get eventName => 'onboarding_v2_interests_completed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'selected_count': selectedCount};
  }
}

class OnboardingV2StarterPackCompletedEvent extends AnalyticsEvent {
  const OnboardingV2StarterPackCompletedEvent({required this.followedCount});

  final int followedCount;

  @override
  String get eventName => 'onboarding_v2_starter_pack_completed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'followed_count': followedCount};
  }
}

class OnboardingV2FirstWallpaperShownEvent extends AnalyticsEvent {
  const OnboardingV2FirstWallpaperShownEvent();

  @override
  String get eventName => 'onboarding_v2_first_wallpaper_shown';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class OnboardingV2FirstWallpaperActionEvent extends AnalyticsEvent {
  const OnboardingV2FirstWallpaperActionEvent({required this.result, required this.elapsedMs, required this.platform});

  final BinaryResultValue result;
  final int elapsedMs;
  final String platform;

  @override
  String get eventName => 'onboarding_v2_first_wallpaper_action';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'result': result.wireValue, 'elapsed_ms': elapsedMs, 'platform': platform};
  }
}

class OnboardingV2CompletedEvent extends AnalyticsEvent {
  const OnboardingV2CompletedEvent({required this.didPurchase, required this.totalElapsedMs});

  final bool didPurchase;
  final int totalElapsedMs;

  @override
  String get eventName => 'onboarding_v2_completed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'did_purchase': didPurchase ? 1 : 0, 'total_elapsed_ms': totalElapsedMs};
  }
}

class TasteQuizStartedEvent extends AnalyticsEvent {
  const TasteQuizStartedEvent({required this.source});

  final TasteQuizSource source;

  @override
  String get eventName => 'taste_quiz_started';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source.wireValue};
  }
}

class TasteQuizRoundPickedEvent extends AnalyticsEvent {
  const TasteQuizRoundPickedEvent({
    required this.source,
    required this.roundIndex,
    required this.side,
    required this.wildCard,
  });

  final TasteQuizSource source;
  final int roundIndex;
  final QuizSide side;
  final bool wildCard;

  @override
  String get eventName => 'taste_quiz_round_picked';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'source': source.wireValue,
      'round_index': roundIndex,
      'side': side.wireValue,
      'wild_card': wildCard ? 1 : 0,
    };
  }
}

class TasteQuizSkippedEvent extends AnalyticsEvent {
  const TasteQuizSkippedEvent({required this.source, required this.roundIndex});

  final TasteQuizSource source;
  final int roundIndex;

  @override
  String get eventName => 'taste_quiz_skipped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source.wireValue, 'round_index': roundIndex};
  }
}

class TasteQuizCompletedEvent extends AnalyticsEvent {
  const TasteQuizCompletedEvent({required this.source});

  final TasteQuizSource source;

  @override
  String get eventName => 'taste_quiz_completed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source.wireValue};
  }
}

class TasteQuizRetakeOpenedEvent extends AnalyticsEvent {
  const TasteQuizRetakeOpenedEvent();

  @override
  String get eventName => 'taste_quiz_retake_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class BadgeEarnedEvent extends AnalyticsEvent {
  const BadgeEarnedEvent({required this.badgeId, required this.coins});

  final String badgeId;
  final int coins;

  @override
  String get eventName => 'badge_earned';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'badge_id': badgeId, 'coins': coins};
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

class AppErrorEvent extends AnalyticsEvent {
  const AppErrorEvent({required this.errorSource});

  final String errorSource;

  @override
  String get eventName => 'app_error';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'error_source': errorSource};
  }
}

class QuickTileAddRequestedEvent extends AnalyticsEvent {
  const QuickTileAddRequestedEvent({required this.tile, required this.result});

  final String tile;
  final String result;

  @override
  String get eventName => 'quick_tile_add_requested';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'tile': tile, 'result': result};
  }
}

class WidgetTappedEvent extends AnalyticsEvent {
  const WidgetTappedEvent({required this.kind});

  final WidgetKindValue kind;

  @override
  String get eventName => 'widget_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'kind': kind.wireValue};
  }
}

class WidgetGuideOpenedEvent extends AnalyticsEvent {
  const WidgetGuideOpenedEvent({required this.source});

  final WidgetGuideSourceValue source;

  @override
  String get eventName => 'widget_guide_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source.wireValue};
  }
}

class GuestFavouritesMergedEvent extends AnalyticsEvent {
  const GuestFavouritesMergedEvent({required this.count});

  final int count;

  @override
  String get eventName => 'guest_favourites_merged';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count': count};
  }
}

class FavouriteSavedAsGuestEvent extends AnalyticsEvent {
  const FavouriteSavedAsGuestEvent();

  @override
  String get eventName => 'favourite_saved_as_guest';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class StreakRescueOfferedEvent extends AnalyticsEvent {
  const StreakRescueOfferedEvent({required this.streakCount});

  final int streakCount;

  @override
  String get eventName => 'streak_rescue_offered';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'streak_count': streakCount};
  }
}

class StreakRescueUsedEvent extends AnalyticsEvent {
  const StreakRescueUsedEvent({required this.result});

  final String result;

  @override
  String get eventName => 'streak_rescue_used';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'result': result};
  }
}

class CoinHistoryOpenedEvent extends AnalyticsEvent {
  const CoinHistoryOpenedEvent();

  @override
  String get eventName => 'coin_history_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class PushOpenedEvent extends AnalyticsEvent {
  const PushOpenedEvent({required this.kind});

  final PushKindValue kind;

  @override
  String get eventName => 'push_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'kind': kind.wireValue};
  }
}

class ReportProblemOpenedEvent extends AnalyticsEvent {
  const ReportProblemOpenedEvent({required this.source, required this.trigger});

  final String source;
  final String trigger;

  @override
  String get eventName => 'report_problem_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'trigger': trigger};
  }
}

class ReportProblemSharedEvent extends AnalyticsEvent {
  const ReportProblemSharedEvent({
    required this.result,
    this.topic,
    required this.hasScreenshot,
    required this.trigger,
  });

  final String result;
  final String? topic;
  final bool hasScreenshot;
  final String trigger;

  @override
  String get eventName => 'report_problem_shared';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'result': result,
      if (topic != null) 'topic': topic!,
      'has_screenshot': hasScreenshot ? 1 : 0,
      'trigger': trigger,
    };
  }
}

class ReportProblemSentEvent extends AnalyticsEvent {
  const ReportProblemSentEvent({
    required this.result,
    required this.topic,
    required this.hasScreenshot,
    required this.trigger,
  });

  final String result;
  final String topic;
  final bool hasScreenshot;
  final String trigger;

  @override
  String get eventName => 'report_problem_sent';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'result': result,
      'topic': topic,
      'has_screenshot': hasScreenshot ? 1 : 0,
      'trigger': trigger,
    };
  }
}

class RatePromptShownEvent extends AnalyticsEvent {
  const RatePromptShownEvent({required this.trigger});

  final String trigger;

  @override
  String get eventName => 'rate_prompt_shown';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'trigger': trigger};
  }
}

class RatePromptResultEvent extends AnalyticsEvent {
  const RatePromptResultEvent({required this.result});

  final String result;

  @override
  String get eventName => 'rate_prompt_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'result': result};
  }
}

class SettingsRowTappedEvent extends AnalyticsEvent {
  const SettingsRowTappedEvent({required this.row});

  final String row;

  @override
  String get eventName => 'settings_row_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'row': row};
  }
}

class DataSaverToggledEvent extends AnalyticsEvent {
  const DataSaverToggledEvent({required this.value});

  final bool value;

  @override
  String get eventName => 'data_saver_toggled';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'value': value ? 1 : 0};
  }
}

class AdLoadResultEvent extends AnalyticsEvent {
  const AdLoadResultEvent({required this.result, this.reason});

  final String result;
  final String? reason;

  @override
  String get eventName => 'ad_load_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'result': result, if (reason != null) 'reason': reason!};
  }
}

class AdShowResultEvent extends AnalyticsEvent {
  const AdShowResultEvent({required this.result, this.reason});

  final String result;
  final String? reason;

  @override
  String get eventName => 'ad_show_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'result': result, if (reason != null) 'reason': reason!};
  }
}

class AdConsentResultEvent extends AnalyticsEvent {
  const AdConsentResultEvent({required this.status});

  final String status;

  @override
  String get eventName => 'ad_consent_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'status': status};
  }
}

class DownloadAttemptEvent extends AnalyticsEvent {
  const DownloadAttemptEvent({
    this.requestId,
    required this.source,
    required this.premium,
    this.operationId,
    this.itemId,
    this.provider,
  });

  final String? requestId;
  final String source;
  final bool premium;
  final String? operationId;
  final String? itemId;
  final String? provider;

  @override
  String get eventName => 'download_attempt';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (requestId != null) 'request_id': requestId!,
      'source': source,
      'premium': premium ? 1 : 0,
      if (operationId != null) 'operation_id': operationId!,
      if (itemId != null) 'item_id': itemId!,
      if (provider != null) 'provider': provider!,
    };
  }
}

class DownloadResultEvent extends AnalyticsEvent {
  const DownloadResultEvent({
    this.requestId,
    required this.result,
    this.reason,
    required this.stage,
    this.operationId,
    this.itemId,
    this.provider,
    this.source,
  });

  final String? requestId;
  final String result;
  final String? reason;
  final String stage;
  final String? operationId;
  final String? itemId;
  final String? provider;
  final String? source;

  @override
  String get eventName => 'download_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (requestId != null) 'request_id': requestId!,
      'result': result,
      if (reason != null) 'reason': reason!,
      'stage': stage,
      if (operationId != null) 'operation_id': operationId!,
      if (itemId != null) 'item_id': itemId!,
      if (provider != null) 'provider': provider!,
      if (source != null) 'source': source!,
    };
  }
}

class UploadMetadataSubmittedEvent extends AnalyticsEvent {
  const UploadMetadataSubmittedEvent({required this.hasTitle, required this.tagCount, required this.category});

  final bool hasTitle;
  final int tagCount;
  final String category;

  @override
  String get eventName => 'upload_metadata_submitted';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'has_title': hasTitle ? 1 : 0, 'tag_count': tagCount, 'category': category};
  }
}

class FollowResultEvent extends AnalyticsEvent {
  const FollowResultEvent({required this.action, required this.result, this.creatorId, this.source});

  final String action;
  final String result;
  final String? creatorId;
  final String? source;

  @override
  String get eventName => 'follow_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'action': action,
      'result': result,
      if (creatorId != null) 'creator_id': creatorId!,
      if (source != null) 'source': source!,
    };
  }
}

class UploadStageEvent extends AnalyticsEvent {
  const UploadStageEvent({required this.stage});

  final String stage;

  @override
  String get eventName => 'upload_stage';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'stage': stage};
  }
}

class UploadFailedEvent extends AnalyticsEvent {
  const UploadFailedEvent({required this.reason});

  final String reason;

  @override
  String get eventName => 'upload_failed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'reason': reason};
  }
}

class OnboardingStartedEvent extends AnalyticsEvent {
  const OnboardingStartedEvent();

  @override
  String get eventName => 'onboarding_started';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class TermsAcceptedEvent extends AnalyticsEvent {
  const TermsAcceptedEvent();

  @override
  String get eventName => 'terms_accepted';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class BrowseAsGuestTappedEvent extends AnalyticsEvent {
  const BrowseAsGuestTappedEvent();

  @override
  String get eventName => 'browse_as_guest_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class OnboardingStepCompletedEvent extends AnalyticsEvent {
  const OnboardingStepCompletedEvent({required this.step});

  final String step;

  @override
  String get eventName => 'onboarding_step_completed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'step': step};
  }
}

class FolderCreatedEvent extends AnalyticsEvent {
  const FolderCreatedEvent({required this.source, required this.withWall});

  final String source;
  final bool withWall;

  @override
  String get eventName => 'folder_created';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'with_wall': withWall ? 1 : 0};
  }
}

class WallSavedToFolderEvent extends AnalyticsEvent {
  const WallSavedToFolderEvent({required this.wallId, required this.provider, required this.folderCount});

  final String wallId;
  final String provider;
  final int folderCount;

  @override
  String get eventName => 'wall_saved_to_folder';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wall_id': wallId, 'provider': provider, 'folder_count': folderCount};
  }
}

class FolderOpenedEvent extends AnalyticsEvent {
  const FolderOpenedEvent({required this.source, required this.itemCount});

  final String source;
  final int itemCount;

  @override
  String get eventName => 'folder_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'item_count': itemCount};
  }
}

class FolderVisibilityChangedEvent extends AnalyticsEvent {
  const FolderVisibilityChangedEvent({required this.isPublic, required this.source});

  final bool isPublic;
  final String source;

  @override
  String get eventName => 'folder_visibility_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'is_public': isPublic ? 1 : 0, 'source': source};
  }
}

class PublicFolderViewedEvent extends AnalyticsEvent {
  const PublicFolderViewedEvent({required this.source, required this.itemCount});

  final String source;
  final int itemCount;

  @override
  String get eventName => 'public_folder_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'item_count': itemCount};
  }
}

class FolderFollowChangedEvent extends AnalyticsEvent {
  const FolderFollowChangedEvent({required this.following, required this.source});

  final bool following;
  final String source;

  @override
  String get eventName => 'folder_follow_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'following': following ? 1 : 0, 'source': source};
  }
}

class FolderSharedEvent extends AnalyticsEvent {
  const FolderSharedEvent({required this.source});

  final String source;

  @override
  String get eventName => 'folder_shared';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source};
  }
}

class FolderPushOpenedEvent extends AnalyticsEvent {
  const FolderPushOpenedEvent({required this.folderCount});

  final int folderCount;

  @override
  String get eventName => 'folder_push_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'folder_count': folderCount};
  }
}

class MoodChipTappedEvent extends AnalyticsEvent {
  const MoodChipTappedEvent({required this.moodId, required this.position});

  final String moodId;
  final int position;

  @override
  String get eventName => 'mood_chip_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'mood_id': moodId, 'position': position};
  }
}

class MoodRowSeenEvent extends AnalyticsEvent {
  const MoodRowSeenEvent({required this.moodId, required this.slot});

  final String moodId;
  final int slot;

  @override
  String get eventName => 'mood_row_seen';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'mood_id': moodId, 'slot': slot};
  }
}

class MoodPageOpenedEvent extends AnalyticsEvent {
  const MoodPageOpenedEvent({required this.moodId, required this.source});

  final String moodId;
  final String source;

  @override
  String get eventName => 'mood_page_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'mood_id': moodId, 'source': source};
  }
}

class GalleryOpenedEvent extends AnalyticsEvent {
  const GalleryOpenedEvent({required this.source, required this.wallCount});

  final String source;
  final int wallCount;

  @override
  String get eventName => 'gallery_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source, 'wall_count': wallCount};
  }
}

class LibraryTabViewedEvent extends AnalyticsEvent {
  const LibraryTabViewedEvent({required this.tab});

  final String tab;

  @override
  String get eventName => 'library_tab_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'tab': tab};
  }
}

class LibraryHistorySetAgainEvent extends AnalyticsEvent {
  const LibraryHistorySetAgainEvent({required this.provider, required this.target});

  final String provider;
  final String target;

  @override
  String get eventName => 'library_history_set_again';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'provider': provider, 'target': target};
  }
}

class LibraryHistoryClearedEvent extends AnalyticsEvent {
  const LibraryHistoryClearedEvent({required this.count});

  final int count;

  @override
  String get eventName => 'library_history_cleared';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count': count};
  }
}

class RecentlyViewedClearedEvent extends AnalyticsEvent {
  const RecentlyViewedClearedEvent({required this.count});

  final int count;

  @override
  String get eventName => 'recently_viewed_cleared';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count': count};
  }
}

class ViewingHistoryToggledEvent extends AnalyticsEvent {
  const ViewingHistoryToggledEvent({required this.value});

  final bool value;

  @override
  String get eventName => 'viewing_history_toggled';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'value': value ? 1 : 0};
  }
}

class HistoryRestoredEvent extends AnalyticsEvent {
  const HistoryRestoredEvent({required this.countBucket});

  final String countBucket;

  @override
  String get eventName => 'history_restored';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count_bucket': countBucket};
  }
}

class PickUpRowSeenEvent extends AnalyticsEvent {
  const PickUpRowSeenEvent({required this.count});

  final int count;

  @override
  String get eventName => 'pick_up_row_seen';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count': count};
  }
}

class PickUpTileOpenedEvent extends AnalyticsEvent {
  const PickUpTileOpenedEvent({required this.provider, required this.position});

  final String provider;
  final int position;

  @override
  String get eventName => 'pick_up_tile_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'provider': provider, 'position': position};
  }
}

class FavouritesExportedEvent extends AnalyticsEvent {
  const FavouritesExportedEvent({required this.count});

  final int count;

  @override
  String get eventName => 'favourites_exported';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count': count};
  }
}

class SetWallUndoneEvent extends AnalyticsEvent {
  const SetWallUndoneEvent({required this.wallpaperTarget, required this.result});

  final WallpaperTarget wallpaperTarget;
  final BinaryResultValue result;

  @override
  String get eventName => 'set_wall_undone';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wallpaper_target': wallpaperTarget.wireValue, 'result': result.wireValue};
  }
}

class SetWallPairEvent extends AnalyticsEvent {
  const SetWallPairEvent({required this.homeSource, required this.lockSource, required this.result});

  final String homeSource;
  final String lockSource;
  final String result;

  @override
  String get eventName => 'set_wall_pair';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'home_source': homeSource, 'lock_source': lockSource, 'result': result};
  }
}

class WallpaperPositionOpenedEvent extends AnalyticsEvent {
  const WallpaperPositionOpenedEvent({required this.source});

  final String source;

  @override
  String get eventName => 'wallpaper_position_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source};
  }
}

class WallpaperPlacementAppliedEvent extends AnalyticsEvent {
  const WallpaperPlacementAppliedEvent({
    required this.fit,
    required this.zoomed,
    required this.dimBucket,
    required this.wallpaperTarget,
    required this.result,
  });

  final String fit;
  final bool zoomed;
  final int dimBucket;
  final WallpaperTarget wallpaperTarget;
  final BinaryResultValue result;

  @override
  String get eventName => 'wallpaper_placement_applied';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'fit': fit,
      'zoomed': zoomed ? 1 : 0,
      'dim_bucket': dimBucket,
      'wallpaper_target': wallpaperTarget.wireValue,
      'result': result.wireValue,
    };
  }
}

class AccentMatchedFromWallEvent extends AnalyticsEvent {
  const AccentMatchedFromWallEvent();

  @override
  String get eventName => 'accent_matched_from_wall';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class LiveWallpaperAppliedEvent extends AnalyticsEvent {
  const LiveWallpaperAppliedEvent({required this.style, required this.result});

  final LiveWallpaperStyleValue style;
  final String result;

  @override
  String get eventName => 'live_wallpaper_applied';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'style': style.wireValue, 'result': result};
  }
}

class AutoRotateRunResultEvent extends AnalyticsEvent {
  const AutoRotateRunResultEvent({required this.result});

  final BinaryResultValue result;

  @override
  String get eventName => 'auto_rotate_run_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'result': result.wireValue};
  }
}

class SpinWheelSpunEvent extends AnalyticsEvent {
  const SpinWheelSpunEvent({
    required this.free,
    required this.cost,
    required this.segment,
    required this.prize,
    required this.coins,
    required this.xp,
  });

  final bool free;
  final int cost;
  final int segment;
  final String prize;
  final int coins;
  final int xp;

  @override
  String get eventName => 'spin_wheel_spun';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'free': free ? 1 : 0,
      'cost': cost,
      'segment': segment,
      'prize': prize,
      'coins': coins,
      'xp': xp,
    };
  }
}

class DailyChestOpenedEvent extends AnalyticsEvent {
  const DailyChestOpenedEvent({
    required this.free,
    required this.cost,
    required this.slot,
    required this.prize,
    required this.tier,
    required this.coins,
    required this.xp,
    required this.doubled,
  });

  final bool free;
  final int cost;
  final int slot;
  final String prize;
  final String tier;
  final int coins;
  final int xp;
  final bool doubled;

  @override
  String get eventName => 'daily_chest_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'free': free ? 1 : 0,
      'cost': cost,
      'slot': slot,
      'prize': prize,
      'tier': tier,
      'coins': coins,
      'xp': xp,
      'doubled': doubled ? 1 : 0,
    };
  }
}

class QuestProgressedEvent extends AnalyticsEvent {
  const QuestProgressedEvent({
    required this.questId,
    required this.event,
    required this.progress,
    required this.target,
  });

  final String questId;
  final String event;
  final int progress;
  final int target;

  @override
  String get eventName => 'quest_progressed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'quest_id': questId, 'event': event, 'progress': progress, 'target': target};
  }
}

class QuestCompletedEvent extends AnalyticsEvent {
  const QuestCompletedEvent({required this.questId, required this.coins, required this.xp});

  final String questId;
  final int coins;
  final int xp;

  @override
  String get eventName => 'quest_completed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'quest_id': questId, 'coins': coins, 'xp': xp};
  }
}

class ShopItemPurchasedEvent extends AnalyticsEvent {
  const ShopItemPurchasedEvent({required this.itemId, required this.price});

  final String itemId;
  final int price;

  @override
  String get eventName => 'shop_item_purchased';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'item_id': itemId, 'price': price};
  }
}

class CosmeticEquippedEvent extends AnalyticsEvent {
  const CosmeticEquippedEvent({required this.slot, this.itemId});

  final String slot;
  final String? itemId;

  @override
  String get eventName => 'cosmetic_equipped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'slot': slot, if (itemId != null) 'item_id': itemId!};
  }
}

class DropViewedEvent extends AnalyticsEvent {
  const DropViewedEvent({required this.weekKey});

  final String weekKey;

  @override
  String get eventName => 'drop_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'week_key': weekKey};
  }
}

class DropUnlockedEvent extends AnalyticsEvent {
  const DropUnlockedEvent({required this.weekKey, required this.pack, required this.count, required this.price});

  final String weekKey;
  final bool pack;
  final int count;
  final int price;

  @override
  String get eventName => 'drop_unlocked';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'week_key': weekKey, 'pack': pack ? 1 : 0, 'count': count, 'price': price};
  }
}

class BoostPurchasedEvent extends AnalyticsEvent {
  const BoostPurchasedEvent({required this.wallId});

  final String wallId;

  @override
  String get eventName => 'boost_purchased';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wall_id': wallId};
  }
}

class GiftSentEvent extends AnalyticsEvent {
  const GiftSentEvent({required this.recipientUid});

  final String recipientUid;

  @override
  String get eventName => 'gift_sent';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'recipient_uid': recipientUid};
  }
}

class DrawTicketBoughtEvent extends AnalyticsEvent {
  const DrawTicketBoughtEvent({required this.weekKey, required this.tickets});

  final String weekKey;
  final int tickets;

  @override
  String get eventName => 'draw_ticket_bought';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'week_key': weekKey, 'tickets': tickets};
  }
}

class LeaderboardViewedEvent extends AnalyticsEvent {
  const LeaderboardViewedEvent({required this.tab});

  final String tab;

  @override
  String get eventName => 'leaderboard_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'tab': tab};
  }
}

class RankUpEvent extends AnalyticsEvent {
  const RankUpEvent({required this.rank, required this.xp});

  final String rank;
  final int xp;

  @override
  String get eventName => 'rank_up';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'rank': rank, 'xp': xp};
  }
}

class WallpaperImpressionEvent extends AnalyticsEvent {
  const WallpaperImpressionEvent({
    required this.itemId,
    required this.provider,
    required this.surface,
    required this.requestId,
    required this.index,
    required this.source,
    this.rankingVersion,
  });

  final String itemId;
  final String provider;
  final String surface;
  final String requestId;
  final int index;
  final String source;
  final String? rankingVersion;

  @override
  String get eventName => 'wallpaper_impression';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'item_id': itemId,
      'provider': provider,
      'surface': surface,
      'request_id': requestId,
      'index': index,
      'source': source,
      if (rankingVersion != null) 'ranking_version': rankingVersion!,
    };
  }
}

class PurchaseVerifiedEvent extends AnalyticsEvent {
  const PurchaseVerifiedEvent({
    this.source,
    this.placement,
    required this.productId,
    required this.restored,
    this.amount,
    this.currency,
    this.transactionId,
  });

  final String? source;
  final String? placement;
  final String productId;
  final bool restored;
  final num? amount;
  final String? currency;
  final String? transactionId;

  @override
  String get eventName => 'purchase_verified';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      if (source != null) 'source': source!,
      if (placement != null) 'placement': placement!,
      'product_id': productId,
      'restored': restored ? 1 : 0,
      if (amount != null) 'amount': amount!,
      if (currency != null) 'currency': currency!,
      if (transactionId != null) 'transaction_id': transactionId!,
    };
  }
}

class ReferralResultEvent extends AnalyticsEvent {
  const ReferralResultEvent({
    required this.outcome,
    required this.role,
    this.operationId,
    this.referralId,
    this.reason,
    this.referrerId,
    this.refereeId,
  });

  final String outcome;
  final String role;
  final String? operationId;
  final String? referralId;
  final String? reason;
  final String? referrerId;
  final String? refereeId;

  @override
  String get eventName => 'referral_result';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'outcome': outcome,
      'role': role,
      if (operationId != null) 'operation_id': operationId!,
      if (referralId != null) 'referral_id': referralId!,
      if (reason != null) 'reason': reason!,
      if (referrerId != null) 'referrer_id': referrerId!,
      if (refereeId != null) 'referee_id': refereeId!,
    };
  }
}

class StreakLifecycleEvent extends AnalyticsEvent {
  const StreakLifecycleEvent({
    required this.action,
    required this.streakCount,
    this.previousCount,
    this.coins,
    this.result,
    this.freezesUsed,
    this.freezesLeft,
    this.milestone,
  });

  final String action;
  final int streakCount;
  final int? previousCount;
  final int? coins;
  final String? result;
  final int? freezesUsed;
  final int? freezesLeft;
  final int? milestone;

  @override
  String get eventName => 'streak_lifecycle';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{
      'action': action,
      'streak_count': streakCount,
      if (previousCount != null) 'previous_count': previousCount!,
      if (coins != null) 'coins': coins!,
      if (result != null) 'result': result!,
      if (freezesUsed != null) 'freezes_used': freezesUsed!,
      if (freezesLeft != null) 'freezes_left': freezesLeft!,
      if (milestone != null) 'milestone': milestone!,
    };
  }
}

class SpatialPreviewOpenedEvent extends AnalyticsEvent {
  const SpatialPreviewOpenedEvent({required this.wallId, required this.tilt});

  final String wallId;
  final String tilt;

  @override
  String get eventName => 'spatial_preview_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wall_id': wallId, 'tilt': tilt};
  }
}

class SpatialGuideOpenedEvent extends AnalyticsEvent {
  const SpatialGuideOpenedEvent({required this.wallId, required this.tier});

  final String wallId;
  final String tier;

  @override
  String get eventName => 'spatial_guide_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'wall_id': wallId, 'tier': tier};
  }
}

class DetailImmersiveToggledEvent extends AnalyticsEvent {
  const DetailImmersiveToggledEvent({required this.immersive, required this.source});

  final bool immersive;
  final ImmersiveToggleSourceValue source;

  @override
  String get eventName => 'detail_immersive_toggled';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'immersive': immersive ? 1 : 0, 'source': source.wireValue};
  }
}

class DetailImmersiveHintShownEvent extends AnalyticsEvent {
  const DetailImmersiveHintShownEvent();

  @override
  String get eventName => 'detail_immersive_hint_shown';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class FavouritePinChangedEvent extends AnalyticsEvent {
  const FavouritePinChangedEvent({required this.pinned, required this.surface});

  final bool pinned;
  final FavouritePinSurfaceValue surface;

  @override
  String get eventName => 'favourite_pin_changed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'pinned': pinned ? 1 : 0, 'surface': surface.wireValue};
  }
}

class FavouritePinLimitHitEvent extends AnalyticsEvent {
  const FavouritePinLimitHitEvent({required this.surface});

  final FavouritePinSurfaceValue surface;

  @override
  String get eventName => 'favourite_pin_limit_hit';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'surface': surface.wireValue};
  }
}

class WallRequestSheetOpenedEvent extends AnalyticsEvent {
  const WallRequestSheetOpenedEvent({required this.source});

  final WallRequestSourceValue source;

  @override
  String get eventName => 'wall_request_sheet_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source.wireValue};
  }
}

class WallRequestCreatedEvent extends AnalyticsEvent {
  const WallRequestCreatedEvent({required this.source, required this.tagCount, required this.forced});

  final WallRequestSourceValue source;
  final int tagCount;
  final bool forced;

  @override
  String get eventName => 'wall_request_created';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source': source.wireValue, 'tag_count': tagCount, 'forced': forced ? 1 : 0};
  }
}

class WallRequestDuplicateUpvotedEvent extends AnalyticsEvent {
  const WallRequestDuplicateUpvotedEvent({required this.exact});

  final bool exact;

  @override
  String get eventName => 'wall_request_duplicate_upvoted';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'exact': exact ? 1 : 0};
  }
}

class WallRequestVoteToggledEvent extends AnalyticsEvent {
  const WallRequestVoteToggledEvent({required this.voted, required this.tab});

  final bool voted;
  final String tab;

  @override
  String get eventName => 'wall_request_vote_toggled';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'voted': voted ? 1 : 0, 'tab': tab};
  }
}

class WallRequestFilledEvent extends AnalyticsEvent {
  const WallRequestFilledEvent({required this.filledBy});

  final WallRequestFillerValue filledBy;

  @override
  String get eventName => 'wall_request_filled';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'filled_by': filledBy.wireValue};
  }
}

class WallRequestPushOpenedEvent extends AnalyticsEvent {
  const WallRequestPushOpenedEvent({required this.requestId});

  final String requestId;

  @override
  String get eventName => 'wall_request_push_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'request_id': requestId};
  }
}

class RemixTappedEvent extends AnalyticsEvent {
  const RemixTappedEvent({required this.sourceWallType});

  final RemixSourceType sourceWallType;

  @override
  String get eventName => 'remix_tapped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_wall_type': sourceWallType.wireValue};
  }
}

class RemixGeneratedEvent extends AnalyticsEvent {
  const RemixGeneratedEvent({required this.sourceWallType, required this.quality});

  final RemixSourceType sourceWallType;
  final String quality;

  @override
  String get eventName => 'remix_generated';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_wall_type': sourceWallType.wireValue, 'quality': quality};
  }
}

class RemixSubmittedEvent extends AnalyticsEvent {
  const RemixSubmittedEvent({required this.generationId});

  final String generationId;

  @override
  String get eventName => 'remix_submitted';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'generation_id': generationId};
  }
}

class RemixLinkDroppedEvent extends AnalyticsEvent {
  const RemixLinkDroppedEvent({required this.sourceWallType});

  final RemixSourceType sourceWallType;

  @override
  String get eventName => 'remix_link_dropped';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'source_wall_type': sourceWallType.wireValue};
  }
}

class RemixesGridOpenedEvent extends AnalyticsEvent {
  const RemixesGridOpenedEvent({required this.count});

  final int count;

  @override
  String get eventName => 'remixes_grid_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'count': count};
  }
}

class DailyMomentShownEvent extends AnalyticsEvent {
  const DailyMomentShownEvent();

  @override
  String get eventName => 'daily_moment_shown';

  @override
  Map<String, Object?> toWireParameters() {
    return const <String, Object?>{};
  }
}

class DailyMomentStepDoneEvent extends AnalyticsEvent {
  const DailyMomentStepDoneEvent({required this.step});

  final DailyMomentStepValue step;

  @override
  String get eventName => 'daily_moment_step_done';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'step': step.wireValue};
  }
}

class DailyMomentStoppedEarlyEvent extends AnalyticsEvent {
  const DailyMomentStoppedEarlyEvent({required this.step});

  final DailyMomentStepValue step;

  @override
  String get eventName => 'daily_moment_stopped_early';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'step': step.wireValue};
  }
}

class DailyMomentDeepLinkOpenedEvent extends AnalyticsEvent {
  const DailyMomentDeepLinkOpenedEvent({required this.step});

  final DailyMomentStepValue step;

  @override
  String get eventName => 'daily_moment_deep_link_opened';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'step': step.wireValue};
  }
}

class ChallengeViewedEvent extends AnalyticsEvent {
  const ChallengeViewedEvent({required this.challengeId});

  final String challengeId;

  @override
  String get eventName => 'challenge_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'challenge_id': challengeId};
  }
}

class ChallengeEnteredEvent extends AnalyticsEvent {
  const ChallengeEnteredEvent({required this.challengeId, required this.source});

  final String challengeId;
  final ChallengeEntrySource source;

  @override
  String get eventName => 'challenge_entered';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'challenge_id': challengeId, 'source': source.wireValue};
  }
}

class ChallengeVotedEvent extends AnalyticsEvent {
  const ChallengeVotedEvent({required this.challengeId});

  final String challengeId;

  @override
  String get eventName => 'challenge_voted';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'challenge_id': challengeId};
  }
}

class ChallengeUnvotedEvent extends AnalyticsEvent {
  const ChallengeUnvotedEvent({required this.challengeId});

  final String challengeId;

  @override
  String get eventName => 'challenge_unvoted';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'challenge_id': challengeId};
  }
}

class ChallengeSharedEvent extends AnalyticsEvent {
  const ChallengeSharedEvent({required this.challengeId});

  final String challengeId;

  @override
  String get eventName => 'challenge_shared';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'challenge_id': challengeId};
  }
}

class ChallengeWinnerViewedEvent extends AnalyticsEvent {
  const ChallengeWinnerViewedEvent({required this.challengeId});

  final String challengeId;

  @override
  String get eventName => 'challenge_winner_viewed';

  @override
  Map<String, Object?> toWireParameters() {
    return <String, Object?>{'challenge_id': challengeId};
  }
}
