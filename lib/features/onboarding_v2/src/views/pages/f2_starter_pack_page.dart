import 'package:Prism/core/utils/status.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/creator_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class F2StarterPackPage extends StatelessWidget {
  const F2StarterPackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) => prev.starterPackData != curr.starterPackData || prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        final packData = state.starterPackData;
        final selectedCount = packData.selectedEmails.length;
        final canContinue = packData.canContinue;
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
                      const Text(
                        'Follow artists',
                        style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                      ),
                      Row(
                        children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Text(
                              '$selectedCount/${OnboardingV2Config.minFollows}',
                              key: ValueKey(selectedCount),
                              style: TextStyle(
                                color: canContinue ? Theme.of(context).colorScheme.primary : Colors.white54,
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Step 3 of 4',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Get the latest drops from top creators.',
                    style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Stack(
                    children: [
                      if (packData.creators.isEmpty)
                        const Center(child: CircularProgressIndicator(color: Colors.white))
                      else
                        ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 124),
                          itemCount: packData.creators.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final creator = packData.creators[index];
                            return CreatorCard(
                              creator: creator,
                              onToggle: () => context.read<OnboardingV2Bloc>().add(
                                OnboardingV2Event.creatorFollowToggled(creator.email),
                              ),
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
                          padding: const EdgeInsets.fromLTRB(16, 64, 16, 20),
                          child: SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: canContinue && !isLoading
                                  ? () => context.read<OnboardingV2Bloc>().add(
                                      const OnboardingV2Event.starterPackConfirmed(),
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
                                  : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            ),
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
