import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_copy.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_staggered_fade.dart';
import 'package:Prism/global/svg_assets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// F0 unique content: logo + tagline body text, with staggered fade-in on mount.
/// Background, headline, button, and legal text are owned by the shell overlay.
class F0AuthPage extends StatelessWidget {
  const F0AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingV2Bloc, OnboardingV2State>(
      listenWhen: (prev, curr) =>
          prev.interestsData.categoryImages.isEmpty && curr.interestsData.categoryImages.isNotEmpty,
      listener: (context, state) {
        for (final url in state.interestsData.categoryImages.values) {
          precacheImage(NetworkImage(url), context);
        }
      },
      child: OnboardingFrame(
        builder: (context, sx, sy) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: OnboardingLayout.welcomeLogoY * sy),
                  child: OnboardingStaggeredFade(
                    delay: const Duration(milliseconds: 300),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(padding: const EdgeInsets.only(top: 6), child: SvgPicture.string(prismVector)),
                        const SizedBox(width: 6),
                        const Text('prism', style: OnboardingTypography.logo),
                      ],
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: EdgeInsets.only(top: OnboardingLayout.welcomeBodyY * sy),
                  child: const OnboardingStaggeredFade(
                    delay: Duration(milliseconds: 600),
                    child: OnboardingBodyText(
                      text: 'access millions of premium wallpapers\ncreated by top digital artists.',
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
