import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/purchases/annual_trial.dart';
import 'package:Prism/core/purchases/manage_subscription.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/purchases/purchases_service.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
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

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ValueListenableBuilder<ActiveTrial?>(
      valueListenable: PurchasesService.instance.activeTrial,
      builder: (BuildContext context, ActiveTrial? trial, _) => _build(context, l10n, trial),
    );
  }

  Widget _build(BuildContext context, AppLocalizations l10n, ActiveTrial? trial) {
    return PrismPage(
      title: l10n.premiumPageTitle,
      body: Center(
        child: SingleChildScrollView(
          padding: PrismSpace.pageInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: trial == null
                ? <Widget>[
                    Text(
                      _unavailable ? l10n.premiumPagePlansUnavailable : l10n.premiumPageExplorePlans,
                      textAlign: TextAlign.center,
                      style: PrismTextStyles.body(context),
                    ),
                    const SizedBox(height: PrismSpace.lg),
                    PrismButton(
                      label: _unavailable ? l10n.premiumPageTryAgain : l10n.premiumPageViewPlans,
                      loading: _presenting,
                      onPressed: _viewPlans,
                    ),
                  ]
                : <Widget>[
                    Text(
                      l10n.premiumTrialEnds(DateFormat.yMMMd(l10n.localeName).format(trial.endsAt.toLocal())),
                      textAlign: TextAlign.center,
                      style: PrismTextStyles.sectionTitle(context),
                    ),
                    if (!trial.willRenew) ...<Widget>[
                      const SizedBox(height: PrismSpace.xs),
                      Text(
                        l10n.premiumTrialAutoRenewOff,
                        textAlign: TextAlign.center,
                        style: PrismTextStyles.body(context),
                      ),
                    ],
                    const SizedBox(height: PrismSpace.lg),
                    PrismButton(
                      label: l10n.accountManageSubscription,
                      variant: PrismButtonVariant.tonal,
                      trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                      onPressed: () => openManageSubscription(l10n),
                    ),
                  ],
          ),
        ),
      ),
    );
  }
}
