import 'dart:async';
import 'dart:math' as math;

import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_edit.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/views/folder_sections.dart';
import 'package:Prism/features/folders/views/widgets/folder_cover.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum _SectionAction { rename, saveAll, delete }

/// A folder's walls. With no sections it is one grid. With sections it is Unsorted, then each section under a header
/// with its count and a collapse button, and a strip at the top that jumps to a section.
///
/// When [canOrganize] is true, a wall can be dragged onto a header or a strip chip, and [selecting] turns taps into
/// a selection with a "Move to section" bar. [folder] is needed only to organize. A public folder passes
/// [tileBuilder] and its own [top] header and is read-only.
class FolderSectionsView extends StatefulWidget {
  const FolderSectionsView({
    super.key,
    required this.sections,
    required this.walls,
    required this.sectionOf,
    this.folder,
    this.canOrganize = false,
    this.heroTag,
    this.onOpen,
    this.tileBuilder,
    this.gridDelegate,
    this.top,
    this.onMenu,
    this.onSaveSection,
    this.selecting = false,
    this.onSelectingDone,
  });

  final List<FolderSection> sections;
  final FolderEntity? folder;

  /// Newest first.
  final List<FavouriteWallEntity> walls;

  /// Item key to section id.
  final Map<String, String> sectionOf;
  final bool canOrganize;
  final String Function(FavouriteWallEntity wall)? heroTag;

  /// Opens the wall at [index] of [order], the walls in the order they show.
  final void Function(BuildContext grid, List<FavouriteWallEntity> order, int index)? onOpen;

  /// Builds a read-only tile in place of the default one.
  final Widget Function(BuildContext grid, List<FavouriteWallEntity> order, int index)? tileBuilder;

  /// The grid of each group. Defaults to [PrismWallGrid.delegate].
  final SliverGridDelegate Function(BuildContext context)? gridDelegate;

  /// A widget above the strip, for example the public folder header.
  final Widget? top;
  final void Function(FavouriteWallEntity wall)? onMenu;
  final void Function(FolderSection section, List<FavouriteWallEntity> walls)? onSaveSection;
  final bool selecting;
  final VoidCallback? onSelectingDone;

  @override
  State<FolderSectionsView> createState() => _FolderSectionsViewState();
}

class _FolderSectionsViewState extends State<FolderSectionsView> {
  final ScrollController _scroll = ScrollController();
  final Set<String> _collapsed = <String>{};
  final Set<String> _selected = <String>{};
  final Map<String, GlobalKey> _headerKeys = <String, GlobalKey>{};
  bool _dragging = false;

  @override
  void didUpdateWidget(FolderSectionsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.selecting && _selected.isNotEmpty) _selected.clear();
    final Set<String> keys = widget.walls.map(folderItemKey).toSet();
    _selected.removeWhere((key) => !keys.contains(key));
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _hasSections => widget.sections.isNotEmpty;

  bool get _organize => widget.canOrganize && widget.folder != null;

  double _stripHeight(BuildContext context) => math.max(60, MediaQuery.textScalerOf(context).scale(15) * 1.3 + 36);

  GlobalKey _headerKey(String key) => _headerKeys.putIfAbsent(key, GlobalKey.new);

  /// Scrolls so the header of [groupKey] sits just under the strip.
  void _jumpTo(String groupKey, double stripHeight) {
    PrismHaptics.selection();
    if (_collapsed.contains(groupKey)) setState(() => _collapsed.remove(groupKey));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final RenderObject? box = _headerKeys[groupKey]?.currentContext?.findRenderObject();
      if (box == null || !_scroll.hasClients) return;
      final RenderAbstractViewport viewport = RenderAbstractViewport.of(box);
      final double target = (viewport.getOffsetToReveal(box, 0).offset - stripHeight).clamp(
        _scroll.position.minScrollExtent,
        _scroll.position.maxScrollExtent,
      );
      final Duration duration = context.motion(PrismDurations.slow);
      duration == Duration.zero
          ? _scroll.jumpTo(target)
          : unawaited(_scroll.animateTo(target, duration: duration, curve: PrismCurves.move));
    });
  }

  void _toggleCollapsed(String key) {
    PrismHaptics.selection();
    setState(() => _collapsed.contains(key) ? _collapsed.remove(key) : _collapsed.add(key));
  }

  void _toggleSelected(String key) {
    PrismHaptics.selection();
    setState(() => _selected.contains(key) ? _selected.remove(key) : _selected.add(key));
  }

  Future<void> _drop(List<String> itemKeys, String? sectionId) async {
    setState(() => _dragging = false);
    final FolderEntity? folder = widget.folder;
    if (folder != null) await moveFolderWalls(context, folder, itemKeys, sectionId, method: WallMoveMethod.drag);
  }

  Future<void> _moveSelected() async {
    final List<String> keys = _selected.toList();
    final Set<String?> current = <String?>{for (final String key in keys) _sectionOfKey(key)};
    final FolderEntity? folder = widget.folder;
    if (folder == null) return;
    await showMoveToSectionSheet(
      context,
      folder: folder,
      itemKeys: keys,
      current: current.length == 1 ? current.single : null,
      mixed: current.length > 1,
    );
    if (mounted) widget.onSelectingDone?.call();
  }

  String? _sectionOfKey(String key) {
    final String? id = widget.sectionOf[key];
    return widget.sections.any((section) => section.id == id) ? id : null;
  }

  @override
  Widget build(BuildContext context) {
    final List<FolderGroup> groups = _hasSections
        ? folderGroups(widget.sections, widget.walls, widget.sectionOf, keepEmptyUnsorted: _dragging)
        : <FolderGroup>[FolderGroup(section: null, walls: widget.walls)];
    final List<FavouriteWallEntity> order = <FavouriteWallEntity>[for (final group in groups) ...group.walls];
    final double stripHeight = _stripHeight(context);
    final double bottom = MediaQuery.paddingOf(context).bottom + PrismSpace.md;
    int start = 0;
    final List<Widget> slivers = <Widget>[
      if (widget.top case final Widget top) SliverToBoxAdapter(child: top),
      if (_hasSections)
        SliverPersistentHeader(
          pinned: true,
          delegate: _StripDelegate(
            height: stripHeight,
            child: _SectionStrip(
              groups: groups,
              canDrop: _organize && !widget.selecting,
              onJump: (key) => _jumpTo(key, stripHeight),
              onDrop: _drop,
            ),
          ),
        ),
    ];
    for (final FolderGroup group in groups) {
      final int offset = start;
      start += group.walls.length;
      final bool collapsed = _collapsed.contains(group.key);
      if (_hasSections) {
        slivers.add(
          SliverToBoxAdapter(
            child: _SectionHeader(
              key: _headerKey(group.key),
              group: group,
              collapsed: collapsed,
              canOrganize: _organize,
              canDrop: _organize && !widget.selecting,
              onToggle: () => _toggleCollapsed(group.key),
              onDrop: (keys) => _drop(keys, group.section?.id),
              onAction: (action) => _onSectionAction(action, group),
            ),
          ),
        );
      }
      if (collapsed) continue;
      if (group.walls.isEmpty) {
        if (group.section != null) {
          slivers.add(SliverToBoxAdapter(child: _EmptySection(canOrganize: _organize)));
        }
        continue;
      }
      slivers.add(
        SliverPadding(
          padding: PrismWallGrid.padding.copyWith(bottom: _hasSections ? PrismSpace.md : 0),
          sliver: SliverGrid(
            gridDelegate: widget.gridDelegate?.call(context) ?? PrismWallGrid.delegate(context),
            delegate: SliverChildBuilderDelegate(
              (grid, index) => _tile(grid, group.walls[index], order, offset + index),
              childCount: group.walls.length,
            ),
          ),
        ),
      );
    }
    slivers.add(SliverToBoxAdapter(child: SizedBox(height: bottom)));
    final Widget scroll = CustomScrollView(controller: _scroll, slivers: slivers);
    if (!widget.selecting) return scroll;
    return Column(
      children: <Widget>[
        Expanded(child: scroll),
        _SelectionBar(
          count: _selected.length,
          onMove: _selected.isEmpty ? null : () => unawaited(_moveSelected()),
          onDone: () => widget.onSelectingDone?.call(),
        ),
      ],
    );
  }

  Future<void> _onSectionAction(_SectionAction action, FolderGroup group) async {
    final FolderSection? section = group.section;
    final FolderEntity? folder = widget.folder;
    if (section == null || folder == null) return;
    switch (action) {
      case _SectionAction.rename:
        await renameFolderSection(context, folder, section);
      case _SectionAction.saveAll:
        widget.onSaveSection?.call(section, group.walls);
      case _SectionAction.delete:
        await deleteFolderSection(context, folder, section, group.walls.length);
    }
  }

  Widget _tile(BuildContext grid, FavouriteWallEntity wall, List<FavouriteWallEntity> order, int index) {
    if (widget.tileBuilder case final builder?) return builder(grid, order, index);
    final AppLocalizations l10n = context.l10n;
    final String key = folderItemKey(wall);
    final bool selected = _selected.contains(key);
    final Widget tile = PrismWallTile(
      key: ValueKey<String>(key),
      url: wall.thumbnailUrl,
      fallbackUrl: wall.source == WallpaperSource.prism ? null : wall.fullUrl,
      heroTag: widget.selecting ? null : widget.heroTag?.call(wall),
      semanticLabel: wallpaperSemanticLabel(wall.authorName, l10n),
      onTap: widget.selecting
          ? () => _toggleSelected(key)
          : wall is LegacyFavouriteWall || widget.onOpen == null
          ? null
          : () => widget.onOpen!(grid, order, index),
      onLongPress: widget.selecting || widget.onMenu == null ? null : () => widget.onMenu!(wall),
      overlay: widget.selecting ? _SelectMark(selected: selected) : null,
    );
    if (widget.selecting) return Semantics(selected: selected, child: tile);
    if (!_organize || !_hasSections) return tile;
    return _DraggableWall(
      itemKey: key,
      thumbnailUrl: wall.thumbnailUrl,
      onStarted: () => setState(() => _dragging = true),
      onEnded: () {
        if (mounted && _dragging) setState(() => _dragging = false);
      },
      onHeldWithoutMoving: widget.onMenu == null ? null : () => widget.onMenu!(wall),
      child: tile,
    );
  }
}

/// Long press and move to drag. Long press and let go without moving opens the wall's menu, as before.
class _DraggableWall extends StatefulWidget {
  const _DraggableWall({
    required this.itemKey,
    required this.thumbnailUrl,
    required this.onStarted,
    required this.onEnded,
    required this.onHeldWithoutMoving,
    required this.child,
  });

  final String itemKey;
  final String thumbnailUrl;
  final VoidCallback onStarted;
  final VoidCallback onEnded;
  final VoidCallback? onHeldWithoutMoving;
  final Widget child;

  @override
  State<_DraggableWall> createState() => _DraggableWallState();
}

class _DraggableWallState extends State<_DraggableWall> {
  double _moved = 0;

  void _end({required bool accepted}) {
    widget.onEnded();
    if (!accepted && _moved < kTouchSlop) widget.onHeldWithoutMoving?.call();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => LongPressDraggable<List<String>>(
        data: <String>[widget.itemKey],
        delay: const Duration(milliseconds: 350),
        onDragStarted: () {
          _moved = 0;
          PrismHaptics.impact();
          widget.onStarted();
        },
        onDragUpdate: (details) => _moved += details.delta.distance,
        onDragEnd: (details) => _end(accepted: details.wasAccepted),
        feedback: _DragFeedback(url: widget.thumbnailUrl, size: constraints.biggest),
        childWhenDragging: Opacity(opacity: 0.35, child: widget.child),
        child: widget.child,
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.url, required this.size});

  final String url;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 0.9,
      child: Material(
        color: Colors.transparent,
        elevation: 12,
        shadowColor: Colors.black54,
        borderRadius: PrismWallGrid.tileRadius,
        child: SizedBox.fromSize(
          size: size,
          child: PrismWallTile(url: url),
        ),
      ),
    );
  }
}

/// Wraps [child] so walls can be dropped on it. The surface tints with the accent while a wall hovers.
class _DropZone extends StatelessWidget {
  const _DropZone({required this.enabled, required this.onDrop, required this.child, this.radius = PrismRadius.sm});

  final bool enabled;
  final void Function(List<String> itemKeys) onDrop;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DragTarget<List<String>>(
      onWillAcceptWithDetails: (details) {
        PrismHaptics.selection();
        return true;
      },
      onAcceptWithDetails: (details) => onDrop(details.data),
      builder: (context, candidates, _) => AnimatedContainer(
        duration: context.motion(PrismDurations.fast),
        curve: PrismCurves.enter,
        decoration: BoxDecoration(
          color: candidates.isEmpty ? Colors.transparent : cs.primary.withValues(alpha: 0.14),
          border: Border.all(color: candidates.isEmpty ? Colors.transparent : cs.primary, width: 1.5),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      ),
    );
  }
}

class _StripDelegate extends SliverPersistentHeaderDelegate {
  _StripDelegate({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(color: Theme.of(context).scaffoldBackgroundColor, child: child);

  @override
  bool shouldRebuild(_StripDelegate oldDelegate) => oldDelegate.height != height || oldDelegate.child != child;
}

class _SectionStrip extends StatelessWidget {
  const _SectionStrip({required this.groups, required this.canDrop, required this.onJump, required this.onDrop});

  final List<FolderGroup> groups;
  final bool canDrop;
  final void Function(String key) onJump;
  final Future<void> Function(List<String> itemKeys, String? sectionId) onDrop;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page, vertical: PrismSpace.xs),
      itemCount: groups.length,
      separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.xs),
      itemBuilder: (context, index) {
        final FolderGroup group = groups[index];
        final String name = group.section?.name ?? l10n.foldersSectionUnsorted;
        final String? cover = group.cover?.thumbnailUrl;
        return _DropZone(
          enabled: canDrop,
          radius: PrismRadius.pill,
          onDrop: (keys) => unawaited(onDrop(keys, group.section?.id)),
          child: Semantics(
            button: true,
            label: l10n.foldersSectionJumpTo(name, group.walls.length),
            excludeSemantics: true,
            onTap: () => onJump(group.key),
            child: PressScale(
              child: Material(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onJump(group.key),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(PrismSpace.xxs, 0, PrismSpace.sm, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (cover != null)
                            FolderCover(covers: <String>[cover], size: 32, radius: PrismRadius.pill)
                          else
                            SizedBox.square(
                              dimension: 32,
                              child: Icon(Icons.inbox_rounded, size: 18, color: cs.onSurfaceVariant),
                            ),
                          const SizedBox(width: PrismSpace.xs),
                          Text(name, maxLines: 1, style: PrismTextStyles.rowTitle(context)),
                          const SizedBox(width: PrismSpace.xxs + 2),
                          Text('${group.walls.length}', maxLines: 1, style: PrismTextStyles.caption(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    super.key,
    required this.group,
    required this.collapsed,
    required this.canOrganize,
    required this.canDrop,
    required this.onToggle,
    required this.onDrop,
    required this.onAction,
  });

  final FolderGroup group;
  final bool collapsed;
  final bool canOrganize;
  final bool canDrop;
  final VoidCallback onToggle;
  final void Function(List<String> itemKeys) onDrop;
  final void Function(_SectionAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final FolderSection? section = group.section;
    final String name = section?.name ?? l10n.foldersSectionUnsorted;
    final String? cover = group.cover?.thumbnailUrl;
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.xs, PrismSpace.xs, PrismSpace.xs, PrismSpace.xs),
      child: _DropZone(
        enabled: canDrop,
        onDrop: onDrop,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  button: true,
                  expanded: !collapsed,
                  label: l10n.foldersSectionHeaderLabel(name, group.walls.length),
                  excludeSemantics: true,
                  onTap: onToggle,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(PrismRadius.sm),
                    onTap: onToggle,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.xs, vertical: PrismSpace.xxs),
                      child: Row(
                        children: <Widget>[
                          if (cover != null)
                            FolderCover(covers: <String>[cover], size: 40, radius: PrismRadius.xs)
                          else
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(PrismRadius.xs),
                              ),
                              child: Icon(
                                section == null ? Icons.inbox_rounded : Icons.folder_outlined,
                                size: 20,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(width: PrismSpace.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(name, softWrap: true, style: PrismTextStyles.cardTitle(context)),
                                Text(
                                  l10n.foldersSectionWallCount(group.walls.length),
                                  style: PrismTextStyles.caption(context),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: collapsed ? -0.25 : 0,
                            duration: context.motion(PrismDurations.fast),
                            curve: PrismCurves.move,
                            child: SizedBox.square(
                              dimension: 44,
                              child: Icon(Icons.expand_more_rounded, color: cs.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (canOrganize && section != null)
                PopupMenuButton<_SectionAction>(
                  tooltip: l10n.foldersSectionOptions(name),
                  icon: Icon(Icons.more_horiz_rounded, color: cs.onSurfaceVariant),
                  onSelected: onAction,
                  itemBuilder: (context) => <PopupMenuEntry<_SectionAction>>[
                    PopupMenuItem<_SectionAction>(value: _SectionAction.rename, child: Text(l10n.foldersRename)),
                    if (group.walls.isNotEmpty)
                      PopupMenuItem<_SectionAction>(
                        value: _SectionAction.saveAll,
                        child: Text(l10n.foldersSectionSaveAll),
                      ),
                    PopupMenuItem<_SectionAction>(
                      value: _SectionAction.delete,
                      child: Text(l10n.foldersSectionDelete, style: TextStyle(color: cs.error)),
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

class _EmptySection extends StatelessWidget {
  const _EmptySection({required this.canOrganize});

  final bool canOrganize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.md),
      child: Text(
        canOrganize ? context.l10n.foldersSectionEmptyHint : context.l10n.foldersSectionEmpty,
        style: PrismTextStyles.body(context),
      ),
    );
  }
}

class _SelectMark extends StatelessWidget {
  const _SelectMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Stack(
      children: <Widget>[
        if (selected) Positioned.fill(child: ColoredBox(color: cs.primary.withValues(alpha: 0.22))),
        PositionedDirectional(
          top: PrismSpace.xs,
          end: PrismSpace.xs,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? cs.primary : Colors.black38,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.check_rounded, size: 18, color: selected ? cs.onPrimary : Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionBar extends StatelessWidget {
  const _SelectionBar({required this.count, required this.onMove, required this.onDone});

  final int count;
  final VoidCallback? onMove;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(PrismSpace.xs, PrismSpace.xs, PrismSpace.md, PrismSpace.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Row(
                children: <Widget>[
                  PrismIconButton(icon: Icons.close_rounded, tooltip: l10n.coreCancel, onPressed: onDone),
                  const SizedBox(width: PrismSpace.xs),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(l10n.foldersSectionSelected(count), style: PrismTextStyles.rowTitle(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: PrismSpace.xs),
              PrismButton(label: l10n.foldersSectionMoveTo, expand: true, maxLines: null, onPressed: onMove),
            ],
          ),
        ),
      ),
    );
  }
}
