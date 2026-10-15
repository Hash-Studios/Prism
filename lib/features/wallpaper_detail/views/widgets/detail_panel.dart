import 'dart:async';
import 'dart:io';
import 'dart:math' show max;

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/theme_utils.dart';
import 'package:Prism/core/utils/url_utils.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/prepare_source.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/biz/block_wall_creator.dart';
import 'package:Prism/features/wallpaper_detail/biz/wallpaper_detail_rules.dart';
import 'package:Prism/features/wallpaper_detail/data/downloaded_wall_index.dart';
import 'package:Prism/features/wallpaper_detail/data/wallpaper_tint_renderer.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_facts.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_palette.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/make_it_live_button.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/similar_wallpapers_strip.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/wallpaper_tag_chips.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The docked sheet at the bottom of the wallpaper detail screen. Collapsed it is one row: the name, the main action
/// and Favourite. Expanded it adds the palette, the facts and the secondary actions.
class DetailPanel extends StatelessWidget {
  const DetailPanel({
    super.key,
    required this.state,
    required this.sourceContext,
    required this.contentVisible,
    required this.onToggle,
    required this.onScrollStart,
    required this.onScrollEnd,
    required this.onResetColor,
    required this.onSelectColor,
    required this.onCopyColor,
    required this.onDownloaded,
    required this.onSet,
    required this.onFavourited,
    this.localFile,
    this.onMatchAccent,
    this.onTagTap,
    this.onMakeItLive,
    this.similarLoader,
    this.onOpenSimilar,
  });

  final WallpaperDetailLoaded state;
  final String sourceContext;

  /// True while the panel is open enough to show its expanded content.
  final ValueListenable<bool> contentVisible;
  final VoidCallback onToggle;
  final VoidCallback onScrollStart;
  final VoidCallback onScrollEnd;
  final VoidCallback onResetColor;
  final ValueChanged<Color> onSelectColor;
  final ValueChanged<Color> onCopyColor;
  final VoidCallback onDownloaded;
  final VoidCallback onSet;
  final VoidCallback onFavourited;

  /// Set when the wallpaper was opened from Downloads. Set, Download and Edit use this file, not the link.
  final File? localFile;

  /// "Match accent" on the success snackbar of Set. Null hides it.
  final VoidCallback? onMatchAccent;

  /// Opens a search for a tag. Null hides the tag chips.
  final ValueChanged<String>? onTagTap;

  /// Opens Make it live. Null hides the button.
  final VoidCallback? onMakeItLive;

  /// Loads wallpapers like this one. Null hides the "More like this" strip.
  final Future<List<FeedItemEntity>> Function(FeedItemEntity entity)? similarLoader;
  final ValueChanged<FeedItemEntity>? onOpenSimilar;

  static const double _handleZone = 44;
  static const double _rowHeight = CircularMenuButton.size;

  static double _scaledRowHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(_rowHeight).clamp(_rowHeight, double.infinity);

  /// Height of the collapsed panel, including the bottom safe area.
  static double collapsedHeight(BuildContext context) =>
      _handleZone + _scaledRowHeight(context) + PrismSpace.sm + bottomPadding(context);

  static double bottomPadding(BuildContext context) => max(MediaQuery.paddingOf(context).bottom, PrismSpace.md);

  /// The solid, rounded surface shared by the detail panel and the downloaded wallpaper bar.
  static ShapeDecoration surfaceDecoration(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return ShapeDecoration(
      color: cs.surfaceContainerLow.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(PrismRadius.xl)),
        side: BorderSide(color: cs.onSurface.withValues(alpha: 0.08)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: surfaceDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _handle(context),
          _collapsedRow(context),
          const SizedBox(height: PrismSpace.sm),
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: contentVisible,
              builder: (context, visible, child) => AnimatedOpacity(
                duration: context.motion(PrismDurations.fast),
                curve: PrismCurves.enter,
                opacity: visible ? 1 : 0,
                // The hidden content stops its tickers, so a skeleton in it does not animate while nobody sees it.
                child: ExcludeSemantics(
                  excluding: !visible,
                  child: TickerMode(enabled: visible, child: child!),
                ),
              ),
              child: _expandedContent(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _handle(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: state.panelCollapsed ? 'Expand wallpaper details' : 'Collapse wallpaper details',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: SizedBox(
          height: _handleZone,
          child: Center(
            child: Container(
              width: PrismBottomSheet.dragHandleWidth,
              height: PrismBottomSheet.dragHandleHeight,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(PrismRadius.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _collapsedRow(BuildContext context) {
    final FeedItemEntity entity = state.entity;
    final String? author = detailAuthor(entity);
    final _ActionSource source = _actionSource(context);
    final Widget main = hideSetWallpaperUi
        ? _downloadButton(source, primary: true)
        : SetWallpaperButton(
            url: source.path,
            prepareSource: source.prepare,
            thumbnailUrl: entity.thumbnailUrl,
            primary: true,
            promptNotificationPermissionOnSuccess: true,
            entryPoint: 'wallpaper_detail',
            notes: _notes(context),
            onMatchAccent: onMatchAccent,
            onSet: onSet,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
      child: SizedBox(
        height: _scaledRowHeight(context),
        child: Row(
          children: <Widget>[
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      detailTitle(entity),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.cardTitle(context),
                    ),
                    Text(
                      author == null ? _sourceName(entity) : 'by $author',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PrismTextStyles.caption(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: PrismSpace.sm),
            Flexible(child: main),
            const SizedBox(width: PrismSpace.xs),
            FavouriteWallpaperButton(
              wall: FavouriteWallEntity.fromFeedItem(entity),
              trash: false,
              onFavourited: onFavourited,
            ),
          ],
        ),
      ),
    );
  }

  Size _screenPixels(BuildContext context) => MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);

  List<String> _notes(BuildContext context) =>
      wallpaperResolutionNotes(state.entity.wallpaperCore, _screenPixels(context));

  /// What Set, Download and Edit work on: the local file or the link, rendered in the colour variation in use.
  _ActionSource _actionSource(BuildContext context) {
    final FeedItemEntity entity = state.entity;
    final File? local = localFile;
    final String path = local?.path ?? entity.fullUrl;
    final Color? tint = state.tint;
    if (tint != null) {
      final double deviceLongSidePx = _screenPixels(context).longestSide;
      Future<String> prepare() => renderTintedWallpaper(source: path, tint: tint, deviceLongSidePx: deviceLongSidePx);
      return _ActionSource(path, prepare, DownloadVariant(key: _tintKey(tint), prepare: prepare), prepare);
    }
    if (local == null) return _ActionSource(path, null, null, null);
    final String? savedKey = _savedTintKeyOf(local.path);
    return _ActionSource(
      path,
      null,
      savedKey == null ? null : DownloadVariant(key: savedKey, prepare: () async => local.path),
      () async => local.path,
    );
  }

  Widget _downloadButton(_ActionSource source, {bool primary = false, bool labelled = false}) {
    final FeedItemEntity entity = state.entity;
    return DownloadButton(
      link: entity.fullUrl,
      variant: source.variant,
      isPremiumContent: isPremiumFeedItem(entity, app_state.premiumCollections),
      contentId: entity.id,
      // The main action on iOS reads "Save" and shows its price, or "Saved" for a wallpaper already in Downloads.
      label: primary ? 'Save' : null,
      primary: primary,
      labelled: labelled,
      sourceContext: sourceContext,
      onDownloaded: () {
        onDownloaded();
        if (getIt.isRegistered<DownloadedWallIndex>()) {
          unawaited(
            getIt<DownloadedWallIndex>().remember(
              link: source.variant?.identityOf(entity.fullUrl) ?? entity.fullUrl,
              id: entity.id,
              source: entity.source,
            ),
          );
        }
      },
    );
  }

  String? _shareContextLine(FeedItemEntity entity) {
    final String? name = entity.wallpaperCore.authorName?.trim();
    return name == null || name.isEmpty || name.contains('@') ? null : 'by $name';
  }

  String _sourceName(FeedItemEntity entity) =>
      entity.when(prism: (_, _) => 'Prism', wallhaven: (_, _) => 'Wallhaven', pexels: (_, _) => 'Pexels');

  Widget _expandedContent(BuildContext context) {
    final FeedItemEntity entity = state.entity;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollStartNotification) {
          onScrollStart();
        } else if (notification is ScrollEndNotification) {
          onScrollEnd();
        }
        return false;
      },
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, bottomPadding(context)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _palette(context),
            const SizedBox(height: PrismSpace.xl),
            DetailFactsGrid(facts: detailFacts(context, entity, state)),
            ..._extras(context),
            const SizedBox(height: PrismSpace.xl),
            _actions(context),
            ..._blockCreator(context),
          ],
        ),
      ),
    );
  }

  Widget _palette(BuildContext context) {
    final List<Color>? colors = state.colors;
    if (colors == null) {
      return PrismSkeleton(
        child: Row(
          children: <Widget>[
            for (int i = 0; i < 5; i++) ...<Widget>[
              const Padding(padding: EdgeInsets.all(6), child: PrismBone.circle(size: 32)),
            ],
          ],
        ),
      );
    }
    return DetailPalette(
      thumbnailUrl: state.entity.thumbnailUrl.trim(),
      localFile: localFile,
      colors: colors,
      selected: state.colorChanged ? state.accent : null,
      onReset: onResetColor,
      onSelect: onSelectColor,
      onCopy: onCopyColor,
    );
  }

  /// Resolution warnings, tags, Make it live and similar wallpapers. Each shows only when it has something to say.
  List<Widget> _extras(BuildContext context) {
    final FeedItemEntity entity = state.entity;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final List<String> tags = wallpaperTags(entity);
    final List<Widget> sections = <Widget>[
      for (final String note in _notes(context))
        Row(
          children: <Widget>[
            Icon(JamIcons.alert, size: 18, color: cs.error),
            const SizedBox(width: PrismSpace.xs),
            Expanded(child: Text(note, style: PrismTextStyles.body(context))),
          ],
        ),
      if (tags.isNotEmpty && onTagTap != null) WallpaperTagChips(tags: tags, onTagTap: onTagTap!),
      if (!hideSetWallpaperUi && entity.fullUrl.trim().isNotEmpty && onMakeItLive != null)
        Align(
          alignment: Alignment.centerLeft,
          child: MakeItLiveButton(onPressed: onMakeItLive!),
        ),
      if (similarLoader != null)
        SimilarWallpapersStrip(entity: entity, loader: similarLoader!, onOpen: onOpenSimilar ?? (_) {}),
    ];
    return <Widget>[
      for (final Widget section in sections) ...<Widget>[const SizedBox(height: PrismSpace.xl), section],
    ];
  }

  /// The quiet "Block creator" row, offered next to Report on someone else's wall.
  List<Widget> _blockCreator(BuildContext context) {
    final FeedItemEntity entity = state.entity;
    if (!canBlockWallCreator(entity)) return const <Widget>[];
    return <Widget>[
      const SizedBox(height: PrismSpace.sm),
      Align(
        alignment: Alignment.centerLeft,
        child: PrismButton(
          label: 'Block creator',
          icon: JamIcons.user_remove,
          variant: PrismButtonVariant.ghost,
          size: PrismButtonSize.compact,
          onPressed: () => unawaited(blockWallCreator(context, entity)),
        ),
      ),
    ];
  }

  Widget _actions(BuildContext context) {
    final FeedItemEntity entity = state.entity;
    final _ActionSource source = _actionSource(context);
    final bool canBlock = canBlockWallCreator(entity);
    final String previewTitle = wallpaperPreviewTitle(entity);
    final String? reportDocId = switch (entity) {
      PrismFeedItem(:final wallpaper) => wallpaper.firestoreDocumentId,
      _ => null,
    };
    final List<Widget> actions = <Widget>[
      if (!hideSetWallpaperUi) _downloadButton(source, labelled: true),
      ShareButton(
        id: entity.id,
        source: entity.source,
        url: entity.fullUrl,
        thumbUrl: entity.thumbnailUrl,
        contextLine: _shareContextLine(entity),
        createLink: (id, source, url, thumbUrl) => createDynamicLink(id, source, url, thumbUrl, title: previewTitle),
        labelled: true,
      ),
      EditButton(url: entity.fullUrl, prepareSource: source.editPrepare, labelled: true),
      if (reportDocId != null && reportDocId.isNotEmpty)
        CircularMenuButton(
          label: 'Report',
          caption: 'Report',
          isLoading: false,
          onTap: () => showContentReportSheet(
            context,
            contentType: 'wall',
            targetFirestoreDocId: reportDocId,
            subtitle: entity.id,
            onBlockCreator: canBlock ? () => unawaited(blockWallCreator(context, entity)) : null,
          ),
          child: const Icon(JamIcons.flag),
        ),
    ];
    return Row(
      children: <Widget>[for (final Widget action in actions) Expanded(child: Center(child: action))],
    );
  }
}

/// What Set, Download and Edit work on. [prepare] renders the colour variation in use and is null for the original.
/// [editPrepare] is what the editor opens: the variation, else the local file, else null for the wallpaper link.
class _ActionSource {
  const _ActionSource(this.path, this.prepare, this.variant, this.editPrepare);

  final String path;
  final Future<String> Function()? prepare;
  final DownloadVariant? variant;
  final Future<String> Function()? editPrepare;
}

String _tintKey(Color tint) => 'tint-${tint.rgbHex}';

final RegExp _savedTintKey = RegExp(r'_(tint-[0-9a-f]{6})(?: \(\d+\))?$');

/// The colour key in the name of a tinted wallpaper saved from this screen, so a reopened file is that variation.
String? _savedTintKeyOf(String path) => _savedTintKey.firstMatch(downloadBaseName(path))?.group(1);

/// The collapsed panel with skeleton blocks, shown while the wallpaper loads.
class DetailPanelSkeleton extends StatelessWidget {
  const DetailPanelSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: DetailPanel.surfaceDecoration(context),
      child: SizedBox(
        height: DetailPanel.collapsedHeight(context),
        child: const Padding(
          padding: EdgeInsets.fromLTRB(PrismSpace.page, DetailPanel._handleZone, PrismSpace.page, 0),
          child: PrismSkeleton(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      PrismBone(width: 120, height: 16),
                      SizedBox(height: PrismSpace.xs),
                      PrismBone(width: 80, height: 11),
                    ],
                  ),
                ),
                PrismBone(width: 120, height: 40, radius: PrismRadius.pill),
                SizedBox(width: PrismSpace.xs),
                PrismBone.circle(size: CircularMenuButton.size),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
