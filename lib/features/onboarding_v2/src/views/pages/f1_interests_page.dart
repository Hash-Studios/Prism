import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/theme/onboarding_theme.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/interest_category_tile.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// F1 unique content: interest category tiles grid.
/// Background, headline, progress, button, and helper text are owned by the shell overlay.
class F1InterestsPage extends StatelessWidget {
  const F1InterestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingV2Bloc, OnboardingV2State>(
      listenWhen: (prev, curr) => prev.starterPackData.creators.isEmpty && curr.starterPackData.creators.isNotEmpty,
      listener: (context, state) {
        for (final creator in state.starterPackData.creators) {
          if (creator.photoUrl.isNotEmpty) {
            precacheImage(CachedNetworkImageProvider(creator.photoUrl), context);
          }
          for (final url in creator.previewUrls) {
            precacheImage(CachedNetworkImageProvider(url), context);
          }
        }
      },
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
                      : ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                            stops: [0.01, 0.10, 0.82, 1.0],
                          ).createShader(rect),
                          blendMode: BlendMode.dstIn,
                          child: Padding(
                            padding: const EdgeInsets.all(1),
                            child: GridView.builder(
                              padding: const EdgeInsets.fromLTRB(0, 25, 0, 60),
                              physics: const BouncingScrollPhysics(),
                              itemCount: available.length,
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
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
                                  onTap: () =>
                                      context.read<OnboardingV2Bloc>().add(OnboardingV2Event.interestToggled(category)),
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
