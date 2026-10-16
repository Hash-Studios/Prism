import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/admin_review/views/widgets/swipe_wallpaper_card.dart';
import 'package:flutter/material.dart';

/// The tint and stamp that grow over the top card while it is dragged: green "Approve" to the right, red "Reject"
/// to the left. Colour is never the only signal: each stamp has an icon and a word.
class SwipeActionOverlay extends StatelessWidget {
  final double swipeProgress;

  const SwipeActionOverlay({super.key, required this.swipeProgress});

  @override
  Widget build(BuildContext context) {
    if (swipeProgress.abs() < 0.1) {
      return const SizedBox.shrink();
    }

    final ColorScheme cs = Theme.of(context).colorScheme;
    final double opacity = Curves.easeOut.transform((swipeProgress.abs() * 1.5).clamp(0.0, 1.0));
    final bool approve = swipeProgress > 0;
    final Color tone = approve ? PrismColors.success : cs.error;

    return Positioned.fill(
      child: IgnorePointer(
        child: Padding(
          padding: SwipeWallpaperCard.margin,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PrismRadius.lg),
              color: tone.withValues(alpha: opacity * 0.28),
              border: Border.all(color: tone.withValues(alpha: opacity), width: 3),
            ),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Transform.rotate(
                  angle: approve ? -0.12 : 0.12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.xs),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.62),
                      border: Border.all(color: tone, width: 2),
                      borderRadius: BorderRadius.circular(PrismRadius.md),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(approve ? Icons.check_rounded : Icons.close_rounded, color: tone, size: 28),
                        const SizedBox(width: PrismSpace.xs),
                        Text(
                          approve ? 'Approve' : 'Reject',
                          style: PrismTextStyles.sheetHeadline(context).copyWith(color: Colors.white),
                        ),
                      ],
                    ),
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
