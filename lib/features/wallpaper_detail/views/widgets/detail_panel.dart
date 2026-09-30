import 'dart:math' show max;

import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/widgets/content_report/content_report_sheet.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/core/widgets/menu_button/edit_button.dart';
import 'package:Prism/core/widgets/menu_button/fav_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/core/widgets/menu_button/share_button.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/ads/views/widgets/download_button.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/wallpaper_detail/biz/bloc/wallpaper_detail_state.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_facts.dart';
import 'package:Prism/features/wallpaper_detail/views/widgets/detail_palette.dart';
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

  static const double _handleZone = 28;
  static const double _rowHeight = CircularMenuButton.size;

  /// Height of the collapsed panel, including the bottom safe area.
  static double collapsedHeight(BuildContext context) =>
      _handleZone + _rowHeight + PrismSpace.sm + bottomPadding(context);

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
                child: ExcludeSemantics(excluding: !visible, child: child),
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
    final Widget main = hideSetWallpaperUi
        ? DownloadButton(link: entity.fullUrl, primary: true, sourceContext: sourceContext, onDownloaded: onDownloaded)
        : SetWallpaperButton(
            url: entity.fullUrl,
            primary: true,
            promptNotificationPermissionOnSuccess: true,
            onSet: onSet,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.page),
      child: SizedBox(
        height: _rowHeight,
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
            main,
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
            const SizedBox(height: PrismSpace.xl),
            _actions(context),
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
      colors: colors,
      selected: state.colorChanged ? state.accent : null,
      onReset: onResetColor,
      onSelect: onSelectColor,
      onCopy: onCopyColor,
    );
  }

  Widget _actions(BuildContext context) {
    final FeedItemEntity entity = state.entity;
    final String? reportDocId = switch (entity) {
      PrismFeedItem(:final wallpaper) => wallpaper.firestoreDocumentId,
      _ => null,
    };
    final List<Widget> actions = <Widget>[
      if (!hideSetWallpaperUi)
        DownloadButton(link: entity.fullUrl, labelled: true, sourceContext: sourceContext, onDownloaded: onDownloaded),
      ShareButton(
        id: entity.id,
        source: entity.source,
        url: entity.fullUrl,
        thumbUrl: entity.thumbnailUrl,
        labelled: true,
      ),
      EditButton(url: entity.fullUrl, labelled: true),
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
          ),
          child: const Icon(JamIcons.flag),
        ),
    ];
    return Row(
      children: <Widget>[for (final Widget action in actions) Expanded(child: Center(child: action))],
    );
  }
}

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
