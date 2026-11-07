import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/color/prism_palette.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/folders/data/wall_traits_source.dart';
import 'package:Prism/features/folders/domain/entities/folder_edit.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_section.dart';
import 'package:Prism/features/folders/domain/section_suggester.dart';
import 'package:Prism/features/folders/views/folder_sections.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/features/moods/views/mood_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

typedef WallTraitsLoader = Future<Map<String, WallTraits>> Function(List<FavouriteWallEntity> walls);

/// Groups the Unsorted walls by mood, category or main colour on the device, shows the groups, and adds the ones the
/// user keeps as sections.
Future<void> showSectionSuggestionsSheet(
  BuildContext context, {
  required FolderEntity folder,
  required List<FavouriteWallEntity> walls,
  required Map<String, String> sectionOf,
  WallTraitsLoader? loadTraits,
}) async {
  PrismHaptics.tap();
  final List<FavouriteWallEntity> unsorted = <FavouriteWallEntity>[
    for (final FolderGroup group in folderGroups(folder.sections, walls, sectionOf))
      if (group.section == null) ...group.walls,
  ];
  final _Accepted? accepted = await showPrismSheet<_Accepted>(
    context,
    builder: (_) => _SuggestionsSheet(
      folder: folder,
      unsorted: unsorted,
      loadTraits: loadTraits ?? WallTraitsSource(getIt<FirestoreClient>()).traitsOf,
    ),
  );
  if (accepted == null || accepted.groups.isEmpty || !context.mounted) return;
  final AppLocalizations l10n = context.l10n;
  if (!await organizeFolder(context, folder.id, SuggestionsAccepted(accepted.groups))) return;
  PrismHaptics.success();
  final int wallCount = accepted.groups.fold(0, (sum, group) => sum + group.itemKeys.length);
  unawaited(
    analytics.track(
      FolderSectionSuggestionsAcceptedEvent(
        count: accepted.groups.length,
        offered: accepted.offered,
        kind: accepted.kind.name,
      ),
    ),
  );
  toasts.success(l10n.foldersSuggestSorted(wallCount));
}

class _Accepted {
  const _Accepted(this.groups, this.offered, this.kind);

  final List<AcceptedGroup> groups;
  final int offered;
  final SuggestionKind kind;
}

String? _nameOf(SuggestionKind kind, String key, AppLocalizations l10n) => switch (kind) {
  SuggestionKind.mood => WallMood.parse(key)?.title(l10n),
  SuggestionKind.category => categoryDisplayName(key, l10n),
  SuggestionKind.colour => switch (paletteColorById(key)) {
    final PrismPaletteColor color => prismPaletteColorDisplayName(color, l10n),
    null => null,
  },
};

class _SuggestionsSheet extends StatefulWidget {
  const _SuggestionsSheet({required this.folder, required this.unsorted, required this.loadTraits});

  final FolderEntity folder;
  final List<FavouriteWallEntity> unsorted;
  final WallTraitsLoader loadTraits;

  @override
  State<_SuggestionsSheet> createState() => _SuggestionsSheetState();
}

class _SuggestionsSheetState extends State<_SuggestionsSheet> {
  Map<SuggestionKind, List<SectionSuggestion>>? _byKind;
  bool _failed = false;
  SuggestionKind _kind = SuggestionKind.mood;
  final Map<SuggestionKind, Set<String>> _skipped = <SuggestionKind, Set<String>>{};
  late final Map<String, FavouriteWallEntity> _wallByKey = <String, FavouriteWallEntity>{
    for (final FavouriteWallEntity wall in widget.unsorted) folderItemKey(wall): wall,
  };

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final Map<String, WallTraits> traits = await widget.loadTraits(widget.unsorted);
      if (!mounted) return;
      final AppLocalizations l10n = context.l10n;
      final List<String> keys = widget.unsorted.map(folderItemKey).toList();
      final Map<SuggestionKind, List<SectionSuggestion>> byKind = <SuggestionKind, List<SectionSuggestion>>{
        for (final SuggestionKind kind in SuggestionKind.values)
          kind: suggestSections(
            kind: kind,
            itemKeys: keys,
            traits: traits,
            sections: widget.folder.sections,
            nameOf: (key) => _nameOf(kind, key, l10n) ?? '',
          ),
      };
      final SuggestionKind best = bestSuggestionKind(byKind);
      setState(() {
        _byKind = byKind;
        _kind = best;
      });
      unawaited(analytics.track(FolderSectionSuggestionsShownEvent(kind: best.name, groupCount: byKind[best]!.length)));
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  List<SectionSuggestion> get _groups => _byKind?[_kind] ?? const <SectionSuggestion>[];

  Set<String> get _skippedNow => _skipped.putIfAbsent(_kind, () => <String>{});

  List<SectionSuggestion> get _kept => _groups.where((group) => !_skippedNow.contains(group.key)).toList();

  void _toggle(SectionSuggestion group) {
    PrismHaptics.selection();
    setState(() => _skippedNow.contains(group.key) ? _skippedNow.remove(group.key) : _skippedNow.add(group.key));
  }

  void _accept() {
    final List<AcceptedGroup> groups = <AcceptedGroup>[
      for (final SectionSuggestion group in _kept)
        AcceptedGroup(sectionId: group.existingSectionId ?? newSectionId(), name: group.name, itemKeys: group.itemKeys),
    ];
    Navigator.of(context).pop(_Accepted(groups, _groups.length, _kind));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Map<SuggestionKind, List<SectionSuggestion>>? byKind = _byKind;
    final int newSections = _kept.where((group) => group.existingSectionId == null).length;
    final Widget body;
    if (_failed) {
      body = GlintState(
        kind: GlintStateKind.error,
        title: l10n.foldersSuggestError,
        body: l10n.wallpaperCheckConnection,
        actionLabel: l10n.wallpaperTryAgain,
        onAction: () => unawaited(_load()),
      );
    } else if (byKind == null) {
      body = Padding(
        padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
        child: PrismSkeleton.rows(),
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
            child: PrismSegmented<SuggestionKind>(
              values: SuggestionKind.values,
              selected: _kind,
              labelOf: (kind) => switch (kind) {
                SuggestionKind.mood => l10n.foldersSuggestByMood,
                SuggestionKind.category => l10n.foldersSuggestByCategory,
                SuggestionKind.colour => l10n.foldersSuggestByColour,
              },
              onChanged: (kind) {
                PrismHaptics.selection();
                setState(() => _kind = kind);
              },
            ),
          ),
          const SizedBox(height: PrismSpace.sm),
          Flexible(
            child: AnimatedSwitcher(
              duration: context.motion(PrismDurations.fast),
              switchOutCurve: PrismCurves.exitReverse,
              child: _groups.isEmpty
                  ? KeyedSubtree(
                      key: ValueKey<String>('empty-${_kind.name}'),
                      child: SingleChildScrollView(
                        child: GlintState(
                          kind: GlintStateKind.empty,
                          title: l10n.foldersSuggestEmptyTitle,
                          body: l10n.foldersSuggestEmptyBody,
                        ),
                      ),
                    )
                  : ListView(
                      key: ValueKey<SuggestionKind>(_kind),
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: PrismSpace.md),
                      children: <Widget>[
                        for (final SectionSuggestion group in _groups)
                          _GroupRow(
                            group: group,
                            walls: <FavouriteWallEntity>[
                              for (final String key in group.itemKeys.take(4))
                                if (_wallByKey[key] case final FavouriteWallEntity wall) wall,
                            ],
                            kept: !_skippedNow.contains(group.key),
                            onTap: () => _toggle(group),
                          ),
                        const SizedBox(height: PrismSpace.md),
                      ],
                    ),
            ),
          ),
        ],
      );
    }
    return PrismSheetBody(
      title: l10n.foldersSuggestTitle,
      message: l10n.foldersSuggestBody,
      childScrolls: true,
      actions: <Widget>[
        PrismButton(
          label: newSections == 0 && _kept.isNotEmpty
              ? l10n.foldersSuggestSort(_kept.fold(0, (sum, group) => sum + group.itemKeys.length))
              : l10n.foldersSuggestAdd(newSections),
          expand: true,
          maxLines: 2,
          onPressed: _kept.isEmpty ? null : _accept,
        ),
      ],
      child: body,
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({required this.group, required this.walls, required this.kept, required this.onTap});

  final SectionSuggestion group;
  final List<FavouriteWallEntity> walls;
  final bool kept;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme cs = Theme.of(context).colorScheme;
    final String count = l10n.foldersSectionWallCount(group.itemKeys.length);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: PrismSpace.xxs),
      child: MergeSemantics(
        child: Semantics(
          checked: kept,
          child: PrismCard(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(group.name, softWrap: true, style: PrismTextStyles.cardTitle(context)),
                          Text(
                            group.existingSectionId == null ? count : l10n.foldersSuggestJoins(count),
                            style: PrismTextStyles.caption(context),
                          ),
                        ],
                      ),
                    ),
                    SizedBox.square(
                      dimension: 44,
                      child: Icon(
                        kept ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: kept ? cs.primary : cs.onSurface.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PrismSpace.xs),
                ExcludeSemantics(
                  child: Row(
                    children: <Widget>[
                      for (final FavouriteWallEntity wall in walls) ...<Widget>[
                        Expanded(
                          child: AspectRatio(
                            aspectRatio: 9 / 16,
                            child: PrismWallTile(url: wall.thumbnailUrl),
                          ),
                        ),
                        const SizedBox(width: PrismSpace.xxs),
                      ],
                      for (int i = walls.length; i < 4; i++) ...<Widget>[
                        const Expanded(child: SizedBox.shrink()),
                        const SizedBox(width: PrismSpace.xxs),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
