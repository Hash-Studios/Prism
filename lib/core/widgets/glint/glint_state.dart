import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
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

/// One widget for empty, error, offline, loading and "nothing new" states, with Glint.
class GlintState extends StatelessWidget {
  const GlintState({
    super.key,
    required this.kind,
    required this.title,
    this.body,
    this.actionLabel,
    this.onAction,
    this.glintSize = 96,
    this.padding = const EdgeInsets.all(24),
  });

  final GlintStateKind kind;
  final String title;
  final String? body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final double glintSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final String? bodyText = body;
    final bool hasAction = actionLabel != null && onAction != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool tight = constraints.maxHeight < 260;
        final Widget content = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Glint(mood: kind.mood, size: glintSize),
              const SizedBox(height: 16),
              Text(title, textAlign: TextAlign.center, style: PrismTextStyles.cardTitle(context)),
              if (bodyText != null) ...[
                const SizedBox(height: 6),
                Text(bodyText, textAlign: TextAlign.center, style: PrismTextStyles.body(context)),
              ],
              if (hasAction) ...[
                const SizedBox(height: 16),
                FilledButton.tonal(onPressed: onAction, child: Text(actionLabel!)),
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
        return Center(child: animated);
      },
    );
  }
}
