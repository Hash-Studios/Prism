import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:palette_generator/palette_generator.dart';

/// F3 unique content: skip button.
/// Background, headline, progress, button, and helper text are owned by the shell overlay.
/// The wallpaper-success listener has been moved to the shell's BlocConsumer.
class F3FirstWallpaperPage extends StatefulWidget {
  const F3FirstWallpaperPage({super.key});

  @override
  State<F3FirstWallpaperPage> createState() => _F3FirstWallpaperPageState();
}

class _F3FirstWallpaperPageState extends State<F3FirstWallpaperPage> {
  // Defaults to white before palette resolves.
  Color _skipColor = OnboardingColors.textOnDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final url = context.read<OnboardingV2Bloc>().state.wallpaperData.wallpaper?.thumbnailUrl;
    if (url != null && url.isNotEmpty) _computeSkipColor(url);
  }

  void _computeSkipColor(String thumbnailUrl) {
    PaletteGenerator.fromImageProvider(CachedNetworkImageProvider(thumbnailUrl), maximumColorCount: 8)
        .then((palette) {
          final dominant = palette.dominantColor?.color ?? Colors.black;
          final brightness = ThemeData.estimateBrightnessForColor(dominant);
          if (mounted) {
            setState(() {
              _skipColor = brightness == Brightness.light ? OnboardingColors.textPrimary : OnboardingColors.textOnDark;
            });
          }
        })
        .catchError((_) {});
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
                    child: Text('skip', style: OnboardingTypography.skip.copyWith(color: _skipColor)),
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
