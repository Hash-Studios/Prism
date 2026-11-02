import 'dart:async';

import 'package:Prism/core/analytics/events/analytics_enums.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/popup/sign_in_pop_up.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/wall_requests/biz/wall_requests_cubit.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_row.dart';
import 'package:Prism/features/wall_requests/views/widgets/wall_request_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
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
      child: PrismPage(
        title: l10n.wallRequestsTitle,
        headerBottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs),
          labelPadding: const EdgeInsets.symmetric(horizontal: PrismSpace.sm),
          labelColor: cs.primary,
          unselectedLabelColor: cs.onSurface.withValues(alpha: 0.6),
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
              ),
          ],
        ),
        bottomBar: PrismButton(
          label: l10n.wallRequestsAsk,
          icon: Icons.add_rounded,
          expand: true,
          onPressed: () => unawaited(_ask()),
        ),
      ),
    );
  }
}

class _TabBody extends StatelessWidget {
  const _TabBody({required this.tab, required this.isAdmin, required this.onVote, required this.onAsk});

  final WallRequestTab tab;
  final bool isAdmin;
  final void Function(WallRequest request) onVote;
  final VoidCallback onAsk;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final WallRequestsCubit cubit = context.read<WallRequestsCubit>();
    return BlocSelector<WallRequestsCubit, WallRequestsState, WallRequestsTabState>(
      selector: (WallRequestsState state) => state.tab(tab),
      builder: (BuildContext context, WallRequestsTabState state) {
        return switch (state) {
          WallRequestsTabLoading() => PrismSkeleton.cards(count: 4, height: 112),
          WallRequestsTabFailed() => GlintState(
            kind: GlintStateKind.error,
            title: l10n.wallRequestsLoadFailed,
            actionLabel: l10n.wallRequestsRetry,
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
              onAction: onAsk,
            ),
          },
          WallRequestsTabLoaded(:final List<WallRequest> requests) => RefreshIndicator(
            onRefresh: () => cubit.load(tab),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xl),
              itemCount: requests.length,
              separatorBuilder: (_, _) => const SizedBox(height: PrismSpace.sm),
              itemBuilder: (BuildContext context, int index) {
                final WallRequest request = requests[index];
                return WallRequestRow(
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
              },
            ),
          ),
        };
      },
    );
  }
}
