import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/utils/wallpaper_brightness.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_skip_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// F4 unique content: skip button.
/// Background, headline, progress, button, and helper text are owned by the shell overlay.
class F4FirstWallpaperPage extends StatefulWidget {
  const F4FirstWallpaperPage({super.key});

  @override
  State<F4FirstWallpaperPage> createState() => _F4FirstWallpaperPageState();
}

class _F4FirstWallpaperPageState extends State<F4FirstWallpaperPage> {
  // Defaults to white before palette resolves.
  Color _skipColor = OnboardingColors.textOnDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final url = context.read<OnboardingV2Bloc>().state.wallpaperData.wallpaper?.thumbnailUrl;
    if (url != null && url.isNotEmpty) _computeSkipColor(url);
  }

  Future<void> _computeSkipColor(String thumbnailUrl) async {
    final brightness = await wallpaperBrightness(thumbnailUrl);
    if (brightness == null || !mounted) return;
    setState(() {
      _skipColor = brightness == Brightness.light ? OnboardingColors.textPrimary : OnboardingColors.textOnDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<OnboardingV2Bloc, OnboardingV2State>(
      listenWhen: (prev, curr) {
        final oldUrl = prev.wallpaperData.wallpaper?.thumbnailUrl;
        final newUrl = curr.wallpaperData.wallpaper?.thumbnailUrl;
        return newUrl != null && newUrl.isNotEmpty && newUrl != oldUrl;
      },
      listener: (context, state) => _computeSkipColor(state.wallpaperData.wallpaper!.thumbnailUrl),
      child: OnboardingFrame(
        builder: (context, sx, sy) {
          return Stack(
            fit: StackFit.expand,
            children: [
              OnboardingSkipButton(
                sx: sx,
                sy: sy,
                color: _skipColor,
                onTap: () =>
                    context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.firstWallpaperStepContinued()),
              ),
            ],
          );
        },
      ),
    );
  }
}
