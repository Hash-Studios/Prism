import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/home/core/headingChipBar.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/user_summary_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class FollowingListScreen extends StatefulWidget {
  const FollowingListScreen({super.key, required this.following});

  /// Full list of email addresses that the current user follows (all pages).
  final List<String> following;

  @override
  _FollowingListScreenState createState() => _FollowingListScreenState();
}

class _FollowingListScreenState extends State<FollowingListScreen> {
  static const int _pageSize = 20;
  static const int _searchDebounceMs = 500;
  static const int _searchMinLength = 2;

  // Each FollowingListScreen instance gets its own bloc so that navigating into
  // another user's following list (and back) never clobbers this screen's state.
  late final PublicProfileBloc _bloc;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearchActive = false;

  void _maybeAutoLoadMore(PublicProfileState state) {
    if (_isSearchActive || state.isFetchingFollowing || !state.hasMoreFollowing) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      final current = _bloc.state;
      if (_isSearchActive || current.isFetchingFollowing || !current.hasMoreFollowing) {
        return;
      }
      if (_scrollController.position.maxScrollExtent <= 0) {
        _bloc.add(
          PublicProfileEvent.fetchFollowingSummariesPageRequested(
            allEmails: widget.following,
            currentUserEmail: app_state.prismUser.email,
            page: current.followingPage + 1,
            pageSize: _pageSize,
          ),
        );
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
    if (widget.following.isNotEmpty) {
      _bloc.add(
        PublicProfileEvent.fetchFollowingSummariesPageRequested(
          allEmails: widget.following,
          currentUserEmail: app_state.prismUser.email,
          page: 0,
          pageSize: _pageSize,
        ),
      );
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
    if (state.isFetchingFollowing || !state.hasMoreFollowing || _isSearchActive) return;

    _bloc.add(
      PublicProfileEvent.fetchFollowingSummariesPageRequested(
        allEmails: widget.following,
        currentUserEmail: app_state.prismUser.email,
        page: state.followingPage + 1,
        pageSize: _pageSize,
      ),
    );
  }

  void _onSearchChanged() {
    _debounce?.cancel();
    final query = _searchController.text.trim();

    if (query.length < _searchMinLength) {
      if (_isSearchActive) {
        setState(() => _isSearchActive = false);
        _bloc.add(const PublicProfileEvent.clearFollowingSearch());
      }
      return;
    }

    _debounce = Timer(const Duration(milliseconds: _searchDebounceMs), () {
      if (!mounted) return;
      setState(() => _isSearchActive = true);
      _bloc.add(
        PublicProfileEvent.searchFollowingSummariesRequested(
          query: query,
          allEmails: widget.following,
          currentUserEmail: app_state.prismUser.email,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublicProfileBloc>.value(
      value: _bloc,
      child: Scaffold(
        backgroundColor: Theme.of(context).primaryColor,
        appBar: const PreferredSize(
          preferredSize: Size(double.infinity, 55),
          child: HeadingChipBar(current: 'Following'),
        ),
        body: Column(
          children: [
            _FollowingSearchBar(controller: _searchController),
            Expanded(
              child: BlocBuilder<PublicProfileBloc, PublicProfileState>(
                buildWhen: (prev, curr) =>
                    prev.followingSummaries != curr.followingSummaries ||
                    prev.isFetchingFollowing != curr.isFetchingFollowing ||
                    prev.hasMoreFollowing != curr.hasMoreFollowing ||
                    prev.followingSearchResults != curr.followingSearchResults ||
                    prev.isSearchingFollowing != curr.isSearchingFollowing,
                builder: (context, state) {
                  // Search mode.
                  if (_isSearchActive) {
                    if (state.isSearchingFollowing) {
                      return Center(child: Loader());
                    }
                    final results = state.followingSearchResults ?? const <UserSummaryEntity>[];
                    if (results.isEmpty) {
                      return Center(child: _emptyText('No results found.', context));
                    }
                    return _FollowingUserList(users: results, scrollController: null, hasMore: false, isLoading: false);
                  }

                  // Paginated mode.
                  if (state.isFetchingFollowing && state.followingSummaries.isEmpty) {
                    return Center(child: Loader());
                  }
                  if (state.followingSummaries.isEmpty) {
                    return Center(
                      child: _emptyText(
                        widget.following.isEmpty
                            ? "You're not following anyone yet."
                            : 'Could not load following list.',
                        context,
                      ),
                    );
                  }
                  _maybeAutoLoadMore(state);
                  return _FollowingUserList(
                    users: state.followingSummaries,
                    scrollController: _scrollController,
                    hasMore: state.hasMoreFollowing,
                    isLoading: state.isFetchingFollowing,
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

class _FollowingUserList extends StatelessWidget {
  const _FollowingUserList({
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
      separatorBuilder: (_, __) =>
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

class _FollowingSearchBar extends StatelessWidget {
  const _FollowingSearchBar({required this.controller});

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
            builder: (_, value, __) {
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
