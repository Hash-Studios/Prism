import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_copy.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

class F0AuthPage extends StatefulWidget {
  const F0AuthPage({super.key});

  @override
  State<F0AuthPage> createState() => _F0AuthPageState();
}

class _F0AuthPageState extends State<F0AuthPage> {
  bool _loading = false;

  Future<void> _onGooglePressed() async {
    if (_loading) {
      return;
    }
    setState(() => _loading = true);
    final bloc = context.read<OnboardingV2Bloc>();
    bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: true));
    try {
      final result = await app_state.gAuth.signInWithGoogle();
      if (!mounted) {
        return;
      }
      if (result == GoogleAuth.signInCancelledResult) {
        app_state.prismUser.loggedIn = false;
        app_state.persistPrismUser();
        toasts.codeSend('Sign in cancelled.');
        bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
      } else {
        app_state.prismUser.loggedIn = true;
        app_state.persistPrismUser();
        bloc.add(const OnboardingV2Event.authCompleted());
      }
    } catch (_) {
      if (mounted) {
        toasts.error('Something went wrong, please try again!');
      }
      bloc.add(const OnboardingV2Event.authLoadingChanged(isLoading: false));
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bgSx = constraints.maxWidth / OnboardingLayout.designWidth;
          final bgSy = constraints.maxHeight / OnboardingLayout.designHeight;

          return Stack(
            fit: StackFit.expand,
            children: [
              OnboardingBackground(assetPath: OnboardingAssets.wallpaperPrimary, sx: bgSx, sy: bgSy),
              OnboardingFrame(
                builder: (context, sx, sy) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: OnboardingLayout.welcomeLogoY * sy),
                          child: const Text('prism', style: OnboardingTypography.logo, textAlign: TextAlign.center),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: OnboardingLayout.welcomeHeadlineY * sy),
                          child: const OnboardingHeadline(text: 'Your screen,\nreimagined.'),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: OnboardingLayout.welcomeBodyY * sy),
                          child: const OnboardingBodyText(
                            text: 'access thousands of premium wallpapers\ncreated by top digital artists.',
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: OnboardingLayout.ctaY * sy,
                            left: OnboardingLayout.ctaX * sx,
                            right: OnboardingLayout.ctaX * sx,
                          ),
                          child: SizedBox(
                            height: OnboardingLayout.ctaHeight * sy,
                            child: OnboardingPrimaryButton(
                              label: 'continue with Google',
                              onPressed: _onGooglePressed,
                              loading: _loading,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.topCenter,
                        child: Padding(
                          padding: EdgeInsets.only(top: OnboardingLayout.legalY * sy),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: OnboardingTypography.helper,
                              children: [
                                const TextSpan(text: 'by continuing you agree to our '),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: OnboardingTypography.helper.copyWith(decoration: TextDecoration.underline),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      launchUrl(
                                        Uri.parse('https://prism-app-terms.web.app'),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
