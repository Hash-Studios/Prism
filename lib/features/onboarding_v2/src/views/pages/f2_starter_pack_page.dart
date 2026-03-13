import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/creator_card.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_background.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_copy.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_primary_button.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class F2StarterPackPage extends StatelessWidget {
  const F2StarterPackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) =>
          prev.starterPackData != curr.starterPackData ||
          prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        final creators = state.starterPackData.creators
            .take(3)
            .toList(growable: false);
        final canContinue = state.starterPackData.canContinue;
        final isLoading = state.actionStatus == ActionStatus.inProgress;

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
                              padding: EdgeInsets.only(
                                top: OnboardingLayout.progressY * sy,
                              ),
                              child: Transform.scale(
                                alignment: Alignment.topCenter,
                                scaleX: sx,
                                scaleY: sy,
                                child: const OnboardingProgressIndicator(
                                  step: 2,
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
                                text: 'Find your people',
                              ),
                            ),
                          ),
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: EdgeInsets.only(
                                top: OnboardingLayout.creatorsY * sy,
                                left: OnboardingLayout.creatorsX * sx,
                                right: OnboardingLayout.creatorsX * sx,
                              ),
                              child: SizedBox(
                                height: OnboardingLayout.tilesHeight * sy,
                                child: ListView.separated(
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: 3,
                                  separatorBuilder: (_, index) => SizedBox(
                                    height: OnboardingLayout.creatorGap * sy,
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index >= creators.length) {
                                      return SizedBox(
                                        height:
                                            OnboardingLayout.creatorHeight * sy,
                                        child: const CreatorCard(
                                          creator: null,
                                          onToggle: null,
                                        ),
                                      );
                                    }
                                    final creator = creators[index];
                                    return SizedBox(
                                      height:
                                          OnboardingLayout.creatorHeight * sy,
                                      child: CreatorCard(
                                        creator: creator,
                                        onToggle: () => context
                                            .read<OnboardingV2Bloc>()
                                            .add(
                                              OnboardingV2Event.creatorFollowToggled(
                                                creator.email,
                                              ),
                                            ),
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
                                  onPressed: () =>
                                      context.read<OnboardingV2Bloc>().add(
                                        const OnboardingV2Event.starterPackConfirmed(),
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
                                left: OnboardingLayout.helperStep3X * sx,
                                right: OnboardingLayout.helperStep3X * sx,
                              ),
                              child: const OnboardingHelperText(
                                text:
                                    'follow at least 3 creators to personalize your feed',
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
