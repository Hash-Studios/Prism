import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// A caption label beside its value, for the facts on a moderation card.
class ModerationFact extends StatelessWidget {
  const ModerationFact({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextStyle caption = PrismTextStyles.caption(context);
    return Semantics(
      container: true,
      label: '$label: $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(width: 68, child: Text(label, style: caption)),
            Expanded(
              child: Text(
                value,
                style: caption.copyWith(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wallpaper thumbnail with a skeleton while it loads and a quiet placeholder when it is missing or broken.
class ModerationThumb extends StatelessWidget {
  const ModerationThumb({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    required this.semanticLabel,
    this.onTap,
  });

  /// An empty [url] shows the missing-image placeholder.
  final String url;
  final double width;
  final double height;
  final String semanticLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    Widget missing() => ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(child: Icon(Icons.image_not_supported_outlined, color: cs.onSurface.withValues(alpha: 0.5))),
    );
    final Widget image = ClipRRect(
      borderRadius: BorderRadius.circular(PrismRadius.sm),
      child: SizedBox(
        width: width,
        height: height,
        child: url.isEmpty
            ? missing()
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, _) => PrismSkeleton(
                  child: PrismBone(width: width, height: height, radius: 0),
                ),
                errorWidget: (_, _, _) => missing(),
              ),
      ),
    );
    if (onTap == null) return image;
    return PressScale(
      scale: 0.97,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: image),
      ),
    );
  }
}

/// A tonal button whose label is in the error colour, for rejecting or removing. [PrismButton] has no such variant.
class ModerationDangerButton extends StatelessWidget {
  const ModerationDangerButton({super.key, required this.label, required this.onPressed});

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PressScale(
      enabled: onPressed != null,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: cs.onSurface.withValues(alpha: 0.08),
          foregroundColor: cs.error,
          disabledBackgroundColor: cs.onSurface.withValues(alpha: 0.06),
          disabledForegroundColor: cs.onSurface.withValues(alpha: 0.38),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
          textStyle: PrismTextStyles.button.copyWith(fontSize: 14),
          splashFactory: NoSplash.splashFactory,
        ),
        child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
