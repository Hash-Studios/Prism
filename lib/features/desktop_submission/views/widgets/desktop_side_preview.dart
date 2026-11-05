import 'package:Prism/core/cache/prism_image_cache.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// The wide image next to the phone wallpaper, so the creator sees how the pair reads on a phone and a computer.
class DesktopSidePreview extends StatelessWidget {
  const DesktopSidePreview({
    required this.phoneThumbUrl,
    required this.desktopImage,
    required this.desktopWidth,
    required this.desktopHeight,
    required this.aspectLabel,
    super.key,
  });

  final String phoneThumbUrl;
  final ImageProvider? desktopImage;
  final int? desktopWidth;
  final int? desktopHeight;

  /// `16:10` or `16:9`. Null until the picked image passes the check.
  final String? aspectLabel;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final int? width = desktopWidth;
    final int? height = desktopHeight;
    final String? ratio = aspectLabel;

    final Widget phone = Semantics(
      image: true,
      label: l10n.desktopUploadPhoneSemantic,
      child: ExcludeSemantics(
        child: _Frame(
          aspectRatio: 9 / 19.5,
          child: CachedNetworkImage(
            cacheManager: PrismImageCache.instance,
            imageUrl: phoneThumbUrl,
            fit: BoxFit.cover,
            memCacheWidth: 240,
            placeholder: (_, _) => ColoredBox(color: cs.surfaceContainerHighest),
            errorWidget: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
          ),
        ),
      ),
    );

    final Widget desktopFrame = _Frame(
      aspectRatio: ratio == '16:9' ? 16 / 9 : 16 / 10,
      child: desktopImage == null
          ? ColoredBox(
              color: cs.onSurface.withValues(alpha: 0.08),
              child: Center(child: Icon(Icons.desktop_windows_outlined, color: cs.onSurfaceVariant)),
            )
          : Image(
              image: desktopImage!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => ColoredBox(color: cs.surfaceContainerHighest),
            ),
    );
    final Widget desktop = width != null && height != null
        ? Semantics(
            image: true,
            label: l10n.desktopUploadDesktopSemantic(width, height),
            child: ExcludeSemantics(child: desktopFrame),
          )
        : ExcludeSemantics(child: desktopFrame);

    final Widget phoneColumn = _Labelled(label: l10n.desktopUploadPhoneLabel, frame: phone);
    final Widget desktopColumn = _Labelled(
      label: l10n.desktopUploadDesktopLabel,
      frame: desktop,
      size: width != null && height != null && ratio != null ? l10n.desktopUploadSize(width, height, ratio) : null,
    );

    // At large text the side-by-side pair cannot fit, so the phone sits above the desktop frame.
    final bool largeText = MediaQuery.textScalerOf(context).scale(16) / 16 >= 1.6;
    if (largeText) {
      return Column(
        children: <Widget>[
          SizedBox(width: 140, child: phoneColumn),
          const SizedBox(height: PrismSpace.md),
          desktopColumn,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(flex: 2, child: phoneColumn),
        const SizedBox(width: PrismSpace.md),
        Expanded(flex: 5, child: desktopColumn),
      ],
    );
  }
}

class _Labelled extends StatelessWidget {
  const _Labelled({required this.label, required this.frame, this.size});

  final String label;
  final Widget frame;
  final String? size;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        frame,
        const SizedBox(height: PrismSpace.sm),
        Text(label, style: PrismTextStyles.body(context), textAlign: TextAlign.center),
        if (size != null) ...<Widget>[
          const SizedBox(height: PrismSpace.xxs),
          Text(size!, style: PrismTextStyles.caption(context), textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _Frame extends StatelessWidget {
  const _Frame({required this.aspectRatio, required this.child});

  final double aspectRatio;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.sm);
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
        ),
        child: ClipRRect(borderRadius: radius, child: child),
      ),
    );
  }
}
