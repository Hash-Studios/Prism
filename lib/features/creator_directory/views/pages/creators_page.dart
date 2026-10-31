import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_directory/biz/creator_directory_cubit.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/follow_outcome_toast.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// All creators in the directory, with category chips and infinite scroll.
@RoutePage()
class CreatorsPage extends StatelessWidget {
  const CreatorsPage({super.key, this.source = 'home'});

  final String source;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<CreatorDirectoryCubit>(create: (_) => getIt<CreatorDirectoryCubit>()..loadPage()),
        BlocProvider<PublicProfileBloc>(create: (_) => getIt<PublicProfileBloc>()),
      ],
      child: BlocListener<PublicProfileBloc, PublicProfileState>(
        listenWhen: (prev, curr) => curr.followOutcome != null && prev.followOutcome != curr.followOutcome,
        listener: (context, state) => showFollowOutcomeToast(context, state.followOutcome!),
        child: BlocBuilder<CreatorDirectoryCubit, CreatorDirectoryState>(
          builder: (context, state) => PrismPage(
            title: context.l10n.creatorsTitle,
            headerBottom: state.categories.isEmpty ? null : _CategoryChips(state: state),
            body: _Body(state: state),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.state});

  final CreatorDirectoryState state;

  @override
  Widget build(BuildContext context) {
    final List<String?> filters = <String?>[null, ...state.categories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: PrismSpace.pageInsets,
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.xs),
        itemBuilder: (context, index) {
          final String? category = filters[index];
          return Center(
            child: PrismChip(
              label: category ?? context.l10n.creatorsFilterAll,
              selected: state.category == category,
              onTap: () => _select(context, category),
            ),
          );
        },
      ),
    );
  }

  void _select(BuildContext context, String? category) {
    if (state.category == category) return;
    analytics.track(CreatorsCategoryFilteredEvent(category: category ?? 'all'));
    context.read<CreatorDirectoryCubit>().loadPage(category: category);
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state});

  final CreatorDirectoryState state;

  @override
  Widget build(BuildContext context) {
    if (state.status == CreatorDirectoryStatus.loading) return PrismSkeleton.cards();
    if (state.status == CreatorDirectoryStatus.failed) {
      return GlintState(
        kind: GlintStateKind.error,
        title: context.l10n.creatorsLoadError,
        actionLabel: context.l10n.wallpaperTryAgain,
        onAction: () => context.read<CreatorDirectoryCubit>().loadPage(category: state.category),
      );
    }
    if (state.isEmpty) {
      return GlintState(
        kind: GlintStateKind.empty,
        title: context.l10n.creatorsEmptyTitle,
        body: context.l10n.creatorsEmptyBody,
      );
    }
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification.metrics.extentAfter < 600 && state.hasMore) {
          context.read<CreatorDirectoryCubit>().loadMore();
        }
        return false;
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
          PrismSpace.page,
          PrismSpace.md,
          PrismSpace.page,
          PrismSpace.bottomBarClearance,
        ),
        itemCount: state.creators.length + (state.loadingMore ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.md),
        itemBuilder: (context, index) {
          if (index >= state.creators.length) {
            return const Padding(
              padding: EdgeInsets.all(PrismSpace.md),
              child: Center(child: CircularProgressIndicator.adaptive()),
            );
          }
          final creator = state.creators[index];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: CreatorDirectoryCard(
                creator: creator,
                followed: state.followed.contains(creator.uid),
                source: 'see_all',
              ),
            ),
          );
        },
      ),
    );
  }
}
