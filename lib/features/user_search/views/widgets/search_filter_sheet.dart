import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Shortest side, in pixels, offered by the "Min resolution" choices. `null` is "Any".
const List<({String label, int? shortSide})> searchResolutionChoices = <({String label, int? shortSide})>[
  (label: 'Any', shortSide: null),
  (label: '1080p', shortSide: 1080),
  (label: '1440p', shortSide: 1440),
  (label: '4K', shortSide: 2160),
];

/// `<width>x<height>` for a minimum shortest side. Portrait asks for a 9:16 wallpaper, so 1080 becomes `1080x1920`.
/// Without the portrait filter only the shortest side is bounded, so landscape wallpapers still match.
String? minResolutionFor({required int? shortSide, required bool portraitOnly}) {
  if (shortSide == null) {
    return null;
  }
  final int longSide = portraitOnly ? (shortSide * 16 / 9).round() : shortSide;
  return '${shortSide}x$longSide';
}

/// The shortest side that [filters] ask for, or `null` for "Any".
int? shortSideOf(SearchFilters filters) {
  final RegExpMatch? match = RegExp(r'^\s*(\d+)\s*[xX]\s*(\d+)\s*$').firstMatch(filters.minResolution ?? '');
  if (match == null) {
    return null;
  }
  final int width = int.parse(match.group(1)!);
  final int height = int.parse(match.group(2)!);
  return width < height ? width : height;
}

/// [SearchFilters] after the user picks [portraitOnly], [shortSide] and [sort] in the sheet.
SearchFilters buildSearchFilters({required bool portraitOnly, required int? shortSide, required SearchSort sort}) {
  return SearchFilters(
    portraitOnly: portraitOnly,
    minResolution: minResolutionFor(shortSide: shortSide, portraitOnly: portraitOnly),
    sort: sort,
  );
}

String _sortLabel(SearchSort sort) => switch (sort) {
  SearchSort.relevance => 'Relevance',
  SearchSort.latest => 'Latest',
  SearchSort.toplist => 'Top',
};

/// Opens the filter sheet. Returns the chosen filters, or `null` when the sheet is dismissed.
Future<SearchFilters?> showSearchFilterSheet(BuildContext context, SearchFilters current) {
  return showPrismSheet<SearchFilters>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // The Search tab has its own navigator under the floating nav bar; the root one puts the sheet above it.
    useRootNavigator: true,
    builder: (BuildContext sheetContext) => _SearchFilterSheet(initial: current),
  );
}

class _SearchFilterSheet extends StatefulWidget {
  const _SearchFilterSheet({required this.initial});

  final SearchFilters initial;

  @override
  State<_SearchFilterSheet> createState() => _SearchFilterSheetState();
}

class _SearchFilterSheetState extends State<_SearchFilterSheet> {
  late bool _portraitOnly = widget.initial.portraitOnly;
  late int? _shortSide = shortSideOf(widget.initial);
  late SearchSort _sort = widget.initial.sort;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle heading = TextStyle(
      color: scheme.secondary,
      fontFamily: PrismFonts.proximaNova,
      fontWeight: FontWeight.bold,
    );
    Widget chip({required String label, required bool selected, required VoidCallback onSelected}) => ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: scheme.error,
      labelStyle: TextStyle(
        color: selected ? scheme.onError : scheme.secondary,
        fontFamily: PrismFonts.proximaNova,
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => onSelected(),
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Filters', style: heading.copyWith(fontSize: 20)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Portrait only',
                style: TextStyle(color: scheme.secondary, fontFamily: PrismFonts.proximaNova, fontSize: 16),
              ),
              value: _portraitOnly,
              onChanged: (value) => setState(() => _portraitOnly = value),
            ),
            const SizedBox(height: 8),
            Text('Min resolution', style: heading.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final choice in searchResolutionChoices)
                  chip(
                    label: choice.label,
                    selected: _shortSide == choice.shortSide,
                    onSelected: () => setState(() => _shortSide = choice.shortSide),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Sort', style: heading.copyWith(fontSize: 14)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final sort in SearchSort.values)
                  chip(
                    label: _sortLabel(sort),
                    selected: _sort == sort,
                    onSelected: () => setState(() => _sort = sort),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(const SearchFilters()),
                  child: const Text('Reset'),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(
                    context,
                  ).pop(buildSearchFilters(portraitOnly: _portraitOnly, shortSide: _shortSide, sort: _sort)),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
