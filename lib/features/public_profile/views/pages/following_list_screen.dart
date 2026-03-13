import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/user_summary_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class FollowingListScreen extends StatefulWidget {
  const FollowingListScreen({super.key, required this.following});

  /// List of email addresses that the current user follows, passed from the
  /// profile screen.
  final List<String> following;

  @override
  _FollowingListScreenState createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends State<FollowingListScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.following.isNotEmpty) {
      context.read<PublicProfileBloc>().add(
        PublicProfileEvent.fetchFollowingSummariesRequested(
          emails: widget.following,
          currentUserEmail: app_state.prismUser.email,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: const PreferredSize(
        preferredSize: Size(double.infinity, 55),
        child: HeadingChipBar(current: 'Following'),
      ),
      body: BlocBuilder<PublicProfileBloc, PublicProfileState>(
        buildWhen: (prev, curr) =>
            prev.followingSummaries != curr.followingSummaries || prev.isFetchingSummaries != curr.isFetchingSummaries,
        builder: (context, state) {
          if (state.isFetchingSummaries && state.followingSummaries.isEmpty) {
            return Center(child: Loader());
          }

          if (state.followingSummaries.isEmpty) {
            return Center(
              child: Text(
                widget.following.isEmpty ? "You're not following anyone yet." : 'Could not load following list.',
                style: TextStyle(
                  fontFamily: 'Proxima Nova',
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                  fontSize: 15,
                ),
              ),
            );
          }

          return ListView.separated(
            itemCount: state.followingSummaries.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08), indent: 72),
            itemBuilder: (context, index) {
              final user = state.followingSummaries[index];
              return UserSummaryTile(
                user: user,
                onTap: () {
                  context.router.push(ProfileRoute(profileIdentifier: user.email));
                },
              );
            },
          );
        },
      ),
    );
  }
}
