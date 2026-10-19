import 'dart:math' as math;

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/biz/bloc/drops_bloc.j.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/preview/phone_screen_overlay.dart';
import 'package:Prism/features/drops/views/preview/preview_bottom_bar.dart';
import 'package:Prism/features/drops/views/preview/preview_chrome.dart';
import 'package:Prism/features/drops/views/preview/preview_wall_page.dart';
import 'package:Prism/features/drops/views/widgets/drop_actions.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/features/drops/views/widgets/drop_wall_tiles.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the full-screen preview of the live Drop at [wall]. Reads the [DropsBloc] from [context].
Future<void> openDropPreview(BuildContext context, {required DropWall wall}) async {
  final DropsBloc bloc = context.read<DropsBloc>();
  if (bloc.state.drop == null) return;
  final bool still = MediaQuery.disableAnimationsOf(context);
  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      fullscreenDialog: true,
      transitionDuration: still ? Duration.zero : const Duration(milliseconds: 280),
      reverseTransitionDuration: still ? Duration.zero : const Duration(milliseconds: 200),
      pageBuilder: (_, _, _) => BlocProvider<DropsBloc>.value(
        value: bloc,
        child: DropPreviewPage(wallId: wall.id),
      ),
      transitionsBuilder: (_, animation, _, child) {
        final Animation<double> eased = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(eased), child: child),
        );
      },
    ),
  );
}

/// Resolves a preview independently when opened outside the Drops page.
@RoutePage(name: 'DropPreviewRoute')
class DropPreviewRoutePage extends StatelessWidget {
  const DropPreviewRoutePage({
    super.key,
    @PathParam('weekKey') required this.weekKey,
    @PathParam('wallId') required this.wallId,
    this.bloc,
  });

  final String weekKey;
  final String wallId;
  final DropsBloc? bloc;

  @override
  Widget build(BuildContext context) {
    final Widget child = _ResolvedDropPreview(weekKey: weekKey, wallId: wallId);
    final DropsBloc? existing = bloc;
    if (existing != null) return BlocProvider<DropsBloc>.value(value: existing, child: child);
    return BlocProvider<DropsBloc>(
      create: (_) => getIt<DropsBloc>()..add(DropsEvent.started(weekKey: weekKey)),
      child: child,
    );
  }
}

class _ResolvedDropPreview extends StatelessWidget {
  const _ResolvedDropPreview({required this.weekKey, required this.wallId});

  final String weekKey;
  final String wallId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DropsBloc, DropsState>(
      builder: (context, state) {
        if (state.status == LoadStatus.initial || state.status == LoadStatus.loading) {
          return const PrismPage(
            title: 'Drop preview',
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.status == LoadStatus.failure) {
          return PrismPage(
            title: 'Drop preview',
            body: GlintState(
              kind: GlintStateKind.error,
              title: "Couldn't load this Drop",
              actionLabel: 'Try again',
              onAction: () => context.read<DropsBloc>().add(const DropsEvent.refreshed()),
            ),
          );
        }
        final DropEntity? drop = state.drop;
        if (drop == null || drop.weekKey != weekKey || !drop.walls.any((wall) => wall.id == wallId)) {
          return const PrismPage(
            title: 'Drop preview',
            body: GlintState(kind: GlintStateKind.empty, title: 'This wallpaper is unavailable'),
          );
        }
        return DropPreviewPage(key: ValueKey<String>('$weekKey/$wallId'), wallId: wallId);
      },
    );
  }
}

/// The pager over every wall of the live Drop, starting at [wallId].
class DropPreviewPage extends StatefulWidget {
  const DropPreviewPage({super.key, required this.wallId});

  final String wallId;

  @override
  State<DropPreviewPage> createState() => _DropPreviewPageState();
}

class _DropPreviewPageState extends State<DropPreviewPage> {
  late final PageController _pages;
  late final ValueNotifier<int> _index;
  DropPreviewMode _mode = DropPreviewMode.lockScreen;

  @override
  void initState() {
    super.initState();
    final List<DropWall> walls = context.read<DropsBloc>().state.drop?.walls ?? const <DropWall>[];
    final int start = math.max(0, walls.indexWhere((w) => w.id == widget.wallId));
    _index = ValueNotifier<int>(start);
    _pages = PageController(initialPage: start, viewportFraction: 0.82);
  }

  @override
  void dispose() {
    _pages.dispose();
    _index.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DropPalette.obsidian,
      body: BlocBuilder<DropsBloc, DropsState>(
        builder: (context, state) {
          final DropEntity? drop = state.drop;
          if (drop == null || drop.walls.isEmpty) return const SizedBox.shrink();
          final bool isPro = app_state.prismUser.premium;
          return SafeArea(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: _index,
                  builder: (context, i, _) {
                    final DropWall wall = drop.walls[i];
                    return PreviewHeader(
                      index: i,
                      total: drop.walls.length,
                      wall: wall,
                      owned: state.unlocked.containsKey(wall.id),
                    );
                  },
                ),
                const SizedBox(height: 12),
                PreviewModeToggle(mode: _mode, onChanged: (mode) => setState(() => _mode = mode)),
                const SizedBox(height: 12),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final double height = math.min(box.maxHeight, MediaQuery.sizeOf(context).height * 0.72);
                      return PageView.builder(
                        controller: _pages,
                        itemCount: drop.walls.length,
                        onPageChanged: (i) => _index.value = i,
                        itemBuilder: (context, i) {
                          final DropWall wall = drop.walls[i];
                          return _PageScale(
                            controller: _pages,
                            index: i,
                            child: PreviewWallPage(
                              wall: wall,
                              owned: state.unlocked.containsKey(wall.id),
                              mode: _mode,
                              now: state.now,
                              height: height,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                ValueListenableBuilder<int>(
                  valueListenable: _index,
                  builder: (context, i, _) {
                    final DropWall wall = drop.walls[i];
                    final DropUnlock? unlock = state.unlocked[wall.id];
                    return PreviewBottomBar(
                      drop: drop,
                      now: state.now,
                      owned: unlock != null,
                      busy: state.busyKey == wall.id,
                      isPro: isPro,
                      onUnlock: () => askToUnlock(context, state, wall),
                      onOpen: () {
                        if (unlock != null) openDropWall(context, wall, unlock);
                      },
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PageScale extends StatelessWidget {
  const _PageScale({required this.controller, required this.index, required this.child});

  final PageController controller;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return AnimatedBuilder(
      animation: controller,
      child: child,
      builder: (context, child) {
        final double page = controller.hasClients && controller.position.haveDimensions
            ? controller.page ?? index.toDouble()
            : controller.initialPage.toDouble();
        final double scale = 1 - 0.07 * (page - index).abs().clamp(0, 1);
        return Transform.scale(scale: scale, child: child);
      },
    );
  }
}
