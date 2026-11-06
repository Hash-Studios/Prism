import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/analytics_correlation.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/creator_directory/biz/creator_directory_cubit.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/views/widgets/creator_directory_card.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/views/widgets/follow_outcome_toast.dart';
import 'package:Prism/features/user_search/domain/entities/user_search_user.dart';
import 'package:Prism/features/user_search/user_search.dart';
import 'package:Prism/features/user_search/views/widgets/prism_search_field.dart';
import 'package:Prism/l10n/l10n.dart';
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
  Timer? _debounce;
  String? _searchId;

  void _search(String text, {required String sourceContext}) {
    _debounce?.cancel();
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      _bloc.add(const UserSearchEvent.cleared());
      return;
    }
    setState(() => _searchId = AnalyticsCorrelation.newId());
    unawaited(
      analytics.track(
        UserSearchSubmittedEvent(queryLength: trimmed.length, sourceContext: sourceContext, searchId: _searchId),
      ),
    );
    _bloc.add(UserSearchEvent.searchRequested(query: trimmed));
  }

  void _onChanged(String text) {
    if (text.trim().isEmpty) {
      _search(text, sourceContext: 'user_search_typing');
      return;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted || text.trim() == _bloc.state.query) return;
      _search(text, sourceContext: 'user_search_typing');
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    searchController.dispose();
    unawaited(_bloc.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // usersV2 reads require auth per firestore.rules; guests must sign in first.
    final bool loggedIn = app_state.prismUser.loggedIn;
    return PrismPage(
      title: context.l10n.accountFindCreators,
      headerBottom: loggedIn
          ? Padding(
              padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.sm),
              child: PrismSearchField(
                controller: searchController,
                hint: context.l10n.accountSearchCreators,
                autofocus: true,
                onChanged: _onChanged,
                onSubmitted: (text) => _search(text, sourceContext: 'user_search_textfield'),
              ),
            )
          : null,
      body: loggedIn
          ? MultiBlocProvider(
              providers: <BlocProvider<dynamic>>[
                BlocProvider<UserSearchBloc>.value(value: _bloc),
                // Creators to follow, shown before the first search. Loaded once per page.
                BlocProvider<CreatorDirectoryCubit>(create: (_) => getIt<CreatorDirectoryCubit>()..loadRow()),
                BlocProvider<PublicProfileBloc>(create: (_) => getIt<PublicProfileBloc>()),
              ],
              child: BlocListener<PublicProfileBloc, PublicProfileState>(
                listenWhen: (prev, curr) => curr.followOutcome != null && prev.followOutcome != curr.followOutcome,
                listener: (context, state) => showFollowOutcomeToast(context, state.followOutcome!),
                child: _UserSearchLoader(searchId: _searchId),
              ),
            )
          : SignInPrompt(feature: context.l10n.coreSignInCreatorSearchFeature),
    );
  }
}

class _UserSearchLoader extends StatelessWidget {
  const _UserSearchLoader({this.searchId});
  final String? searchId;

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
            title: context.l10n.accountCouldNotSearchCreators,
            body: context.l10n.accountCheckConnectionTryAgain,
            actionLabel: context.l10n.accountTryAgain,
            onAction: () => context.read<UserSearchBloc>().add(UserSearchEvent.searchRequested(query: state.query)),
          );
        }
        if (state.users.isEmpty) {
          return GlintState(
            kind: GlintStateKind.empty,
            title: context.l10n.accountNoCreatorsFound,
            body: context.l10n.accountCreatorSearchEmptyBody,
            actionLabel: context.l10n.accountBrowseCreators,
            onAction: () => _openCreators(context),
          );
        }
        return _CreatorList(users: state.users, queryLength: state.query.trim().length, searchId: searchId);
      },
    );
  }
}

/// Opens the creator directory, so an empty search still leads somewhere.
void _openCreators(BuildContext context) {
  context.router.push(CreatorsRoute(source: 'user_search'));
}

/// Before the first search: creators to follow under a section header. While they load, row skeletons. When there
/// are none, a Glint with a hint and a link to the directory.
class _SearchHint extends StatelessWidget {
  const _SearchHint();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CreatorDirectoryCubit, CreatorDirectoryState>(
      builder: (context, state) => switch (state.status) {
        CreatorDirectoryStatus.loading => PrismSkeleton.rows(),
        CreatorDirectoryStatus.loaded when state.creators.isNotEmpty => _SuggestedCreators(creators: state.creators),
        _ => const _EmptyHint(),
      },
    );
  }
}

class _SuggestedCreators extends StatelessWidget {
  const _SuggestedCreators({required this.creators});

  final List<DirectoryCreator> creators;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md),
      children: <Widget>[
        PrismSectionHeader(
          title: context.l10n.creatorsToFollow,
          actionLabel: context.l10n.creatorsSeeAll,
          onAction: () => _openCreators(context),
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xxs),
        ),
        for (final DirectoryCreator creator in creators)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
            // The row load drops creators the viewer already follows.
            child: CreatorFollowRow(creator: creator.entry, followed: false, source: 'search'),
          ),
      ],
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    // Above the centre, where the eye lands first, and clear of the keyboard.
    return Align(
      alignment: const Alignment(0, -0.35),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(PrismSpace.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Glint(mood: GlintMood.curious),
            const SizedBox(height: PrismSpace.md),
            Text(
              context.l10n.accountSearchCreatorsByName,
              textAlign: TextAlign.center,
              style: PrismTextStyles.body(context),
            ),
            const SizedBox(height: PrismSpace.lg),
            PrismButton(
              label: context.l10n.creatorsToFollow,
              variant: PrismButtonVariant.tonal,
              size: PrismButtonSize.compact,
              onPressed: () => _openCreators(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreatorList extends StatelessWidget {
  const _CreatorList({required this.users, required this.queryLength, this.searchId});
  final String? searchId;

  final List<UserSearchUser> users;
  final int queryLength;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: EdgeInsets.only(top: PrismSpace.xxs, bottom: MediaQuery.paddingOf(context).bottom + PrismSpace.md),
      itemCount: users.length,
      itemBuilder: (context, index) =>
          _CreatorRow(user: users[index], index: index, queryLength: queryLength, searchId: searchId),
    );
  }
}

class _CreatorRow extends StatelessWidget {
  const _CreatorRow({required this.user, required this.index, required this.queryLength, this.searchId});
  final String? searchId;

  final UserSearchUser user;
  final int index;
  final int queryLength;

  @override
  Widget build(BuildContext context) {
    final String followers = context.l10n.accountFollowersCount(user.followerCount);
    return PrismRow(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
      leading: PrismAvatar(url: user.profilePhoto, name: user.name),
      title: user.name,
      subtitle: '@${user.username} · $followers',
      onTap: () {
        PrismHaptics.tap();
        analytics.track(
          UserSearchResultOpenedEvent(
            resultUserId: user.id.trim().isNotEmpty ? user.id : 'unknown',
            index: index,
            queryLength: queryLength,
            searchId: searchId,
          ),
        );
        context.router.push(ProfileRoute(profileIdentifier: user.id));
      },
    );
  }
}
