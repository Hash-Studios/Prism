import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/coins/prism_coin_icon.dart';
import 'package:Prism/features/spin_wheel/views/widgets/wheel_palette.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// The fat gold button of the machine. It has a gold face and a darker gold edge under it, and the face sinks into the
/// edge while it is pressed. With no [onPressed] the face stays down and goes flat, as it does while the wheel turns.
class SpinButton extends StatefulWidget {
  const SpinButton({
    super.key,
    required this.label,
    required this.semanticLabel,
    required this.onPressed,
    this.caption,
    this.price,
    this.pressed = false,
    this.compact = false,
  });

  final String label;
  final String semanticLabel;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// A line under the label, such as "Free spin".
  final String? caption;

  /// A coin price under the label. Wins over [caption].
  final int? price;

  /// Holds the face down in gold, for a wheel that is turning. A disabled button that is not held goes flat and grey.
  final bool pressed;

  /// The small version for the result panel: one line, 40 high.
  final bool compact;

  @override
  State<SpinButton> createState() => _SpinButtonState();
}

class _SpinButtonState extends State<SpinButton> {
  /// A label up to this long ("SPIN") is set big. A longer one ("Get coins", "Back tomorrow") is set smaller and
  /// tighter so it stays on one line.
  static const int _bigLabelMaxChars = 5;

  bool _down = false;

  bool get _enabled => widget.onPressed != null;

  void _setDown(bool value) {
    if (_down == value || !_enabled) return;
    setState(() => _down = value);
  }

  @override
  void didUpdateWidget(SpinButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled && _down) _down = false;
  }

  @override
  Widget build(BuildContext context) {
    final WheelPalette palette = WheelPalette.of(Theme.of(context).colorScheme);
    final WheelGold gold = palette.gold;
    final bool compact = widget.compact;
    final double height = compact ? 40 : 58;
    final double depth = compact ? 5 : 8;
    final double radius = compact ? 14 : 20;
    final bool flat = !_enabled && !widget.pressed;
    final bool sunk = _down || widget.pressed;
    final Duration duration = context.motion(PrismDurations.press);
    final Color plinthInk = palette.plinthInk;
    final Color faceTop = flat ? plinthInk.withValues(alpha: 0.16) : gold.highlight;
    final Color faceMid = flat ? plinthInk.withValues(alpha: 0.13) : gold.light;
    final Color faceBottom = flat ? plinthInk.withValues(alpha: 0.1) : gold.base;
    final Color edge = flat ? plinthInk.withValues(alpha: 0.06) : gold.deep;
    final Color edgeBottom = flat ? plinthInk.withValues(alpha: 0.04) : gold.dark;
    final Color ink = flat ? plinthInk.withValues(alpha: 0.85) : gold.ink;
    final bool big = widget.label.length <= _bigLabelMaxChars;
    final TextStyle labelStyle = PrismTextStyles.button.copyWith(
      fontSize: compact ? 15 : (big ? 30 : 23),
      fontWeight: FontWeight.w700,
      letterSpacing: compact ? 0.2 : (big ? 2.4 : 0.4),
      height: 1,
      color: ink,
      shadows: flat
          ? null
          : <Shadow>[Shadow(color: gold.glint.withValues(alpha: 0.7), offset: Offset(0, compact ? 0.8 : 1.4))],
    );
    final TextStyle captionStyle = PrismTextStyles.button.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      height: 1,
      color: ink.withValues(alpha: flat ? 0.6 : 0.78),
    );
    final Widget caption = widget.price != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Opacity(opacity: flat ? 0.6 : 1, child: const PrismCoinIcon(size: 16)),
              const SizedBox(width: 4),
              Text('${widget.price}', style: captionStyle.copyWith(fontSize: 14)),
            ],
          )
        : widget.caption == null
        ? const SizedBox.shrink()
        : Text(widget.caption!, style: captionStyle);
    final Widget content = compact
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(widget.label, style: labelStyle),
              if (widget.price != null || widget.caption != null) ...<Widget>[const SizedBox(width: 8), caption],
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(widget.label, style: labelStyle, maxLines: 1),
              ),
              if (widget.price != null || widget.caption != null) ...<Widget>[const SizedBox(height: 5), caption],
            ],
          );

    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[faceTop, faceMid, faceBottom],
          stops: const <double>[0, 0.35, 1],
        ),
        border: Border.all(color: flat ? Colors.transparent : gold.deep.withValues(alpha: 0.9), width: 1.2),
      ),
      child: Stack(
        children: <Widget>[
          if (!flat)
            Positioned(
              left: 3,
              right: 3,
              top: 2,
              height: height * 0.42,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(radius - 3),
                    bottom: const Radius.circular(10),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[gold.glint.withValues(alpha: 0.55), gold.glint.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          Center(child: content),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _setDown(true),
        onTapUp: (_) => _setDown(false),
        onTapCancel: () => _setDown(false),
        onTap: widget.onPressed,
        child: SizedBox(
          height: height + depth,
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                right: 0,
                top: depth,
                height: height,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(radius),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[edge, edgeBottom],
                    ),
                    border: Border.all(color: flat ? Colors.transparent : palette.ink, width: 2),
                    boxShadow: sunk || flat
                        ? null
                        : <BoxShadow>[
                            BoxShadow(
                              color: palette.colorScheme.scrim.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 6),
                            ),
                          ],
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: height,
                child: AnimatedSlide(
                  offset: Offset(0, sunk ? depth * 0.78 / height : 0),
                  duration: duration,
                  curve: PrismCurves.enter,
                  child: face,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
