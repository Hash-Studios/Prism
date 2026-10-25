import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The banner and the update announcement run until this local date. The theme itself stays.
final DateTime spookySeasonEnd = DateTime(2026, 11, 3);

/// The clock [isSpookySeason] reads when no date is given. Tests set it, so they do not depend on the real date.
@visibleForTesting
DateTime Function() spookyClock = DateTime.now;

DateTime spookyNow() => spookyClock();

bool isSpookySeason([DateTime? now]) => (now ?? spookyNow()).isBefore(spookySeasonEnd);

/// True when the theme in [context] is Spooky. It reads the page colour, so it needs no theme bloc above it.
bool isSpookyActive(BuildContext context) => Theme.of(context).colorScheme.surface == kDarkTheme9.colorScheme.surface;

const String _spiderSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 96" fill="none">
<path d="M24 0 V56" stroke="currentColor" stroke-width="1" stroke-opacity="0.55"/>
<path d="M19 60 L8 51 L2 57 M29 60 L40 51 L46 57 M18 63 L5 60 L1 69 M30 63 L43 60 L47 69 M18 66 L6 71 L3 81 M30 66 L42 71 L45 81 M19 69 L10 79 L8 89 M29 69 L38 79 L40 89" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
<ellipse cx="24" cy="75" rx="9.5" ry="11.5" fill="currentColor"/>
<circle cx="24" cy="61" r="6.5" fill="currentColor"/>
<circle cx="21.6" cy="60.2" r="1.5" fill="__EYE_ACCENT__"/><circle cx="26.4" cy="60.2" r="1.5" fill="__EYE_ACCENT__"/>
</svg>''';

String _spiderSvgWithAccent(Color accent) {
  final String hex = (accent.toARGB32() & 0x00ffffff).toRadixString(16).padLeft(6, '0');
  return _spiderSvg.replaceAll('__EYE_ACCENT__', '#$hex');
}

const String _webSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 120" fill="none" stroke="currentColor" stroke-linecap="round">
<path d="M0 0 L118 0 M0 0 L112.2 36.5 M0 0 L95.5 69.4 M0 0 L69.4 95.5 M0 0 L36.5 112.2 M0 0 L0 118" stroke-width="1.1"/>
<path d="M26 0 Q22.1 3.5 24.7 8 Q19.9 10.2 21 15.3 Q15.8 15.8 15.3 21 Q10.2 19.9 8 24.7 Q3.5 22.1 0 26 M50 0 Q42.5 6.7 47.6 15.5 Q38.3 19.5 40.5 29.4 Q30.4 30.4 29.4 40.5 Q19.5 38.3 15.5 47.6 Q6.7 42.5 0 50 M74 0 Q62.9 10 70.4 22.9 Q56.7 28.9 59.9 43.5 Q45 45 43.5 59.9 Q28.9 56.7 22.9 70.4 Q10 62.9 0 74 M98 0 Q83.2 13.2 93.2 30.3 Q75.1 38.3 79.3 57.6 Q59.6 59.6 57.6 79.3 Q38.3 75.1 30.3 93.2 Q13.2 83.2 0 98" stroke-width="0.9"/>
</svg>''';

const String _pumpkinSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 120 110">
<path d="M58 22 C57 14 60 8 67 4 L71 8 C66 11 64 16 65 22 Z" fill="#5B6B2A"/>
<ellipse cx="34" cy="64" rx="26" ry="38" fill="#E8620E"/>
<ellipse cx="86" cy="64" rx="26" ry="38" fill="#E8620E"/>
<ellipse cx="60" cy="64" rx="30" ry="42" fill="#FF7A1A"/>
<ellipse cx="46" cy="64" rx="14" ry="40" fill="#FF8B33" opacity="0.55"/>
<ellipse cx="74" cy="64" rx="14" ry="40" fill="#F06D12" opacity="0.6"/>
<path d="M36 52 L47 40 L52 55 Z M84 52 L73 40 L68 55 Z M57 60 L60 54 L63 60 Z" fill="#2B1206"/>
<path d="M30 70 Q60 96 90 70 L84 74 L80 70 L74 78 L68 72 L60 82 L52 72 L46 78 L40 70 L36 74 Z" fill="#2B1206"/>
</svg>''';

const String _batSvg = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 28"><path fill="currentColor" d="M32 8 C30 4 29 3 29.5 1 L31 4 L33 4 L34.5 1 C35 3 34 4 32 8 Z M32 7 C36 7 38 10 40 13 C44 8 52 6 64 9 C58 11 56 15 57 20 C53 17 49 17 47 20 C45 17 41 17 38 21 C36 18 34 17 32 19 C30 17 28 18 26 21 C23 17 19 17 17 20 C15 17 11 17 7 20 C8 15 6 11 0 9 C12 6 20 8 24 13 C26 10 28 7 32 7 Z"/></svg>''';

Widget _svg(String source, {required double width, Color? color}) => SvgPicture.string(
  source,
  width: width,
  colorFilter: color == null ? null : ColorFilter.mode(color, BlendMode.srcIn),
);

Widget _svgCurrentColor(String source, {required double width, required Color color}) => SvgPicture.string(
  source,
  width: width,
  theme: SvgTheme(currentColor: color),
);

/// A spider that hangs from the top of its box and bobs on its thread. Draws nothing unless Spooky is active.
class SpookySpider extends StatefulWidget {
  const SpookySpider({super.key, this.size = 28});

  final double size;

  @override
  State<SpookySpider> createState() => _SpookySpiderState();
}

class _SpookySpiderState extends State<SpookySpider> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!isSpookyActive(context)) {
      if (_bob.isAnimating) _bob.stop();
      return const SizedBox.shrink();
    }
    if (context.reduceMotion) {
      _bob.stop();
    } else if (!_bob.isAnimating) {
      _bob.repeat(reverse: true);
    }
    final Widget spider = _svgCurrentColor(
      _spiderSvgWithAccent(Theme.of(context).colorScheme.primary),
      width: widget.size,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.85),
    );
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _bob,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, -widget.size * 0.5 * Curves.easeInOut.transform(_bob.value)),
            child: child,
          ),
          child: spider,
        ),
      ),
    );
  }
}

/// A cobweb for a top corner. Draws nothing unless Spooky is active.
class SpookyWeb extends StatelessWidget {
  const SpookyWeb({super.key, this.size = 96, this.right = false});

  final double size;

  /// Mirrors the web for the top right corner.
  final bool right;

  @override
  Widget build(BuildContext context) {
    if (!isSpookyActive(context)) return const SizedBox.shrink();
    final Widget web = _svg(
      _webSvg,
      width: size,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.22),
    );
    return IgnorePointer(
      child: ExcludeSemantics(child: right ? Transform.flip(flipX: true, child: web) : web),
    );
  }
}

/// Artwork for the home carousel card that offers the Spooky theme. It does not depend on the active theme.
class SpookyBannerArt extends StatelessWidget {
  const SpookyBannerArt({super.key});

  static const Color _bone = Color(0xFFF5E6D3);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double h = constraints.maxHeight;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: RadialGradient(
              center: Alignment(0.6, 0.2),
              radius: 1.1,
              colors: <Color>[Color(0xFF3A1A06), Color(0xFF0B0806)],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                child: _svg(_webSvg, width: h * 0.6, color: _bone.withValues(alpha: 0.28)),
              ),
              Positioned(
                right: h * 0.12,
                bottom: h * 0.2,
                child: _svg(_pumpkinSvg, width: h * 0.62),
              ),
              Positioned(
                right: h * 0.86,
                top: 0,
                child: _svgCurrentColor(
                  _spiderSvgWithAccent(const Color(0xFFFF7A1A)),
                  width: h * 0.16,
                  color: _bone.withValues(alpha: 0.9),
                ),
              ),
              Positioned(
                right: h * 0.22,
                top: h * 0.1,
                child: _svgCurrentColor(_batSvg, width: h * 0.2, color: _bone.withValues(alpha: 0.75)),
              ),
              Positioned(
                right: h * 0.62,
                top: h * 0.26,
                child: _svgCurrentColor(_batSvg, width: h * 0.13, color: _bone.withValues(alpha: 0.5)),
              ),
            ],
          ),
        );
      },
    );
  }
}
