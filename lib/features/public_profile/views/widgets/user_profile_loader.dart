import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/home/wallpapers/loading.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class UserProfileLoader extends StatefulWidget {
  final String? email;
  const UserProfileLoader({required this.email});
  @override
  _UserProfileLoaderState createState() => _UserProfileLoaderState();
}

class _UserProfileLoaderState extends State<UserProfileLoader> with AutomaticKeepAliveClientMixin<UserProfileLoader> {
  String get _normalizedEmail => widget.email?.trim() ?? '';

  @override
  void initState() {
    super.initState();
    _requestProfileLoadIfNeeded();
  }

  @override
  void didUpdateWidget(UserProfileLoader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.email != widget.email) {
      _requestProfileLoadIfNeeded();
    }
  }

  /// Same gating as [PublicProfileAdapter._loadForEmail] (without [force]).
  void _requestProfileLoadIfNeeded() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final email = _normalizedEmail;
      if (email.isEmpty) return;

      final bloc = context.read<PublicProfileBloc>();
      final state = bloc.state;
      final sameEmail = state.email == email;
      if (sameEmail) {
        if (state.status == LoadStatus.loading) return;
        if (state.status != LoadStatus.initial) return;
      }
      bloc.add(PublicProfileEvent.started(email: email));
    });
  }

  bool _showLoading(PublicProfileState state) {
    final email = _normalizedEmail;
    if (email.isEmpty) return false;
    if (state.email != email) return true;
    if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
      return true;
    }
    // [PublicProfileBloc._onStarted] sets [PublicProfileState.email] before
    // [_loadAll] emits loading, so we can briefly see success with stale data.
    final loadedEmail = state.profile.email.trim();
    if (loadedEmail.isNotEmpty && loadedEmail.toLowerCase() != email.toLowerCase()) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: BlocBuilder<PublicProfileBloc, PublicProfileState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.email != current.email ||
            previous.profile.email != current.profile.email,
        builder: (context, state) {
          if (_showLoading(state)) {
            return const LoadingCards();
          }
          return UserProfileGrid(email: widget.email);
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}
