import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_copy.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/global/svgAssets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// F0 unique content: logo + tagline body text, with staggered fade-in on mount.
/// Background, headline, button, and legal text are owned by the shell overlay.
class F0AuthPage extends StatefulWidget {
  const F0AuthPage({super.key});

  @override
  State<F0AuthPage> createState() => _F0AuthPageState();
}

class _F0AuthPageState extends State<F0AuthPage> {
  bool _logoVisible = false;
  bool _bodyVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _logoVisible = true);
      });
      Future.delayed(const Duration(milliseconds: 600), () {
        if (!mounted) return;
        setState(() => _bodyVisible = true);
      });
    });
  }

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
                  child: AnimatedOpacity(
                    opacity: _logoVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 1000),
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
                  child: AnimatedOpacity(
                    opacity: _bodyVisible ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 1000),
                    child: const OnboardingBodyText(
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
