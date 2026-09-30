import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:flutter/material.dart';

/// The shared layout of onboarding steps 1 to 4: a skip button, a left-aligned title and one line of body text, the
/// step content, and a bottom bar with one primary action. The progress bar is drawn above it by the shell so its
/// fill can animate between steps.
class OnboardingFrame extends StatelessWidget {
  const OnboardingFrame({
    super.key,
    required this.title,
    required this.body,
    required this.child,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryLoading = false,
    this.secondary,
    this.onSkip,
  });

  /// Height the shell's progress bar takes at the top of the safe area.
  static const double progressSlot = 16;

  final String title;
  final String body;
  final Widget child;
  final String primaryLabel;

  /// Null disables the primary button.
  final VoidCallback? onPrimary;
  final bool primaryLoading;

  /// A quiet action under the primary one, for example "Later".
  final Widget? secondary;

  /// Shows "Skip" at the top right when set.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SizedBox(height: progressSlot),
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerRight,
              child: onSkip == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.only(right: PrismSpace.xs),
                      child: PrismButton(
                        label: 'Skip',
                        variant: PrismButtonVariant.ghost,
                        size: PrismButtonSize.compact,
                        onPressed: onSkip,
                      ),
                    ),
            ),
          ),
          Padding(
            padding: PrismSpace.pageInsets,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Semantics(header: true, child: Text(title, style: PrismTextStyles.display(context))),
                const SizedBox(height: PrismSpace.xs),
                Text(body, style: PrismTextStyles.body(context).copyWith(fontSize: 15, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(height: PrismSpace.lg),
          Expanded(child: _FadeBottom(child: child)),
          Padding(
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.sm, PrismSpace.page, PrismSpace.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                PrismButton(label: primaryLabel, expand: true, loading: primaryLoading, onPressed: onPrimary),
                if (secondary != null) ...<Widget>[const SizedBox(height: PrismSpace.xxs), secondary!],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The thin progress bar at the top of steps 1 to 4. [step] runs from 1 to [totalSteps]; the fill slides to it.
class OnboardingProgressBar extends StatelessWidget {
  const OnboardingProgressBar({super.key, required this.step, this.totalSteps = 4});

  final int step;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Onboarding progress',
      value: 'Step $step of $totalSteps',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        child: SizedBox(
          height: 4,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ColoredBox(color: cs.onSurface.withValues(alpha: 0.1)),
              TweenAnimationBuilder<double>(
                tween: Tween<double>(end: step / totalSteps),
                duration: context.motion(PrismDurations.base),
                curve: PrismCurves.move,
                builder: (context, value, _) => Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: value,
                    child: ColoredBox(color: cs.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Softens the edge where scrolling content meets the bottom bar.
class _FadeBottom extends StatelessWidget {
  const _FadeBottom({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Color surface = Theme.of(context).colorScheme.surface;
    return Stack(
      children: <Widget>[
        Positioned.fill(child: child),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: PrismSpace.md,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: <Color>[surface.withValues(alpha: 0), surface],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
