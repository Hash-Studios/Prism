import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/features/user_search/views/widgets/search_discovery_sections.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

/// What the search tab shows before a search: tags, creators, trending walls, categories and colours.
class SearchDiscoveryWidget extends StatelessWidget {
  const SearchDiscoveryWidget({
    super.key,
    required this.tags,
    required this.selectedTag,
    required this.onTagPressed,
    this.header,
    this.recentSearches = const <String>[],
    this.onRecentPressed,
    this.onClearRecents,
  });

  final List<String> tags;
  final String selectedTag;
  final void Function(String tag) onTagPressed;
  final List<String> recentSearches;
  final void Function(String query)? onRecentPressed;
  final VoidCallback? onClearRecents;

  /// Scrolls with the content, above the tags. The search tab puts its title and field here.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?header,
          if (recentSearches.isNotEmpty)
            _RecentSearches(searches: recentSearches, onPressed: onRecentPressed, onClear: onClearRecents),
          _TagsRow(tags: tags, selectedTag: selectedTag, onTagPressed: onTagPressed),
          const SizedBox(height: PrismSpace.md),
          const Padding(padding: PrismSpace.pageInsets, child: _FindCreatorsCard()),
          const TrendingSection(),
          const CategorySection(),
          const ColourSection(),
          const SizedBox(height: PrismSpace.bottomBarClearance),
        ],
      ),
    );
  }
}

/// The last few searches, newest first, with a Clear action.
class _RecentSearches extends StatelessWidget {
  const _RecentSearches({required this.searches, required this.onPressed, required this.onClear});

  final List<String> searches;
  final void Function(String query)? onPressed;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        PrismSectionHeader(
          title: 'Recent searches',
          actionLabel: 'Clear',
          onAction: onClear,
          padding: const EdgeInsets.fromLTRB(PrismSpace.page, 0, PrismSpace.page, PrismSpace.xxs),
          small: true,
        ),
        Padding(
          padding: PrismSpace.pageInsets,
          child: Wrap(
            spacing: PrismSpace.xs,
            children: <Widget>[
              for (final String query in searches)
                PrismChip(
                  label: query,
                  icon: Icons.history_rounded,
                  onTap: onPressed == null ? null : () => onPressed!(query),
                ),
            ],
          ),
        ),
        const SizedBox(height: PrismSpace.xs),
      ],
    );
  }
}

class _TagsRow extends StatelessWidget {
  const _TagsRow({required this.tags, required this.selectedTag, required this.onTagPressed});

  final List<String> tags;
  final String selectedTag;
  final void Function(String tag) onTagPressed;

  @override
  Widget build(BuildContext context) {
    final String selected = selectedTag.trim().toLowerCase();
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: PrismSpace.pageInsets,
        itemCount: tags.length,
        separatorBuilder: (_, _) => const SizedBox(width: PrismSpace.xs),
        itemBuilder: (context, index) {
          final String tag = tags[index];
          return Center(
            child: PrismChip(label: tag, selected: selected == tag.toLowerCase(), onTap: () => onTagPressed(tag)),
          );
        },
      ),
    );
  }
}

class _FindCreatorsCard extends StatelessWidget {
  const _FindCreatorsCard();

  @override
  Widget build(BuildContext context) {
    return PrismGroup(
      children: <Widget>[
        PrismRow(
          icon: Icons.person_search_rounded,
          title: 'Find creators',
          subtitle: 'Search Prism users by name',
          onTap: () {
            PrismHaptics.tap();
            context.router.push(const UserSearchRoute());
          },
        ),
      ],
    );
  }
}
