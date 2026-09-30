import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/creator_card.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Step 2: follow a few suggested creators.
class F2StarterPackPage extends StatelessWidget {
  const F2StarterPackPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OnboardingV2Bloc, OnboardingV2State>(
      buildWhen: (prev, curr) =>
          prev.starterPackData != curr.starterPackData ||
          prev.loadStatus != curr.loadStatus ||
          prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        final OnboardingStarterPackData data = state.starterPackData;
        final bool loading = data.creators.isEmpty && state.loadStatus != LoadStatus.success;
        final bool empty = data.creators.isEmpty && !loading;
        final OnboardingV2Bloc bloc = context.read<OnboardingV2Bloc>();
        return OnboardingFrame(
          title: 'Find your people',
          body: 'We picked a few creators for you. Follow at least ${OnboardingV2Config.minFollows}.',
          primaryLabel: 'Continue',
          primaryLoading: state.actionStatus == ActionStatus.inProgress,
          onPrimary: data.canContinue ? () => bloc.add(const OnboardingV2Event.starterPackConfirmed()) : null,
          onSkip: empty ? () => bloc.add(const OnboardingV2Event.aiGenerationStepContinued()) : null,
          child: loading
              ? PrismSkeleton.cards(height: 190)
              : empty
              ? Center(
                  child: GlintState(
                    kind: GlintStateKind.empty,
                    title: 'No creators to suggest yet',
                    body: 'You can follow creators from their profiles later.',
                    actionLabel: 'Try again',
                    onAction: () => bloc.add(const OnboardingV2Event.started()),
                  ),
                )
              : _CreatorList(data: data, bloc: bloc),
        );
      },
    );
  }
}

class _CreatorList extends StatelessWidget {
  const _CreatorList({required this.data, required this.bloc});

  final OnboardingStarterPackData data;
  final OnboardingV2Bloc bloc;

  @override
  Widget build(BuildContext context) {
    final int followed = data.selectedEmails.length;
    final String counter = followed < OnboardingV2Config.minFollows
        ? '$followed of ${OnboardingV2Config.minFollows} followed'
        : '$followed followed';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: PrismSpace.pageInsets,
          child: Semantics(liveRegion: true, child: Text(counter, style: PrismTextStyles.caption(context))),
        ),
        const SizedBox(height: PrismSpace.xs),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.sm),
            itemCount: data.creators.length,
            separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.sm),
            itemBuilder: (context, index) {
              final creator = data.creators[index];
              return CreatorCard(
                creator: creator,
                isSelected: data.selectedEmails.contains(creator.email),
                onToggle: () => bloc.add(OnboardingV2Event.creatorFollowToggled(creator.email)),
              );
            },
          ),
        ),
      ],
    );
  }
}
