import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/user_search.dart';
import 'package:Prism/features/user_search/views/widgets/prism_search_field.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage(name: 'UserSearchRoute')
class UserSearch extends StatefulWidget {
  const UserSearch({super.key});

  @override
  State<UserSearch> createState() => _UserSearchState();
}

class _UserSearchState extends State<UserSearch> {
  final TextEditingController searchController = TextEditingController();
  final UserSearchBloc _bloc = getIt<UserSearchBloc>();

  @override
  void dispose() {
    searchController.dispose();
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // usersV2 reads require auth per firestore.rules; guests must sign in first.
    final bool loggedIn = app_state.prismUser.loggedIn;
    return PrismPage(
      title: 'Find creators',
      headerBottom: loggedIn
          ? Padding(
              padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.sm),
              child: PrismSearchField(
                controller: searchController,
                hint: 'Search creators',
                autofocus: true,
                onChanged: (text) {
                  if (text.trim().isEmpty) _bloc.add(const UserSearchEvent.cleared());
                },
                onSubmitted: (text) {
                  final String trimmed = text.trim();
                  if (trimmed.isEmpty) {
                    _bloc.add(const UserSearchEvent.cleared());
                    return;
                  }
                  analytics.track(
                    UserSearchSubmittedEvent(queryLength: trimmed.length, sourceContext: 'user_search_textfield'),
                  );
                  _bloc.add(UserSearchEvent.searchRequested(query: trimmed));
                },
              ),
            )
          : null,
      body: loggedIn
          ? BlocProvider.value(value: _bloc, child: const _UserSearchLoader())
          : const SignInPrompt(feature: 'creator search'),
    );
  }
}

class _UserSearchLoader extends StatelessWidget {
  const _UserSearchLoader();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserSearchBloc, UserSearchState>(
      builder: (context, state) {
        if (state.status == LoadStatus.initial) {
          return const _SearchHint();
        }
        if (state.status == LoadStatus.loading) {
          return PrismSkeleton.rows();
        }
        if (state.status == LoadStatus.failure) {
          return GlintState(
            kind: GlintStateKind.error,
            title: "Couldn't search creators",
            body: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => context.read<UserSearchBloc>().add(UserSearchEvent.searchRequested(query: state.query)),
          );
        }
        if (state.users.isEmpty) {
          return const GlintState(
            kind: GlintStateKind.empty,
            title: 'No creators found',
            body: 'Check the spelling or try another name.',
          );
        }
        return _CreatorList(users: state.users, queryLength: state.query.trim().length);
      },
    );
  }
}

class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Glint(mood: GlintMood.curious),
            const SizedBox(height: PrismSpace.md),
            Text('Search creators by name', style: PrismTextStyles.body(context)),
          ],
        ),
      ),
    );
  }
}

class _CreatorList extends StatelessWidget {
  const _CreatorList({required this.users, required this.queryLength});

  final List<UserSearchUser> users;
  final int queryLength;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.only(top: PrismSpace.xxs, bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md),
      itemCount: users.length,
      itemBuilder: (context, index) => _CreatorRow(user: users[index], index: index, queryLength: queryLength),
    );
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.user, required this.index, required this.queryLength});

  final UserSearchUser user;
  final int index;
  final int queryLength;

  @override
  Widget build(BuildContext context) {
    final String followers = '${user.followerCount} ${user.followerCount == 1 ? 'follower' : 'followers'}';
    return PrismRow(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
      leading: PrismAvatar(url: user.profilePhoto, name: user.name),
      title: user.name,
      subtitle: '@${user.username} · $followers',
      onTap: () {
        analytics.track(
          UserSearchResultOpenedEvent(
            resultUserId: user.id.trim().isNotEmpty ? user.id : user.email,
            index: index,
            queryLength: queryLength,
          ),
        );
        context.router.push(ProfileRoute(profileIdentifier: user.email));
      },
    );
  }
}
