import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/purchases/annual_trial.dart';
import 'package:Prism/core/purchases/purchase_analytics.dart';
import 'package:Prism/core/purchases/purchase_constants.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/purchases/trial_reminder.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/daily_flow/daily_moment_presentation_gate.dart';
import 'package:Prism/features/in_app_notifications/views/widgets/notification_settings_sheet.dart';
import 'package:Prism/features/premium/views/pages/trial_timeline_page.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class PaywallPlacement {
  const PaywallPlacement._();

  static const String mainUpsell = 'main_upsell';
  static const String lowBalance = 'low_balance';
  static const String afterAdWatch3 = 'after_ad_watch_3';
  static const String uploadLimitReached = 'upload_limit_reached';
  static const String autoRotate = 'auto_rotate';
}

/// Tracks overlapping presentations so an early result cannot hide a paywall that is still open.
class PaywallPresentationGate {
  final ValueNotifier<bool> presenting = ValueNotifier<bool>(false);
  int _activePresentations = 0;

  Future<T> run<T>(Future<T> Function() presentation) async {
    _activePresentations++;
    presenting.value = true;
    try {
      return await presentation();
    } finally {
      _activePresentations--;
      presenting.value = _activePresentations > 0;
    }
  }

  void dispose() => presenting.dispose();
}

class PaywallOrchestrator {
  PaywallOrchestrator._();

  static final PaywallOrchestrator instance = PaywallOrchestrator._();

  static const int _adWatchThreshold = 3;
  static const String _adWatchCountKey = 'paywall_ad_watch_count';
  static const String _adWatchPromptedAtKey = 'paywall_ad_watch_prompted_at';
  static const Duration _adWatchPromptGap = Duration(hours: 24);

  /// A RevenueCat setup or offerings call that never settles must not leave the caller loading forever.
  static const Duration _loadTimeout = Duration(seconds: 10);
  static const Duration _permissionRequestTimeout = Duration(seconds: 2);
  bool get _rcPaywallsEnabled => app_state.useRcPaywalls;
  SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();
  int _activePresentations = 0;

  /// The root navigator context. The trial timeline is a Flutter page, and many callers pass no context.
  BuildContext? Function()? navigatorContext;

  /// True while a paywall is loading or on screen. Prompts that Prism opens on its own wait until it is false.
  final PaywallPresentationGate _presentationGate = PaywallPresentationGate();
  ValueListenable<bool> get presenting => _presentationGate.presenting;

  Future<PaywallResultValue> present({
    required String placement,
    required String source,
    AppLocalizations? messages,
    BuildContext? context,
  }) => _presentationGate.run(
    () => _presentSignedIn(placement: placement, source: source, messages: messages, context: context),
  );

  Future<PaywallResultValue> _presentSignedIn({
    required String placement,
    required String source,
    AppLocalizations? messages,
    BuildContext? context,
  }) async {
    if (!app_state.prismUser.loggedIn) {
      if (context == null) return PaywallResultValue.guestSignInRequired;
      final bool signedIn = await requireSignedInAction(context);
      if (!signedIn || !context.mounted) return PaywallResultValue.guestSignInRequired;
    }
    final BuildContext? presentationContext = context?.mounted == true ? context : null;
    _activePresentations++;
    DailyMomentPresentationGate.instance.purchaseActive = true;
    try {
      return await _present(placement: placement, source: source, messages: messages, context: presentationContext);
    } finally {
      _activePresentations--;
      DailyMomentPresentationGate.instance.purchaseActive = _activePresentations > 0;
    }
  }

  Future<PaywallResultValue> _present({
    required String placement,
    required String source,
    AppLocalizations? messages,
    BuildContext? context,
  }) async {
    final String normalizedPlacement = placement.trim().isEmpty ? PaywallPlacement.mainUpsell : placement.trim();
    _logPlacementTriggerContext(placement: normalizedPlacement, source: source);
    analytics.track(
      PaywallImpressionEvent(
        source: source,
        placement: normalizedPlacement,
        rcOrFallback: _rcPaywallsEnabled ? RcOrFallbackValue.rcAttempt : RcOrFallbackValue.fallbackOnly,
      ),
    );

    // Without RevenueCat paywalls there is no fallback screen.
    final PaywallResultValue result = _rcPaywallsEnabled
        ? await _presentRevenueCatPaywall(placement: normalizedPlacement, source: source, context: context)
        : PaywallResultValue.notPresented;
    if (_unavailableResults.contains(result)) {
      final AppLocalizations localized = messages ?? await loadDeviceAppLocalizations();
      toasts.error(localized.premiumPagePlansUnavailable);
    }
    return result;
  }

  static const Set<PaywallResultValue> _unavailableResults = <PaywallResultValue>{
    PaywallResultValue.notPresented,
    PaywallResultValue.noOffering,
    PaywallResultValue.rcError,
  };

  Future<PaywallResultValue?> presentOrRequireSignIn(
    BuildContext context, {
    required String placement,
    required String source,
  }) async {
    if (!await requireSignedInAction(context)) return null;
    if (!context.mounted) return null;
    return present(placement: placement, source: source, messages: AppLocalizations.of(context), context: context);
  }

  Future<void> recordRewardedAdWatchAndMaybeUpsell({required String source}) async {
    if (app_state.prismUser.premium) {
      _resetAdWatchCounter();
      return;
    }

    final int count = (_settings.get<int>(_adWatchCountKey, defaultValue: 0)) + 1;
    _settings.set(_adWatchCountKey, count);
    final int promptedAtMs = _settings.get<int>(_adWatchPromptedAtKey, defaultValue: 0);
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    if (count < _adWatchThreshold || nowMs - promptedAtMs < _adWatchPromptGap.inMilliseconds) {
      return;
    }
    _settings.set(_adWatchPromptedAtKey, nowMs);
    await present(placement: PaywallPlacement.afterAdWatch3, source: source);
  }

  void _resetAdWatchCounter() {
    _settings.set(_adWatchCountKey, 0);
    _settings.delete(_adWatchPromptedAtKey);
  }

  void _logPlacementTriggerContext({required String placement, required String source}) {
    switch (placement) {
      case PaywallPlacement.lowBalance:
        analytics.track(SubscriptionTriggerLowBalanceEvent(source: source, placement: placement));
        return;
      case PaywallPlacement.afterAdWatch3:
        analytics.track(SubscriptionTriggerAfterAdWatch3Event(source: source, placement: placement));
        return;
      case PaywallPlacement.uploadLimitReached:
        analytics.track(SubscriptionTriggerUploadLimitBlockEvent(source: source, placement: placement));
        return;
      default:
        return;
    }
  }

  Future<PaywallResultValue> _presentRevenueCatPaywall({
    required String placement,
    required String source,
    BuildContext? context,
  }) async {
    final String requestedUserId = app_state.prismUser.id.trim();
    final bool requestedLoggedIn = app_state.prismUser.loggedIn;
    bool isCurrentAccount() =>
        requestedUserId == app_state.prismUser.id.trim() && requestedLoggedIn == app_state.prismUser.loggedIn;
    try {
      await PurchasesService.instance.ensureConfigured(requestedUserId).timeout(_loadTimeout);
      if (!isCurrentAccount()) return PaywallResultValue.error;
      final Offering? placementOffering = await PurchasesService.instance
          .getCurrentOfferingForPlacement(placement)
          .timeout(_loadTimeout);
      final Offerings? offerings = await PurchasesService.instance.getOfferings().timeout(_loadTimeout);
      if (!isCurrentAccount()) return PaywallResultValue.error;
      // Never substitute legacy pricing when the v3 catalog is unavailable.
      final Offering? offering = offerings?.all[PurchaseConstants.offeringV3Default];
      if (offering != null &&
          placementOffering != null &&
          placementOffering.identifier != PurchaseConstants.offeringV3Default) {
        analytics.track(
          PaywallResultEvent(
            source: source,
            placement: placement,
            result: PaywallResultValue.placementOverriddenToV3,
            placementOffering: placementOffering.identifier,
            selectedOffering: offering.identifier,
            rcOrFallback: RcOrFallbackValue.rc,
          ),
        );
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
        return PaywallResultValue.noOffering;
      }

      PaywallResultValue? timelineResult;
      final TrialOfferLookup trial = await PurchasesService.instance
          .trialOffer(offering)
          .timeout(_loadTimeout, onTimeout: () => (offer: null, reason: TrialUnavailableReason.eligibilityUnknown));
      if (!isCurrentAccount()) return PaywallResultValue.error;
      final TrialOffer? trialOffer = trial.offer;
      final BuildContext? timelineContext = navigatorContext?.call() ?? context;
      if (trialOffer != null && timelineContext != null && timelineContext.mounted) {
        timelineResult = await _presentTrialTimeline(
          timelineContext,
          offer: trialOffer,
          placement: placement,
          source: source,
          isCurrentAccount: isCurrentAccount,
        );
        if (!isCurrentAccount()) return PaywallResultValue.error;
        if (timelineResult == PaywallResultValue.cancelled) {
          analytics.track(
            PaywallResultEvent(
              source: source,
              placement: placement,
              result: PaywallResultValue.cancelled,
              rcOrFallback: RcOrFallbackValue.rc,
            ),
          );
          return isCurrentAccount() ? PaywallResultValue.cancelled : PaywallResultValue.error;
        }
      } else if (trial.reason != null && trial.reason != TrialUnavailableReason.noAnnualPackage) {
        analytics.track(TrialNotEligibleShownEvent(source: source, placement: placement, reason: trial.reason!.name));
      }

      if (!isCurrentAccount()) return PaywallResultValue.error;
      final PaywallResultValue resultValue =
          timelineResult ?? await _presentRevenueCatSheet(offering, placement: placement, source: source);
      if (resultValue == PaywallResultValue.notPresented || resultValue == PaywallResultValue.error) {
        analytics.track(
          PaywallResultEvent(
            source: source,
            placement: placement,
            result: resultValue,
            rcOrFallback: RcOrFallbackValue.rc,
          ),
        );
        return isCurrentAccount() ? resultValue : PaywallResultValue.error;
      }

      final bool completed = resultValue == PaywallResultValue.purchased || resultValue == PaywallResultValue.restored;
      final PurchaseEntitlementStatus status = isCurrentAccount() && completed
          ? await PurchasesService.instance.checkPurchaseEntitlement()
          : PurchaseEntitlementStatus.none;
      final bool confirmedForCurrentAccount = isCurrentAccount() && status == PurchaseEntitlementStatus.serverConfirmed;
      if (confirmedForCurrentAccount) {
        _resetAdWatchCounter();
      }

      analytics.track(
        PaywallResultEvent(
          source: source,
          placement: placement,
          result: resultValue,
          entitlementSynced: confirmedForCurrentAccount ? 1 : 0,
          entitlement: PurchaseConstants.entitlementV3ProAccess,
          rcOrFallback: RcOrFallbackValue.rc,
        ),
      );
      if (!isCurrentAccount()) return PaywallResultValue.error;
      if (completed && status == PurchaseEntitlementStatus.guestSignInRequired) {
        final AppLocalizations l10n = await loadDeviceAppLocalizations();
        if (!isCurrentAccount()) return PaywallResultValue.error;
        toasts.info(l10n.premiumGuestStorePurchaseActive);
        return PaywallResultValue.guestSignInRequired;
      }
      if (completed && !confirmedForCurrentAccount) {
        final AppLocalizations l10n = await loadDeviceAppLocalizations();
        if (app_state.prismUser.premium) {
          toasts.info(l10n.premiumPurchasePending);
        } else {
          toasts.error(l10n.premiumPurchaseUnconfirmed);
        }
        return PaywallResultValue.error;
      }
      return resultValue;
    } catch (error) {
      if (!isCurrentAccount()) return PaywallResultValue.error;
      analytics.track(
        PaywallResultEvent(
          source: source,
          placement: placement,
          result: PaywallResultValue.rcError,
          error: error.toString(),
          rcOrFallback: RcOrFallbackValue.rc,
        ),
      );
      return PaywallResultValue.rcError;
    }
  }

  Future<PaywallResultValue> _presentRevenueCatSheet(
    Offering offering, {
    required String placement,
    required String source,
  }) async {
    Package? selectedPackage;
    final PaywallResult paywallResult = await RevenueCatUI.presentPaywall(
      offering: offering,
      onPurchaseStarted: (package) => selectedPackage = package,
      onPurchaseCompleted: (customerInfo, transaction) =>
          _recordVerifiedPurchase(transaction, selectedPackage, customerInfo, source: source, placement: placement),
      onRestoreCompleted: (customerInfo) {
        for (final event in restoredPurchaseEvents(
          customerInfo.entitlements.active.values.map((e) => e.productIdentifier),
        )) {
          analytics.track(event);
        }
      },
      customVariables: <String, CustomVariableValue>{
        'placement': CustomVariableValue.string(placement),
        'source': CustomVariableValue.string(source),
      },
    );
    return paywallResultValueFromSdkName(paywallResult.name);
  }

  void _recordVerifiedPurchase(
    StoreTransaction transaction,
    Package? selectedPackage,
    CustomerInfo customerInfo, {
    required String source,
    required String placement,
  }) {
    const String transactionKey = 'analytics_verified_purchase_transactions';
    final List<String> recorded = List<String>.from(
      _settings.get<List<Object?>>(transactionKey, defaultValue: const <Object?>[]),
    );
    final events = verifiedPurchaseEvents(
      transaction: transaction,
      selectedPackage: selectedPackage,
      recordedTransactions: recorded,
      source: source,
      placement: placement,
      subscriptionTier: PurchasesService.instance.tierFromCustomerInfo(customerInfo).name,
    );
    if (events.isEmpty) return;
    _settings.set(transactionKey, recorded);
    for (final event in events) {
      analytics.track(event);
    }
  }

  /// Starting the trial buys the annual package from the timeline. "See all plans" returns null, so the RevenueCat
  /// paywall shows next.
  Future<PaywallResultValue?> _presentTrialTimeline(
    BuildContext context, {
    required TrialOffer offer,
    required String placement,
    required String source,
    required bool Function() isCurrentAccount,
  }) async {
    analytics.track(
      TrialTimelineShownEvent(source: source, placement: placement, productId: offer.productId, trialDays: offer.days),
    );
    await TrialReminder.instance.setOptIn(true);
    if (!context.mounted || !isCurrentAccount()) return null;
    Future<bool>? purchaseInFlight;
    final TrialTimelineChoice? choice = await Navigator.of(context, rootNavigator: true).push<TrialTimelineChoice>(
      MaterialPageRoute<TrialTimelineChoice>(
        fullscreenDialog: true,
        builder: (BuildContext pageContext) => TrialTimelinePage(
          offer: offer,
          onReminderToggled: (bool enabled) {
            analytics.track(TrialReminderToggledEvent(enabled: enabled));
            unawaited(TrialReminder.instance.setOptIn(enabled));
          },
          onStartTrial: ({required bool remind}) => purchaseInFlight = _purchaseTrial(
            offer,
            remind: remind,
            placement: placement,
            source: source,
            isCurrentAccount: isCurrentAccount,
            isTimelineCurrent: () => pageContext.mounted && ModalRoute.of(pageContext)?.isCurrent == true,
            dismissTimeline: (TrialTimelineChoice choice) {
              if (pageContext.mounted && ModalRoute.of(pageContext)?.isCurrent == true) {
                Navigator.of(pageContext, rootNavigator: true).pop(choice);
              }
            },
          ),
        ),
      ),
    );
    if (choice == TrialTimelineChoice.closed || choice == null) {
      return await purchaseInFlight == true ? PaywallResultValue.purchased : PaywallResultValue.cancelled;
    }
    return switch (choice) {
      TrialTimelineChoice.started => PaywallResultValue.purchased,
      TrialTimelineChoice.seeAllPlans => null,
      TrialTimelineChoice.closed => PaywallResultValue.cancelled,
    };
  }

  Future<bool> _purchaseTrial(
    TrialOffer offer, {
    required bool remind,
    required String placement,
    required String source,
    required bool Function() isCurrentAccount,
    required bool Function() isTimelineCurrent,
    required ValueChanged<TrialTimelineChoice> dismissTimeline,
  }) async {
    if (!isCurrentAccount()) {
      dismissTimeline(TrialTimelineChoice.closed);
      return false;
    }
    try {
      await TrialReminder.instance.setOptIn(remind);
      if (!isCurrentAccount()) {
        dismissTimeline(TrialTimelineChoice.closed);
        return false;
      }
      final Offerings? latestOfferings = await PurchasesService.instance.getOfferings().timeout(
        _loadTimeout,
        onTimeout: () => null,
      );
      if (!isCurrentAccount()) {
        dismissTimeline(TrialTimelineChoice.closed);
        return false;
      }
      if (!isTimelineCurrent()) return false;
      final Offering? latestOffering = latestOfferings?.all[PurchaseConstants.offeringV3Default];
      final TrialOfferLookup? latestLookup = latestOffering == null
          ? null
          : await PurchasesService.instance
                .trialOffer(latestOffering)
                .timeout(
                  _loadTimeout,
                  onTimeout: () => (offer: null, reason: TrialUnavailableReason.eligibilityUnknown),
                );
      if (!isCurrentAccount()) {
        dismissTimeline(TrialTimelineChoice.closed);
        return false;
      }
      if (!isTimelineCurrent()) return false;
      final TrialOffer? latestOffer = latestLookup?.offer;
      if (latestOffer == null) {
        analytics.track(
          TrialNotEligibleShownEvent(
            source: source,
            placement: placement,
            reason: latestLookup?.reason?.name ?? TrialUnavailableReason.eligibilityUnknown.name,
          ),
        );
        dismissTimeline(TrialTimelineChoice.seeAllPlans);
        return false;
      }
      if (latestOffer.productId != offer.productId ||
          latestOffer.days != offer.days ||
          latestOffer.priceString != offer.priceString) {
        dismissTimeline(TrialTimelineChoice.seeAllPlans);
        return false;
      }
      if (!isTimelineCurrent()) return false;

      final PurchaseResult result = await Purchases.purchase(PurchaseParams.package(latestOffer.package));
      final bool currentAccount = isCurrentAccount();
      if (currentAccount) {
        _recordVerifiedPurchase(
          result.storeTransaction,
          latestOffer.package,
          result.customerInfo,
          source: source,
          placement: placement,
        );
      }
      if (remind && currentAccount) {
        final Future<bool> permissionRequest = const NotificationPermissionGateway().request();
        try {
          await permissionRequest.timeout(_permissionRequestTimeout);
        } on TimeoutException {
          _refreshReminderAfterPermissionRequest(permissionRequest, isCurrentAccount: isCurrentAccount);
        } catch (error) {
          logger.w('Notification permission request failed.', error: error);
        }
      }
      return true;
    } on PlatformException catch (error) {
      if (!isCurrentAccount()) {
        dismissTimeline(TrialTimelineChoice.closed);
        return false;
      }
      if (int.tryParse(error.code) == PurchasesErrorCode.purchaseCancelledError.index) return false;
      await _showTrialPurchaseFailure(error, StackTrace.current, isCurrentAccount: isCurrentAccount);
      return false;
    } catch (error, stackTrace) {
      if (!isCurrentAccount()) {
        dismissTimeline(TrialTimelineChoice.closed);
        return false;
      }
      await _showTrialPurchaseFailure(error, stackTrace, isCurrentAccount: isCurrentAccount);
      return false;
    }
  }

  void _refreshReminderAfterPermissionRequest(
    Future<bool> permissionRequest, {
    required bool Function() isCurrentAccount,
  }) {
    unawaited(
      permissionRequest
          .then((_) async {
            if (!isCurrentAccount()) return;
            await PurchasesService.instance.checkAndPersistPremium();
          })
          .catchError((Object error, StackTrace stackTrace) {
            logger.w(
              'Unable to refresh trial reminder after permission request.',
              error: error,
              stackTrace: stackTrace,
            );
          }),
    );
  }

  Future<void> _showTrialPurchaseFailure(
    Object error,
    StackTrace stackTrace, {
    required bool Function() isCurrentAccount,
  }) async {
    logger.w('Trial purchase failed.', error: error, stackTrace: stackTrace);
    try {
      if (!isCurrentAccount()) return;
      final AppLocalizations l10n = await loadDeviceAppLocalizations();
      if (!isCurrentAccount()) return;
      toasts.error(l10n.trialTimelineStartFailed);
    } catch (localizationError, localizationStackTrace) {
      logger.w(
        'Unable to show the trial purchase error.',
        error: localizationError,
        stackTrace: localizationStackTrace,
      );
    }
  }
}
