import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// F3 unique content: skip button.
/// Background, headline, progress, button, and helper text are owned by the shell overlay.
/// The wallpaper-success listener has been moved to the shell's BlocConsumer.
class F3FirstWallpaperPage extends StatelessWidget {
  const F3FirstWallpaperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingFrame(
      builder: (context, sx, sy) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(
                  top: OnboardingLayout.skipY * sy,
                  right: (OnboardingLayout.designWidth - OnboardingLayout.skipX - 32) * sx,
                ),
                child: GestureDetector(
                  onTap: () =>
                      context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.firstWallpaperStepContinued()),
                  child: const Text('skip', style: OnboardingTypography.skip),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
