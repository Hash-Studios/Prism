import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/drops/domain/entities/drop_entity.dart';
import 'package:Prism/features/drops/views/preview/phone_screen_overlay.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// Close button, the wall title, its creator and its place in the Drop.
class PreviewHeader extends StatelessWidget {
  const PreviewHeader({super.key, required this.index, required this.total, required this.wall, required this.owned});

  final int index;
  final int total;
  final DropWall wall;
  final bool owned;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String position = l10n.economyDropPosition(index + 1, total);
    final String detail = wall.by.isEmpty ? position : '${l10n.economyDropByCreator(wall.by)} · $position';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: l10n.economyClosePreview,
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion(PrismDurations.fast),
              child: Column(
                key: ValueKey<String>(wall.id),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    wall.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.sectionTitle(context),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PrismTextStyles.caption(context),
                        ),
                      ),
                      if (owned) ...<Widget>[
                        const SizedBox(width: PrismSpace.xs),
                        PrismTag(label: l10n.economyOwned, tone: PrismTone.success, icon: Icons.check_rounded),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

/// A switch between the lock screen and the home screen mock.
class PreviewModeToggle extends StatelessWidget {
  const PreviewModeToggle({super.key, required this.mode, required this.onChanged});

  final DropPreviewMode mode;
  final ValueChanged<DropPreviewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: PrismSegmented<DropPreviewMode>(
        values: DropPreviewMode.values,
        selected: mode,
        labelOf: (value) => switch (value) {
          DropPreviewMode.lockScreen => context.l10n.economyLockScreen,
          DropPreviewMode.homeScreen => context.l10n.economyHomeScreen,
        },
        onChanged: onChanged,
      ),
    );
  }
}
