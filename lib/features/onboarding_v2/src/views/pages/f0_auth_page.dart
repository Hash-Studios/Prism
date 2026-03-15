import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_copy.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// F0 unique content: logo + tagline body text.
/// Background, headline, button, and legal text are owned by the shell overlay.
class F0AuthPage extends StatelessWidget {
  const F0AuthPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      builder: (context, sx, sy) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: OnboardingLayout.welcomeLogoY * sy),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(padding: const EdgeInsets.only(top: 6), child: SvgPicture.string(prismVector)),
                    const SizedBox(width: 6),
                    const Text('prism', style: OnboardingTypography.logo),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: OnboardingLayout.welcomeBodyY * sy),
                child: const OnboardingBodyText(
                  text: 'access millions of premium wallpapers\ncreated by top digital artists.',
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
