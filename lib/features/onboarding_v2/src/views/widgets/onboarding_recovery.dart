import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';

/// True when an onboarding save failed and the user must act on it.
bool onboardingSaveFailed(OnboardingV2State state) =>
    state.actionStatus == ActionStatus.failure &&
    (state.completionFailed || state.step == OnboardingV2Step.interests || state.step == OnboardingV2Step.starterPack);

/// The starter pack loaded no creators, so there is nothing to follow until it is reloaded.
bool onboardingStarterPackShort(OnboardingV2State state) =>
    state.step == OnboardingV2Step.starterPack &&
    !onboardingSaveFailed(state) &&
    state.loadStatus == LoadStatus.success &&
    state.starterPackData.creators.isEmpty;

/// What the primary action does while a save error needs the user's attention.
@immutable
class OnboardingRecovery {
  const OnboardingRecovery({required this.label, required this.helper, required this.onPressed, this.loading = false});

  /// The primary button label.
  final String label;

  /// Replaces the body hint with what went wrong and what to do.
  final String helper;
  final VoidCallback onPressed;

  /// "Sign in again" is running the sign-out.
  final bool loading;
}

/// The recovery for [state], or null when the step runs normally.
OnboardingRecovery? onboardingRecoveryFor(
  OnboardingV2State state, {
  required AppLocalizations l10n,
  required void Function(OnboardingV2Event event) add,
  required VoidCallback signInAgain,
  required bool signingOut,
}) {
  if (onboardingSaveFailed(state)) {
    if (state.sessionInvalid) {
      return OnboardingRecovery(
        label: l10n.onboardingRecoverySignIn,
        helper: l10n.onboardingRecoverySessionExpiredHelper,
        onPressed: signInAgain,
        loading: signingOut,
      );
    }
    if (state.completionFailed) {
      return OnboardingRecovery(
        label: l10n.onboardingRecoveryRetry,
        helper: l10n.onboardingRecoverySetupFailedHelper,
        onPressed: () => add(const OnboardingV2Event.completionRetried()),
        loading: signingOut,
      );
    }
    final bool interests = state.step == OnboardingV2Step.interests;
    return OnboardingRecovery(
      label: l10n.onboardingRecoveryRetry,
      helper: interests ? l10n.onboardingRecoverySaveInterestsFailedHelper : l10n.onboardingRecoveryFollowFailedHelper,
      onPressed: () => add(
        interests ? const OnboardingV2Event.interestsConfirmed() : const OnboardingV2Event.starterPackConfirmed(),
      ),
      loading: signingOut,
    );
  }
  if (onboardingStarterPackShort(state)) {
    return OnboardingRecovery(
      label: l10n.onboardingRecoveryReload,
      helper: l10n.onboardingRecoveryCreatorsFailed,
      onPressed: () => add(const OnboardingV2Event.starterPackReloadRequested()),
      loading: signingOut,
    );
  }
  return null;
}

/// Carries the current [OnboardingRecovery] from the shell to [OnboardingFrame] and the welcome page.
class OnboardingRecoveryScope extends InheritedWidget {
  const OnboardingRecoveryScope({super.key, required this.recovery, required super.child});

  final OnboardingRecovery? recovery;

  static OnboardingRecovery? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OnboardingRecoveryScope>()?.recovery;

  @override
  bool updateShouldNotify(OnboardingRecoveryScope oldWidget) =>
      recovery?.label != oldWidget.recovery?.label ||
      recovery?.helper != oldWidget.recovery?.helper ||
      recovery?.loading != oldWidget.recovery?.loading;
}
