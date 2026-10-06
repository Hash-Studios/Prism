import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserProfileLoader extends StatefulWidget {
  const UserProfileLoader({required this.email});

  final String email;

  @override
  _UserProfileLoaderState createState() => _UserProfileLoaderState();
}

class _UserProfileLoaderState extends State<UserProfileLoader> with AutomaticKeepAliveClientMixin<UserProfileLoader> {
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
    return state.email != widget.email || state.status == LoadStatus.initial || state.status == LoadStatus.loading;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: BlocBuilder<PublicProfileBloc, PublicProfileState>(
        buildWhen: (previous, current) => previous.status != current.status || previous.email != current.email,
        builder: (context, state) {
          if (_showLoading(state)) {
            return const LoadingCards();
          }
          if (state.status == LoadStatus.failure && state.walls.isEmpty) {
            return GlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load wallpapers",
              actionLabel: 'Retry',
              onAction: () => context.read<PublicProfileBloc>().add(const PublicProfileEvent.refreshRequested()),
            );
          }
          return const UserProfileGrid();
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
