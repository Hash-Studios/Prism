import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// A profile's public folders in one horizontal row. Takes no space when there are none, when the read fails, or
/// when a block in either direction hides them (the rules then refuse the read).
class ProfileFoldersRow extends StatefulWidget {
  const ProfileFoldersRow({super.key, required this.ownerId, required this.ownProfile});

  final String ownerId;

  /// The owner sees each folder marked as public.
  final bool ownProfile;

  /// The cover inside each wide card.
  static const double coverSize = 72;

  @override
  State<ProfileFoldersRow> createState() => _ProfileFoldersRowState();
}

class _ProfileFoldersRowState extends State<ProfileFoldersRow> {
  late Future<Result<List<PublicFolderEntity>>> _folders = _load();

  /// The last loaded folders. The row keeps showing them while a reload runs, so the profile scroll does not jump.
  List<PublicFolderEntity>? _shown;

  Future<Result<List<PublicFolderEntity>>> _load() async => getIt.isRegistered<PublicFoldersRepository>()
      ? getIt<PublicFoldersRepository>().fetchOwnerFolders(widget.ownerId)
      : Result.success(const <PublicFolderEntity>[]);

  @override
  void didUpdateWidget(ProfileFoldersRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) {
      _shown = null;
      _folders = _load();
    }
  }

  Future<void> _open(PublicFolderEntity folder) async {
    PrismHaptics.tap();
    await context.router.push(FolderRoute(folderId: folder.id));
    if (mounted) {
      setState(() {
        _folders = _load();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<List<PublicFolderEntity>>>(
      future: _folders,
      builder: (context, snapshot) {
        final bool done = snapshot.connectionState == ConnectionState.done;
        if (!done && _shown == null) return const SizedBox(width: double.infinity);
        final List<PublicFolderEntity> folders = done
            ? (_shown = snapshot.data?.data ?? const <PublicFolderEntity>[])
            : _shown!;
        return AnimatedSize(
          duration: context.motion(PrismDurations.fast),
          alignment: Alignment.topCenter,
          child: folders.isEmpty ? const SizedBox(width: double.infinity) : _row(context, folders),
        );
      },
    );
  }

  Widget _row(BuildContext context, List<PublicFolderEntity> folders) {
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    // Two name lines and the count, or the cover, whichever is taller, inside the card's padding and border.
    final double inner = math.max(ProfileFoldersRow.coverSize, scaler.scale(20) * 2 + scaler.scale(18));
    final double height = inner + PrismSpace.sm * 2 + 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
          child: PrismSectionHeader(
            title: context.l10n.foldersTitle,
            padding: const EdgeInsets.only(top: PrismSpace.md, bottom: PrismSpace.sm),
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final double content = constraints.maxWidth - PrismSpace.page * 2;
            // One folder fills the row; more show as wide cards with the next one peeking in.
            final double width = folders.length == 1 ? content : math.min(content * 0.82, 340);
            return SizedBox(
              height: height,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
                itemCount: folders.length,
                separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.sm),
                itemBuilder: (context, index) {
                  final PublicFolderEntity folder = folders[index];
                  return SizedBox(
                    width: width,
                    child: _WideFolderCard(
                      key: ValueKey<String>(folder.id),
                      folder: folder,
                      markPublic: widget.ownProfile,
                      onTap: () => unawaited(_open(folder)),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A folder as one wide card: the cover, then the full name (two lines) and the count.
class _WideFolderCard extends StatelessWidget {
  const _WideFolderCard({super.key, required this.folder, required this.markPublic, required this.onTap});

  final PublicFolderEntity folder;
  final bool markPublic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String count = l10n.foldersItemCount(folder.itemCount);
    final TextStyle caption = PrismTextStyles.caption(context);
    return Semantics(
      button: true,
      label: folder.name,
      value: <String>[count, if (markPublic) l10n.foldersPublic].join(', '),
      excludeSemantics: true,
      onTap: onTap,
      child: PrismCard(
        padding: const EdgeInsets.all(PrismSpace.sm),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            FolderCover(covers: folder.covers, size: ProfileFoldersRow.coverSize),
            const SizedBox(width: PrismSpace.sm),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    folder.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PrismTextStyles.rowTitle(context),
                  ),
                  const SizedBox(height: 2),
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
          ],
        ),
      ),
    );
  }
}
