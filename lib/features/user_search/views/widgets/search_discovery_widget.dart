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
  });

  final List<String> tags;
  final String selectedTag;
  final void Function(String tag) onTagPressed;

  /// Scrolls with the content, above the tags. The search tab puts its title and field here.
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ?header,
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
          onTap: () => context.router.push(const UserSearchRoute()),
        ),
      ],
    );
  }
}
