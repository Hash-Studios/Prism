import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/creator_card.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// F2 unique content: starter pack creator cards.
/// Background, headline, progress, button, and helper text are owned by the shell overlay.
class F2StarterPackPage extends StatelessWidget {
  const F2StarterPackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.starterPackData != curr.starterPackData,
      builder: (context, state) {
        final creators = state.starterPackData.creators.take(3).toList(growable: false);

        return OnboardingFrame(
          builder: (context, sx, sy) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: OnboardingLayout.creatorsY * sy,
                  left: OnboardingLayout.creatorsX * sx,
                  right: OnboardingLayout.creatorsX * sx,
                  height: OnboardingLayout.tilesHeight * sy,
                  child: ListView.separated(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 3,
                    separatorBuilder: (_, __) => SizedBox(height: OnboardingLayout.creatorGap * sy),
                    itemBuilder: (context, index) {
                      if (index >= creators.length) {
                        return SizedBox(
                          height: OnboardingLayout.creatorHeight * sy,
                          child: const CreatorCard(creator: null, onToggle: null),
                        );
                      }
                      final creator = creators[index];
                      return SizedBox(
                        height: OnboardingLayout.creatorHeight * sy,
                        child: CreatorCard(
                          creator: creator,
                          onToggle: () => context.read<OnboardingV2Bloc>().add(
                            OnboardingV2Event.creatorFollowToggled(creator.email),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
