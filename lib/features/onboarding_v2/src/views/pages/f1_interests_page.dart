import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/interest_category_tile.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_copy.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class F1InterestsPage extends StatelessWidget {
  const F1InterestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.interestsData != curr.interestsData || prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        final available = state.interestsData.available.take(6).toList(growable: false);
        final canContinue = state.interestsData.canContinue;
        final isLoading = state.actionStatus == ActionStatus.inProgress;

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final bgSx = constraints.maxWidth / OnboardingLayout.designWidth;
              final bgSy = constraints.maxHeight / OnboardingLayout.designHeight;

              return Stack(
                fit: StackFit.expand,
                children: [
                  OnboardingBackground(
                    assetPath: OnboardingAssets.wallpaperPrimary,
                    sx: bgSx,
                    sy: bgSy,
                    mode: OnboardingBackgroundMode.softened,
                  ),
                  OnboardingFrame(
                    builder: (context, sx, sy) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: OnboardingLayout.progressY * sy),
                              child: Transform.scale(
                                alignment: Alignment.topCenter,
                                scaleX: sx,
                                scaleY: sy,
                                child: const OnboardingProgressIndicator(step: 1),
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(top: OnboardingLayout.stepTitleY * sy),
                              child: const OnboardingHeadline(text: 'Pick your vibe'),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: OnboardingLayout.tilesY * sy,
                                left: OnboardingLayout.tilesX * sx,
                                right: OnboardingLayout.tilesX * sx,
                              ),
                              child: SizedBox(
                                height: OnboardingLayout.tilesHeight * sy,
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: 6,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: OnboardingLayout.tileGap * sx,
                                    mainAxisSpacing: OnboardingLayout.tileGap * sy,
                                    childAspectRatio:
                                        (OnboardingLayout.tileSize * sx) / (OnboardingLayout.tileSize * sy),
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index >= available.length) {
                                      return const InterestCategoryTile(isSelected: false, onTap: null);
                                    }
                                    final category = available[index];
                                    return InterestCategoryTile(
                                      isSelected: state.interestsData.selected.contains(category),
                                      onTap: () => context.read<OnboardingV2Bloc>().add(
                                        OnboardingV2Event.interestToggled(category),
                                      ),
                                    );
                                  },
                                ),
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
                                  label: 'continue',
                                  onPressed: () => context.read<OnboardingV2Bloc>().add(
                                    const OnboardingV2Event.interestsConfirmed(),
                                  ),
                                  enabled: canContinue,
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
                                left: OnboardingLayout.helperStep2X * sx,
                                right: OnboardingLayout.helperStep2X * sx,
                              ),
                              child: const OnboardingHelperText(
                                text: 'select at least 5 categories to personalize your feed',
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
