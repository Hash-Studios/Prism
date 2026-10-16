import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
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
  required void Function(OnboardingV2Event event) add,
  required VoidCallback signInAgain,
  required bool signingOut,
}) {
  if (onboardingSaveFailed(state)) {
    if (state.sessionInvalid) {
      return OnboardingRecovery(
        label: 'Sign in again',
        helper: 'Your session has expired. Sign in again to continue.',
        onPressed: signInAgain,
        loading: signingOut,
      );
    }
    if (state.completionFailed) {
      return OnboardingRecovery(
        label: 'Try again',
        helper: "Couldn't finish setup. Check your connection and try again.",
        onPressed: () => add(const OnboardingV2Event.completionRetried()),
        loading: signingOut,
      );
    }
    final bool interests = state.step == OnboardingV2Step.interests;
    return OnboardingRecovery(
      label: 'Try again',
      helper: interests
          ? "Couldn't save your picks. Check your connection and try again."
          : "Couldn't follow these creators. Check your connection and try again.",
      onPressed: () => add(
        interests ? const OnboardingV2Event.interestsConfirmed() : const OnboardingV2Event.starterPackConfirmed(),
      ),
      loading: signingOut,
    );
  }
  if (onboardingStarterPackShort(state)) {
    return OnboardingRecovery(
      label: 'Reload',
      helper: "Couldn't load creators. Check your connection and tap Reload.",
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
