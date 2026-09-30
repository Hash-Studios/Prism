import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Starts loading the wallpapers of [email] and shows a skeleton, then the grid. It is a sliver.
class UserProfileLoader extends StatefulWidget {
  const UserProfileLoader({super.key, required this.email, this.ownProfile = false});

  final String email;
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
    if (oldWidget.email != widget.email) {
      _startIfNeeded();
    }
  }

  void _startIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.email.isEmpty) return;

      final bloc = context.read<PublicProfileBloc>();
      final state = bloc.state;
      if (state.email == widget.email && state.status != LoadStatus.initial) return;
      bloc.add(PublicProfileEvent.started(email: widget.email));
    });
  }

  bool _showLoading(PublicProfileState state) {
    if (widget.email.isEmpty) return false;
    return state.email != widget.email ||
        state.status == LoadStatus.initial ||
        (state.status == LoadStatus.loading && state.walls.isEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PublicProfileBloc, PublicProfileState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.email != current.email ||
          previous.walls.isEmpty != current.walls.isEmpty,
      builder: (context, state) {
        if (_showLoading(state)) {
          return const SliverToBoxAdapter(child: LoadingCards());
        }
        return UserProfileGrid(ownProfile: widget.ownProfile);
      },
    );
  }
}
