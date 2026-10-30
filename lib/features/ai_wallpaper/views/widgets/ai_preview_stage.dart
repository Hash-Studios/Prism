import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A phone-shaped rounded frame with a hairline outline. It holds the generating state.
class AiPreviewFrame extends StatelessWidget {
  const AiPreviewFrame({super.key, required this.child});

  final Widget child;

  /// The frame is narrower than the page so the controls below stay in reach.
  static double widthOf(BuildContext context) =>
      ((MediaQuery.sizeOf(context).width - 2 * PrismSpace.page) * 0.62).clamp(160.0, 280.0);

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final BorderRadius radius = BorderRadius.circular(PrismRadius.lg);
    return SizedBox(
      width: widthOf(context),
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: cs.onSurface.withValues(alpha: 0.08)),
          ),
          child: ClipRRect(borderRadius: radius, child: child),
        ),
      ),
    );
  }
}

/// The top of the compose page: nothing, or the generating state. A finished wallpaper opens [AiResultView].
class AiPreviewStage extends StatelessWidget {
  const AiPreviewStage({super.key, required this.generating});

  final bool generating;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: context.motion(PrismDurations.base),
        switchInCurve: PrismCurves.enter,
        child: generating
            ? const _GeneratingStage(key: ValueKey<String>('generating'))
            : const SizedBox.shrink(key: ValueKey<String>('none')),
      ),
    );
  }
}

class _GeneratingStage extends StatelessWidget {
  const _GeneratingStage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        AiPreviewFrame(
          child: PulsePlaceholder(
            builder: (context, _) => const Stack(
              fit: StackFit.expand,
              children: <Widget>[
                PulseFill(),
                Center(child: Glint(mood: GlintMood.curious)),
              ],
            ),
          ),
        ),
        const SizedBox(height: PrismSpace.md),
        const AiGeneratingStatusLine(),
        const SizedBox(height: PrismSpace.xxs),
        Text(l10n.economyAiGenerationTime, style: PrismTextStyles.caption(context)),
      ],
    );
  }
}

/// What the generation is doing. The line changes every few seconds; with reduced motion it stays on the first.
class AiGeneratingStatusLine extends StatefulWidget {
  const AiGeneratingStatusLine({super.key});

  @override
  State<AiGeneratingStatusLine> createState() => _AiGeneratingStatusLineState();
}

class _AiGeneratingStatusLineState extends State<AiGeneratingStatusLine> {
  static const int _lineCount = 3;

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _lineCount);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final List<String> lines = <String>[
      l10n.economyAiMatchingScreenSize,
      l10n.economyAiApplyingStyle,
      l10n.economyAiFinalizingWallpaper,
    ];
    final String line = context.reduceMotion ? lines.first : lines[_index];
    return Semantics(
      liveRegion: true,
      child: AnimatedSwitcher(
        duration: context.motion(PrismDurations.base),
        switchInCurve: PrismCurves.enter,
        child: Text(
          line,
          key: ValueKey<String>(line),
          textAlign: TextAlign.center,
          style: PrismTextStyles.rowTitle(context),
        ),
      ),
    );
  }
}
