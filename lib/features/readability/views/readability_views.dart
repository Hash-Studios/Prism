import 'dart:async';
import 'dart:ui' as ui;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/readability/data/readability_render.dart';
import 'package:Prism/features/readability/data/readability_tips.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/preview_layers.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

typedef ReadabilityFrameRenderer =
    Future<ui.Image> Function(
      ui.Image source, {
      required int width,
      required int height,
      required TargetPlatform platform,
      ui.Color? tint,
      List<ReadabilityFix> fixes,
    });

@visibleForTesting
ReadabilityFrameRenderer readabilityFrameRenderer = renderReadabilityFrame;

/// A quiet pill next to a zone that may be hard to read. It fades in once and never blocks the screen.
class ReadabilityChip extends StatelessWidget {
  const ReadabilityChip({super.key, required this.zone, required this.onTap});

  final ReadabilityZone zone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String label = switch (zone) {
      ReadabilityZone.clock => l10n.readabilityClockChip,
      ReadabilityZone.icons => l10n.readabilityIconsChip,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: context.motion(PrismDurations.base),
      curve: PrismCurves.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.scale(scale: 0.95 + 0.05 * t, child: child),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 320, minHeight: prismTapTarget(context)),
        child: Semantics(
          button: true,
          label: label,
          hint: l10n.readabilityChipHint,
          excludeSemantics: true,
          onTap: onTap,
          child: PressScale(
            child: Material(
              color: scheme.surface.withValues(alpha: 0.92),
              shape: const StadiumBorder(),
              child: InkWell(
                key: ValueKey<String>('readability-chip-${zone.name}'),
                customBorder: const StadiumBorder(),
                onTap: () {
                  PrismHaptics.selection();
                  onTap();
                },
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 14, 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(Icons.contrast_rounded, size: 16, color: scheme.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PrismTextStyles.caption(context).copyWith(color: scheme.onSurface),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the before and after sheet needs to draw the wall the way the Set screen shows it.
class ReadabilityPreviewSource {
  const ReadabilityPreviewSource({required this.provider, required this.screen, required this.textColor, this.tint});

  final ImageProvider provider;

  /// The screen size in logical pixels. The thumbnails keep its aspect.
  final Size screen;
  final Color textColor;
  final Color? tint;
}

/// Shows the wall before and after [fix]. Returns true for Apply, false for Keep as is, null when dismissed.
Future<bool?> showReadabilityFixSheet(BuildContext context, ReadabilityPreviewSource source, ReadabilityFix fix) =>
    showPrismSheet<bool>(
      context,
      useRootNavigator: true,
      builder: (_) => ReadabilityFixSheet(source: source, fix: fix),
    );

class ReadabilityFixSheet extends StatefulWidget {
  const ReadabilityFixSheet({super.key, required this.source, required this.fix});

  final ReadabilityPreviewSource source;
  final ReadabilityFix fix;

  @override
  State<ReadabilityFixSheet> createState() => _ReadabilityFixSheetState();
}

class _ReadabilityFixSheetState extends State<ReadabilityFixSheet> {
  static const double _thumbWidth = 132;

  ui.Image? _before;
  ui.Image? _after;
  bool _failed = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    unawaited(_render(MediaQuery.devicePixelRatioOf(context)));
  }

  Future<void> _render(double dpr) async {
    final Size screen = widget.source.screen;
    final int width = (_thumbWidth * dpr).round();
    final int height = (width * screen.height / screen.width).round();
    try {
      final ui.Image decoded = await decodeForFrame(widget.source.provider, height);
      try {
        final TargetPlatform platform = defaultTargetPlatform;
        final ui.Image before = await readabilityFrameRenderer(
          decoded,
          width: width,
          height: height,
          platform: platform,
          tint: widget.source.tint,
        );
        late final ui.Image after;
        try {
          after = await readabilityFrameRenderer(
            decoded,
            width: width,
            height: height,
            platform: platform,
            tint: widget.source.tint,
            fixes: <ReadabilityFix>[widget.fix],
          );
        } catch (_) {
          before.dispose();
          rethrow;
        }
        if (!mounted) {
          before.dispose();
          after.dispose();
          return;
        }
        setState(() {
          _before = before;
          _after = after;
        });
      } finally {
        decoded.dispose();
      }
    } catch (error, stackTrace) {
      logger.w('Readability: could not draw the before and after preview', error: error, stackTrace: stackTrace);
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _before?.dispose();
    _after?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ReadabilityFix fix = widget.fix;
    final String title = switch ((fix.zone, fix.kind)) {
      (ReadabilityZone.clock, ReadabilityFixKind.dim) => l10n.readabilityDimClockTitle,
      (ReadabilityZone.clock, ReadabilityFixKind.blur) => l10n.readabilityBlurClockTitle,
      (ReadabilityZone.icons, ReadabilityFixKind.dim) => l10n.readabilityDimIconsTitle,
      (ReadabilityZone.icons, ReadabilityFixKind.blur) => l10n.readabilityBlurIconsTitle,
    };
    return PrismSheetBody(
      title: title,
      message: fix.zone == ReadabilityZone.clock ? l10n.readabilityClockBody : l10n.readabilityIconsBody,
      actions: <Widget>[
        PrismButton(
          key: const ValueKey<String>('readability-apply'),
          label: l10n.readabilityApply,
          // Apply waits for the preview, so the user sees the change before they take it.
          onPressed: _after == null ? null : () => Navigator.of(context).pop(true),
        ),
        PrismButton(
          key: const ValueKey<String>('readability-keep'),
          label: l10n.readabilityKeep,
          variant: PrismButtonVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
      child: _failed
          ? null
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _Thumb(
                  image: _before,
                  label: l10n.readabilityBefore,
                  semanticLabel: l10n.readabilityBeforeSemantic,
                  traversalOrder: 0,
                  zone: fix.zone,
                  source: widget.source,
                ),
                const SizedBox(width: PrismSpace.md),
                _Thumb(
                  key: const ValueKey<String>('readability-after'),
                  image: _after,
                  label: l10n.readabilityAfter,
                  semanticLabel: l10n.readabilityAfterSemantic,
                  traversalOrder: 1,
                  zone: fix.zone,
                  source: widget.source,
                ),
              ],
            ),
    );
  }
}

/// One phone-shaped thumbnail with the clock or the icons drawn on top, and a label under it.
class _Thumb extends StatelessWidget {
  const _Thumb({
    super.key,
    required this.image,
    required this.label,
    required this.semanticLabel,
    required this.traversalOrder,
    required this.zone,
    required this.source,
  });

  final ui.Image? image;
  final String label;
  final String semanticLabel;
  final double traversalOrder;
  final ReadabilityZone zone;
  final ReadabilityPreviewSource source;

  @override
  Widget build(BuildContext context) {
    final ui.Image? shown = image;
    final Size screen = source.screen;
    return Flexible(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _ReadabilityFixSheetState._thumbWidth),
        child: Semantics(
          sortKey: OrdinalSortKey(traversalOrder),
          child: MergeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Semantics(
                  image: true,
                  label: semanticLabel,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(PrismRadius.lg),
                    child: AspectRatio(
                      aspectRatio: screen.width / screen.height,
                      child: ExcludeSemantics(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            AnimatedSwitcher(
                              duration: context.motion(PrismDurations.fast),
                              child: shown == null
                                  ? ColoredBox(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06))
                                  : RawImage(key: ValueKey<ui.Image>(shown), image: shown, fit: BoxFit.cover),
                            ),
                            if (shown != null && zone == ReadabilityZone.clock)
                              LockPreviewLayer(textColor: source.textColor)
                            else if (shown != null)
                              const HomePreviewLayer(textColor: Colors.white),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: PrismSpace.xs),
                Text(label, style: PrismTextStyles.caption(context), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The Readability tips switch in Settings. On by default.
class ReadabilityTipsRow extends StatefulWidget {
  const ReadabilityTipsRow({super.key});

  @override
  State<ReadabilityTipsRow> createState() => _ReadabilityTipsRowState();
}

class _ReadabilityTipsRowState extends State<ReadabilityTipsRow> {
  late bool _on = ReadabilityTips.instance.enabled;

  void _set(bool value) {
    setState(() => _on = value);
    unawaited(ReadabilityTips.instance.setEnabled(value));
  }

  @override
  Widget build(BuildContext context) => PrismSwitchRow(
    icon: Icons.contrast_rounded,
    title: context.l10n.settingsReadabilityTipsTitle,
    subtitle: context.l10n.settingsReadabilityTipsBody,
    value: _on,
    onChanged: _set,
  );
}

/// [provider] covering its box with [fixes] painted on, through the same painter as the file that gets set.
/// It shows the plain image until the fixed one is drawn.
class ReadabilityFixedImage extends StatefulWidget {
  const ReadabilityFixedImage({super.key, required this.provider, required this.fixes});

  final ImageProvider provider;
  final List<ReadabilityFix> fixes;

  @override
  State<ReadabilityFixedImage> createState() => _ReadabilityFixedImageState();
}

class _ReadabilityFixedImageState extends State<ReadabilityFixedImage> {
  ui.Image? _image;
  Object? _drawn;
  int _generation = 0;

  Future<void> _draw(Size size, double dpr) async {
    final Object job = (widget.provider, Object.hashAll(widget.fixes), size, dpr);
    if (job == _drawn) return;
    _drawn = job;
    final int generation = ++_generation;
    _image?.dispose();
    _image = null;
    final int width = (size.width * dpr).round();
    final int height = (size.height * dpr).round();
    if (width < 2 || height < 2) return;
    try {
      final ui.Image decoded = await decodeForFrame(widget.provider, height);
      final ui.Image drawn;
      try {
        drawn = await readabilityFrameRenderer(
          decoded,
          width: width,
          height: height,
          platform: defaultTargetPlatform,
          fixes: widget.fixes,
        );
      } finally {
        decoded.dispose();
      }
      if (!mounted || generation != _generation) {
        drawn.dispose();
        return;
      }
      final ui.Image? old = _image;
      setState(() => _image = drawn);
      old?.dispose();
    } catch (error, stackTrace) {
      logger.w('Readability: could not draw the fixed preview', error: error, stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _generation++;
    _image?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        unawaited(_draw(constraints.biggest, dpr));
        final ui.Image? image = _image;
        return image == null
            ? Image(image: widget.provider, fit: BoxFit.cover)
            : RawImage(image: image, fit: BoxFit.cover);
      },
    );
  }
}
