import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/status.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/core/widgets/sign_in_prompt.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/folders/biz/bloc/folders_bloc.j.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/views/folders_access.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the folder picker for [wall]. Guests see the sign-in prompt instead.
Future<void> showFolderSheet(BuildContext context, FavouriteWallEntity wall) async {
  PrismHaptics.tap();
  if (app_state.prismUser.id.isEmpty) {
    await showPrismSheet<void>(
      context,
      builder: (sheetContext) => PrismSheetBody(
        title: sheetContext.l10n.foldersSaveToFolder,
        child: SignInPrompt(feature: sheetContext.l10n.foldersSignInFeature),
      ),
    );
    return;
  }
  await showPrismSheet<void>(context, dismissKeyboardOnDrag: true, builder: (_) => FolderSheet(wall: wall));
}

/// Asks for a folder name. Returns the trimmed name, or null when the user closes the sheet.
Future<String?> showFolderNameSheet(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initialName = '',
}) {
  return showPrismSheet<String>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    dismissKeyboardOnDrag: true,
    builder: (_) => _FolderNameSheet(title: title, actionLabel: actionLabel, initialName: initialName),
  );
}

class FolderSheet extends StatefulWidget {
  const FolderSheet({super.key, required this.wall});

  final FavouriteWallEntity wall;

  @override
  State<FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<FolderSheet> {
  final TextEditingController _name = TextEditingController();

  /// Null until the user changes a tick; until then the ticks show the wall's folders.
  Set<String>? _selected;
  final List<String> _newNames = <String>[];

  String get _key => folderItemKey(widget.wall);

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final FoldersBloc bloc = context.read<FoldersBloc>();
    await ensureFoldersLoaded(context);
    if (mounted) bloc.add(FoldersEvent.membershipRequested(wall: widget.wall));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Set<String> _current(FoldersState state) => _selected ?? state.membership[_key] ?? const <String>{};

  void _toggle(FoldersState state, String folderId) {
    PrismHaptics.selection();
    setState(() {
      final Set<String> next = _current(state).toSet();
      if (!next.remove(folderId)) next.add(folderId);
      _selected = next;
    });
  }

  void _addName([String? raw]) {
    final String? name = normalizeFolderName(raw ?? _name.text);
    if (name == null || _newNames.contains(name)) return;
    PrismHaptics.selection();
    setState(() => _newNames.add(name));
    _name.clear();
  }

  Future<void> _done(FoldersState state) async {
    _addName();
    final Set<String> initial = state.membership[_key] ?? const <String>{};
    final Set<String> selected = _current(state);
    final List<String> newNames = List<String>.of(_newNames);
    final int added = selected.difference(initial).length + newNames.length;
    final bool changed = added > 0 || initial.difference(selected).isNotEmpty;
    final FoldersBloc bloc = context.read<FoldersBloc>();
    final FavouriteWallsAdapter favourites = context.favouriteWallsAdapter(listen: false);
    final AppLocalizations l10n = context.l10n;
    Navigator.of(context).pop();
    if (!changed) return;
    final FavouriteWallEntity wall = widget.wall;
    final bool ok = await bloc.run(
      (id) => FoldersEvent.saveRequested(wall: wall, folderIds: selected, newNames: newNames, operationId: id),
    );
    if (!ok) {
      toasts.error(l10n.foldersSaveFailed);
      return;
    }
    if (added > 0) {
      unawaited(
        analytics.track(
          WallSavedToFolderEvent(wallId: wall.id, provider: wall.source.legacyProviderString, folderCount: added),
        ),
      );
      for (int i = 0; i < newNames.length; i++) {
        unawaited(analytics.track(const FolderCreatedEvent(source: 'sheet', withWall: true)));
      }
      await _favourite(favourites, wall);
    }
    toasts.success(added > 0 ? l10n.foldersSavedToCount(added) : l10n.foldersUpdated);
  }

  /// Saving to a folder also favourites the wall. Removing it from a folder leaves the favourite alone.
  Future<void> _favourite(FavouriteWallsAdapter favourites, FavouriteWallEntity wall) async {
    if (getIt<FavoritesLocalDataSource>().isWallFavourite(app_state.prismUser.id, wall.id)) return;
    try {
      await favourites.favCheck(wall, desired: true);
    } catch (error, stackTrace) {
      logger.w('Favourite after a folder save failed', error: error, stackTrace: stackTrace);
    }
  }

  Widget _body(BuildContext context, FoldersState state) {
    final AppLocalizations l10n = context.l10n;
    final LoadStatus? membership = state.membershipStatus[_key];
    if (state.status == LoadStatus.failure || membership == LoadStatus.failure) {
      return GlintState(
        kind: GlintStateKind.error,
        title: l10n.foldersSaveFailed,
        actionLabel: l10n.wallpaperTryAgain,
        onAction: () => unawaited(_load()),
      );
    }
    // Three 64 px rows: the sheet body scrolls, so the skeleton list needs a bounded height.
    if (membership != LoadStatus.success) return SizedBox(height: 3 * 64, child: PrismSkeleton.rows(rows: 3));
    final Set<String> selected = _current(state);
    final bool suggest = state.folders.isEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
          child: PrismTextField(
            controller: _name,
            hint: l10n.foldersNewFolder,
            prefixIcon: Icons.create_new_folder_outlined,
            maxLength: folderNameMaxLength,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            onSubmitted: _addName,
            suffix: PrismIconButton(icon: Icons.add_rounded, tooltip: l10n.foldersCreateFolder, onPressed: _addName),
          ),
        ),
        for (final String name in _newNames)
          FolderCheckRow(
            key: ValueKey<String>('new:$name'),
            title: name,
            covers: <String>[widget.wall.thumbnailUrl],
            tag: l10n.foldersNewTag,
            checked: true,
            onTap: () => setState(() => _newNames.remove(name)),
          ),
        if (suggest)
          for (final String name in suggestedFolderNames(widget.wall, l10n).where((name) => !_newNames.contains(name)))
            FolderCheckRow(
              key: ValueKey<String>('suggested:$name'),
              title: name,
              covers: const <String>[],
              tag: l10n.foldersSuggested,
              checked: false,
              onTap: () => _addName(name),
            ),
        for (final FolderEntity folder in state.folders)
          FolderCheckRow(
            key: ValueKey<String>(folder.id),
            title: folder.name,
            subtitle: l10n.foldersItemCount(folder.itemCount),
            covers: folder.covers,
            checked: selected.contains(folder.id),
            onTap: () => _toggle(state, folder.id),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FoldersBloc, FoldersState>(
      builder: (context, state) => PrismSheetBody(
        title: context.l10n.foldersSaveToFolder,
        actions: <Widget>[
          PrismButton(
            label: context.l10n.coreDone,
            expand: true,
            onPressed: state.membershipStatus[_key] == LoadStatus.success ? () => unawaited(_done(state)) : null,
          ),
        ],
        child: _body(context, state),
      ),
    );
  }
}

/// One folder in the picker: a small cover, the name, an optional tag and a tick.
class FolderCheckRow extends StatelessWidget {
  const FolderCheckRow({
    super.key,
    required this.title,
    required this.covers,
    required this.checked,
    required this.onTap,
    this.subtitle,
    this.tag,
  });

  final String title;
  final String? subtitle;
  final List<String> covers;
  final String? tag;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return MergeSemantics(
      child: Semantics(
        checked: checked,
        child: PrismRow(
          title: title,
          subtitle: subtitle,
          leading: FolderCover(covers: covers, size: 40, radius: PrismRadius.xs),
          onTap: onTap,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (tag != null) ...<Widget>[
                PrismTag(label: tag!, tone: checked ? PrismTone.accent : PrismTone.neutral),
                const SizedBox(width: PrismSpace.xs),
              ],
              AnimatedSwitcher(
                duration: context.motion(PrismDurations.fast),
                switchInCurve: PrismCurves.pop,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween<double>(begin: 0.95, end: 1).animate(animation), child: child),
                ),
                child: Icon(
                  checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  key: ValueKey<bool>(checked),
                  color: checked ? cs.primary : cs.onSurface.withValues(alpha: 0.35),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderNameSheet extends StatefulWidget {
  const _FolderNameSheet({required this.title, required this.actionLabel, required this.initialName});

  final String title;
  final String actionLabel;
  final String initialName;

  @override
  State<_FolderNameSheet> createState() => _FolderNameSheetState();
}

class _FolderNameSheetState extends State<_FolderNameSheet> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialName)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String? name = normalizeFolderName(_controller.text);
    if (name != null) Navigator.of(context).pop(name);
  }

  @override
  Widget build(BuildContext context) {
    return PrismSheetBody(
      title: widget.title,
      actions: <Widget>[
        PrismButton(
          label: widget.actionLabel,
          expand: true,
          onPressed: normalizeFolderName(_controller.text) == null ? null : _submit,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
        child: PrismTextField(
          controller: _controller,
          hint: context.l10n.foldersNameHint,
          autofocus: true,
          maxLength: folderNameMaxLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ),
    );
  }
}
