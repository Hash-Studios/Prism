import 'dart:async';

import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

class ProfileCompletenessCard extends StatefulWidget {
  const ProfileCompletenessCard({super.key, required this.status, this.onCompleteNow});

  final ProfileCompletenessStatus status;
  final Future<void> Function()? onCompleteNow;

  @override
  State<ProfileCompletenessCard> createState() => _ProfileCompletenessCardState();
}

class _ProfileCompletenessCardState extends State<ProfileCompletenessCard> with SingleTickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _entranceController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _entranceController, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entranceController, curve: Curves.easeOutQuart));
    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _handleComplete() async {
    if (_isLoading || widget.onCompleteNow == null) return;
    setState(() => _isLoading = true);
    SemanticsService.announce('Opening profile editor', TextDirection.ltr);
    try {
      await widget.onCompleteNow!();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status.isComplete) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme colorScheme = theme.colorScheme;
    // Lerp from brand pink (start) toward primary as the profile fills up —
    // keeps the ring on-brand at low completion and themed at 100%.
    final Color progressColor =
        Color.lerp(PrismColors.brandPink, colorScheme.primary, widget.status.progress.clamp(0.0, 1.0)) ??
        PrismColors.brandPink;
    final int remainingSteps = (widget.status.totalSteps - widget.status.completedSteps).clamp(
      0,
      widget.status.totalSteps,
    );

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Card(
          elevation: 0,
          // onSurface at low opacity is hue-neutral across all 12 themes —
          // secondaryContainer picked up saturated tints from theme accents.
          color: colorScheme.onSurface.withValues(alpha: 0.07),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                _ProgressRing(status: widget.status, progressColor: progressColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Profile ${widget.status.percent}% done',
                        style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            remainingSteps == 1 ? '1 step · ' : '$remainingSteps steps · ',
                            style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                          ),
                          const Icon(
                            Icons.monetization_on_rounded,
                            size: 12,
                            color: Colors.amber,
                            semanticLabel: 'coin',
                          ),
                          Text(
                            ' 25 coins',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: widget.onCompleteNow == null ? null : _handleComplete,
                  style: FilledButton.styleFrom(
                    backgroundColor: PrismColors.brandPink,
                    foregroundColor: PrismColors.onPrimary,
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: _isLoading
                        ? SizedBox(
                            key: const ValueKey('loading'),
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                          )
                        : const Text('Finish', key: ValueKey('label')),
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

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.status, this.progressColor});

  final ProfileCompletenessStatus status;
  final Color? progressColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Semantics(
      label: 'Profile ${status.percent}% complete',
      value: '${status.percent}%',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: status.progress),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double value, Widget? child) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: 4.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(progressColor ?? theme.colorScheme.primary),
                );
              },
            ),
            // Excluded from semantics — the outer Semantics node already
            // conveys the percentage as a structured value.
            Center(
              child: ExcludeSemantics(
                child: TweenAnimationBuilder<int>(
                  tween: IntTween(begin: 0, end: status.percent),
                  duration: const Duration(milliseconds: 650),
                  curve: Curves.easeOutCubic,
                  builder: (BuildContext context, int value, Widget? child) {
                    return Text('$value%', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w800));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
