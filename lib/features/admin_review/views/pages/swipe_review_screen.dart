import 'package:Prism/core/firestore/firestore_document.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/admin_review/biz/bloc/review_batch_bloc.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_action_overlay.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_wallpaper_card.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:cached_network_image/cached_network_image.dart';

@RoutePage()
class SwipeReviewScreen extends StatefulWidget {
  const SwipeReviewScreen({super.key});

  @override
  State<SwipeReviewScreen> createState() => _SwipeReviewScreenState();
}

class _SwipeReviewScreenState extends State<SwipeReviewScreen> with SingleTickerProviderStateMixin {
  late final ReviewBatchBloc _bloc;
  late AnimationController _animationController;
  Animation<Offset>? _slideAnimation;

  double _dragOffset = 0;
  bool _isDragging = false;
  static const double _swipeThreshold = 100;

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

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _isDragging = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta.dx;
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;

    if (_dragOffset.abs() > _swipeThreshold || velocity.abs() > 500) {
      if (_dragOffset > 0 || velocity > 500) {
        _animateSwipeOff(true);
      } else {
        _showRejectDialog();
      }
    } else {
      _animateBack();
    }
  }

  void _animateSwipeOff(bool isApprove) {
    final screenWidth = MediaQuery.of(context).size.width;
    final targetX = isApprove ? screenWidth * 1.5 : -screenWidth * 1.5;

    _slideAnimation = Tween<Offset>(
      begin: Offset(_dragOffset, 0),
      end: Offset(targetX, 0),
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeOut));

    _animationController.forward(from: 0).then((_) {
      if (isApprove) {
        _bloc.add(const ReviewBatchSwipeApproved());
      }
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
      _animationController.reset();
    });
  }

  void _animateBack() {
    _slideAnimation = Tween<Offset>(
      begin: Offset(_dragOffset, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.elasticOut));

    _animationController.forward(from: 0).then((_) {
      setState(() {
        _dragOffset = 0;
        _isDragging = false;
      });
      _animationController.reset();
    });
  }

  void _showRejectDialog() {
    final reasonController = TextEditingController(
      text: "Sorry! This item doesn't meet our expectations and failed the review.",
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Wallpaper'),
        content: TextField(
          controller: reasonController,
          minLines: 2,
          maxLines: 4,
          decoration: const InputDecoration(labelText: 'Reason', hintText: 'Why are you rejecting this wallpaper?'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _animateBack();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _bloc.add(ReviewBatchSwipeRejected(reason: reasonController.text.trim()));
              setState(() {
                _dragOffset = 0;
                _isDragging = false;
              });
            },
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
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

    final swipeProgress = _dragOffset / _swipeThreshold;

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
                      isTopCard: false,
                    ),
                  ),
                ),
              AnimatedBuilder(
                animation: _animationController,
                builder: (context, child) {
                  final offset = _slideAnimation?.value ?? Offset(_dragOffset, 0);
                  return Transform.translate(
                    offset: offset,
                    child: Transform.rotate(
                      angle: (_dragOffset / 1000) * 0.3,
                      child: SwipeWallpaperCard(
                        imageUrl: currentWall.wallpaperThumb.isNotEmpty
                            ? currentWall.wallpaperThumb
                            : currentWall.wallpaperUrl,
                        title: currentWall.data()['title']?.toString() ?? '',
                        category: currentWall.data()['category']?.toString() ?? 'General',
                        authorName: currentWall.by,
                        authorPhoto: currentWall.userPhoto,
                        swipeProgress: swipeProgress,
                        isTopCard: true,
                        onTap: () => _showFullImage(currentWall),
                      ),
                    ),
                  );
                },
              ),
              SwipeActionOverlay(swipeProgress: swipeProgress, isApprove: true),
              GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                child: Container(color: Colors.transparent, width: double.infinity, height: double.infinity),
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
