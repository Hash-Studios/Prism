import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/personalization/taste_signals.dart';
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
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Opens the folder picker for [wall]. Guests see the sign-in prompt instead.
Future<void> showFolderSheet(BuildContext context, FavouriteWallEntity wall) async {
  PrismHaptics.tap();
  if (app_state.prismUser.id.isEmpty) {
    await showPrismSheet<void>(
      context,
      builder: (sheetContext) => PrismSheetBody(
        title: sheetContext.l10n.foldersAddToFolder,
        child: SignInPrompt(feature: sheetContext.l10n.foldersSignInFeature),
      ),
    );
    return;
  }
  await showPrismSheet<void>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    dismissKeyboardOnDrag: true,
    builder: (_) => FolderSheet(wall: wall),
  );
}

/// Asks for a folder name. Returns the trimmed name, or null when the user closes the sheet.
Future<String?> showFolderNameSheet(
  BuildContext context, {
  required String title,
  required String actionLabel,
  String initialName = '',
  String? hint,
  int maxLength = folderNameMaxLength,
  String? Function(String raw) normalize = normalizeFolderName,
}) {
  return showPrismSheet<String>(
    context,
    detents: const <PrismSheetDetent>[PrismSheetDetent.fit],
    dismissKeyboardOnDrag: true,
    builder: (_) => _FolderNameSheet(
      title: title,
      actionLabel: actionLabel,
      initialName: initialName,
      hint: hint,
      maxLength: maxLength,
      normalize: normalize,
    ),
  );
}

enum _FolderSheetPage { folders, create }

/// The Add to folder sheet. Page one ticks folders and commits them on Done in one save. Page two names a new folder
/// and creates it at once, then goes back to page one with that folder first and ticked.
class FolderSheet extends StatefulWidget {
  const FolderSheet({super.key, required this.wall});

  final FavouriteWallEntity wall;

  @override
  State<FolderSheet> createState() => _FolderSheetState();
}

class _FolderSheetState extends State<FolderSheet> {
  final TextEditingController _name = TextEditingController();
  final String _ownerId = app_state.prismUser.id;
  bool _closing = false;
  _FolderSheetPage _page = _FolderSheetPage.folders;

  /// The ticks the user changed, by folder id. A folder not here keeps the tick the wall's membership gives it.
  final Map<String, bool> _ticks = <String, bool>{};

  /// Folders made in this sheet, newest first. They show above the other folders.
  final List<String> _createdIds = <String>[];
  bool _creating = false;
  String? _createError;

  String get _key => folderItemKey(widget.wall);

  @override
  void initState() {
    super.initState();
    _name.addListener(_nameChanged);
    unawaited(_load());
  }

  Future<void> _load() async {
    final FoldersBloc bloc = context.read<FoldersBloc>();
    await ensureFoldersLoaded(context);
    if (mounted &&
        app_state.prismUser.id == _ownerId &&
        bloc.state.userId == _ownerId &&
        bloc.state.status == LoadStatus.success) {
      bloc.add(FoldersEvent.membershipRequested(wall: widget.wall));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _nameChanged() => setState(() => _createError = null);

  Set<String> _current(FoldersState state) => <String>{
    for (final String id in state.membership[_key] ?? const <String>{})
      if (_ticks[id] ?? true) id,
    for (final MapEntry<String, bool> tick in _ticks.entries)
      if (tick.value) tick.key,
  };

  bool _ready(FoldersState state) =>
      state.status == LoadStatus.success && state.membershipStatus[_key] == LoadStatus.success;

  void _toggle(FoldersState state, String folderId) {
    PrismHaptics.selection();
    setState(() => _ticks[folderId] = !_current(state).contains(folderId));
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).pop();
  }

  void _showPage(_FolderSheetPage page) {
    if (page == _FolderSheetPage.folders) FocusScope.of(context).unfocus();
    setState(() {
      _page = page;
      _createError = null;
    });
  }

  Future<void> _create() async {
    final String? name = normalizeFolderName(_name.text);
    if (name == null || _creating || _closing) return;
    final FoldersBloc bloc = context.read<FoldersBloc>();
    final AppLocalizations l10n = context.l10n;
    final Set<String> before = bloc.state.folders.map((folder) => folder.id).toSet();
    setState(() => _creating = true);
    final bool ok = await bloc.run((id) => FoldersEvent.createRequested(name: name, operationId: id));
    if (ok) unawaited(analytics.track(const FolderCreatedEvent(source: 'sheet', withWall: false)));
    if (!mounted || _closing || app_state.prismUser.id != _ownerId || bloc.state.userId != _ownerId) return;
    if (!ok) {
      PrismHaptics.error();
      setState(() {
        _creating = false;
        _createError = l10n.foldersCreateFailed;
      });
      return;
    }
    final String? createdId = bloc.state.folders
        .where((folder) => !before.contains(folder.id) && folder.name == name && folder.isOwnedBy(_ownerId))
        .firstOrNull
        ?.id;
    PrismHaptics.success();
    _name.clear();
    setState(() {
      _creating = false;
      if (createdId != null) {
        _createdIds.insert(0, createdId);
        _ticks[createdId] = true;
      }
    });
    _showPage(_FolderSheetPage.folders);
  }

  Future<void> _done(FoldersState state) async {
    if (_closing || app_state.prismUser.id != _ownerId || state.userId != _ownerId) return;
    final Set<String> initial = state.membership[_key] ?? const <String>{};
    final Set<String> selected = _current(state);
    final int added = selected.difference(initial).length;
    final bool changed = added > 0 || initial.difference(selected).isNotEmpty;
    final FoldersBloc bloc = context.read<FoldersBloc>();
    final FavouriteWallsAdapter favourites = context.favouriteWallsAdapter(listen: false);
    final AppLocalizations l10n = context.l10n;
    _close();
    if (!changed) return;
    final FavouriteWallEntity wall = widget.wall;
    // Favourite first, so a saved folder item always has its favourite.
    if (added > 0) {
      final bool favourited = await _favourite(favourites, wall);
      if (app_state.prismUser.id != _ownerId || bloc.state.userId != _ownerId) return;
      if (!favourited) {
        toasts.error(l10n.foldersSaveFailed);
        return;
      }
    }
    final bool ok = await bloc.run(
      (id) => FoldersEvent.saveRequested(wall: wall, folderIds: selected, operationId: id),
    );
    if (app_state.prismUser.id != _ownerId || bloc.state.userId != _ownerId) return;
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
      final TasteSignal? signal = _folderAddSignal(wall);
      if (signal != null && getIt.isRegistered<TasteSignalStore>()) {
        unawaited(getIt<TasteSignalStore>().record(signal));
      }
    }
    toasts.success(added > 0 ? l10n.foldersSavedToCount(added) : l10n.foldersUpdated);
  }

  /// Saving to a folder also favourites the wall. Removing it from a folder leaves the favourite alone.
  /// A later folder write failure keeps the favourite.
  Future<bool> _favourite(FavouriteWallsAdapter favourites, FavouriteWallEntity wall) async {
    if (app_state.prismUser.id != _ownerId) return false;
    if (getIt<FavoritesLocalDataSource>().isWallFavourite(_ownerId, wall.key)) return true;
    try {
      return await favourites.favCheck(wall, desired: true);
    } catch (error, stackTrace) {
      logger.w('Favourite before a folder save failed', error: error, stackTrace: stackTrace);
      return false;
    }
  }

  /// The folders the user can put a wall in: their own and the ones they edit. A smart folder fills itself from
  /// rules, so it is never a save target. Folders made in this sheet come first.
  List<FolderEntity> _targets(FoldersState state) {
    final List<FolderEntity> targets = state.folders
        .where((folder) => !folder.isSmart && folder.roleOf(_ownerId) != null)
        .toList();
    final List<FolderEntity> created = <FolderEntity>[
      for (final String id in _createdIds) ?targets.where((folder) => folder.id == id).firstOrNull,
    ];
    return <FolderEntity>[...created, ...targets.where((folder) => !_createdIds.contains(folder.id))];
  }

  List<Widget> _rows(BuildContext context, FoldersState state) {
    final AppLocalizations l10n = context.l10n;
    if (state.status == LoadStatus.failure || state.membershipStatus[_key] == LoadStatus.failure) {
      return <Widget>[
        PrismInlineState(
          icon: Icons.cloud_off_rounded,
          title: l10n.foldersSaveFailed,
          actionLabel: l10n.wallpaperTryAgain,
          onAction: () => unawaited(_load()),
        ),
      ];
    }
    if (!_ready(state)) return <Widget>[SizedBox(height: 3 * 64, child: PrismSkeleton.rows(rows: 3))];
    final Set<String> selected = _current(state);
    final List<FolderEntity> targets = _targets(state);
    return <Widget>[
      PrismRow(
        key: const ValueKey<String>('create-folder'),
        title: l10n.foldersCreateNewFolder,
        subtitle: l10n.foldersCreateNewFolderSubtitle,
        padding: _rowPadding,
        leading: const _CreateFolderTile(),
        onTap: () {
          PrismHaptics.tap();
          _showPage(_FolderSheetPage.create);
        },
      ),
      if (targets.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xl, vertical: PrismSpace.sm),
          child: Text(l10n.foldersPickerEmpty, style: PrismTextStyles.caption(context)),
        ),
      for (final FolderEntity folder in targets)
        FolderCheckRow(
          key: ValueKey<String>(folder.id),
          title: folder.name,
          covers: folder.covers,
          checked: selected.contains(folder.id),
          onTap: () => _toggle(state, folder.id),
        ),
    ];
  }

  Widget _foldersPage(BuildContext context, FoldersState state) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      key: const ValueKey<_FolderSheetPage>(_FolderSheetPage.folders),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FolderSheetHeader(title: l10n.foldersAddToFolder, onClose: _close),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.55),
            child: _FadeBottom(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(top: PrismSpace.xs, bottom: _FadeBottom.height),
                children: _rows(context, state),
              ),
            ),
          ),
        ),
        Padding(
          padding: PrismBottomSheet.actionsPadding,
          child: PrismButton(
            label: l10n.coreDone,
            expand: true,
            onPressed: _ready(state) ? () => unawaited(_done(state)) : null,
          ),
        ),
      ],
    );
  }

  Widget _createPage(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final bool hasName = normalizeFolderName(_name.text) != null;
    return Column(
      key: const ValueKey<_FolderSheetPage>(_FolderSheetPage.create),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _FolderSheetHeader(
          title: l10n.foldersNewFolder,
          subpage: true,
          onBack: _creating ? null : () => _showPage(_FolderSheetPage.folders),
          onClose: _close,
        ),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(PrismSpace.xl, PrismSpace.md, PrismSpace.xl, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(l10n.foldersNewFolderHelp, style: PrismTextStyles.body(context).copyWith(height: 1.4)),
                const SizedBox(height: PrismSpace.md),
                PrismTextField(
                  controller: _name,
                  hint: l10n.foldersNameHint,
                  autofocus: true,
                  enabled: !_creating,
                  error: _createError,
                  inputFormatters: <TextInputFormatter>[LengthLimitingTextInputFormatter(folderNameMaxLength)],
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => unawaited(_create()),
                  suffix: _name.text.isEmpty || _creating
                      ? null
                      : PrismIconButton(
                          icon: Icons.cancel_rounded,
                          tooltip: l10n.foldersClearName,
                          iconSize: 20,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          onPressed: _name.clear,
                        ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: PrismBottomSheet.actionsPadding.copyWith(top: PrismSpace.md),
          child: PrismButton(
            label: l10n.foldersCreateFolder,
            expand: true,
            loading: _creating,
            haptic: false,
            onPressed: hasName ? () => unawaited(_create()) : null,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Duration duration = context.motion(PrismDurations.base);
    return BlocConsumer<FoldersBloc, FoldersState>(
      listenWhen: (previous, current) => previous.userId != current.userId,
      listener: (context, state) {
        if (state.userId != _ownerId) _close();
      },
      builder: (context, state) => Material(
        type: MaterialType.transparency,
        child: AnimatedSize(
          duration: duration,
          curve: PrismCurves.sheet,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: duration,
            switchInCurve: PrismCurves.enter,
            switchOutCurve: PrismCurves.exit,
            layoutBuilder: (current, previous) =>
                Stack(alignment: Alignment.topCenter, children: <Widget>[...previous, ?current]),
            transitionBuilder: (child, animation) {
              final bool incoming = child.key == ValueKey<_FolderSheetPage>(_page);
              final bool forward = _page == _FolderSheetPage.create;
              final double dx = incoming == forward ? 0.25 : -0.25;
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: Offset(dx, 0), end: Offset.zero).animate(animation),
                  child: child,
                ),
              );
            },
            child: _page == _FolderSheetPage.folders ? _foldersPage(context, state) : _createPage(context),
          ),
        ),
      ),
    );
  }
}

const EdgeInsets _rowPadding = EdgeInsets.symmetric(horizontal: PrismSpace.xl, vertical: PrismSpace.xs);

/// The drag handle, the title row and a thin divider. Page one puts the title on the left; page two adds a back
/// button and centres the title.
class _FolderSheetHeader extends StatelessWidget {
  const _FolderSheetHeader({required this.title, required this.onClose, this.subpage = false, this.onBack});

  final String title;
  final VoidCallback onClose;
  final bool subpage;

  /// Null disables the back button, while the folder is being created.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    PrismIconButton button(IconData icon, String tooltip, VoidCallback? onPressed) => PrismIconButton(
      icon: icon,
      tooltip: tooltip,
      filled: true,
      size: PrismBottomSheet.closeButtonSize,
      iconSize: 20,
      onPressed: onPressed,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 6, bottom: 4),
            width: PrismBottomSheet.dragHandleWidth,
            height: PrismBottomSheet.dragHandleHeight,
            decoration: BoxDecoration(
              color: cs.onSurface.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(PrismBottomSheet.dragHandleRadius),
            ),
          ),
        ),
        Padding(
          padding: PrismBottomSheet.headerPadding,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: PrismBottomSheet.headerRowHeight),
            child: Row(
              children: <Widget>[
                if (subpage) ...<Widget>[
                  button(Icons.arrow_back_rounded, context.l10n.coreBack, onBack),
                  const SizedBox(width: PrismSpace.xs),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: subpage ? TextAlign.center : TextAlign.start,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.cardTitle(context),
                    ),
                  ),
                ),
                const SizedBox(width: PrismSpace.xs),
                button(Icons.close_rounded, context.l10n.actionClose, () {
                  PrismHaptics.tap();
                  onClose();
                }),
              ],
            ),
          ),
        ),
        Container(
          height: 1,
          margin: const EdgeInsets.symmetric(horizontal: PrismSpace.xl),
          color: cs.onSurface.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

/// Fades the last [height] of its child, so a list reads as scrolling under the button below it.
class _FadeBottom extends StatelessWidget {
  const _FadeBottom({required this.child});

  static const double height = 28;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const <Color>[Colors.black, Colors.black, Colors.transparent],
        stops: <double>[0, math.max(0, 1 - height / rect.height), 1],
      ).createShader(rect),
      child: child,
    );
  }
}

class _CreateFolderTile extends StatelessWidget {
  const _CreateFolderTile();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: cs.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(PrismRadius.xs),
      ),
      child: Icon(Icons.add_rounded, size: 22, color: cs.onSurface),
    );
  }
}

/// One folder in the picker: a small cover, the name and a check box. Screen readers get one checkable node.
class FolderCheckRow extends StatelessWidget {
  const FolderCheckRow({
    super.key,
    required this.title,
    required this.covers,
    required this.checked,
    required this.onTap,
  });

  final String title;
  final List<String> covers;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Semantics(
        checked: checked,
        child: PrismRow(
          title: title,
          padding: _rowPadding,
          leading: FolderCover(covers: covers, size: 40, radius: PrismRadius.xs),
          onTap: onTap,
          trailing: _CheckBox(checked: checked),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  const _CheckBox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Duration duration = context.motion(PrismDurations.fast);
    return AnimatedContainer(
      duration: duration,
      curve: PrismCurves.enter,
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: checked ? cs.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: checked ? cs.primary : cs.onSurface.withValues(alpha: 0.35), width: 1.5),
      ),
      child: AnimatedScale(
        duration: duration,
        curve: PrismCurves.pop,
        scale: checked ? 1 : 0.5,
        child: AnimatedOpacity(
          duration: duration,
          opacity: checked ? 1 : 0,
          child: Icon(Icons.check_rounded, size: 18, color: cs.onPrimary),
        ),
      ),
    );
  }
}

class _FolderNameSheet extends StatefulWidget {
  const _FolderNameSheet({
    required this.title,
    required this.actionLabel,
    required this.initialName,
    required this.hint,
    required this.maxLength,
    required this.normalize,
  });

  final String title;
  final String actionLabel;
  final String initialName;
  final String? hint;
  final int maxLength;
  final String? Function(String raw) normalize;

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
    final String? name = widget.normalize(_controller.text);
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
          onPressed: widget.normalize(_controller.text) == null ? null : _submit,
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
        child: PrismTextField(
          controller: _controller,
          hint: widget.hint ?? context.l10n.foldersNameHint,
          autofocus: true,
          maxLength: widget.maxLength,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
      ),
    );
  }
}

/// A folder add teaches the For you feed, like a favourite. Old favourites without a wall model teach nothing.
TasteSignal? _folderAddSignal(FavouriteWallEntity wall) => switch (wall) {
  PrismFavouriteWall(:final wallpaper) => TasteSignal.forWallpaper(
    TasteAction.folderAdd,
    wallpaper.core,
    tags: wallpaper.tags,
    collections: wallpaper.collections,
  ),
  WallhavenFavouriteWall(:final wallpaper) => TasteSignal.forWallpaper(
    TasteAction.folderAdd,
    wallpaper.core,
    tags: wallpaper.tags,
  ),
  PexelsFavouriteWall(:final wallpaper) => TasteSignal.forWallpaper(TasteAction.folderAdd, wallpaper.core),
  _ => null,
};
