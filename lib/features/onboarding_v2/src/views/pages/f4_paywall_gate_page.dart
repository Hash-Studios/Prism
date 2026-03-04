import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class F4PaywallGatePage extends StatelessWidget {
  const F4PaywallGatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.paywallData != curr.paywallData || prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        final paywallData = state.paywallData;
        final continueUnlocked = paywallData.continueUnlocked;
        final timerRemaining = paywallData.timerRemainingSeconds;
        final isLoading = state.actionStatus == ActionStatus.inProgress;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      size: 44,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Unlock Prism Pro',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Get unlimited wallpapers, no ads, and exclusive collections — start your free trial now.',
                    style: TextStyle(color: Colors.white60, fontSize: 15, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  _ProFeatureRow(icon: Icons.download_rounded, label: 'Unlimited downloads'),
                  const SizedBox(height: 12),
                  _ProFeatureRow(icon: Icons.block_rounded, label: 'No ads, ever'),
                  const SizedBox(height: 12),
                  _ProFeatureRow(icon: Icons.collections_bookmark_rounded, label: 'Exclusive collections'),
                  const Spacer(flex: 2),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isLoading
                          ? null
                          : () => context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.paywallPrimaryTapped()),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const StadiumBorder(),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      child: const Text('Start Free Trial'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ContinueFreeButton(
                    continueUnlocked: continueUnlocked,
                    timerRemaining: timerRemaining,
                    isLoading: isLoading,
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ProFeatureRow extends StatelessWidget {
  const _ProFeatureRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _ContinueFreeButton extends StatelessWidget {
  const _ContinueFreeButton({required this.continueUnlocked, required this.timerRemaining, required this.isLoading});

  final bool continueUnlocked;
  final int timerRemaining;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final label = continueUnlocked ? 'Continue for free' : 'Continue for free ($timerRemaining)';

    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: continueUnlocked && !isLoading
            ? () => context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.paywallContinueFreeTapped())
            : null,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const StadiumBorder(),
          foregroundColor: Colors.white54,
          disabledForegroundColor: Colors.white30,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white54),
              )
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
      ),
    );
  }
}
