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
        final creators = state.starterPackData.creators;

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
                  child: creators.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                            stops: [0.0, 0.08, 0.82, 1.0],
                          ).createShader(rect),
                          blendMode: BlendMode.dstIn,
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: ListView.separated(
                              physics: const BouncingScrollPhysics(),
                              itemCount: creators.length,
                              padding: const EdgeInsets.fromLTRB(0, 25, 0, 60),
                              separatorBuilder: (_, _) => SizedBox(height: OnboardingLayout.creatorGap * sy),
                              itemBuilder: (context, index) {
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
