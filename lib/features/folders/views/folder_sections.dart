import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_edit.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Runs [edit] on the folder. Shows an error toast when it fails.
Future<bool> organizeFolder(BuildContext context, String folderId, FolderEdit edit) async {
  final AppLocalizations l10n = context.l10n;
  final bool ok = await context.read<FoldersBloc>().run(
    (id) => FoldersEvent.organizeRequested(folderId: folderId, edit: edit, operationId: id),
  );
  if (!ok) toasts.error(l10n.foldersUpdateFailed);
  return ok;
}

/// Asks for a name and adds a section at the end. Returns its id, or null when the user stops or it fails.
Future<String?> addFolderSection(BuildContext context, FolderEntity folder, {required String source}) async {
  final AppLocalizations l10n = context.l10n;
  if (folder.sections.length >= folderMaxSections) {
    toasts.error(l10n.foldersSectionsFull(folderMaxSections));
    return null;
  }
  final String? name = await _askSectionName(
    context,
    title: l10n.foldersSectionNewTitle,
    action: l10n.foldersSectionAdd,
  );
  if (name == null || !context.mounted) return null;
  final String id = newSectionId();
  if (!await organizeFolder(context, folder.id, SectionAdded(id: id, name: name))) return null;
  unawaited(analytics.track(FolderSectionCreatedEvent(source: source, sectionCount: folder.sections.length + 1)));
  return id;
}

Future<void> renameFolderSection(BuildContext context, FolderEntity folder, FolderSection section) async {
  final String? name = await _askSectionName(
    context,
    title: context.l10n.foldersSectionRenameTitle,
    action: context.l10n.foldersRename,
    initial: section.name,
  );
  if (name == null || name == section.name || !context.mounted) return;
  if (await organizeFolder(context, folder.id, SectionRenamed(id: section.id, name: name))) {
    unawaited(analytics.track(FolderSectionRenamedEvent(sectionCount: folder.sections.length)));
  }
}

Future<void> deleteFolderSection(
  BuildContext context,
  FolderEntity folder,
  FolderSection section,
  int wallCount,
) async {
  final AppLocalizations l10n = context.l10n;
  final bool confirmed = await showPrismConfirm(
    context,
    title: l10n.foldersSectionDeleteTitle(section.name),
    message: l10n.foldersSectionDeleteMessage(wallCount),
    confirmLabel: l10n.foldersSectionDelete,
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  if (await organizeFolder(context, folder.id, SectionDeleted(section.id))) {
    unawaited(analytics.track(FolderSectionDeletedEvent(wallCount: wallCount)));
  }
}

/// Moves [itemKeys] to [sectionId] (null is Unsorted) and confirms it in a toast.
Future<bool> moveFolderWalls(
  BuildContext context,
  FolderEntity folder,
  List<String> itemKeys,
  String? sectionId, {
  required WallMoveMethod method,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String name = folder.sections.where((s) => s.id == sectionId).firstOrNull?.name ?? l10n.foldersSectionUnsorted;
  final bool ok = await organizeFolder(
    context,
    folder.id,
    WallsMoved(itemKeys: itemKeys, sectionId: sectionId, method: method),
  );
  if (!ok) return false;
  PrismHaptics.success();
  unawaited(analytics.track(FolderWallMovedEvent(method: method.name, wallCount: itemKeys.length)));
  toasts.success(l10n.foldersSectionMoved(itemKeys.length, name));
  return true;
}

Future<String?> _askSectionName(
  BuildContext context, {
  required String title,
  required String action,
  String initial = '',
}) => showFolderNameSheet(
  context,
  title: title,
  actionLabel: action,
  initialName: initial,
  hint: context.l10n.foldersSectionNameHint,
  maxLength: folderSectionNameMaxLength,
  normalize: normalizeSectionName,
);

/// The accessible way to move walls: a list of Unsorted, every section and "New section". [current] is ticked.
Future<void> showMoveToSectionSheet(
  BuildContext context, {
  required FolderEntity folder,
  required List<String> itemKeys,
  required String? current,
  bool mixed = false,
}) async {
  PrismHaptics.tap();
  final AppLocalizations l10n = context.l10n;
  final _MoveChoice? choice = await showPrismSheet<_MoveChoice>(
    context,
    builder: (sheetContext) => PrismSheetBody(
      title: l10n.foldersSectionMoveTitle,
      childScrolls: true,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
        children: <Widget>[
          PrismGroup(
            children: <Widget>[
              _MoveRow(
                title: l10n.foldersSectionUnsorted,
                icon: Icons.inbox_rounded,
                checked: !mixed && current == null,
                onTap: () => Navigator.of(sheetContext).pop(const _MoveChoice(null)),
              ),
              for (final FolderSection section in folder.sections)
                _MoveRow(
                  title: section.name,
                  icon: Icons.folder_outlined,
                  checked: !mixed && current == section.id,
                  onTap: () => Navigator.of(sheetContext).pop(_MoveChoice(section.id)),
                ),
            ],
          ),
          if (folder.sections.length < folderMaxSections) ...<Widget>[
            const SizedBox(height: PrismSpace.sm),
            PrismGroup(
              children: <Widget>[
                PrismRow(
                  title: l10n.foldersSectionNewTitle,
                  icon: Icons.add_rounded,
                  onTap: () => Navigator.of(sheetContext).pop(const _MoveChoice.newSection()),
                ),
              ],
            ),
          ],
          const SizedBox(height: PrismSpace.md),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  String? target = choice.sectionId;
  if (choice.isNew) {
    target = await addFolderSection(context, folder, source: 'move_sheet');
    if (target == null || !context.mounted) return;
  }
  if (!mixed && target == current) return;
  await moveFolderWalls(context, folder, itemKeys, target, method: WallMoveMethod.menu);
}

class _MoveChoice {
  const _MoveChoice(this.sectionId) : isNew = false;
  const _MoveChoice.newSection() : sectionId = null, isNew = true;

  final String? sectionId;
  final bool isNew;
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.title, required this.icon, required this.checked, required this.onTap});

  final String title;
  final IconData icon;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Semantics(
        selected: checked,
        child: PrismRow(
          title: title,
          icon: icon,
          onTap: onTap,
          showChevron: false,
          trailing: checked ? Icon(Icons.check_rounded, color: cs.primary) : null,
        ),
      ),
    );
  }
}

/// Drag the handles to reorder. Screen readers get "Move up" and "Move down" actions from the list.
Future<void> showReorderSectionsSheet(BuildContext context, FolderEntity folder) async {
  PrismHaptics.tap();
  await showPrismSheet<void>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.large],
    builder: (sheetContext) => _ReorderSheet(folder: folder, host: context),
  );
}

class _ReorderSheet extends StatefulWidget {
  const _ReorderSheet({required this.folder, required this.host});

  final FolderEntity folder;
  final BuildContext host;

  @override
  State<_ReorderSheet> createState() => _ReorderSheetState();
}

class _ReorderSheetState extends State<_ReorderSheet> {
  late List<FolderSection> _sections = widget.folder.sections;

  void _onReorder(int oldIndex, int target) {
    if (target == oldIndex) return;
    PrismHaptics.selection();
    final FolderSection moved = _sections[oldIndex];
    setState(() => _sections = moveEntry(_sections, oldIndex, target));
    if (widget.host.mounted) {
      unawaited(organizeFolder(widget.host, widget.folder.id, SectionMoved(id: moved.id, toIndex: target)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<FavouriteWallEntity> walls =
        widget.host.read<FoldersBloc>().state.items[widget.folder.id] ?? const <FavouriteWallEntity>[];
    final Map<String, String> sectionOf =
        widget.host.read<FoldersBloc>().state.itemSections[widget.folder.id] ?? const <String, String>{};
    final Map<String, FolderGroup> groups = <String, FolderGroup>{
      for (final FolderGroup group in folderGroups(_sections, walls, sectionOf)) group.key: group,
    };
    return PrismSheetBody(
      title: l10n.foldersSectionReorder,
      childScrolls: true,
      actions: <Widget>[PrismButton(label: l10n.coreDone, expand: true, onPressed: () => Navigator.of(context).pop())],
      child: ReorderableListView.builder(
        buildDefaultDragHandles: false,
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
        itemCount: _sections.length,
        onReorderItem: _onReorder,
        itemBuilder: (context, index) {
          final FolderSection section = _sections[index];
          final FolderGroup? group = groups[section.id];
          final String? cover = group?.cover?.thumbnailUrl;
          return Padding(
            key: ValueKey<String>(section.id),
            padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
            child: PrismCard(
              child: Row(
                children: <Widget>[
                  FolderCover(covers: <String>[?cover], size: 40, radius: PrismRadius.xs),
                  const SizedBox(width: PrismSpace.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(section.name, style: PrismTextStyles.rowTitle(context), softWrap: true),
                        Text(
                          l10n.foldersSectionWallCount(group?.walls.length ?? 0),
                          style: PrismTextStyles.caption(context),
                        ),
                      ],
                    ),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Tooltip(
                      message: l10n.foldersSectionDragHandle(section.name),
                      child: SizedBox.square(
                        dimension: 44,
                        child: Icon(Icons.drag_handle_rounded, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
