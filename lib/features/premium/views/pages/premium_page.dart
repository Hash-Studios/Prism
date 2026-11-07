import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/auth/require_signed_in_action.dart';
import 'package:Prism/core/purchases/annual_trial.dart';
import 'package:Prism/core/purchases/manage_subscription.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/glint/cover_mosaic.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

@RoutePage()
class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage> {
  bool _presenting = false;
  bool _unavailable = false;
  bool _restoring = false;

  Future<void> _viewPlans() async {
    if (_presenting) return;
    setState(() {
      _presenting = true;
      _unavailable = false;
    });
    try {
      final PaywallResultValue? result = await PaywallOrchestrator.instance.presentOrRequireSignIn(
        context,
        placement: PaywallPlacement.mainUpsell,
        source: 'premium_page',
      );
      if (mounted) {
        setState(() {
          _unavailable = <PaywallResultValue>{
            PaywallResultValue.notPresented,
            PaywallResultValue.noOffering,
            PaywallResultValue.rcError,
            PaywallResultValue.error,
          }.contains(result);
        });
      }
    } finally {
      if (mounted) setState(() => _presenting = false);
    }
  }

  // Same outcomes and messages as Restore purchases in Settings.
  Future<void> _restore() async {
    if (_restoring) return;
    setState(() => _restoring = true);
    try {
      if (!await requireSignedInAction(context) || !mounted) return;
      await _restoreSignedIn();
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _restoreSignedIn() async {
    final String requestedUserId = app_state.prismUser.id.trim();
    final bool requestedLoggedIn = app_state.prismUser.loggedIn;
    bool isCurrentAccount() =>
        requestedUserId == app_state.prismUser.id.trim() && requestedLoggedIn == app_state.prismUser.loggedIn;
    final AppLocalizations l10n = context.l10n;
    try {
      final PurchaseEntitlementStatus status = await PurchasesService.instance.restore();
      if (!mounted || !isCurrentAccount()) return;
      if (status == PurchaseEntitlementStatus.serverConfirmed) {
        toasts.success(l10n.accountPurchasesRestored);
      } else if (status == PurchaseEntitlementStatus.guestSignInRequired) {
        toasts.success(l10n.premiumGuestStorePurchaseActive);
      } else if (app_state.prismUser.premium) {
        toasts.success(l10n.accountPurchasesRestoredPending);
      } else {
        toasts.error(l10n.accountNoPurchasesToRestore);
      }
    } catch (_) {
      if (mounted && isCurrentAccount()) toasts.error(l10n.accountCouldNotRestorePurchases);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ValueListenableBuilder<ActiveTrial?>(
      valueListenable: PurchasesService.instance.activeTrial,
      builder: (BuildContext context, ActiveTrial? trial, _) => _build(context, l10n, trial),
    );
  }

  Widget _build(BuildContext context, AppLocalizations l10n, ActiveTrial? trial) {
    final List<(IconData, String)> benefits = <(IconData, String)>[
      (Icons.collections_rounded, l10n.premiumBenefitWalls),
      (Icons.download_rounded, l10n.premiumBenefitFree),
      (Icons.casino_rounded, l10n.premiumBenefitSpin),
      (Icons.autorenew_rounded, l10n.premiumBenefitAutomation),
      (Icons.animation_rounded, l10n.premiumBenefitLiveStyles),
      (Icons.auto_awesome_rounded, l10n.premiumBenefitAiClean),
    ];
    return PrismPage(
      title: l10n.premiumPageTitle,
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          PrismSpace.page,
          PrismSpace.xs,
          PrismSpace.page,
          PrismSpace.xl + (trial == null ? MediaQuery.paddingOf(context).bottom : 0),
        ),
        children: <Widget>[
          // A short banner, so View plans and Restore purchases stay above the fold on a 852 point phone.
          SizedBox(height: 104, child: CoverMosaic(seed: l10n.premiumPageTitle)),
          const SizedBox(height: PrismSpace.md),
          Text(l10n.premiumPageHeadline, style: PrismTextStyles.display(context)),
          if (trial != null) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PrismTag(
                label: l10n.premiumTrialEnds(DateFormat.yMMMd(l10n.localeName).format(trial.endsAt.toLocal())),
                tone: PrismTone.accent,
                icon: Icons.schedule_rounded,
              ),
            ),
            if (!trial.willRenew) ...<Widget>[
              const SizedBox(height: PrismSpace.xs),
              Text(l10n.premiumTrialAutoRenewOff, style: PrismTextStyles.body(context)),
            ],
          ],
          const SizedBox(height: PrismSpace.xl),
          PrismGroup(
            children: <Widget>[
              for (final (IconData icon, String title) in benefits) PrismRow(icon: icon, title: title),
            ],
          ),
          // The page is short, so the actions follow the benefits instead of sitting in a bottom bar.
          if (trial == null) ...<Widget>[
            const SizedBox(height: PrismSpace.xl),
            if (_unavailable) ...<Widget>[
              Text(l10n.premiumPagePlansUnavailable, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
              const SizedBox(height: PrismSpace.sm),
            ],
            PrismButton(
              label: _unavailable ? l10n.premiumPageTryAgain : l10n.premiumPageViewPlans,
              loading: _presenting,
              expand: true,
              onPressed: _viewPlans,
            ),
            const SizedBox(height: PrismSpace.xxs),
            PrismButton(
              label: l10n.accountRestorePurchases,
              variant: PrismButtonVariant.ghost,
              loading: _restoring,
              expand: true,
              onPressed: _restore,
            ),
          ],
        ],
      ),
      bottomBar: trial == null
          ? null
          : PrismButton(
              label: l10n.accountManageSubscription,
              variant: PrismButtonVariant.tonal,
              expand: true,
              trailing: const Icon(Icons.open_in_new_rounded, size: 18),
              onPressed: () => openManageSubscription(l10n),
            ),
    );
  }
}
