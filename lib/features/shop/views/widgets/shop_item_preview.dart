import 'package:Prism/features/shop/domain/cosmetic_styles.dart';
import 'package:Prism/features/shop/domain/shop_catalog.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:flutter/material.dart';

/// What a shop item looks like: a theme swatch, an icon tile, a profile ring or a glowing name.
class ShopItemPreview extends StatelessWidget {
  const ShopItemPreview({super.key, required this.item, this.size = 72, this.sheen = false});

  final ShopItem item;
  final double size;

  /// Sweeps a glint across an app icon once, unless animations are off.
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: switch (item.kind) {
          ShopItemKind.theme => _ThemeSwatch(item: item, size: size),
          ShopItemKind.appIcon => _IconTile(item: item, size: size, sheen: sheen),
          ShopItemKind.frame => _FramePreview(item: item, size: size),
          ShopItemKind.nameGlow => _GlowPreview(item: item, size: size),
        },
      ),
    );
  }
}

class _ThemeSwatch extends StatelessWidget {
  const _ThemeSwatch({required this.item, required this.size});

  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final PrismThemeOption? option =
        prismThemeById(prismLightThemes, item.themeId ?? '') ?? prismThemeById(prismDarkThemes, item.themeId ?? '');
    final ColorScheme scheme = option?.theme.colorScheme ?? Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(PrismRadius.sm),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
      ),
      child: Padding(
        padding: EdgeInsets.all(size * 0.14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            CircleAvatar(radius: size * 0.1, backgroundColor: scheme.primary),
            SizedBox(height: size * 0.1),
            _Bar(width: size * 0.6, height: size * 0.07, color: scheme.onSurface),
            SizedBox(height: size * 0.06),
            _Bar(width: size * 0.4, height: size * 0.07, color: scheme.surfaceContainerHigh),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.width, required this.height, required this.color});

  final double width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.item, required this.size, required this.sheen});

  final ShopItem item;
  final double size;
  final bool sheen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(size * 0.225);
    final int cacheWidth = (size * MediaQuery.devicePixelRatioOf(context)).ceil();
    return ClipRSuperellipse(
      borderRadius: radius,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(appIconAsset(item.id), fit: BoxFit.cover, cacheWidth: cacheWidth),
          if (sheen && !MediaQuery.disableAnimationsOf(context)) const _Sheen(),
          DecoratedBox(
            decoration: ShapeDecoration(
              shape: RoundedSuperellipseBorder(
                borderRadius: radius,
                side: BorderSide(color: scheme.onSurface.withValues(alpha: 0.10), width: 0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One diagonal white glint that crosses the icon and stops.
class _Sheen extends StatelessWidget {
  const _Sheen();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: -3, end: 3),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (BuildContext context, double dx, Widget? _) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(dx - 1, -1),
              end: Alignment(dx + 1, 1),
              colors: <Color>[
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.5),
                Colors.white.withValues(alpha: 0),
              ],
              stops: const <double>[0.4, 0.5, 0.6],
            ),
          ),
        ),
      ),
    );
  }
}

class _FramePreview extends StatelessWidget {
  const _FramePreview({required this.item, required this.size});

  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final FrameStyle style = frameStyle(item.id, accent: scheme.primary);
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: style.colors),
      ),
      child: Padding(
        padding: EdgeInsets.all(style.width),
        child: DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surfaceContainerHigh),
          child: Padding(
            padding: EdgeInsets.all(style.width),
            child: DecoratedBox(
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.surface),
              child: Icon(Icons.person_rounded, size: size * 0.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlowPreview extends StatelessWidget {
  const _GlowPreview({required this.item, required this.size});

  final ShopItem item;
  final double size;

  @override
  Widget build(BuildContext context) {
    final NameGlowStyle style = glowStyle(item.id);
    return Center(
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (Rect bounds) => LinearGradient(colors: style.colors).createShader(bounds),
        child: Text(
          'Glint',
          maxLines: 1,
          style: PrismTextStyles.cardTitle(context).copyWith(
            fontSize: size * 0.3,
            color: Colors.white,
            shadows: <Shadow>[Shadow(color: style.colors.first.withValues(alpha: 0.7), blurRadius: size * 0.16)],
          ),
        ),
      ),
    );
  }
}
