import 'dart:async';

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/prism_refresh.dart';
import 'package:Prism/features/wall_requests/biz/wall_requests_cubit.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_row.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class WallRequestsPage extends StatelessWidget implements AutoRouteWrapper {
  const WallRequestsPage({super.key, @QueryParam('tab') this.tab = 'top'});

  final String tab;

  @override
  Widget wrappedRoute(BuildContext context) =>
      BlocProvider<WallRequestsCubit>(create: (_) => getIt<WallRequestsCubit>(), child: this);

  @override
  Widget build(BuildContext context) => _WallRequestsView(initialTab: WallRequestTab.fromWire(tab));
}

/// A list shorter than this puts its intro and its Request button in the list. A longer one pins the button.
const int _shortListRows = 4;

const List<WallRequestTab> _tabOrder = <WallRequestTab>[
  WallRequestTab.top,
  WallRequestTab.newest,
  WallRequestTab.filled,
];

class _WallRequestsView extends StatefulWidget {
  const _WallRequestsView({required this.initialTab});

  final WallRequestTab initialTab;

  @override
  State<_WallRequestsView> createState() => _WallRequestsViewState();
}

class _WallRequestsViewState extends State<_WallRequestsView> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  /// Tabs that already asked for their list. Each tab loads the first time it shows.
  final Set<WallRequestTab> _requested = <WallRequestTab>{};

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _tabOrder.length, vsync: this, initialIndex: _tabOrder.indexOf(widget.initialTab));
    _tabs.addListener(_onTabChanged);
    _ensureLoaded(widget.initialTab);
    // Short Top and New lists show filled walls under the rows, so the Filled list loads at once.
    _ensureLoaded(WallRequestTab.filled);
  }

  @override
  void dispose() {
    _tabs.removeListener(_onTabChanged);
    _tabs.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabs.indexIsChanging) return;
    _ensureLoaded(_tabOrder[_tabs.index]);
  }

  void _ensureLoaded(WallRequestTab tab) {
    if (!_requested.add(tab)) return;
    unawaited(context.read<WallRequestsCubit>().load(tab));
  }

  void _vote(WallRequestsCubit cubit, WallRequest request, WallRequestTab tab) {
    if (!app_state.prismUser.loggedIn) {
      toasts.info(context.l10n.wallRequestSignIn);
      unawaited(
        googleSignInPopUp(context, () {
          unawaited(cubit.load(tab));
        }),
      );
      return;
    }
    unawaited(cubit.toggleVote(request, tab));
  }

  Future<void> _ask() async {
    final WallRequest? request = await showWallRequestSheet(context, source: WallRequestSourceValue.requestsPage);
    if (request == null || !mounted) return;
    final WallRequestsCubit cubit = context.read<WallRequestsCubit>();
    unawaited(cubit.load(WallRequestTab.top));
    unawaited(cubit.load(WallRequestTab.newest));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final TextStyle label = PrismTextStyles.rowTitle(context).copyWith(fontSize: 15);
    final bool isAdmin = app_state.isAdminUser();
    return BlocListener<WallRequestsCubit, WallRequestsState>(
      listenWhen: (WallRequestsState previous, WallRequestsState current) =>
          current.error != null && current.error != previous.error,
      listener: (BuildContext context, WallRequestsState state) {
        final WallRequestError? error = state.error;
        if (error == null) return;
        toasts.error(wallRequestErrorText(context, error));
        context.read<WallRequestsCubit>().clearError();
      },
      child: ListenableBuilder(
        listenable: _tabs,
        builder: (BuildContext context, _) => BlocBuilder<WallRequestsCubit, WallRequestsState>(
          builder: (BuildContext context, WallRequestsState state) => PrismPage(
            title: l10n.wallRequestsTitle,
            headerBottom: TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
              labelPadding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm),
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              labelStyle: label,
              unselectedLabelStyle: label,
              indicator: UnderlineTabIndicator(
                borderSide: BorderSide(color: cs.primary, width: 3),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
              ),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: <Widget>[
                Tab(text: l10n.wallRequestsTabTop),
                Tab(text: l10n.wallRequestsTabNew),
                Tab(text: l10n.wallRequestsTabFilled),
              ],
            ),
            body: TabBarView(
              controller: _tabs,
              children: <Widget>[
                for (final WallRequestTab tab in _tabOrder)
                  _TabBody(
                    tab: tab,
                    isAdmin: isAdmin,
                    onVote: (WallRequest request) => _vote(context.read<WallRequestsCubit>(), request, tab),
                    onAsk: () => unawaited(_ask()),
                    onSeeAllFilled: () => _tabs.animateTo(_tabOrder.indexOf(WallRequestTab.filled)),
                  ),
              ],
            ),
            bottomBar: _listIsShort(state.tab(_tabOrder[_tabs.index]))
                ? null
                : PrismButton(
                    label: l10n.wallRequestsAsk,
                    icon: Icons.add_rounded,
                    expand: true,
                    onPressed: () => unawaited(_ask()),
                  ),
          ),
        ),
      ),
    );
  }
}

/// A loaded list of one to three rows. It has its Request button in the list, not pinned.
bool _listIsShort(WallRequestsTabState state) =>
    state is WallRequestsTabLoaded && state.requests.isNotEmpty && state.requests.length < _shortListRows;

const int _filledTiles = 6;

/// Walls that filled earlier requests. It shows under a short list so the page has pictures on it.
class _FilledWalls extends StatelessWidget {
  const _FilledWalls({required this.walls, required this.onSeeAll});

  final List<WallRequest> walls;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(title: l10n.wallRequestsTabFilled, actionLabel: l10n.moodSeeAll, onAction: onSeeAll),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: PrismSpace.sm,
          crossAxisSpacing: PrismSpace.sm,
          childAspectRatio: 3 / 4,
          children: <Widget>[
            for (final WallRequest wall in walls)
              InkWell(
                onTap: () => context.router.pushPath('/gallery?ids=${wall.filledWallId}&source=request'),
                child: Semantics(
                  label: wall.text,
                  image: true,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: wall.filledWallThumb,
                      fit: BoxFit.cover,
                      placeholder: (BuildContext context, String _) => ColoredBox(color: cs.surfaceContainerHighest),
                      errorWidget: (BuildContext context, String _, Object _) =>
                          ColoredBox(color: cs.surfaceContainerHighest),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tab,
    required this.isAdmin,
    required this.onVote,
    required this.onAsk,
    required this.onSeeAllFilled,
  });

  final WallRequestTab tab;
  final bool isAdmin;
  final void Function(WallRequest request) onVote;
  final VoidCallback onAsk;
  final VoidCallback onSeeAllFilled;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final WallRequestsCubit cubit = context.read<WallRequestsCubit>();
    final ColorScheme cs = Theme.of(context).colorScheme;
    bool short(List<WallRequest> requests) => requests.length < _shortListRows;
    final WallRequestsTabState filledState = context.select<WallRequestsCubit, WallRequestsTabState>(
      (WallRequestsCubit c) => c.state.tab(WallRequestTab.filled),
    );
    final List<WallRequest> filled = tab == WallRequestTab.filled || filledState is! WallRequestsTabLoaded
        ? const <WallRequest>[]
        : filledState.requests
              .where((WallRequest r) => r.filledWallId.isNotEmpty && r.filledWallThumb.isNotEmpty)
              .take(_filledTiles)
              .toList(growable: false);
    return BlocSelector<WallRequestsCubit, WallRequestsState, WallRequestsTabState>(
      selector: (WallRequestsState state) => state.tab(tab),
      builder: (BuildContext context, WallRequestsTabState state) {
        return switch (state) {
          WallRequestsTabLoading() => PrismSkeleton.cards(count: 4, height: 112),
          WallRequestsTabFailed() => GlintState(
            kind: GlintStateKind.error,
            title: l10n.wallRequestsLoadFailed,
            actionLabel: l10n.wallRequestsRetry,
            actionVariant: PrismButtonVariant.tonal,
            onAction: () => unawaited(cubit.load(tab)),
          ),
          WallRequestsTabLoaded(:final List<WallRequest> requests) when requests.isEmpty => switch (tab) {
            WallRequestTab.filled => GlintState(
              kind: GlintStateKind.empty,
              title: l10n.wallRequestsEmptyFilledTitle,
              body: l10n.wallRequestsEmptyFilledBody,
            ),
            _ => GlintState(
              kind: GlintStateKind.empty,
              title: l10n.wallRequestsEmptyTopTitle,
              body: l10n.wallRequestsEmptyTopBody,
              actionLabel: l10n.wallRequestsAsk,
              actionVariant: PrismButtonVariant.tonal,
              onAction: onAsk,
            ),
          },
          WallRequestsTabLoaded(:final List<WallRequest> requests) => PrismRefresh(
            onRefresh: () => cubit.load(tab),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xl),
              // A short list opens with the intro and ends with the Request button, so the page does not look empty.
              itemCount: requests.length + (short(requests) ? (filled.isEmpty ? 2 : 3) : 0),
              itemBuilder: (BuildContext context, int index) {
                final bool isShort = short(requests);
                if (isShort && index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: PrismSpace.xs),
                    child: Text(l10n.wallRequestsEmptyTopBody, style: PrismTextStyles.caption(context)),
                  );
                }
                if (isShort && index == requests.length + 2) {
                  return _FilledWalls(walls: filled, onSeeAll: onSeeAllFilled);
                }
                if (isShort && index == requests.length + 1) {
                  return Padding(
                    padding: const EdgeInsets.only(top: PrismSpace.lg),
                    child: PrismButton(
                      label: l10n.wallRequestsAsk,
                      icon: Icons.add_rounded,
                      expand: true,
                      onPressed: onAsk,
                    ),
                  );
                }
                final int rowIndex = isShort ? index - 1 : index;
                final WallRequest request = requests[rowIndex];
                final Widget row = WallRequestRow(
                  request: request,
                  isAdmin: isAdmin,
                  onVote: request.canVote ? () => onVote(request) : null,
                  onOpenWall: request.isFilled
                      ? () => context.router.pushPath('/gallery?ids=${request.filledWallId}&source=request')
                      : null,
                  onReport: request.mine
                      ? null
                      : () => unawaited(
                          showContentReportSheet(context, contentType: 'wallRequest', targetFirestoreDocId: request.id),
                        ),
                  onToggleHidden: isAdmin ? () => unawaited(cubit.setHidden(request, hidden: !request.hidden)) : null,
                );
                if (rowIndex == requests.length - 1) return row;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    row,
                    Divider(height: 1, thickness: 1, color: cs.onSurface.withValues(alpha: 0.08)),
                  ],
                );
              },
            ),
          ),
        };
      },
    );
  }
}
