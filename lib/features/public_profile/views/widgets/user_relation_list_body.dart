import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/user_summary_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shared body for [FollowersScreen] and [FollowingListScreen]. The two
/// screens are identical apart from terminology, which bloc state fields
/// they read and which events they dispatch; [kind] drives all of that.
class UserRelationListBody extends StatefulWidget {
  const UserRelationListBody({super.key, required this.kind, required this.emails});

  /// Full list of email addresses (all pages). Passed from profile screen.
  final List<String> emails;

  final UserRelationKind kind;

  @override
  State<UserRelationListBody> createState() => _UserRelationListBodyState();
}

class _UserRelationListBodyState extends State<UserRelationListBody> {
  static const int _searchDebounceMs = 500;
  static const int _searchMinLength = 2;

  bool get _isFollowers => widget.kind == UserRelationKind.followers;

  // Each instance gets its own bloc so that navigating into another user's
  // relation list (and back) never clobbers this screen's state.
  late final PublicProfileBloc _bloc;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearchActive = false;

  RelationList _list(PublicProfileState state) => state.relation(widget.kind);

  PublicProfileEvent _fetchPageEvent(int page) =>
      PublicProfileEvent.relationPageRequested(kind: widget.kind, allEmails: widget.emails, page: page);

  String get _title => _isFollowers ? 'Followers' : 'Following';

  String get _emptyTitle => _isFollowers ? 'No followers yet' : 'Not following anyone yet';

  String get _emptyBody => _isFollowers
      ? 'People who follow this account will show up here.'
      : 'Accounts followed from here will show up here.';

  String get _loadFailedTitle => _isFollowers ? 'Could not load followers' : 'Could not load following';

  void _maybeAutoLoadMore(PublicProfileState state) {
    final RelationList list = _list(state);
    if (_isSearchActive || list.isFetching || !list.hasMore) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final current = _list(_bloc.state);
      if (_isSearchActive || current.isFetching || !current.hasMore) {
        return;
      }
      // If the list still cannot scroll, auto-fetch the next page so users are
      // not stuck on a tiny first page when many emails no longer map to docs.
      if (_scrollController.position.maxScrollExtent <= 0) {
        _bloc.add(_fetchPageEvent(current.page + 1));
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PublicProfileBloc>();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
    // Load first page.
    if (widget.emails.isNotEmpty) {
      _bloc.add(_fetchPageEvent(0));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    _bloc.close();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = _scrollController.position.maxScrollExtent - 200;
    if (_scrollController.offset < threshold) return;

    final list = _list(_bloc.state);
    if (list.isFetching || !list.hasMore || _isSearchActive) return;

    _bloc.add(_fetchPageEvent(list.page + 1));
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();

    if (query.length < _searchMinLength) {
      if (_isSearchActive) {
        setState(() => _isSearchActive = false);
        _bloc.add(PublicProfileEvent.relationSearchCleared(kind: widget.kind));
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: _searchDebounceMs), () {
      if (!mounted) return;
      setState(() => _isSearchActive = true);
      _bloc.add(PublicProfileEvent.relationSearchRequested(kind: widget.kind, query: query, allEmails: widget.emails));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublicProfileBloc>.value(
      value: _bloc,
      child: PrismPage(
        title: _title,
        headerBottom: _SearchField(controller: _searchController),
        body: BlocBuilder<PublicProfileBloc, PublicProfileState>(
          buildWhen: (prev, curr) => _list(prev) != _list(curr),
          builder: (context, state) {
            final list = _list(state);
            // Search mode.
            if (_isSearchActive) {
              if (list.isSearching) {
                return PrismSkeleton.rows(rows: 5);
              }
              final results = list.searchResults ?? const <UserSummaryEntity>[];
              if (results.isEmpty) {
                return GlintState(
                  kind: GlintStateKind.empty,
                  title: 'No results',
                  body: 'Nobody matches "${_searchController.text.trim()}". Try a different username.',
                );
              }
              return _UserList(users: results, scrollController: null, hasMore: false, isLoading: false);
            }

            // Paginated mode.
            final summaries = list.summaries;
            if (list.isFetching && summaries.isEmpty) {
              return PrismSkeleton.rows();
            }
            if (summaries.isEmpty) {
              if (widget.emails.isEmpty) {
                return GlintState(kind: GlintStateKind.empty, title: _emptyTitle, body: _emptyBody);
              }
              return GlintState(
                kind: GlintStateKind.error,
                title: _loadFailedTitle,
                body: 'Check your connection and try again.',
                actionLabel: 'Try again',
                onAction: () => _bloc.add(_fetchPageEvent(0)),
              );
            }
            _maybeAutoLoadMore(state);
            return _UserList(
              users: summaries,
              scrollController: _scrollController,
              hasMore: list.hasMore,
              isLoading: list.isFetching,
            );
          },
        ),
      ),
    );
  }
}

/// Reusable list with optional load-more footer.
class _UserList extends StatelessWidget {
  const _UserList({
    required this.users,
    required this.scrollController,
    required this.hasMore,
    required this.isLoading,
  });

  final List<UserSummaryEntity> users;
  final ScrollController? scrollController;
  final bool hasMore;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final itemCount = users.length + (hasMore || isLoading ? 1 : 0);
    return ListView.separated(
      controller: scrollController,
      padding: EdgeInsets.only(top: PrismSpace.xs, bottom: PrismSpace.xxl + MediaQuery.paddingOf(context).bottom),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.xxs),
      itemBuilder: (context, index) {
        if (index >= users.length) {
          return const PrismSkeleton(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
              child: Row(
                children: <Widget>[
                  PrismBone.circle(size: 44),
                  SizedBox(width: PrismSpace.sm),
                  PrismBone(width: 140),
                ],
              ),
            ),
          );
        }
        final user = users[index];
        return UserSummaryTile(
          user: user,
          onTap: () => context.router.push(ProfileRoute(profileIdentifier: user.email)),
        );
      },
    );
  }
}

/// A 48 high pill that filters the list by username.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    const OutlineInputBorder none = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(PrismRadius.pill)),
      borderSide: BorderSide.none,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xxs, PrismSpace.page, PrismSpace.xs),
      child: SizedBox(
        height: 48,
        child: TextField(
          controller: controller,
          textInputAction: TextInputAction.search,
          style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w500),
          cursorColor: cs.primary,
          decoration: InputDecoration(
            hintText: 'Search by username',
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : PrismIconButton(
                      icon: Icons.close_rounded,
                      tooltip: 'Clear search',
                      iconSize: 20,
                      onPressed: controller.clear,
                    ),
            ),
            contentPadding: EdgeInsets.zero,
            border: none,
            enabledBorder: none,
            focusedBorder: none.copyWith(borderSide: BorderSide(color: cs.primary, width: 1.5)),
          ),
        ),
      ),
    );
  }
}
