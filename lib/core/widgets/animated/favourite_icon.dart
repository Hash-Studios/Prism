import 'dart:math' show max;

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

class _FavoriteIconState extends State<FavoriteIcon> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sizeAnimation;
  late double _maxIconSize;

  bool _isAnimationCompleted = false;

  @override
  void initState() {
    super.initState();

    _maxIconSize = widget.iconSize.clamp(20.0, 100.0);
    final double minIconSize = _maxIconSize * 0.7;
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _sizeAnimation = TweenSequence(<TweenSequenceItem<double>>[
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: minIconSize, end: _maxIconSize),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: _maxIconSize, end: minIconSize),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(curve: Curves.slowMiddle, parent: _controller));

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.valueChanged();
        _isAnimationCompleted = true;
      } else if (status == AnimationStatus.dismissed) {
        widget.valueChanged();
        _isAnimationCompleted = false;
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layoutExtent = max(widget.tapTargetExtent ?? _maxIconSize, _maxIconSize);
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, _) {
        return InkResponse(
          onTap: () {
            if (_isAnimationCompleted) {
              _controller.reverse();
            } else {
              _controller.forward();
            }
          },
          containedInkWell: true,
          radius: layoutExtent / 2,
          child: SizedBox(
            width: layoutExtent,
            height: layoutExtent,
            child: Center(
              child: Icon(
                widget.isFavorite ? JamIcons.heart_f : JamIcons.heart,
                color: widget.iconColor,
                size: _sizeAnimation.value,
              ),
            ),
          ),
        );
      },
    );
  }
}
