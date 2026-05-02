import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_action_overlay.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_wallpaper_card.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:timeago/timeago.dart' as timeago;

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

  static String? _uploadedAgo(FirestoreDocument doc) {
    final DateTime? at = doc.createdAt;
    if (at == null) return null;
    return timeago.format(at.toLocal());
  }

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.I<ReviewBatchBloc>();
    _bloc.add(const ReviewBatchLoadRequested());

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _bloc.close();
    super.dispose();
  }

  double _maxDragX(double screenWidth) => screenWidth * 1.5;

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
    final screenWidth = MediaQuery.sizeOf(context).width;
    final targetX = approve ? screenWidth * 1.5 : -screenWidth * 1.5;

    _xAnimation = Tween<double>(
      begin: _dragX,
      end: targetX,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    setState(() {
      _phase = _SwipePhase.animating;
    });

    _animationController.forward(from: 0).then((_) {
      if (!mounted) return;
      if (approve) {
        _bloc.add(const ReviewBatchSwipeApproved());
      } else {
        _bloc.add(const ReviewBatchSwipeRejected());
      }
      setState(() {
        _phase = _SwipePhase.idle;
        _dragX = 0;
        _xAnimation = null;
      });
      _animationController.reset();
    });
  }

  void _startSnapBackAnimation() {
    _xAnimation = Tween<double>(
      begin: _dragX,
      end: 0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic));

    setState(() {
      _phase = _SwipePhase.animating;
    });

    _animationController.forward(from: 0).then((_) {
      if (!mounted) return;
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
    if (!app_state.isAdminUser()) {
      return Scaffold(
        appBar: AppBar(title: const Text('Swipe Review')),
        body: const Center(child: Text('You are not authorized to access this page.')),
      );
    }

    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Swipe Review'),
          actions: [
            BlocBuilder<ReviewBatchBloc, ReviewBatchState>(
              builder: (context, state) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      '${state.currentIndex + 1}/${state.walls.length}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        body: BlocConsumer<ReviewBatchBloc, ReviewBatchState>(
          listener: (context, state) {
            if (state.status == ReviewBatchStatus.error && state.errorMessage != null) {
              toasts.error(state.errorMessage!);
            }
            if (state.status == ReviewBatchStatus.batchComplete) {
              toasts.codeSend('Batch complete! Loading next batch...');
              _bloc.add(const ReviewBatchNextBatchRequested());
            }
          },
          builder: (context, state) {
            if (state.status == ReviewBatchStatus.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state.walls.isEmpty) {
              return _buildEmptyState();
            }

            if (!state.hasMoreWalls && state.remainingInBatch == 0) {
              return _buildBatchComplete(state);
            }

            return _buildSwipeArea(state);
          },
        ),
        bottomNavigationBar: BlocBuilder<ReviewBatchBloc, ReviewBatchState>(
          builder: (context, state) {
            return _buildBottomBar(state);
          },
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
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (state.currentIndex + 1 < state.walls.length)
                Positioned.fill(
                  child: Transform.scale(
                    scale: 0.9,
                    child: SwipeWallpaperCard(
                      imageUrl: state.walls[state.currentIndex + 1].wallpaperThumb.isNotEmpty
                          ? state.walls[state.currentIndex + 1].wallpaperThumb
                          : state.walls[state.currentIndex + 1].wallpaperUrl,
                      title: state.walls[state.currentIndex + 1].data()['title']?.toString() ?? '',
                      category: state.walls[state.currentIndex + 1].data()['category']?.toString() ?? 'General',
                      authorName: state.walls[state.currentIndex + 1].by,
                      authorPhoto: state.walls[state.currentIndex + 1].userPhoto,
                      uploadedAgo: _uploadedAgo(state.walls[state.currentIndex + 1]),
                      isTopCard: false,
                    ),
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
                            child: SwipeWallpaperCard(
                              imageUrl: currentWall.wallpaperThumb.isNotEmpty
                                  ? currentWall.wallpaperThumb
                                  : currentWall.wallpaperUrl,
                              title: currentWall.data()['title']?.toString() ?? '',
                              category: currentWall.data()['category']?.toString() ?? 'General',
                              authorName: currentWall.by,
                              authorPhoto: currentWall.userPhoto,
                              uploadedAgo: _uploadedAgo(currentWall),
                              swipeProgress: swipeProgress,
                            ),
                          ),
                        ),
                      ),
                      SwipeActionOverlay(swipeProgress: swipeProgress, isApprove: true),
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
        _buildSwipeHints(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSwipeHints() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SwipeHintIndicator(icon: Icons.close, label: 'Swipe Left\nto Reject', color: Colors.red),
          SwipeHintIndicator(icon: Icons.check_circle_outline, label: 'Swipe Right\nto Approve', color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildBottomBar(ReviewBatchState state) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _ActionButton(
              icon: Icons.undo,
              label: 'Undo',
              color: Colors.orange,
              enabled: state.canUndo,
              onTap: () {
                _bloc.add(const ReviewBatchUndoRequested());
                toasts.codeSend('Undo successful');
              },
            ),
            _ActionButton(
              icon: Icons.fullscreen,
              label: 'View',
              color: Colors.indigo,
              enabled: state.hasMoreWalls,
              onTap: () {
                final wall = state.currentWall;
                if (wall != null) {
                  _showFullImage(wall);
                }
              },
            ),
            _ActionButton(
              icon: Icons.skip_next,
              label: 'Skip',
              color: Colors.blue,
              enabled: state.hasMoreWalls,
              onTap: () {
                _bloc.add(const ReviewBatchSwipeSkipped());
              },
            ),
            _ActionButton(
              icon: Icons.list,
              label: 'List',
              color: Colors.purple,
              onTap: () {
                context.router.maybePop();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('All caught up!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text('No wallpapers pending review.'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              _bloc.add(const ReviewBatchLoadRequested());
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchComplete(ReviewBatchState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.done_all, size: 80, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text('Batch Complete!', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text('${state.totalPending} wallpapers remaining'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              _bloc.add(const ReviewBatchNextBatchRequested());
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Load Next Batch'),
          ),
        ],
      ),
    );
  }

  void _showFullImage(FirestoreDocument wall) {
    final url = wall.wallpaperUrl.isNotEmpty ? wall.wallpaperUrl : wall.wallpaperThumb;
    if (url.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: InteractiveViewer(
            maxScale: 5,
            child: Center(
              child: CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.contain,
                placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
                errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image, color: Colors.white, size: 48)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
