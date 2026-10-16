import 'dart:async';

import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/pulse_placeholder.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_generation_record.dart';
import 'package:Prism/features/ai_wallpaper/views/widgets/ai_decoded_image.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// A phone-shaped rounded frame with a hairline outline. It holds the generating state and the finished wallpaper.
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

/// The top of the AI page: nothing, the generating state, or the selected generation.
class AiPreviewStage extends StatelessWidget {
  const AiPreviewStage({super.key, required this.generating, required this.record, required this.isPremium});

  final bool generating;
  final AiGenerationRecord? record;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final AiGenerationRecord? current = record;
    final Widget child = generating
        ? const _GeneratingStage(key: ValueKey<String>('generating'))
        : current == null
        ? const SizedBox.shrink(key: ValueKey<String>('none'))
        : Semantics(
            key: ValueKey<String>(current.id),
            image: true,
            label: 'Generated wallpaper',
            child: AiPreviewFrame(
              child: LayoutBuilder(
                builder: (context, box) => AiDecodedImage(
                  url: current.displayUrl(isPremium: isPremium),
                  logicalWidth: box.maxWidth,
                  logicalHeight: box.maxHeight,
                ),
              ),
            ),
          );
    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration: context.motion(PrismDurations.base),
        switchInCurve: PrismCurves.enter,
        child: child,
      ),
    );
  }
}

class _GeneratingStage extends StatelessWidget {
  const _GeneratingStage({super.key});

  @override
  Widget build(BuildContext context) {
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
        const _StatusLine(),
        const SizedBox(height: PrismSpace.xxs),
        Text('This takes about 20 seconds', style: PrismTextStyles.caption(context)),
      ],
    );
  }
}

class _StatusLine extends StatefulWidget {
  const _StatusLine();

  @override
  State<_StatusLine> createState() => _StatusLineState();
}

class _StatusLineState extends State<_StatusLine> {
  static const List<String> _lines = <String>[
    'Matching your screen size…',
    'Applying your style…',
    'Finalizing your wallpaper…',
  ];

  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(() => _index = (_index + 1) % _lines.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String line = context.reduceMotion ? _lines.first : _lines[_index];
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
