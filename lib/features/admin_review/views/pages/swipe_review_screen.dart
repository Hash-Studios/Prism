import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
import 'package:Prism/features/admin_review/views/widgets/full_screen_image_view.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_action_overlay.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_wallpaper_card.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';

@RoutePage()
class SwipeReviewScreen extends StatefulWidget {
  const SwipeReviewScreen({super.key});

  @override
  State<SwipeReviewScreen> createState() => _SwipeReviewScreenState();
}

enum _SwipePhase { idle, dragging, animating }

class _SwipeReviewScreenState extends State<SwipeReviewScreen> with SingleTickerProviderStateMixin {
  late final ReviewBatchBloc _bloc;
  late AnimationController _animationController;
  Animation<double>? _xAnimation;

  _SwipePhase _phase = _SwipePhase.idle;
  double _dragX = 0;

  static const double _swipeThreshold = 100;
  static const double _velocityThreshold = 500;

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.I<ReviewBatchBloc>();
    _bloc.add(const ReviewBatchLoadRequested());

    _animationController = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bloc.close();
    super.dispose();
  }

  static const double _offscreenFactor = 1.5;

  double _maxDragX(double screenWidth) => screenWidth * _offscreenFactor;

  double get _displayX {
    if (_phase == _SwipePhase.animating && _xAnimation != null) {
      return _xAnimation!.value;
    }
    return _dragX;
  }

  void _onPanStart(DragStartDetails details) {
    if (_phase == _SwipePhase.animating) return;
    setState(() {
      _phase = _SwipePhase.dragging;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_phase != _SwipePhase.dragging) return;
    final maxX = _maxDragX(MediaQuery.sizeOf(context).width);
    setState(() {
      _dragX = (_dragX + details.delta.dx).clamp(-maxX, maxX);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_phase != _SwipePhase.dragging) return;
    final vx = details.velocity.pixelsPerSecond.dx;
    final dx = _dragX;

    if (dx.abs() > _swipeThreshold || vx.abs() > _velocityThreshold) {
      if (dx > 0 || vx > _velocityThreshold) {
        _startDismissAnimation(approve: true);
      } else {
        _startDismissAnimation(approve: false);
      }
    } else if (dx.abs() < 0.5) {
      setState(() {
        _phase = _SwipePhase.idle;
        _dragX = 0;
      });
    } else {
      _startSnapBackAnimation();
    }
  }

  void _onPanCancel() {
    if (_phase != _SwipePhase.dragging) return;
    if (_dragX.abs() < 0.5) {
      setState(() {
        _phase = _SwipePhase.idle;
        _dragX = 0;
      });
    } else {
      _startSnapBackAnimation();
    }
  }

  void _startDismissAnimation({required bool approve}) {
    final maxX = _maxDragX(MediaQuery.sizeOf(context).width);
    _startAnimation(
      target: approve ? maxX : -maxX,
      onDone: () => _bloc.add(approve ? const ReviewBatchSwipeApproved() : const ReviewBatchSwipeRejected()),
    );
  }

  void _startSnapBackAnimation() => _startAnimation(target: 0);

  void _startAnimation({required double target, VoidCallback? onDone}) {
    _animationController.duration = context.motion(PrismDurations.base);
    _xAnimation = Tween<double>(
      begin: _dragX,
      end: target,
    ).animate(CurvedAnimation(parent: _animationController, curve: PrismCurves.enter));

    setState(() {
      _phase = _SwipePhase.animating;
    });

    _animationController.forward(from: 0).then((_) {
      if (!mounted) return;
      onDone?.call();
      setState(() {
        _phase = _SwipePhase.idle;
        _dragX = 0;
        _xAnimation = null;
      });
      _animationController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: PrismPage(
        title: 'Swipe review',
        actions: [
          BlocBuilder<ReviewBatchBloc, ReviewBatchState>(
            builder: (context, state) => Padding(
              padding: const EdgeInsets.only(right: PrismSpace.xs),
              child: Text(
                '${state.walls.isEmpty ? 0 : state.currentIndex + 1}/${state.walls.length}',
                style: PrismTextStyles.caption(context),
              ),
            ),
          ),
        ],
        bottomBar: BlocBuilder<ReviewBatchBloc, ReviewBatchState>(builder: (context, state) => _buildBottomBar(state)),
        body: BlocListener<ReviewBatchBloc, ReviewBatchState>(
          listenWhen: (previous, current) => current.undoCount > previous.undoCount,
          listener: (context, state) => toasts.success('Undo successful'),
          child: BlocConsumer<ReviewBatchBloc, ReviewBatchState>(
            listener: (context, state) {
              if (state.status == ReviewBatchStatus.error && state.errorMessage != null) {
                toasts.error(state.errorMessage!);
              }
              if (state.status == ReviewBatchStatus.batchComplete) {
                toasts.success('Batch complete. Loading the next batch.');
                _bloc.add(const ReviewBatchNextBatchRequested());
              }
            },
            builder: (context, state) {
              if (state.status == ReviewBatchStatus.loading) {
                return _buildLoading();
              }

              if (state.walls.isEmpty) {
                return _buildEmptyState();
              }

              if (!state.hasMoreWalls) {
                return _buildBatchComplete(state);
              }

              return _buildSwipeArea(state);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return PrismSkeleton(
      child: Padding(
        padding: SwipeWallpaperCard.margin,
        child: LayoutBuilder(
          builder: (context, constraints) => PrismBone(height: constraints.maxHeight, radius: PrismRadius.lg),
        ),
      ),
    );
  }

  Widget _buildSwipeArea(ReviewBatchState state) {
    final currentWall = state.currentWall;
    if (currentWall == null) return const SizedBox.shrink();

    return Column(
      children: [
        Expanded(
          child: Semantics(
            label: 'Wallpaper to review',
            customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
              const CustomSemanticsAction(label: 'Approve'): () => _dismissFromSemantics(approve: true),
              const CustomSemanticsAction(label: 'Reject'): () => _dismissFromSemantics(approve: false),
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (state.currentIndex + 1 < state.walls.length)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) => Transform.scale(
                        scale: 0.94 + 0.06 * (_displayX.abs() / _swipeThreshold).clamp(0.0, 1.0),
                        child: child,
                      ),
                      child: SwipeWallpaperCard.fromDocument(state.walls[state.currentIndex + 1], isTopCard: false),
                    ),
                  ),
                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    final x = _displayX;
                    final swipeProgress = x / _swipeThreshold;
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Transform.translate(
                            offset: Offset(x, 0),
                            child: Transform.rotate(
                              angle: (x / 1000) * 0.3,
                              child: SwipeWallpaperCard.fromDocument(currentWall),
                            ),
                          ),
                        ),
                        SwipeActionOverlay(swipeProgress: swipeProgress),
                      ],
                    );
                  },
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onPanCancel: _onPanCancel,
                  onTap: () => _showFullImage(currentWall),
                  child: const SizedBox.expand(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: PrismSpace.xxs, bottom: PrismSpace.xs),
          child: Text('Swipe right to approve, left to reject', style: PrismTextStyles.caption(context)),
        ),
      ],
    );
  }

  void _dismissFromSemantics({required bool approve}) {
    if (_phase == _SwipePhase.animating) return;
    _startDismissAnimation(approve: approve);
  }

  Widget _buildBottomBar(ReviewBatchState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: Icons.undo_rounded,
          label: 'Undo',
          enabled: state.canUndo,
          onTap: () => _bloc.add(const ReviewBatchUndoRequested()),
        ),
        _ActionButton(
          icon: Icons.open_in_full_rounded,
          label: 'View',
          enabled: state.hasMoreWalls,
          onTap: () {
            final wall = state.currentWall;
            if (wall != null) {
              _showFullImage(wall);
            }
          },
        ),
        _ActionButton(
          icon: Icons.skip_next_rounded,
          label: 'Skip',
          enabled: state.hasMoreWalls,
          onTap: () {
            _bloc.add(const ReviewBatchSwipeSkipped());
          },
        ),
        _ActionButton(
          icon: Icons.view_list_rounded,
          label: 'List',
          semanticLabel: 'Back to the review list',
          onTap: () {
            context.router.maybePop();
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return GlintState(
      kind: GlintStateKind.nothingNew,
      title: 'All caught up',
      body: 'No wallpapers pending review.',
      actionLabel: 'Refresh',
      onAction: () => _bloc.add(const ReviewBatchLoadRequested()),
    );
  }

  Widget _buildBatchComplete(ReviewBatchState state) {
    return GlintState(
      kind: GlintStateKind.nothingNew,
      title: 'Batch complete',
      body: '${state.totalPending} wallpapers remaining',
      actionLabel: 'Load next batch',
      onAction: () => _bloc.add(const ReviewBatchNextBatchRequested()),
    );
  }

  void _showFullImage(FirestoreDocument wall) {
    final url = wall.wallpaperUrl.isNotEmpty ? wall.wallpaperUrl : wall.wallpaperThumb;
    if (url.isEmpty) return;
    FullScreenImageView.show(context, url);
  }
}

/// A neutral 56 point circle with an icon and a caption. It dims when [enabled] is false.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? semanticLabel;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.semanticLabel,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: semanticLabel ?? label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: PressScale(
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? onTap : null,
          child: Opacity(
            opacity: enabled ? 1 : 0.38,
            child: SizedBox(
              width: 72,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.08), shape: BoxShape.circle),
                    child: Icon(icon, color: cs.onSurface, size: 26),
                  ),
                  const SizedBox(height: PrismSpace.xxs),
                  Text(label, style: PrismTextStyles.caption(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
