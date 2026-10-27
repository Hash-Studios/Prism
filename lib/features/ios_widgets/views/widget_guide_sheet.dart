import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/views/preview/phone_frame.dart';
import 'package:Prism/features/ios_shortcuts/data/ios_shortcuts_support.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';

/// Widgets need iOS 17 here: the extension needs iOS 16.2, and the version check reads only the major number.
Future<bool> iosSupportsWidgets() async =>
    defaultTargetPlatform == TargetPlatform.iOS && (await iosMajorVersion() ?? 0) >= 17;

Future<void> showWidgetGuideSheet(BuildContext context, {required WidgetGuideSourceValue source}) async {
  unawaited(analytics.track(WidgetGuideOpenedEvent(source: source)));
  await showPrismSheet<void>(context, builder: (_) => const WidgetGuideSheet());
}

enum _Surface { home, lock }

class WidgetGuideSheet extends StatefulWidget {
  const WidgetGuideSheet({super.key});

  @override
  State<WidgetGuideSheet> createState() => _WidgetGuideSheetState();
}

class _WidgetGuideSheetState extends State<WidgetGuideSheet> {
  _Surface _surface = _Surface.home;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool home = _surface == _Surface.home;
    final List<String> steps = home
        ? <String>[l10n.widgetsGuideHomeStep1, l10n.widgetsGuideHomeStep2, l10n.widgetsGuideHomeStep3]
        : <String>[l10n.widgetsGuideLockStep1, l10n.widgetsGuideLockStep2, l10n.widgetsGuideLockStep3];
    return PrismSheetBody(
      title: l10n.widgetsGuideTitle,
      actions: <Widget>[
        PrismButton(label: l10n.widgetsGuideDone, expand: true, onPressed: () => Navigator.of(context).pop()),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          PrismSegmented<_Surface>(
            values: _Surface.values,
            selected: _surface,
            labelOf: (surface) => switch (surface) {
              _Surface.home => l10n.widgetsGuideHomeTab,
              _Surface.lock => l10n.widgetsGuideLockTab,
            },
            onChanged: (surface) => setState(() => _surface = surface),
          ),
          const SizedBox(height: PrismSpace.md),
          Center(
            child: Semantics(
              image: true,
              label: home ? l10n.widgetsGuideHomeIllustration : l10n.widgetsGuideLockIllustration,
              child: ExcludeSemantics(
                child: DropPhoneFrame(
                  height: 220,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Theme.of(context).colorScheme.primaryContainer,
                          Theme.of(context).colorScheme.surfaceContainerHigh,
                        ],
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: context.motion(PrismDurations.fast),
                      child: home
                          ? const _HomeScreen(key: ValueKey<_Surface>(_Surface.home))
                          : const _LockScreen(key: ValueKey<_Surface>(_Surface.lock)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: PrismSpace.md),
          for (final (int index, String step) in steps.indexed) _StepRow(number: index + 1, text: step),
        ],
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({super.key});

  static const int _columns = 4;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double cell = constraints.maxWidth / _columns;
          final double inset = cell * 0.11;
          final int rows = (constraints.maxHeight / cell).floor();
          return Stack(
            children: <Widget>[
              Positioned(
                left: 0,
                top: 0,
                width: cell * 2,
                height: cell * 2,
                child: Padding(
                  padding: EdgeInsets.all(inset),
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.wallpaper_rounded, color: cs.onPrimary, size: cell * 0.9),
                  ),
                ),
              ),
              for (int row = 0; row < rows; row++)
                for (int column = 0; column < _columns; column++)
                  if (row >= 2 || column >= 2)
                    Positioned(
                      left: column * cell,
                      top: row * cell,
                      width: cell,
                      height: cell,
                      child: Padding(
                        padding: EdgeInsets.all(inset),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: cs.onSurface.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
            ],
          );
        },
      ),
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: <Widget>[
        const SizedBox(height: 22),
        Text('9:41', style: PrismTextStyles.cardTitle(context).copyWith(fontSize: 22, color: cs.onSurface)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: cs.primary, width: 3),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 44,
              height: 24,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PrismSpace.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 12,
            backgroundColor: cs.primary.withValues(alpha: 0.14),
            child: Text(
              '$number',
              style: PrismTextStyles.caption(context).copyWith(color: cs.primary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: PrismSpace.sm),
          Expanded(
            child: Text(text, style: PrismTextStyles.rowTitle(context).copyWith(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
