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
        final interestsData = state.interestsData;
        final available = interestsData.available;

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
                  child: available.isEmpty
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : GridView.builder(
                          physics: const BouncingScrollPhysics(),
                          itemCount: available.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: OnboardingLayout.tileGap * sx,
                            mainAxisSpacing: OnboardingLayout.tileGap * sy,
                            childAspectRatio: (OnboardingLayout.tileSize * sx) / (OnboardingLayout.tileSize * sy),
                          ),
                          itemBuilder: (context, index) {
                            final category = available[index];
                            return InterestCategoryTile(
                              name: category,
                              imageUrl: interestsData.categoryImages[category],
                              isSelected: interestsData.selected.contains(category),
                              onTap: () => context.read<OnboardingV2Bloc>().add(
                                OnboardingV2Event.interestToggled(category),
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
