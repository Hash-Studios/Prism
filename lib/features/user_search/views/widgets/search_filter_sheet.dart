import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/platform/wallpaper_capability.dart';
import 'package:Prism/core/widgets/prism/prism_chip.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/features/user_search/data/search_filters.dart';
import 'package:Prism/features/user_search/views/widgets/palette_swatch.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:flutter/material.dart';

/// Shortest side, in pixels, offered by the "Min resolution" choices. `null` is "Any".
const List<int?> searchResolutionChoices = <int?>[null, 1080, 1440, 2160];

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

/// [SearchFilters] after the user picks [portraitOnly], [shortSide], [sort], [color] and [depthOnly] in the sheet.
SearchFilters buildSearchFilters({
  required bool portraitOnly,
  required int? shortSide,
  required SearchSort sort,
  PrismPaletteColor? color,
  bool depthOnly = false,
}) {
  return SearchFilters(
    portraitOnly: portraitOnly,
    minResolution: minResolutionFor(shortSide: shortSide, portraitOnly: portraitOnly),
    sort: sort,
    color: color,
    depthOnly: depthOnly,
  );
}

String _sortLabel(AppLocalizations l10n, SearchSort sort) => switch (sort) {
  SearchSort.relevance => l10n.accountRelevance,
  SearchSort.latest => l10n.accountLatest,
  SearchSort.toplist => l10n.accountTop,
};

String _resolutionLabel(AppLocalizations l10n, int? shortSide) => switch (shortSide) {
  null => l10n.accountAnyResolution,
  1080 => l10n.accountResolution1080,
  1440 => l10n.accountResolution1440,
  _ => l10n.accountResolution4k,
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
  late PrismPaletteColor? _color = widget.initial.color;
  late bool _depthOnly = widget.initial.depthOnly;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final TextStyle heading = TextStyle(
      color: scheme.secondary,
      fontFamily: PrismFonts.proximaNova,
      fontWeight: FontWeight.bold,
    );
    Widget chip({required String label, required bool selected, required VoidCallback onSelected}) =>
        ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onSelected());
    final PrismPaletteColor accentMatch = nearestPaletteColor(scheme.primary);
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(context.l10n.accountSearchFilters, style: heading.copyWith(fontSize: 20)),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                context.l10n.accountPortraitOnly,
                style: TextStyle(color: scheme.secondary, fontFamily: PrismFonts.proximaNova, fontSize: 16),
              ),
              value: _portraitOnly,
              onChanged: (value) => setState(() => _portraitOnly = value),
            ),
            if (showDepthEffectUi)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.l10n.accountDepthEffect,
                  style: TextStyle(color: scheme.secondary, fontFamily: PrismFonts.proximaNova, fontSize: 16),
                ),
                subtitle: Text(
                  context.l10n.accountSubjectCanSitInFrontOfClock,
                  style: TextStyle(
                    color: scheme.secondary.withValues(alpha: 0.7),
                    fontFamily: PrismFonts.proximaNova,
                    fontSize: 13,
                  ),
                ),
                value: _depthOnly,
                onChanged: (value) => setState(() => _depthOnly = value),
              ),
            const SizedBox(height: 8),
            Text(context.l10n.accountMinResolution, style: heading.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final int? shortSide in searchResolutionChoices)
                  chip(
                    label: _resolutionLabel(context.l10n, shortSide),
                    selected: _shortSide == shortSide,
                    onSelected: () => setState(() => _shortSide = shortSide),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(context.l10n.accountSort, style: heading.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: <Widget>[
                for (final sort in SearchSort.values)
                  chip(
                    label: _sortLabel(context.l10n, sort),
                    selected: _sort == sort,
                    onSelected: () => setState(() => _sort = sort),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(context.l10n.accountColour, style: heading.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 4),
            Wrap(
              children: <Widget>[
                for (final PrismPaletteColor entry in prismPalette)
                  PaletteSwatch(
                    color: entry,
                    selected: _color == entry,
                    onTap: () => setState(() => _color = _color == entry ? null : entry),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: PrismChip(
                label: context.l10n.accountMyAccent,
                selected: _color == accentMatch,
                leading: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.primary),
                  child: const SizedBox(width: 14, height: 14),
                ),
                onTap: () => setState(() => _color = accentMatch),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(const SearchFilters()),
                  child: Text(context.l10n.accountReset),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(
                    buildSearchFilters(
                      portraitOnly: _portraitOnly,
                      shortSide: _shortSide,
                      sort: _sort,
                      color: _color,
                      depthOnly: _depthOnly,
                    ),
                  ),
                  child: Text(context.l10n.accountApply),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
