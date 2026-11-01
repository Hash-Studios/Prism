import 'package:Prism/core/auth/guest_browsing_policy.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/category_cover.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_recovery.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_terms_row.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/welcome_buttons.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/welcome_staggered_fade.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum _Provider { apple, google }

/// Step 0: the welcome art, the pitch and the sign-in buttons. The art sits behind this page, in the shell.
///
/// Every button is live. Tapping one while the terms box is empty shakes the terms row and says why.
class F0AuthPage extends StatefulWidget {
  const F0AuthPage({
    super.key,
    required this.termsAccepted,
    required this.onTermsChanged,
    required this.legalTap,
    required this.privacyTap,
    required this.onGoogle,
    required this.onApple,
    required this.onBrowse,
  });

  final bool termsAccepted;
  final ValueChanged<bool> onTermsChanged;
  final TapGestureRecognizer legalTap;
  final TapGestureRecognizer privacyTap;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  final VoidCallback onBrowse;

  @override
  State<F0AuthPage> createState() => _F0AuthPageState();
}

class _F0AuthPageState extends State<F0AuthPage> {
  final ShakeController _shake = ShakeController();
  _Provider? _provider;

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _gated(BuildContext context, VoidCallback action, {_Provider? provider}) {
    if (!widget.termsAccepted) {
      _shake.shake();
      PrismHaptics.warning();
      toasts.error(context.l10n.onboardingTermsRequired);
      return;
    }
    setState(() => _provider = provider);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final bool ios = defaultTargetPlatform == TargetPlatform.iOS;
    final OnboardingRecovery? recovery = OnboardingRecoveryScope.maybeOf(context);
    final TextStyle headline = PrismTextStyles.display(context).copyWith(color: Colors.white);
    final TextStyle body = PrismTextStyles.body(
      context,
    ).copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 16);
    return BlocListener<OnboardingV2Bloc, OnboardingV2State>(
      listenWhen: (prev, curr) =>
          prev.interestsData.categoryImages.isEmpty && curr.interestsData.categoryImages.isNotEmpty,
      listener: (context, state) {
        for (final url in state.interestsData.categoryImages.values) {
          precacheCover(url, context);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[
                    Colors.black.withValues(alpha: 0.32),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.55),
                    Colors.black.withValues(alpha: 0.7),
                  ],
                  stops: const <double>[0, 0.16, 0.34, 0.58, 1],
                ),
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      maxWidth: OnboardingLayout.maxContentWidth,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          PrismSpace.page,
                          PrismSpace.md,
                          PrismSpace.page,
                          PrismSpace.md,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const WelcomeStaggeredFade(delay: Duration.zero, child: _Wordmark()),
                            const Spacer(),
                            WelcomeStaggeredFade(
                              delay: PrismDurations.stagger,
                              child: Semantics(
                                header: true,
                                child: Text(context.l10n.onboardingWelcomeHeadline, style: headline),
                              ),
                            ),
                            const SizedBox(height: PrismSpace.sm),
                            WelcomeStaggeredFade(
                              delay: PrismDurations.stagger * 2,
                              child: Text(context.l10n.onboardingWelcomeDescription, style: body),
                            ),
                            const SizedBox(height: PrismSpace.xl),
                            WelcomeStaggeredFade(
                              delay: PrismDurations.stagger * 3,
                              child: BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
                                buildWhen: (prev, curr) =>
                                    prev.isAuthLoading != curr.isAuthLoading || prev.actionStatus != curr.actionStatus,
                                builder: (context, state) {
                                  final bool busy =
                                      state.isAuthLoading || state.actionStatus == ActionStatus.inProgress;
                                  if (recovery != null) {
                                    // Setup failed after sign-in: the terms are already accepted, so offer only the way out.
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.stretch,
                                      children: <Widget>[
                                        Semantics(
                                          liveRegion: true,
                                          child: Text(recovery.helper, style: body.copyWith(fontSize: 14)),
                                        ),
                                        const SizedBox(height: PrismSpace.sm),
                                        WelcomePrimaryButton(
                                          label: recovery.label,
                                          loading: recovery.loading,
                                          onPressed: recovery.onPressed,
                                        ),
                                      ],
                                    );
                                  }
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: <Widget>[
                                      if (ios) ...<Widget>[
                                        WelcomePrimaryButton(
                                          label: context.l10n.onboardingContinueApple,
                                          icon: Icons.apple,
                                          loading: busy && _provider == _Provider.apple,
                                          onPressed: busy
                                              ? null
                                              : () => _gated(context, widget.onApple, provider: _Provider.apple),
                                        ),
                                        const SizedBox(height: PrismSpace.sm),
                                      ],
                                      WelcomePrimaryButton(
                                        label: context.l10n.onboardingContinueGoogle,
                                        icon: JamIcons.google,
                                        style: ios ? WelcomeButtonStyle.glass : WelcomeButtonStyle.solid,
                                        loading: busy && _provider != _Provider.apple,
                                        onPressed: busy
                                            ? null
                                            : () => _gated(context, widget.onGoogle, provider: _Provider.google),
                                      ),
                                      if (guestBrowsingAllowed)
                                        WelcomeTextButton(
                                          label: context.l10n.onboardingBrowseGuest,
                                          onPressed: () => _gated(context, widget.onBrowse),
                                        ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: PrismSpace.xs),
                            if (recovery == null)
                              WelcomeStaggeredFade(
                                delay: PrismDurations.stagger * 4,
                                child: ShakeOnce(
                                  controller: _shake,
                                  child: OnboardingTermsRow(
                                    accepted: widget.termsAccepted,
                                    onChanged: widget.onTermsChanged,
                                    legalTap: widget.legalTap,
                                    privacyTap: widget.privacyTap,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.appTitle,
      child: ExcludeSemantics(
        child: MediaQuery.withNoTextScaling(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              SvgPicture.string(
                prismVector,
                height: 22,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
              const SizedBox(width: PrismSpace.xs),
              Text(context.l10n.appTitle.toLowerCase(), style: PrismTextStyles.brandName.copyWith(fontSize: 22)),
            ],
          ),
        ),
      ),
    );
  }
}
