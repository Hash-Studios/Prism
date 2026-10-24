import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_grid.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Starts loading the wallpapers of [userId] and shows a skeleton, then the grid. It is a sliver.
class UserProfileLoader extends StatefulWidget {
  const UserProfileLoader({super.key, required this.userId, this.ownProfile = false});

  final String userId;
  final bool ownProfile;

  @override
  State<UserProfileLoader> createState() => _UserProfileLoaderState();
}

class _UserProfileLoaderState extends State<UserProfileLoader> {
  @override
  void initState() {
    super.initState();
    _startIfNeeded();
  }

  @override
  void didUpdateWidget(UserProfileLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _startIfNeeded();
    }
  }

  void _startIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.userId.isEmpty) return;

      final bloc = context.read<PublicProfileBloc>();
      final state = bloc.state;
      if (state.profileId == widget.userId && state.status != LoadStatus.initial) return;
      bloc.add(PublicProfileEvent.started(identifier: widget.userId));
    });
  }

  bool _showLoading(PublicProfileState state) {
    if (widget.userId.isEmpty) return false;
    return state.profileId != widget.userId ||
        state.status == LoadStatus.initial ||
        (state.status == LoadStatus.loading && state.walls.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PublicProfileBloc, PublicProfileState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.profileId != current.profileId ||
          previous.walls.isEmpty != current.walls.isEmpty,
      builder: (context, state) {
        if (_showLoading(state)) {
          return const SliverToBoxAdapter(child: LoadingCards());
        }
        if (state.status == LoadStatus.failure && state.walls.isEmpty) {
          return SliverToBoxAdapter(
            child: GlintState(
              kind: GlintStateKind.error,
              title: context.l10n.accountCouldNotLoadWallpapers,
              actionLabel: context.l10n.accountTryAgain,
              onAction: () => context.read<PublicProfileBloc>().add(const PublicProfileEvent.refreshRequested()),
            ),
          );
        }
        return UserProfileGrid(ownProfile: widget.ownProfile);
      },
    );
  }
}
