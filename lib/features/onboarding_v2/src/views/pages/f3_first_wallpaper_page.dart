import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_copy.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class F3FirstWallpaperPage extends StatelessWidget {
  const F3FirstWallpaperPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingV2Bloc, OnboardingV2State>(
      listenWhen: (prev, curr) =>
          prev.wallpaperData.status != curr.wallpaperData.status,
      listener: (context, state) {
        if (state.wallpaperData.status == FirstWallpaperStatus.success) {
          context.read<OnboardingV2Bloc>().add(
            const OnboardingV2Event.paywallContinueFreeTapped(),
          );
        }
      },
      buildWhen: (prev, curr) => prev.wallpaperData != curr.wallpaperData,
      builder: (context, state) {
        final isLoading =
            state.wallpaperData.status == FirstWallpaperStatus.loading;
        final canSetWallpaper = state.wallpaperData.wallpaper != null;

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bgSx = constraints.maxWidth / OnboardingLayout.designWidth;
              final bgSy =
                  constraints.maxHeight / OnboardingLayout.designHeight;

              return Stack(
                fit: StackFit.expand,
                children: [
                  OnboardingBackground(
                    assetPath: OnboardingAssets.wallpaperFinal,
                    sx: bgSx,
                    sy: bgSy,
                    imageLeft: -88,
                    imageTop: -1,
                    imageWidth: 569,
                    imageHeight: 854,
                  ),
                  OnboardingFrame(
                    builder: (context, sx, sy) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: OnboardingLayout.progressY * sy,
                              ),
                              child: Transform.scale(
                                alignment: Alignment.topCenter,
                                scaleX: sx,
                                scaleY: sy,
                                child: const OnboardingProgressIndicator(
                                  step: 3,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topRight,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: OnboardingLayout.skipY * sy,
                                right:
                                    (OnboardingLayout.designWidth -
                                        OnboardingLayout.skipX -
                                        32) *
                                    sx,
                              ),
                              child: GestureDetector(
                                onTap: () => context.read<OnboardingV2Bloc>().add(
                                  const OnboardingV2Event.paywallContinueFreeTapped(),
                                ),
                                child: const Text(
                                  'skip',
                                  style: OnboardingTypography.skip,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: OnboardingLayout.stepTitleY * sy,
                              ),
                              child: const OnboardingHeadline(
                                text: 'Make it yours',
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
                                  label: 'set as wallpaper',
                                  onPressed: () {
                                    if (!canSetWallpaper) {
                                      context.read<OnboardingV2Bloc>().add(
                                        const OnboardingV2Event.paywallContinueFreeTapped(),
                                      );
                                      return;
                                    }
                                    context.read<OnboardingV2Bloc>().add(
                                      const OnboardingV2Event.firstWallpaperActionRequested(),
                                    );
                                  },
                                  loading: isLoading,
                                ),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: OnboardingLayout.helperY * sy,
                                left: OnboardingLayout.helperStep4X * sx,
                                right: OnboardingLayout.helperStep4X * sx,
                              ),
                              child: const OnboardingHelperText(
                                text:
                                    'we picked this wallpaper based on your interest in Minimal',
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
      },
    );
  }
}
