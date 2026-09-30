import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A full-screen wallpaper with pinch zoom to 5x and double-tap to zoom in and out.
class FullScreenImageView extends StatefulWidget {
  const FullScreenImageView({super.key, required this.imageUrl});

  final String imageUrl;

  static Future<void> show(BuildContext context, String imageUrl) {
    return Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FullScreenImageView(imageUrl: imageUrl)));
  }

  @override
  State<FullScreenImageView> createState() => _FullScreenImageViewState();
}

class _FullScreenImageViewState extends State<FullScreenImageView> {
  static const double _doubleTapScale = 2.5;

  final TransformationController _transform = TransformationController();
  Offset _tapPosition = Offset.zero;
  int _attempt = 0;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.01) {
      _transform.value = Matrix4.identity();
      return;
    }
    final Offset p = _tapPosition;
    _transform.value = Matrix4.identity()
      ..translateByDouble(-p.dx * (_doubleTapScale - 1), -p.dy * (_doubleTapScale - 1), 0, 1)
      ..scaleByDouble(_doubleTapScale, _doubleTapScale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          GestureDetector(
            onDoubleTapDown: (TapDownDetails d) => _tapPosition = d.localPosition,
            onDoubleTap: _toggleZoom,
            child: InteractiveViewer(
              transformationController: _transform,
              maxScale: 5,
              child: Center(
                child: Semantics(
                  image: true,
                  label: 'Wallpaper, full screen',
                  child: CachedNetworkImage(
                    key: ValueKey<int>(_attempt),
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: PrismSkeleton(child: PrismBone(height: double.infinity, radius: 0)),
                      ),
                    ),
                    errorWidget: (_, _, _) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.broken_image_outlined, color: Colors.white, size: 48),
                          const SizedBox(height: PrismSpace.sm),
                          Text(
                            'Could not load the wallpaper',
                            style: PrismTextStyles.body(context).copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: PrismSpace.sm),
                          PrismButton(
                            label: 'Try again',
                            variant: PrismButtonVariant.tonal,
                            size: PrismButtonSize.compact,
                            onPressed: () => setState(() => _attempt++),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(PrismSpace.xs),
              child: Align(
                alignment: Alignment.topLeft,
                child: PrismIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Close',
                  onImage: true,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
