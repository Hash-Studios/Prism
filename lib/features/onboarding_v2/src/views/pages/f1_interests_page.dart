import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/interest_category_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class F1InterestsPage extends StatelessWidget {
  const F1InterestsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.interestsData != curr.interestsData || prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        final interestsData = state.interestsData;
        final selectedCount = interestsData.selected.length;
        final canContinue = interestsData.canContinue;
        final isLoading = state.actionStatus == ActionStatus.inProgress;

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => context.read<OnboardingV2Bloc>().add(const OnboardingV2Event.stepBack()),
                        child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Step 2 of 4',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'What do you like?',
                        style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Select at least ${OnboardingV2Config.minInterests} categories to personalize your feed.',
                        style: const TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Stack(
                    children: [
                      if (interestsData.available.isEmpty)
                        const Center(child: CircularProgressIndicator(color: Colors.white))
                      else
                        GridView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 10,
                            crossAxisSpacing: 10,
                          ),
                          itemCount: interestsData.available.length,
                          itemBuilder: (context, index) {
                            final category = interestsData.available[index];
                            final imageUrl = interestsData.categoryImages[category];
                            return InterestCategoryTile(
                              name: category,
                              isSelected: interestsData.selected.contains(category),
                              imageUrl: imageUrl,
                              onTap: () =>
                                  context.read<OnboardingV2Bloc>().add(OnboardingV2Event.interestToggled(category)),
                            );
                          },
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Colors.black],
                              stops: [0.0, 0.45],
                            ),
                          ),
                          padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
                          child: Column(
                            children: [
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Text(
                                  selectedCount == 0
                                      ? '0 of ${OnboardingV2Config.minInterests} selected'
                                      : '$selectedCount selected',
                                  key: ValueKey(selectedCount),
                                  style: TextStyle(
                                    color: canContinue ? Theme.of(context).colorScheme.primary : Colors.white54,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: canContinue && !isLoading
                                      ? () => context.read<OnboardingV2Bloc>().add(
                                          const OnboardingV2Event.interestsConfirmed(),
                                        )
                                      : null,
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: const StadiumBorder(),
                                  ),
                                  child: isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                                        )
                                      : const Text(
                                          'Continue',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
