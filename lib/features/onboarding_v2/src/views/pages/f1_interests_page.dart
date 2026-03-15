import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/interest_category_tile.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// F1 unique content: interest category tiles grid.
/// Background, headline, progress, button, and helper text are owned by the shell overlay.
class F1InterestsPage extends StatelessWidget {
  const F1InterestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.interestsData != curr.interestsData,
      builder: (context, state) {
        final available = state.interestsData.available.take(6).toList(growable: false);

        return OnboardingFrame(
          builder: (context, sx, sy) {
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: OnboardingLayout.tilesY * sy,
                  left: OnboardingLayout.tilesX * sx,
                  right: OnboardingLayout.tilesX * sx,
                  height: OnboardingLayout.tilesHeight * sy,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: 6,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: OnboardingLayout.tileGap * sx,
                      mainAxisSpacing: OnboardingLayout.tileGap * sy,
                      childAspectRatio: (OnboardingLayout.tileSize * sx) / (OnboardingLayout.tileSize * sy),
                    ),
                    itemBuilder: (context, index) {
                      if (index >= available.length) {
                        return const InterestCategoryTile(isSelected: false, onTap: null);
                      }
                      final category = available[index];
                      return InterestCategoryTile(
                        isSelected: state.interestsData.selected.contains(category),
                        onTap: () => context.read<OnboardingV2Bloc>().add(OnboardingV2Event.interestToggled(category)),
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
