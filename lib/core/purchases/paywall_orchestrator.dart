import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class PaywallPlacement {
  const PaywallPlacement._();

  static const String mainUpsell = 'main_upsell';
  static const String lowBalance = 'low_balance';
  static const String afterAdWatch3 = 'after_ad_watch_3';
  static const String blockedSetupCreate = 'blocked_setup_create';
  static const String uploadLimitReached = 'upload_limit_reached';
  static const String onboardingCompletion = 'onboarding_completion';
}

class PaywallOrchestrator {
  PaywallOrchestrator._();

  static final PaywallOrchestrator instance = PaywallOrchestrator._();

  static const int _adWatchThreshold = 3;
  static const String _adWatchCountKey = 'paywall_ad_watch_count';
  static const String _adWatchPromptedKey = 'paywall_ad_watch_prompted';

  bool get _rcPaywallsEnabled => app_state.useRcPaywalls;
  SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  Future<void> present(BuildContext context, {required String placement, required String source}) async {
    final String normalizedPlacement = placement.trim().isEmpty ? PaywallPlacement.mainUpsell : placement.trim();
    _logPlacementTriggerContext(placement: normalizedPlacement, source: source);
    analytics.track(
      PaywallImpressionEvent(
        source: source,
        placement: normalizedPlacement,
        rcOrFallback: _rcPaywallsEnabled ? RcOrFallbackValue.rcAttempt : RcOrFallbackValue.fallbackOnly,
      ),
    );

    bool presentedByRc = false;
    if (_rcPaywallsEnabled) {
      presentedByRc = await _presentRevenueCatPaywall(placement: normalizedPlacement, source: source);
      if (presentedByRc) {
        return;
      }
    }

    if (!context.mounted) {
      return;
    }
    context.router.push(const UpgradeRoute());
    analytics.track(
      PaywallImpressionEvent(source: source, placement: normalizedPlacement, rcOrFallback: RcOrFallbackValue.fallback),
    );
  }

  Future<void> recordRewardedAdWatchAndMaybeUpsell(BuildContext context, {required String source}) async {
    if (app_state.prismUser.premium) {
      _resetAdWatchCounter();
      return;
    }

    final int count = (_settings.get<int>(_adWatchCountKey, defaultValue: 0)) + 1;
    _settings.set(_adWatchCountKey, count);
    final bool prompted = _settings.get<bool>(_adWatchPromptedKey, defaultValue: false);
    if (count < _adWatchThreshold || prompted) {
      return;
    }
    _settings.set(_adWatchPromptedKey, true);
    await present(context, placement: PaywallPlacement.afterAdWatch3, source: source);
  }

  void _resetAdWatchCounter() {
    _settings.set(_adWatchCountKey, 0);
    _settings.set(_adWatchPromptedKey, false);
  }

  void _logPlacementTriggerContext({required String placement, required String source}) {
    switch (placement) {
      case PaywallPlacement.lowBalance:
        analytics.track(SubscriptionTriggerLowBalanceEvent(source: source, placement: placement));
        return;
      case PaywallPlacement.afterAdWatch3:
        analytics.track(SubscriptionTriggerAfterAdWatch3Event(source: source, placement: placement));
        return;
      case PaywallPlacement.blockedSetupCreate:
        analytics.track(SubscriptionTriggerSetupCreateBlockEvent(source: source, placement: placement));
        return;
      case PaywallPlacement.uploadLimitReached:
        analytics.track(SubscriptionTriggerUploadLimitBlockEvent(source: source, placement: placement));
        return;
      default:
        return;
    }
  }

  Future<bool> _presentRevenueCatPaywall({required String placement, required String source}) async {
    try {
      await PurchasesService.instance.ensureConfigured(app_state.prismUser.id);
      final Offering? placementOffering = await PurchasesService.instance.getCurrentOfferingForPlacement(placement);
      final Offerings? offerings = await PurchasesService.instance.getOfferings();
      final Offering? v3Offering = offerings?.all[PurchaseConstants.offeringV3Default];
      Offering? offering;
      if (v3Offering != null) {
        offering = v3Offering;
        if (placementOffering != null && placementOffering.identifier != PurchaseConstants.offeringV3Default) {
          analytics.track(
            PaywallResultEvent(
              source: source,
              placement: placement,
              result: PaywallResultValue.placementOverriddenToV3,
              placementOffering: placementOffering.identifier,
              selectedOffering: v3Offering.identifier,
              rcOrFallback: RcOrFallbackValue.rc,
            ),
          );
        }
      } else {
        offering =
            placementOffering ??
            offerings?.all[PurchaseConstants.offeringUltra] ??
            offerings?.all[PurchaseConstants.offeringDefault] ??
            offerings?.current;
      }
      if (offering == null) {
        analytics.track(
          PaywallResultEvent(
            source: source,
            placement: placement,
            result: PaywallResultValue.noOffering,
            rcOrFallback: RcOrFallbackValue.rc,
          ),
        );
        return false;
      }

      final PaywallResult paywallResult = await RevenueCatUI.presentPaywall(
        offering: offering,
        customVariables: <String, CustomVariableValue>{
          'placement': CustomVariableValue.string(placement),
          'source': CustomVariableValue.string(source),
        },
      );

      if (paywallResult == PaywallResult.notPresented || paywallResult == PaywallResult.error) {
        analytics.track(
          PaywallResultEvent(
            source: source,
            placement: placement,
            result: paywallResultValueFromSdkName(paywallResult.name),
            rcOrFallback: RcOrFallbackValue.rc,
          ),
        );
        return false;
      }

      final bool isPremium = await PurchasesService.instance.checkAndPersistPremium(
        conversionContext: SubscriptionConversionContext(source: source, packageType: placement),
      );
      if (isPremium) {
        _resetAdWatchCounter();
      }

      analytics.track(
        PaywallResultEvent(
          source: source,
          placement: placement,
          result: paywallResultValueFromSdkName(paywallResult.name),
          entitlementSynced: isPremium ? 1 : 0,
          entitlement: PurchaseConstants.entitlementV3ProAccess,
          rcOrFallback: RcOrFallbackValue.rc,
        ),
      );
      return true;
    } catch (error) {
      analytics.track(
        PaywallResultEvent(
          source: source,
          placement: placement,
          result: PaywallResultValue.rcError,
          error: error.toString(),
          rcOrFallback: RcOrFallbackValue.rc,
        ),
      );
      return false;
    }
  }
}
