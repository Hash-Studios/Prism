import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/onboarding_v2/src/biz/onboarding_v2_bloc.j.dart';
import 'package:Prism/features/onboarding_v2/src/utils/onboarding_v2_config.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/interest_category_tile.dart';
import 'package:Prism/features/onboarding_v2/src/views/widgets/onboarding_frame.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const SliverGridDelegateWithFixedCrossAxisCount _gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
  crossAxisCount: 3,
  crossAxisSpacing: PrismSpace.xs,
  mainAxisSpacing: PrismSpace.xs,
  childAspectRatio: 0.85,
);

/// Step 1: pick the categories that shape the feed.
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
      buildWhen: (prev, curr) =>
          prev.interestsData != curr.interestsData ||
          prev.loadStatus != curr.loadStatus ||
          prev.actionStatus != curr.actionStatus,
      builder: (context, state) {
        final OnboardingInterestsData data = state.interestsData;
        final bool loading = data.available.isEmpty && state.loadStatus != LoadStatus.success;
        final bool empty = data.available.isEmpty && !loading;
        final OnboardingV2Bloc bloc = context.read<OnboardingV2Bloc>();
        return OnboardingFrame(
          title: 'Pick your vibe',
          body: 'Choose at least ${OnboardingV2Config.minInterests} to shape your feed.',
          primaryLabel: 'Continue',
          primaryLoading: state.actionStatus == ActionStatus.inProgress,
          onPrimary: data.canContinue ? () => bloc.add(const OnboardingV2Event.interestsConfirmed()) : null,
          onSkip: empty ? () => bloc.add(const OnboardingV2Event.aiGenerationStepContinued()) : null,
          child: loading
              ? const _GridSkeleton()
              : empty
              ? Center(
                  child: GlintState(
                    kind: GlintStateKind.error,
                    title: 'Could not load categories',
                    body: 'Check your connection and try again.',
                    actionLabel: 'Try again',
                    onAction: () => bloc.add(const OnboardingV2Event.started()),
                  ),
                )
              : _Grid(data: data, bloc: bloc),
        );
      },
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.data, required this.bloc});

  final OnboardingInterestsData data;
  final OnboardingV2Bloc bloc;

  @override
  Widget build(BuildContext context) {
    final int picked = data.selected.length;
    final String counter = picked < OnboardingV2Config.minInterests
        ? '$picked of ${OnboardingV2Config.minInterests} picked'
        : '$picked picked';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: PrismSpace.pageInsets,
          child: Semantics(liveRegion: true, child: Text(counter, style: PrismTextStyles.caption(context))),
        ),
        const SizedBox(height: PrismSpace.xs),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.sm),
            itemCount: data.available.length,
            gridDelegate: _gridDelegate,
            itemBuilder: (context, index) {
              final String category = data.available[index];
              return InterestCategoryTile(
                name: category,
                imageUrl: data.categoryImages[category],
                isSelected: data.selected.contains(category),
                onTap: () => bloc.add(OnboardingV2Event.interestToggled(category)),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    return PrismSkeleton(
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.lg, PrismSpace.page, PrismSpace.sm),
        itemCount: 12,
        gridDelegate: _gridDelegate,
        itemBuilder: (_, _) => const PrismBone(height: double.infinity, radius: PrismRadius.sm),
      ),
    );
  }
}
