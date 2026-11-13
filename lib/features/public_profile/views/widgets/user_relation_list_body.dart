import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_loader.dart';
import 'package:Prism/core/widgets/prism_refresh.dart';
import 'package:Prism/features/public_profile/biz/bloc/public_profile_bloc.j.dart';
import 'package:Prism/features/public_profile/domain/entities/user_relation_kind.dart';
import 'package:Prism/features/public_profile/domain/entities/user_summary_entity.dart';
import 'package:Prism/features/public_profile/views/widgets/follow_outcome_toast.dart';
import 'package:Prism/features/public_profile/views/widgets/user_summary_tile.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Shared body for [FollowersScreen] and [FollowingListScreen]. The two
/// screens are identical apart from terminology, which bloc state fields
/// they read and which events they dispatch; [kind] drives all of that.
class UserRelationListBody extends StatefulWidget {
  const UserRelationListBody({super.key, required this.kind, required this.profileUid});

  /// Uid of the profile whose edge ids are loaded when this body opens.
  final String profileUid;

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

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  StreamSubscription<PublicProfileState>? _refreshSubscription;
  Completer<void>? _refreshCompletion;
  bool _isSearchActive = false;

  RelationList _list(PublicProfileState state) => state.relation(widget.kind);

  void _loadNextPage() =>
      _bloc.add(PublicProfileEvent.relationPageRequested(kind: widget.kind, profileUid: widget.profileUid));

  Future<void> _refresh() {
    final Completer<void>? pending = _refreshCompletion;
    if (pending != null) return pending.future;
    final completion = Completer<void>();
    _refreshCompletion = completion;
    bool started = _list(_bloc.state).isFetching;
    _refreshSubscription = _bloc.stream.listen((state) {
      if (_list(state).isFetching) {
        started = true;
      } else if (started) {
        _finishRefresh();
      }
    }, onDone: _finishRefresh);
    _bloc.add(PublicProfileEvent.relationRefreshRequested(kind: widget.kind, profileUid: widget.profileUid));
    return completion.future;
  }

  void _finishRefresh() {
    _refreshSubscription?.cancel();
    _refreshSubscription = null;
    _refreshCompletion?.complete();
    _refreshCompletion = null;
  }

  String _title(AppLocalizations l10n) => _isFollowers ? l10n.accountFollowers : l10n.accountFollowing;

  String _emptyTitle(AppLocalizations l10n) =>
      _isFollowers ? l10n.accountNoFollowersYet : l10n.accountNotFollowingAnyoneYet;

  String _emptyBody(AppLocalizations l10n) =>
      _isFollowers ? l10n.accountFollowersEmptyMessage : l10n.accountFollowingEmptyMessage;

  String _loadFailedTitle(AppLocalizations l10n) =>
      _isFollowers ? l10n.accountCouldNotLoadFollowers : l10n.accountCouldNotLoadFollowing;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<PublicProfileBloc>();
    _searchController.addListener(_onSearchChanged);
    _loadNextPage();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _finishRefresh();
    _searchController.dispose();
    _bloc.close();
    super.dispose();
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
      _bloc.add(
        PublicProfileEvent.relationSearchRequested(kind: widget.kind, query: query, profileUid: widget.profileUid),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PublicProfileBloc>.value(
      value: _bloc,
      child: BlocListener<PublicProfileBloc, PublicProfileState>(
        listenWhen: (prev, curr) => curr.followOutcome != null && prev.followOutcome != curr.followOutcome,
        listener: (context, state) => showFollowOutcomeToast(context, state.followOutcome!),
        child: PrismPage(
          title: _title(context.l10n),
          headerBottom: _SearchField(controller: _searchController),
          body: BlocBuilder<PublicProfileBloc, PublicProfileState>(
            buildWhen: (prev, curr) => _list(prev) != _list(curr),
            builder: (context, state) {
              final list = _list(state);
              if (_isSearchActive) {
                if (list.isSearching) {
                  return PrismSkeleton.rows(rows: 5);
                }
                final results = list.searchResults ?? const <UserSummaryEntity>[];
                if (results.isEmpty) {
                  return GlintState(
                    kind: GlintStateKind.empty,
                    title: context.l10n.accountNoResults,
                    body: context.l10n.accountNobodyMatchesUsername(_searchController.text.trim()),
                  );
                }
                return _UserList(users: results);
              }

              if (list.summaries.isEmpty) {
                if (list.failed) {
                  return GlintState(
                    kind: GlintStateKind.error,
                    title: _loadFailedTitle(context.l10n),
                    body: context.l10n.accountConnectionTryAgain,
                    actionLabel: context.l10n.accountTryAgain,
                    onAction: _loadNextPage,
                  );
                }
                if (list.pages == 0) {
                  return PrismSkeleton.rows();
                }
                if (!list.hasMore) {
                  return PrismRefresh(
                    onRefresh: _refresh,
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: constraints.maxHeight),
                          child: GlintState(
                            kind: GlintStateKind.empty,
                            title: _emptyTitle(context.l10n),
                            body: _emptyBody(context.l10n),
                          ),
                        ),
                      ),
                    ),
                  );
                }
              }
              return PrismRefresh(
                onRefresh: _refresh,
                child: _UserList(
                  users: list.summaries,
                  footer: list.failed
                      ? _LoadMoreErrorRow(onRetry: _loadNextPage)
                      : list.hasMore
                      ? _LoadingRow(key: ObjectKey(list.next), onShown: list.isFetching ? null : _loadNextPage)
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The user rows, then an optional [footer] row.
class _UserList extends StatelessWidget {
  const _UserList({required this.users, this.footer});

  final List<UserSummaryEntity> users;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final Widget? footer = this.footer;
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(top: PrismSpace.xs, bottom: PrismSpace.xxl + MediaQuery.paddingOf(context).bottom),
      itemCount: users.length + (footer == null ? 0 : 1),
      separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.xxs),
      itemBuilder: (context, index) {
        if (index >= users.length) return footer!;
        final user = users[index];
        return UserSummaryTile(
          user: user,
          onTap: () => context.router.push(ProfileRoute(profileIdentifier: user.id)),
        );
      },
    );
  }
}

/// The last row while more pages exist. The list builds it when it comes near the viewport, and then it asks for
/// the next page once.
class _LoadingRow extends StatefulWidget {
  const _LoadingRow({super.key, required this.onShown});

  /// Null while a page loads.
  final VoidCallback? onShown;

  @override
  State<_LoadingRow> createState() => _LoadingRowState();
}

class _LoadingRowState extends State<_LoadingRow> {
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    _requestAfterFrame();
  }

  @override
  void didUpdateWidget(_LoadingRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _requestAfterFrame();
  }

  void _requestAfterFrame() {
    final VoidCallback? onShown = widget.onShown;
    if (onShown == null || _requested) return;
    _requested = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onShown?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.accountRelationLoadingMore,
      liveRegion: true,
      child: const ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: PrismSpace.md),
          child: Center(child: PrismLoader(size: 24)),
        ),
      ),
    );
  }
}

/// The last row after a next page failed. The rows above it stay.
class _LoadMoreErrorRow extends StatelessWidget {
  const _LoadMoreErrorRow({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.sm),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: PrismSpace.sm,
        runSpacing: PrismSpace.xs,
        children: <Widget>[
          Text(
            context.l10n.accountRelationLoadMoreFailed,
            textAlign: TextAlign.center,
            style: PrismTextStyles.body(context).copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          PrismButton(
            label: context.l10n.accountTryAgain,
            onPressed: onRetry,
            variant: PrismButtonVariant.tonal,
            size: PrismButtonSize.compact,
          ),
        ],
      ),
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
            hintText: context.l10n.accountSearchByUsername,
            prefixIcon: const Icon(Icons.search_rounded, size: 22),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : PrismIconButton(
                      icon: Icons.close_rounded,
                      tooltip: context.l10n.accountClearSearch,
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
