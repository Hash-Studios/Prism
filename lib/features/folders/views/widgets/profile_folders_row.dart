import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/features/folders/domain/repositories/public_folders_repository.dart';
import 'package:Prism/features/folders/views/widgets/folder_card.dart';
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

  static const double cardWidth = 132;

  @override
  State<ProfileFoldersRow> createState() => _ProfileFoldersRowState();
}

class _ProfileFoldersRowState extends State<ProfileFoldersRow> {
  late Future<Result<List<PublicFolderEntity>>> _folders = _load();

  Future<Result<List<PublicFolderEntity>>> _load() async => getIt.isRegistered<PublicFoldersRepository>()
      ? getIt<PublicFoldersRepository>().fetchOwnerFolders(widget.ownerId)
      : Result.success(const <PublicFolderEntity>[]);

  @override
  void didUpdateWidget(ProfileFoldersRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ownerId != widget.ownerId) _folders = _load();
  }

  Future<void> _open(PublicFolderEntity folder) async {
    PrismHaptics.tap();
    await context.router.push(FolderRoute(folderId: folder.id));
    if (mounted) setState(() => _folders = _load());
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Result<List<PublicFolderEntity>>>(
      future: _folders,
      builder: (context, snapshot) {
        final List<PublicFolderEntity> folders = snapshot.data?.data ?? const <PublicFolderEntity>[];
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
    final double textHeight = scaler.scale(22) + scaler.scale(18);
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
        SizedBox(
          height: ProfileFoldersRow.cardWidth + PrismSpace.xs + textHeight + PrismSpace.xs,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
            itemCount: folders.length,
            separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.sm),
            itemBuilder: (context, index) {
              final PublicFolderEntity folder = folders[index];
              return SizedBox(
                width: ProfileFoldersRow.cardWidth,
                child: FolderCard(
                  key: ValueKey<String>(folder.id),
                  name: folder.name,
                  covers: folder.covers,
                  itemCount: folder.itemCount,
                  coverSize: ProfileFoldersRow.cardWidth,
                  markPublic: widget.ownProfile,
                  onTap: () => unawaited(_open(folder)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
