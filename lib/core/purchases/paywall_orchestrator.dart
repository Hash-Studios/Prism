import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/main.dart' as main;
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
}

class PaywallOrchestrator {
  PaywallOrchestrator._();

  static final PaywallOrchestrator instance = PaywallOrchestrator._();

  static const int _adWatchThreshold = 3;
  static const String _adWatchCountKey = 'paywall_ad_watch_count';
  static const String _adWatchPromptedKey = 'paywall_ad_watch_prompted';

  bool get _rcPaywallsEnabled => globals.useRcPaywalls;

  Future<void> present(BuildContext context, {required String placement, required String source}) async {
    final String normalizedPlacement = placement.trim().isEmpty ? PaywallPlacement.mainUpsell : placement.trim();
    _logPlacementTriggerContext(placement: normalizedPlacement, source: source);
    analytics.logEvent(
      name: 'paywall_impression',
      parameters: <String, Object>{
        'source': source,
        'placement': normalizedPlacement,
        'rc_or_fallback': _rcPaywallsEnabled ? 'rc_attempt' : 'fallback_only',
      },
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
    analytics.logEvent(
      name: 'paywall_impression',
      parameters: <String, Object>{'source': source, 'placement': normalizedPlacement, 'rc_or_fallback': 'fallback'},
    );
  }

  Future<void> recordRewardedAdWatchAndMaybeUpsell(BuildContext context, {required String source}) async {
    if (globals.prismUser.premium) {
      _resetAdWatchCounter();
      return;
    }

    final int count = ((main.prefs.get(_adWatchCountKey, defaultValue: 0) as int?) ?? 0) + 1;
    main.prefs.put(_adWatchCountKey, count);
    final bool prompted = (main.prefs.get(_adWatchPromptedKey, defaultValue: false) as bool?) ?? false;
    if (count < _adWatchThreshold || prompted) {
      return;
    }
    main.prefs.put(_adWatchPromptedKey, true);
    await present(context, placement: PaywallPlacement.afterAdWatch3, source: source);
  }

  void _resetAdWatchCounter() {
    main.prefs.put(_adWatchCountKey, 0);
    main.prefs.put(_adWatchPromptedKey, false);
  }

  void _logPlacementTriggerContext({required String placement, required String source}) {
    switch (placement) {
      case PaywallPlacement.lowBalance:
        analytics.logEvent(
          name: 'subscription_trigger_low_balance',
          parameters: <String, Object>{'source': source, 'placement': placement},
        );
        return;
      case PaywallPlacement.afterAdWatch3:
        analytics.logEvent(
          name: 'subscription_trigger_after_ad_watch_3',
          parameters: <String, Object>{'source': source, 'placement': placement},
        );
        return;
      case PaywallPlacement.blockedSetupCreate:
        analytics.logEvent(
          name: 'subscription_trigger_setup_create_block',
          parameters: <String, Object>{'source': source, 'placement': placement},
        );
        return;
      case PaywallPlacement.uploadLimitReached:
        analytics.logEvent(
          name: 'subscription_trigger_upload_limit_block',
          parameters: <String, Object>{'source': source, 'placement': placement},
        );
        return;
      default:
        return;
    }
  }

  Future<bool> _presentRevenueCatPaywall({required String placement, required String source}) async {
    try {
      await PurchasesService.instance.ensureConfigured(globals.prismUser.id);
      final Offering? placementOffering = await PurchasesService.instance.getCurrentOfferingForPlacement(placement);
      final Offerings? offerings = await PurchasesService.instance.getOfferings();
      final Offering? v3Offering = offerings?.all[PurchaseConstants.offeringV3Default];
      Offering? offering;
      if (v3Offering != null) {
        offering = v3Offering;
        if (placementOffering != null && placementOffering.identifier != PurchaseConstants.offeringV3Default) {
          analytics.logEvent(
            name: 'paywall_result',
            parameters: <String, Object>{
              'source': source,
              'placement': placement,
              'result': 'placement_overridden_to_v3',
              'placement_offering': placementOffering.identifier,
              'selected_offering': v3Offering.identifier,
              'rc_or_fallback': 'rc',
            },
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
        analytics.logEvent(
          name: 'paywall_result',
          parameters: <String, Object>{
            'source': source,
            'placement': placement,
            'result': 'no_offering',
            'rc_or_fallback': 'rc',
          },
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
        analytics.logEvent(
          name: 'paywall_result',
          parameters: <String, Object>{
            'source': source,
            'placement': placement,
            'result': paywallResult.name,
            'rc_or_fallback': 'rc',
          },
        );
        return false;
      }

      final bool isPremium = await PurchasesService.instance.checkAndPersistPremium();
      if (isPremium) {
        _resetAdWatchCounter();
      }

      analytics.logEvent(
        name: 'paywall_result',
        parameters: <String, Object>{
          'source': source,
          'placement': placement,
          'result': paywallResult.name,
          'entitlement_synced': isPremium ? 1 : 0,
          'entitlement': PurchaseConstants.entitlementV3ProAccess,
          'rc_or_fallback': 'rc',
        },
      );
      return true;
    } catch (error) {
      analytics.logEvent(
        name: 'paywall_result',
        parameters: <String, Object>{
          'source': source,
          'placement': placement,
          'result': 'rc_error',
          'error': error.toString(),
          'rc_or_fallback': 'rc',
        },
      );
      return false;
    }
  }
}
