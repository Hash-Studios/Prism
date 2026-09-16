import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/home/core/heading_chip_bar.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/user_summary_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Which side of the follow graph a [UserRelationListBody] renders.
enum UserRelationKind { followers, following }

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

  bool _isFetching(PublicProfileState state) => _isFollowers ? state.isFetchingFollowers : state.isFetchingFollowing;

  bool _hasMore(PublicProfileState state) => _isFollowers ? state.hasMoreFollowers : state.hasMoreFollowing;

  int _page(PublicProfileState state) => _isFollowers ? state.followerPage : state.followingPage;

  List<UserSummaryEntity> _summaries(PublicProfileState state) =>
      _isFollowers ? state.followerSummaries : state.followingSummaries;

  bool _isSearching(PublicProfileState state) => _isFollowers ? state.isSearchingFollowers : state.isSearchingFollowing;

  List<UserSummaryEntity>? _searchResults(PublicProfileState state) =>
      _isFollowers ? state.followerSearchResults : state.followingSearchResults;

  PublicProfileEvent _fetchPageEvent(int page) => _isFollowers
      ? PublicProfileEvent.fetchFollowerSummariesPageRequested(
          allEmails: widget.emails,
          currentUserEmail: app_state.prismUser.email,
          page: page,
        )
      : PublicProfileEvent.fetchFollowingSummariesPageRequested(
          allEmails: widget.emails,
          currentUserEmail: app_state.prismUser.email,
          page: page,
        );

  PublicProfileEvent _searchEvent(String query) => _isFollowers
      ? PublicProfileEvent.searchFollowerSummariesRequested(
          query: query,
          allEmails: widget.emails,
          currentUserEmail: app_state.prismUser.email,
        )
      : PublicProfileEvent.searchFollowingSummariesRequested(
          query: query,
          allEmails: widget.emails,
          currentUserEmail: app_state.prismUser.email,
        );

  PublicProfileEvent get _clearSearchEvent =>
      _isFollowers ? const PublicProfileEvent.clearFollowerSearch() : const PublicProfileEvent.clearFollowingSearch();

  String get _title => _isFollowers ? 'Followers' : 'Following';

  String get _emptySourceText => _isFollowers ? 'No followers yet.' : "You're not following anyone yet.";

  String get _emptyLoadFailedText => _isFollowers ? 'Could not load followers.' : 'Could not load following list.';

  void _maybeAutoLoadMore(PublicProfileState state) {
    if (_isSearchActive || _isFetching(state) || !_hasMore(state)) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final current = _bloc.state;
      if (_isSearchActive || _isFetching(current) || !_hasMore(current)) {
        return;
      }
      // If the list still cannot scroll, auto-fetch the next page so users are
      // not stuck on a tiny first page when many emails no longer map to docs.
      if (_scrollController.position.maxScrollExtent <= 0) {
        _bloc.add(_fetchPageEvent(_page(current) + 1));
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

    final state = _bloc.state;
    if (_isFetching(state) || !_hasMore(state) || _isSearchActive) return;

    _bloc.add(_fetchPageEvent(_page(state) + 1));
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();

    if (query.length < _searchMinLength) {
      if (_isSearchActive) {
        setState(() => _isSearchActive = false);
        _bloc.add(_clearSearchEvent);
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: _searchDebounceMs), () {
      if (!mounted) return;
      setState(() => _isSearchActive = true);
      _bloc.add(_searchEvent(query));
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublicProfileBloc>.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: PreferredSize(
          preferredSize: const Size(double.infinity, 55),
          child: HeadingChipBar(current: _title),
        ),
        body: Column(
          children: [
            _SearchBar(controller: _searchController),
            Expanded(
              child: BlocBuilder<PublicProfileBloc, PublicProfileState>(
                buildWhen: (prev, curr) =>
                    _summaries(prev) != _summaries(curr) ||
                    _isFetching(prev) != _isFetching(curr) ||
                    _hasMore(prev) != _hasMore(curr) ||
                    _searchResults(prev) != _searchResults(curr) ||
                    _isSearching(prev) != _isSearching(curr),
                builder: (context, state) {
                  // Search mode.
                  if (_isSearchActive) {
                    if (_isSearching(state)) {
                      return Center(child: Loader());
                    }
                    final results = _searchResults(state) ?? const <UserSummaryEntity>[];
                    if (results.isEmpty) {
                      return Center(child: _emptyText('No results found.', context));
                    }
                    return _UserList(users: results, scrollController: null, hasMore: false, isLoading: false);
                  }

                  // Paginated mode.
                  final summaries = _summaries(state);
                  if (_isFetching(state) && summaries.isEmpty) {
                    return Center(child: Loader());
                  }
                  if (summaries.isEmpty) {
                    return Center(
                      child: _emptyText(widget.emails.isEmpty ? _emptySourceText : _emptyLoadFailedText, context),
                    );
                  }
                  _maybeAutoLoadMore(state);
                  return _UserList(
                    users: summaries,
                    scrollController: _scrollController,
                    hasMore: _hasMore(state),
                    isLoading: _isFetching(state),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Text _emptyText(String text, BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontFamily: 'Proxima Nova',
        color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
        fontSize: 15,
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
      itemCount: itemCount,
      separatorBuilder: (_, _) =>
          Divider(height: 1, color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08), indent: 72),
      itemBuilder: (context, index) {
        if (index >= users.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Loader()),
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: controller,
        style: TextStyle(fontFamily: 'Proxima Nova', color: Theme.of(context).colorScheme.secondary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search by username…',
          hintStyle: TextStyle(
            fontFamily: 'Proxima Nova',
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
            fontSize: 15,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.4),
            size: 20,
          ),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: Icon(
                  Icons.clear,
                  size: 18,
                  color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5),
                ),
                onPressed: controller.clear,
              );
            },
          ),
          filled: true,
          fillColor: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.06),
          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
