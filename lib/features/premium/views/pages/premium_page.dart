import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/purchases/paywall_orchestrator.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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
    return PrismPage(
      title: 'Prism Premium',
      body: Center(
        child: Padding(
          padding: PrismSpace.pageInsets,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _unavailable ? PaywallOrchestrator.plansUnavailableMessage : 'Explore Prism Premium plans.',
                textAlign: TextAlign.center,
                style: PrismTextStyles.body(context),
              ),
              const SizedBox(height: PrismSpace.lg),
              PrismButton(
                label: _unavailable ? 'Try again' : 'View plans',
                loading: _presenting,
                onPressed: _viewPlans,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
