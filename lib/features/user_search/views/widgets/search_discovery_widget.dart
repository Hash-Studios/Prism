import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/creator_directory/views/widgets/creators_section.dart';
import 'package:Prism/features/folders/views/widgets/discover_folders.dart';
import 'package:Prism/features/user_search/biz/bloc/search_discovery_bloc.j.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_sections.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// What the search tab shows before a search. Imagery leads: one chip row of recent searches and tags, trending walls,
/// categories, colours, creators and folders. The text rows (creators, requests, live walls, depth, spatial) close the
/// page as one group.
class SearchDiscoveryWidget extends StatelessWidget {
  const SearchDiscoveryWidget({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onTagPressed,
    this.header,
    this.dimmed = false,
    this.recentSearches = const <String>[],
    this.onRecentPressed,
    this.onClearRecents,
    this.onColorPressed,
    this.onDepthPressed,
    this.onSpatialPressed,
    this.onLiveWallsPressed,
  });

  final List<String> tags;
  final String selectedTag;
  final void Function(String tag) onTagPressed;
  final List<String> recentSearches;
  final void Function(String query)? onRecentPressed;
  final VoidCallback? onClearRecents;

  /// Scrolls with the content, above the tags. The search tab puts its title and field here.
  final Widget? header;

  /// Dims everything below [header] a little, while the search field has focus.
  final bool dimmed;

  /// Called with the swatch the user taps in "Browse by colour". Without it the section is hidden.
  final void Function(PrismPaletteColor color)? onColorPressed;

  /// Opens the walls that work with the iOS Lock Screen Depth Effect. Without it the row is hidden.
  final VoidCallback? onDepthPressed;

  /// Opens the walls that work as an iOS 26 Spatial Scene. Without it the row is hidden.
  final VoidCallback? onSpatialPressed;

  /// Opens search with the Live filter on. The row shows only when the [SearchDiscoveryBloc] found live walls.
  final VoidCallback? onLiveWallsPressed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?header,
          AnimatedOpacity(
            opacity: dimmed ? 0.55 : 1,
            duration: context.motion(PrismDurations.fast),
            curve: PrismCurves.enter,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _QueryChips(
                  recents: recentSearches,
                  onRecentPressed: onRecentPressed,
                  onClearRecents: onClearRecents,
                  tags: tags,
                  selectedTag: selectedTag,
                  onTagPressed: onTagPressed,
                ),
                const TrendingSection(),
                const CategorySection(),
                if (onColorPressed != null) ColourSection(onPressed: onColorPressed!),
                const CreatorsSection(source: 'search'),
                const FoldersDiscoverSection(),
                const SizedBox(height: PrismSpace.xl),
                Padding(
                  padding: PrismSpace.pageInsets,
                  child: PrismGroup(
                    children: <Widget>[
                      const _FindCreatorsRow(),
                      const _WallRequestsRow(),
                      if (onLiveWallsPressed != null) _LiveWallsRow(onPressed: onLiveWallsPressed!),
                      if (onDepthPressed != null) _DepthEffectRow(onPressed: onDepthPressed!),
                      if (onSpatialPressed != null) _SpatialSceneRow(onPressed: onSpatialPressed!),
                    ],
                  ),
                ),
                const SizedBox(height: PrismSpace.bottomBarClearance),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Padding for the closing text rows: tighter than a settings list, so the group stays compact.
const EdgeInsets _compactRowPadding = EdgeInsets.symmetric(horizontal: PrismSpace.md, vertical: PrismSpace.xs);

/// One horizontal chip row: the last few searches (newest first, with a history icon), then the curated tags.
/// A small "Recent searches" header with a Clear action sits above it while there are recents.
class _QueryChips extends StatelessWidget {
  const _QueryChips({
    required this.recents,
    required this.onRecentPressed,
    required this.onClearRecents,
    required this.tags,
    required this.selectedTag,
    required this.onTagPressed,
  });

  final List<String> recents;
  final void Function(String query)? onRecentPressed;
  final VoidCallback? onClearRecents;
  final List<String> tags;
  final String selectedTag;
  final void Function(String tag) onTagPressed;

  @override
  Widget build(BuildContext context) {
    final String selected = selectedTag.trim().toLowerCase();
    final List<Widget> chips = <Widget>[
      for (final String query in recents)
        PrismChip(
          label: query,
          icon: Icons.history_rounded,
          onTap: onRecentPressed == null ? null : () => onRecentPressed!(query),
        ),
      for (final String tag in tags)
        PrismChip(label: tag, selected: selected == tag.toLowerCase(), onTap: () => onTagPressed(tag)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (recents.isNotEmpty)
          PrismSectionHeader(
            title: context.l10n.accountRecentSearches,
            actionLabel: context.l10n.accountClear,
            onAction: onClearRecents,
            padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xxs),
            small: true,
          ),
        if (chips.isNotEmpty)
          // The row takes the chip height, so a chip keeps its whole label at large text.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: PrismSpace.pageInsets,
            child: Row(
              children: <Widget>[
                for (int i = 0; i < chips.length; i++) ...<Widget>[
                  if (i > 0) const SizedBox(width: PrismSpace.xs),
                  chips[i],
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _FindCreatorsRow extends StatelessWidget {
  const _FindCreatorsRow();

  @override
  Widget build(BuildContext context) {
    return PrismRow(
      icon: Icons.person_search_rounded,
      title: context.l10n.accountFindCreators,
      subtitle: context.l10n.accountSearchPrismUsersByName,
      padding: _compactRowPadding,
      onTap: () {
        PrismHaptics.tap();
        context.router.push(const UserSearchRoute());
      },
    );
  }
}

class _WallRequestsRow extends StatelessWidget {
  const _WallRequestsRow();

  @override
  Widget build(BuildContext context) {
    return PrismRow(
      icon: Icons.lightbulb_outline_rounded,
      title: context.l10n.discoverRequestsTitle,
      subtitle: context.l10n.discoverRequestsSubtitle,
      padding: _compactRowPadding,
      onTap: () {
        PrismHaptics.tap();
        context.router.push(WallRequestsRoute());
      },
    );
  }
}

/// Shows nothing until the discovery bloc finds at least one live wall.
class _LiveWallsRow extends StatelessWidget {
  const _LiveWallsRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final bool hasLiveWalls = context.select((SearchDiscoveryBloc bloc) => bloc.state.hasLiveWalls);
    if (!hasLiveWalls) return const SizedBox.shrink();
    return PrismRow(
      icon: Icons.motion_photos_on_rounded,
      title: context.l10n.discoverLiveWallsTitle,
      subtitle: context.l10n.discoverLiveWallsSubtitle,
      padding: _compactRowPadding,
      onTap: () {
        PrismHaptics.tap();
        onPressed();
      },
    );
  }
}

class _DepthEffectRow extends StatelessWidget {
  const _DepthEffectRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    void open() {
      PrismHaptics.tap();
      onPressed();
    }

    return Semantics(
      button: true,
      label: context.l10n.accountDepthEffectClockSemanticLabel,
      excludeSemantics: true,
      onTap: open,
      child: PrismRow(
        icon: Icons.layers_rounded,
        title: context.l10n.accountDepthEffect,
        subtitle: context.l10n.accountSubjectInFrontOfClock,
        padding: _compactRowPadding,
        onTap: open,
      ),
    );
  }
}

class _SpatialSceneRow extends StatelessWidget {
  const _SpatialSceneRow({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    void open() {
      PrismHaptics.tap();
      onPressed();
    }

    return Semantics(
      button: true,
      label: context.l10n.accountSpatialSceneSemanticLabel,
      excludeSemantics: true,
      onTap: open,
      child: PrismRow(
        icon: Icons.view_in_ar_rounded,
        title: context.l10n.accountSpatialScene,
        subtitle: context.l10n.accountSpatialSceneSubtitle,
        padding: _compactRowPadding,
        onTap: open,
      ),
    );
  }
}
