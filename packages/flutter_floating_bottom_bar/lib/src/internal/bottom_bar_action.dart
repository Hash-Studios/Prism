import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Internal back action with a stable hit target and animated visual child.
class BottomBarAction extends StatefulWidget {
  const BottomBarAction({
    super.key,
    required this.animation,
    required this.enabled,
    required this.visualWidth,
    required this.visualHeight,
    required this.decoration,
    required this.tooltip,
    required this.semanticLabel,
    required this.onTap,
    required this.visualBuilder,
  });

  final Animation<double> animation;
  final bool enabled;
  final double visualWidth;
  final double visualHeight;
  final Decoration decoration;
  final String tooltip;
  final String semanticLabel;
  final VoidCallback onTap;
  final Widget Function(double width, double height) visualBuilder;

  @override
  State<BottomBarAction> createState() => _BottomBarActionState();
}

class _BottomBarActionState extends State<BottomBarAction> {
  final _actionSubtreeKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final targetExtent = math.max(
      48.0,
      math.max(widget.visualWidth, widget.visualHeight),
    );

    Widget child = SizedBox(
      // TooltipVisibility changes Material's internal RawTooltip ancestry.
      // Preserve this subtree across that wrapper transition.
      key: _actionSubtreeKey,
      width: targetExtent,
      height: targetExtent,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.enabled ? widget.onTap : null,
          child: Center(
            child: AnimatedBuilder(
              animation: widget.animation,
              builder: (context, _) {
                final progress = widget.animation.value.clamp(0.0, 1.0);
                final width = widget.visualWidth * progress;
                final height = widget.visualHeight * progress;
                return Opacity(
                  opacity: progress,
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: ClipOval(
                      child: DecoratedBox(
                        decoration: widget.decoration,
                        child: widget.visualBuilder(width, height),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    return ExcludeFocus(
      excluding: !widget.enabled,
      child: IgnorePointer(
        ignoring: !widget.enabled,
        child: ExcludeSemantics(
          excluding: !widget.enabled,
          child: Semantics(
            button: true,
            label: widget.semanticLabel,
            child: TooltipVisibility(
              visible: widget.enabled && TooltipVisibility.of(context),
              child: Tooltip(
                excludeFromSemantics: true,
                message: widget.tooltip,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
