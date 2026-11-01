import 'package:Prism/features/wrapped/views/wrapped_copy.dart';
import 'package:flutter/widgets.dart';

/// Fixed colours for the story card. The story is immersive and leaves the app as an image, so like the share card it
/// does not follow the active theme: a dark scrim keeps white text readable over any wall.
abstract final class WrappedCardStyle {
  static const Color text = Color(0xFFFFFFFF);
  static const Color muted = Color(0xB3FFFFFF);
  static const Color backdrop = Color(0xFF0B0B0D);
  static const String font = 'Proxima Nova';
  static const String link = 'prismwalls.com';
}

/// The user's top colour, lifted toward white when it is too dark to read on the scrim.
Color wrappedAccent(Color? colour) {
  if (colour == null) return WrappedCardStyle.text;
  return colour.computeLuminance() < 0.3 ? Color.lerp(colour, WrappedCardStyle.text, 0.55)! : colour;
}

/// One Wrapped card: a wall behind, the copy at the bottom. [scale] sizes everything from a 360 wide phone, so the
/// 1080 wide share image uses 3. [footer] adds the logo and link the share image carries.
class WrappedCardView extends StatelessWidget {
  const WrappedCardView({
    required this.copy,
    required this.background,
    required this.accent,
    this.scale = 1,
    this.footer,
    this.topInset = 0,
    this.bottomInset = 0,
    super.key,
  });

  final WrappedCopy copy;
  final Widget background;
  final Color accent;
  final double scale;
  final Widget? footer;

  /// Room left for the story chrome above and below the copy.
  final double topInset;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    final double s = scale;
    final bool big = copy.display.runes.length <= 7;
    return DefaultTextStyle(
      style: const TextStyle(
        fontFamily: WrappedCardStyle.font,
        color: WrappedCardStyle.text,
        decoration: TextDecoration.none,
      ),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const ColoredBox(color: WrappedCardStyle.backdrop),
          background,
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const <double>[0, 0.18, 0.4, 1],
                  colors: <Color>[
                    const Color(0x73000000),
                    const Color(0x00000000),
                    const Color(0x1A000000),
                    const Color(0xE6000000).withValues(alpha: copy.rows.isEmpty ? 0.86 : 0.92),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24 * s, topInset + 24 * s, 24 * s, bottomInset + 24 * s),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                Text(
                  copy.kicker,
                  style: TextStyle(
                    fontSize: 15 * s,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3 * s,
                    color: accent,
                  ),
                ),
                SizedBox(height: 10 * s),
                if (copy.swatches.isNotEmpty) ...<Widget>[
                  Row(
                    children: <Widget>[
                      for (final Color swatch in copy.swatches)
                        Padding(
                          padding: EdgeInsetsDirectional.only(end: 10 * s),
                          child: Container(
                            width: 44 * s,
                            height: 44 * s,
                            decoration: BoxDecoration(
                              color: swatch,
                              shape: BoxShape.circle,
                              border: Border.all(color: WrappedCardStyle.text, width: 2 * s),
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: 14 * s),
                ],
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    copy.display,
                    maxLines: big ? 1 : 2,
                    style: TextStyle(
                      fontSize: (big ? 96 : 44) * s,
                      height: 1.02,
                      fontWeight: FontWeight.w800,
                      letterSpacing: (big ? -3 : -1) * s,
                    ),
                  ),
                ),
                if (copy.body.isNotEmpty) ...<Widget>[
                  SizedBox(height: 12 * s),
                  Text(
                    copy.body,
                    style: TextStyle(fontSize: 20 * s, height: 1.3, fontWeight: FontWeight.w500),
                  ),
                ],
                if (copy.rows.isNotEmpty) ...<Widget>[
                  SizedBox(height: 20 * s),
                  for (final (String label, String value) in copy.rows)
                    Padding(
                      padding: EdgeInsets.only(bottom: 12 * s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            label,
                            style: TextStyle(fontSize: 14 * s, color: WrappedCardStyle.muted),
                          ),
                          Text(
                            value,
                            style: TextStyle(fontSize: 22 * s, fontWeight: FontWeight.w700, height: 1.2),
                          ),
                        ],
                      ),
                    ),
                ],
                if (copy.since != null) ...<Widget>[
                  SizedBox(height: 10 * s),
                  Text(
                    copy.since!,
                    style: TextStyle(fontSize: 14 * s, color: WrappedCardStyle.muted),
                  ),
                ],
                if (footer != null) ...<Widget>[SizedBox(height: 28 * s), footer!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The summary background: up to four of the user's walls in a grid.
class WrappedCollage extends StatelessWidget {
  const WrappedCollage({required this.tiles, this.gap = 2, super.key});

  final List<Widget> tiles;
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (tiles.length < 4) return tiles.first;
    Widget row(int i) => Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(child: tiles[i]),
          SizedBox(width: gap),
          Expanded(child: tiles[i + 1]),
        ],
      ),
    );
    return Column(
      children: <Widget>[
        row(0),
        SizedBox(height: gap),
        row(2),
      ],
    );
  }
}
