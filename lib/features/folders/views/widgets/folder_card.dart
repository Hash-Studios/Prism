import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/material.dart';

/// A folder's cover, name and count. The Library, the profile and "Folders you follow" use it.
class FolderCard extends StatelessWidget {
  const FolderCard({
    super.key,
    required this.name,
    required this.covers,
    required this.itemCount,
    required this.coverSize,
    required this.onTap,
    this.markPublic = false,
  });

  final String name;
  final List<String> covers;
  final int itemCount;
  final double coverSize;
  final VoidCallback onTap;

  /// Shows the owner that others can see this folder.
  final bool markPublic;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String count = l10n.foldersItemCount(itemCount);
    final TextStyle caption = PrismTextStyles.caption(context);
    return PressScale(
      child: Semantics(
        button: true,
        label: name,
        value: markPublic ? '$count, ${l10n.foldersPublic}' : count,
        excludeSemantics: true,
        onTap: onTap,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FolderCover(covers: covers, size: coverSize),
              const SizedBox(height: PrismSpace.xs),
              Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: PrismTextStyles.rowTitle(context)),
              Row(
                children: <Widget>[
                  if (markPublic) ...<Widget>[
                    Icon(Icons.public_rounded, size: 13, color: caption.color),
                    const SizedBox(width: PrismSpace.xxs),
                  ],
                  Flexible(
                    child: Text(count, maxLines: 1, overflow: TextOverflow.ellipsis, style: caption),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
