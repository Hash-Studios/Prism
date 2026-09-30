import 'dart:math' show max;

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class FavoriteIcon extends StatefulWidget {
  const FavoriteIcon({
    this.iconSize = 60.0,
    this.iconColor = Colors.red,
    this.isFavorite = false,
    required this.valueChanged,

    /// When set (e.g. toolbar circles), expands the tap target to this size so
    /// padding around the icon is still tappable. Should match the outer button size.
    this.tapTargetExtent,
    super.key,
  });

  final double iconSize;
  final Color iconColor;
  final bool isFavorite;
  final VoidCallback valueChanged;
  final double? tapTargetExtent;

  @override
  _FavoriteIconState createState() => _FavoriteIconState();
}

class _FavoriteIconState extends State<FavoriteIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final double _maxIconSize;

  @override
  void initState() {
    super.initState();
    _maxIconSize = widget.iconSize.clamp(20.0, 100.0);
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
    _scale = TweenSequence(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1, end: 1.25).chain(CurveTween(curve: PrismCurves.enter)),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.25, end: 1).chain(CurveTween(curve: PrismCurves.exit)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTap() {
    widget.valueChanged();
    if (!context.reduceMotion) _controller.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final layoutExtent = max(widget.tapTargetExtent ?? _maxIconSize, _maxIconSize);
    return InkResponse(
      onTap: _onTap,
      containedInkWell: true,
      radius: layoutExtent / 2,
      child: SizedBox(
        width: layoutExtent,
        height: layoutExtent,
        child: Center(
          child: ScaleTransition(
            scale: _scale,
            child: Icon(
              widget.isFavorite ? JamIcons.heart_f : JamIcons.heart,
              color: widget.iconColor,
              // Rests at 70% of iconSize; the pop grows it from there.
              size: _maxIconSize * 0.7,
            ),
          ),
        ),
      ),
    );
  }
}
