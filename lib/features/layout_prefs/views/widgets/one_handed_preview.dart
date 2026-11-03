import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// A small sketch of the screen. The avatar and the bell move from the top bar to the bottom row when [oneHanded] is
/// on. With [roomy] off, the bar has no room for the bell, so it joins the avatar, as the real bar does. Offsets are
/// from the start edge, so the sketch mirrors in a right-to-left language like the bar.
class OneHandedPreview extends StatelessWidget {
  const OneHandedPreview({super.key, required this.oneHanded, required this.roomy});

  final bool oneHanded;
  final bool roomy;

  static const double _width = 220;
  static const double _height = 132;
  static const double _control = 14;
  static const double _pillWidth = 64;
  static const double _pillHeight = 16;
  static const double _create = 16;
  static const double _topY = 7;
  static const double _bottomY = _height - 10 - _pillHeight;
  static const double _controlBottomY = _bottomY + (_pillHeight - _control) / 2;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Duration duration = context.motion(PrismDurations.base);
    const Curve curve = PrismCurves.move;

    // The row, start to end: avatar, pill, create and, when there is room, the bell.
    final bool bellInRow = oneHanded && roomy;
    final double rowWidth = (oneHanded ? _control + 3 : 0) + _pillWidth + 4 + _create + (bellInRow ? 3 + _control : 0);
    final double rowStart = (_width - rowWidth) / 2;
    final double pillX = rowStart + (oneHanded ? _control + 3 : 0);
    final double createX = pillX + _pillWidth + 4;
    final Offset avatar = oneHanded ? Offset(rowStart, _controlBottomY) : const Offset(10, _topY);
    final Offset bell = switch ((oneHanded, roomy)) {
      (false, _) => const Offset(_width - 10 - _control, _topY),
      (true, true) => Offset(createX + _create + 3, _controlBottomY),
      (true, false) => avatar,
    };

    Widget slide(Offset at, double size, Widget child) => AnimatedPositionedDirectional(
      duration: duration,
      curve: curve,
      start: at.dx,
      top: at.dy,
      width: size,
      height: size,
      child: child,
    );

    final Widget dot = Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: cs.primary, shape: BoxShape.circle),
    );
    final Color disc = oneHanded ? theme.primaryColor : theme.primaryColor.withValues(alpha: 0);
    final List<BoxShadow> lift = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: oneHanded ? 0.25 : 0),
        blurRadius: 2,
        offset: const Offset(0, 1),
      ),
    ];

    return ExcludeSemantics(
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Container(
            width: _width,
            height: _height,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(PrismRadius.lg),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: (_width - 34) / 2,
                  top: _topY + (_control - 5) / 2,
                  child: _Bar(width: 34, height: 5, color: cs.onSurface.withValues(alpha: 0.7)),
                ),
                for (final double x in const <double>[10, _width / 2 + 3])
                  Positioned(
                    left: x,
                    top: 26,
                    child: _Bar(
                      width: _width / 2 - 13,
                      height: _height - 26 - 6,
                      color: cs.surfaceContainerHighest,
                      radius: PrismRadius.sm,
                    ),
                  ),
                AnimatedPositionedDirectional(
                  duration: duration,
                  curve: curve,
                  start: pillX,
                  top: _bottomY,
                  child: _Pill(color: theme.primaryColor, ink: cs.secondary),
                ),
                AnimatedPositionedDirectional(
                  duration: duration,
                  curve: curve,
                  start: createX,
                  top: _bottomY,
                  child: _Bar(width: _create, height: _create, color: cs.primary, radius: _create / 2),
                ),
                slide(
                  bell,
                  _control,
                  AnimatedOpacity(
                    duration: duration,
                    curve: curve,
                    opacity: oneHanded && !roomy ? 0 : 1,
                    child: AnimatedContainer(
                      duration: duration,
                      curve: curve,
                      decoration: BoxDecoration(color: disc, shape: BoxShape.circle, boxShadow: lift),
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          Icon(
                            Icons.notifications_none_rounded,
                            size: 11,
                            color: oneHanded ? cs.secondary : cs.onSurface,
                          ),
                          PositionedDirectional(top: 1, end: 1, child: dot),
                        ],
                      ),
                    ),
                  ),
                ),
                slide(
                  avatar,
                  _control,
                  Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: AnimatedContainer(
                          duration: duration,
                          curve: curve,
                          padding: EdgeInsets.all(oneHanded ? 2 : 0),
                          decoration: BoxDecoration(color: disc, shape: BoxShape.circle, boxShadow: lift),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: cs.onSurface.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        top: -1,
                        end: -1,
                        child: AnimatedOpacity(
                          duration: duration,
                          curve: curve,
                          opacity: oneHanded && !roomy ? 1 : 0,
                          child: dot,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color, this.radius = 3});

  final double width;
  final double height;
  final Color color;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radius)),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.color, required this.ink});

  final Color color;
  final Color ink;

  @override
  Widget build(BuildContext context) => Container(
    width: OneHandedPreview._pillWidth,
    height: OneHandedPreview._pillHeight,
    padding: const EdgeInsets.symmetric(horizontal: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(PrismRadius.pill),
      boxShadow: <BoxShadow>[
        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 2, offset: const Offset(0, 1)),
      ],
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        for (int i = 0; i < 4; i++)
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: i == 0 ? 1 : 0.6),
              shape: BoxShape.circle,
            ),
          ),
      ],
    ),
  );
}
