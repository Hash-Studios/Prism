import 'package:Prism/core/widgets/animated/shake_once.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_staggered_fade.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_terms_row.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    required this.onGoogle,
    required this.onApple,
    required this.onBrowse,
  });

  final bool termsAccepted;
  final ValueChanged<bool> onTermsChanged;
  final TapGestureRecognizer legalTap;
  final VoidCallback onGoogle;
  final VoidCallback onApple;

  /// iOS only: browse without an account.
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

  void _gated(VoidCallback action, {_Provider? provider}) {
    if (!widget.termsAccepted) {
      _shake.shake();
      HapticFeedback.mediumImpact();
      toasts.error('Agree to the Terms of Use to continue.');
      return;
    }
    setState(() => _provider = provider);
    action();
  }

  @override
  Widget build(BuildContext context) {
    final bool ios = defaultTargetPlatform == TargetPlatform.iOS;
    final TextStyle headline = PrismTextStyles.display(context).copyWith(color: Colors.white);
    final TextStyle body = PrismTextStyles.body(
      context,
    ).copyWith(color: Colors.white.withValues(alpha: 0.85), fontSize: 16);
    return BlocListener<OnboardingV2Bloc, OnboardingV2State>(
      listenWhen: (prev, curr) =>
          prev.interestsData.categoryImages.isEmpty && curr.interestsData.categoryImages.isNotEmpty,
      listener: (context, state) {
        for (final url in state.interestsData.categoryImages.values) {
          precacheImage(NetworkImage(url), context);
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
            child: CustomScrollView(
              slivers: <Widget>[
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.md, PrismSpace.page, PrismSpace.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const OnboardingStaggeredFade(delay: Duration.zero, child: _Wordmark()),
                        const Spacer(),
                        OnboardingStaggeredFade(
                          delay: PrismDurations.stagger,
                          child: Semantics(header: true, child: Text('Your screen, reimagined.', style: headline)),
                        ),
                        const SizedBox(height: PrismSpace.sm),
                        OnboardingStaggeredFade(
                          delay: PrismDurations.stagger * 2,
                          child: Text('Millions of premium wallpapers from top artists.', style: body),
                        ),
                        const SizedBox(height: PrismSpace.xl),
                        OnboardingStaggeredFade(
                          delay: PrismDurations.stagger * 3,
                          child: BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
                            buildWhen: (prev, curr) => prev.isAuthLoading != curr.isAuthLoading,
                            builder: (context, state) {
                              final bool busy = state.isAuthLoading;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: <Widget>[
                                  if (ios) ...<Widget>[
                                    OnboardingPrimaryButton(
                                      label: 'Continue with Apple',
                                      icon: Icons.apple,
                                      loading: busy && _provider == _Provider.apple,
                                      onPressed: busy ? null : () => _gated(widget.onApple, provider: _Provider.apple),
                                    ),
                                    const SizedBox(height: PrismSpace.sm),
                                  ],
                                  OnboardingPrimaryButton(
                                    label: 'Continue with Google',
                                    icon: JamIcons.google,
                                    style: ios ? OnboardingButtonStyle.glass : OnboardingButtonStyle.solid,
                                    loading: busy && _provider != _Provider.apple,
                                    onPressed: busy ? null : () => _gated(widget.onGoogle, provider: _Provider.google),
                                  ),
                                  if (ios)
                                    OnboardingTextButton(
                                      label: 'Browse without an account',
                                      onPressed: () => _gated(widget.onBrowse),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: PrismSpace.xs),
                        OnboardingStaggeredFade(
                          delay: PrismDurations.stagger * 4,
                          child: ShakeOnce(
                            controller: _shake,
                            child: OnboardingTermsRow(
                              accepted: widget.termsAccepted,
                              onChanged: widget.onTermsChanged,
                              legalTap: widget.legalTap,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
      label: 'Prism',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SvgPicture.string(
              prismVector,
              height: 22,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            const SizedBox(width: PrismSpace.xs),
            Text('prism', style: PrismTextStyles.brandName.copyWith(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}
