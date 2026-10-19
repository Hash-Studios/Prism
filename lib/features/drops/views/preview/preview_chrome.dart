import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/preview/phone_screen_overlay.dart';
import 'package:Prism/features/drops/views/widgets/drop_palette.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

String _two(int n) => n.toString().padLeft(2, '0');

/// Close button, the "03 / 08" serial, the wall title and its creator.
class PreviewHeader extends StatelessWidget {
  const PreviewHeader({super.key, required this.index, required this.total, required this.wall, required this.owned});

  final int index;
  final int total;
  final DropWall wall;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _CloseButton(onTap: () => Navigator.of(context).maybePop()),
          Expanded(
            child: AnimatedSwitcher(
              duration: still ? Duration.zero : const Duration(milliseconds: 180),
              child: Column(
                key: ValueKey<String>(wall.id),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    '${_two(index + 1)} / ${_two(total)}',
                    style: const TextStyle(
                      fontFamily: PrismFonts.proximaNova,
                      color: DropPalette.gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.4,
                      fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    wall.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: PrismFonts.fraunces,
                      color: DropPalette.ink,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (wall.by.isNotEmpty)
                        Text(
                          'by ${wall.by}',
                          style: const TextStyle(
                            color: DropPalette.inkMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      if (wall.by.isNotEmpty && owned) const SizedBox(width: PrismSpace.xs),
                      if (owned) const _OwnedMark(),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 44,
      child: Tooltip(
        message: 'Close preview',
        child: Semantics(
          button: true,
          label: 'Close preview',
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: DropPalette.obsidianRaised,
                  border: Border.all(color: DropPalette.hairline),
                ),
                child: const SizedBox.square(
                  dimension: 36,
                  child: Icon(Icons.close_rounded, size: 18, color: DropPalette.ink),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OwnedMark extends StatelessWidget {
  const _OwnedMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        border: Border.all(color: DropPalette.gold.withValues(alpha: 0.6)),
      ),
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.check_rounded, size: 12, color: DropPalette.gold),
            SizedBox(width: 3),
            Text(
              'Owned',
              style: TextStyle(color: DropPalette.gold, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

/// A two-part switch between the lock screen and the home screen mock.
class PreviewModeToggle extends StatelessWidget {
  const PreviewModeToggle({super.key, required this.mode, required this.onChanged});

  final DropPreviewMode mode;
  final ValueChanged<DropPreviewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final Duration slide = MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 220);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PrismRadius.pill),
        color: DropPalette.obsidianRaised,
        border: Border.all(color: DropPalette.hairline),
      ),
      child: SizedBox(
        width: 236,
        height: 34,
        child: Stack(
          children: <Widget>[
            AnimatedAlign(
              duration: slide,
              curve: Curves.easeOutCubic,
              alignment: mode == DropPreviewMode.lockScreen ? Alignment.centerLeft : Alignment.centerRight,
              child: FractionallySizedBox(
                widthFactor: 0.5,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(PrismRadius.pill),
                    color: DropPalette.gold.withValues(alpha: 0.18),
                    border: Border.all(color: DropPalette.gold.withValues(alpha: 0.55)),
                  ),
                ),
              ),
            ),
            Row(
              children: <Widget>[
                _Segment(
                  'Lock screen',
                  mode == DropPreviewMode.lockScreen,
                  () => onChanged(DropPreviewMode.lockScreen),
                ),
                _Segment(
                  'Home screen',
                  mode == DropPreviewMode.homeScreen,
                  () => onChanged(DropPreviewMode.homeScreen),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment(this.label, this.selected, this.onTap);

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: selected ? DropPalette.goldLight : DropPalette.inkMuted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
