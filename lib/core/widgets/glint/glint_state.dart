import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/prism/prism_button.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Which state a [GlintState] shows. It sets Glint's mood.
enum GlintStateKind {
  /// Nothing here yet. Calm.
  empty(GlintMood.calm),

  /// All caught up. Sleepy.
  nothingNew(GlintMood.sleepy),

  /// Something failed. Sad.
  error(GlintMood.sad),

  /// No connection. Worried.
  offline(GlintMood.worried),

  /// Waiting for data. Curious.
  loading(GlintMood.curious);

  const GlintStateKind(this.mood);

  final GlintMood mood;
}

/// Glint on a soft accent disc. The disc is [glintSize] + 56 across (176 for the default 120 Glint).
///
/// Use it where a short page has one hero moment: a tall [GlintState], a finished route.
class GlintHalo extends StatelessWidget {
  const GlintHalo({super.key, this.mood = GlintMood.calm, this.glintSize = 120});

  final GlintMood mood;
  final double glintSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: glintSize + 56,
      height: glintSize + 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle),
      child: Glint(mood: mood, size: glintSize),
    );
  }
}

/// One widget for empty, error, offline, loading and "nothing new" states, with Glint.
///
/// On a tall area (480 and up) the state sits above the centre, where the eye lands first, and fills a short page:
/// Glint on a [GlintHalo], a section title and a large action. The action is the screen's primary action by default. A page that already shows a primary action (or a bottom bar) passes
/// [PrismButtonVariant.tonal] as [actionVariant].
///
/// When large text makes the state taller than its area, it scrolls instead of overflowing. Below 260 points it scales
/// down to fit.
class GlintState extends StatelessWidget {
  const GlintState({
    super.key,
    required this.kind,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.actionVariant = PrismButtonVariant.primary,
    this.glintSize,
    this.padding = const EdgeInsets.all(24),
  });

  final GlintStateKind kind;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final PrismButtonVariant actionVariant;

  /// Glint's size. Null is 120 on a tall area and 96 otherwise.
  final double? glintSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final String? bodyText = body;
    final bool hasAction = actionLabel != null && onAction != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool tight = constraints.maxHeight < 260;
        final bool tall = constraints.maxHeight >= 480;
        final Widget content = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tall)
                GlintHalo(mood: kind.mood, glintSize: glintSize ?? 120)
              else
                Glint(mood: kind.mood, size: glintSize ?? 96),
              SizedBox(height: tall ? PrismSpace.xl : PrismSpace.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: tall ? PrismTextStyles.sectionTitle(context) : PrismTextStyles.cardTitle(context),
              ),
              if (bodyText != null) ...[
                SizedBox(height: tall ? PrismSpace.xs : 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 300),
                  child: Text(bodyText, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
                ),
              ],
              if (hasAction) ...[
                SizedBox(height: tall ? PrismSpace.xl : PrismSpace.lg),
                ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tall ? 220 : 0),
                  child: PrismButton(
                    label: actionLabel!,
                    onPressed: onAction,
                    variant: actionVariant,
                    size: tall ? PrismButtonSize.large : PrismButtonSize.compact,
                  ),
                ),
              ],
            ],
          ),
        );
        final Widget body = Padding(
          padding: padding,
          child: tight ? FittedBox(fit: BoxFit.scaleDown, child: content) : content,
        );
        final Widget animated = context.reduceMotion
            ? body
            : TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: 1),
                duration: PrismDurations.base,
                curve: PrismCurves.enter,
                builder: (context, t, child) => Opacity(
                  opacity: t,
                  child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
                ),
                child: body,
              );
        Widget centered = tall ? Align(alignment: const Alignment(0, -0.5), child: animated) : Center(child: animated);
        if (kind == GlintStateKind.error || kind == GlintStateKind.offline) {
          centered = Semantics(liveRegion: true, container: true, child: centered);
        }
        if (tight || !constraints.hasBoundedHeight) return centered;
        return SingleChildScrollView(
          primary: false,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: centered,
          ),
        );
      },
    );
  }
}
