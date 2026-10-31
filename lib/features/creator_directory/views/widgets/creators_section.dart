import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_directory/biz/creator_directory_cubit.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/follow_outcome_toast.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

const EdgeInsets _sectionHeaderPadding = EdgeInsets.fromLTRB(
  PrismSpace.page,
  PrismSpace.xl,
  PrismSpace.page,
  PrismSpace.sm,
);

/// The "Creators to follow" row on Home and Search. It hides while the directory is empty or for guests.
class CreatorsSection extends StatefulWidget {
  const CreatorsSection({super.key, required this.source});

  /// 'home' or 'search'.
  final String source;

  @override
  State<CreatorsSection> createState() => _CreatorsSectionState();
}

class _CreatorsSectionState extends State<CreatorsSection> {
  bool _viewedTracked = false;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<CreatorDirectoryCubit>(create: (_) => getIt<CreatorDirectoryCubit>()..loadRow()),
        BlocProvider<PublicProfileBloc>(create: (_) => getIt<PublicProfileBloc>()),
      ],
      child: BlocListener<PublicProfileBloc, PublicProfileState>(
        listenWhen: (prev, curr) => curr.followOutcome != null && prev.followOutcome != curr.followOutcome,
        listener: (context, state) => showFollowOutcomeToast(context, state.followOutcome!),
        child: BlocBuilder<CreatorDirectoryCubit, CreatorDirectoryState>(builder: _buildSection),
      ),
    );
  }

  Widget _buildSection(BuildContext context, CreatorDirectoryState state) {
    if (state.isEmpty) return const SizedBox.shrink();
    if (state.status == CreatorDirectoryStatus.failed) return _buildFailed(context);
    if (state.status == CreatorDirectoryStatus.loading) return _buildLoading(context);
    if (!_viewedTracked) {
      _viewedTracked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) analytics.track(CreatorsSectionViewedEvent(source: widget.source));
      });
    }
    final double cardWidth = math.min(MediaQuery.sizeOf(context).width * 0.82, 340.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(
          title: context.l10n.creatorsToFollow,
          actionLabel: context.l10n.creatorsSeeAll,
          onAction: () => _openSeeAll(context),
          padding: _sectionHeaderPadding,
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: PrismSpace.pageInsets,
          clipBehavior: Clip.none,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int i = 0; i < state.creators.length; i++) ...<Widget>[
                if (i > 0) const SizedBox(width: PrismSpace.sm),
                SizedBox(
                  width: cardWidth,
                  child: CreatorDirectoryCard(
                    creator: state.creators[i],
                    followed: state.followed.contains(state.creators[i].uid),
                    source: widget.source,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    final double cardWidth = math.min(MediaQuery.sizeOf(context).width * 0.82, 340.0);
    return PrismSkeleton(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(padding: _sectionHeaderPadding, child: PrismBone(width: 160, height: 20)),
          Padding(
            padding: PrismSpace.pageInsets,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                PrismBone(width: cardWidth, height: cardWidth * 0.75, radius: PrismRadius.lg),
                const SizedBox(width: PrismSpace.sm),
                PrismBone(width: cardWidth, height: cardWidth * 0.75, radius: PrismRadius.lg),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed(BuildContext context) {
    return Padding(
      padding: PrismSpace.pageInsets,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(context.l10n.creatorsLoadError, style: PrismTextStyles.caption(context))),
          PrismButton(
            label: context.l10n.wallpaperTryAgain,
            variant: PrismButtonVariant.ghost,
            size: PrismButtonSize.compact,
            onPressed: context.read<CreatorDirectoryCubit>().loadRow,
          ),
        ],
      ),
    );
  }

  void _openSeeAll(BuildContext context) {
    analytics.track(CreatorsSeeAllOpenedEvent(source: widget.source));
    context.router.push(CreatorsRoute(source: widget.source));
  }
}
