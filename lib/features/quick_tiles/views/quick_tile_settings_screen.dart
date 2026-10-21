import 'dart:async';
import 'dart:convert';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/offline/offline_asset_store.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/platform/quick_settings_channel.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/data/categories/category_catalog.dart';
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/data/offline/offline_wallpaper_catalog.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/ios_shortcuts/data/native_asset_paths_store.dart';
import 'package:Prism/features/quick_tiles/data/quick_tile_defaults.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, visibleForTesting;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

@RoutePage()
class QuickTileSettingsScreen extends StatefulWidget {
  const QuickTileSettingsScreen({super.key});

  @override
  State<QuickTileSettingsScreen> createState() => _QuickTileSettingsScreenState();
}

class _QuickTileSettingsScreenState extends State<QuickTileSettingsScreen> {
  String _selectedCategoryName = categoryDefinitions.first.name;
  WallpaperSource _selectedCategorySource = categoryDefinitions.first.source;
  WallpaperTarget _categoryTarget = WallpaperTarget.both;
  WallpaperTarget _wotdTarget = WallpaperTarget.both;
  WallpaperTarget _favsTarget = WallpaperTarget.both;

  bool _loading = true;
  bool _loadFailed = false;
  bool _canAddTile = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _loadAddTileSupport();
  }

  Future<void> _loadAddTileSupport() async {
    final bool supported = await const QuickSettingsChannel().canRequestAddTile;
    if (mounted && supported) setState(() => _canAddTile = true);
  }

  Future<void> _addTile(QuickTileKind tile) async {
    final QuickSettingsAddResult result = await const QuickSettingsChannel().requestAddTile(tile);
    analytics.track(QuickTileAddRequestedEvent(tile: tile.name, result: result.name));
    if (!mounted) return;
    final String message = switch (result) {
      QuickSettingsAddResult.added => context.l10n.wallpaperQuickTileAdded,
      QuickSettingsAddResult.alreadyAdded => context.l10n.wallpaperQuickTileAlreadyAdded,
      QuickSettingsAddResult.notAdded => context.l10n.wallpaperQuickTileNotAdded,
      QuickSettingsAddResult.unsupported || QuickSettingsAddResult.error => context.l10n.wallpaperQuickTileAddError,
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _loadConfig() async {
    try {
      final (catConfig, wotdConfig, favsConfig) = await (
        QuickTileConfigService.loadCategoryTileConfig(),
        QuickTileConfigService.loadWotdTileConfig(),
        QuickTileConfigService.loadFavsTileConfig(),
      ).wait;

      final QuickTileSeed config = await QuickTileDefaults.seedMissing(
        category: catConfig,
        wotd: wotdConfig,
        favs: favsConfig,
      );
      await QuickTileDefaults.mirrorWallhavenCategories(getIt<SettingsLocalDataSource>());

      if (!mounted) return;
      setState(() {
        _selectedCategoryName = config.category.categoryName;
        _selectedCategorySource = config.category.source;
        _categoryTarget = config.category.target;
        _wotdTarget = config.wotd.target;
        _favsTarget = config.favs.target;
        _loading = false;
      });
    } catch (e, stackTrace) {
      logger.e('Failed to load quick tile settings', error: e, stackTrace: stackTrace);
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _saveAll() async {
    try {
      await _prepareCategoryChoices();
      await Future.wait([
        QuickTileConfigService.saveCategoryTileConfig(
          categoryName: _selectedCategoryName,
          source: _selectedCategorySource,
          target: _categoryTarget,
        ),
        QuickTileConfigService.saveWotdTileConfig(target: _wotdTarget),
        QuickTileConfigService.saveFavsTileConfig(target: _favsTarget),
        QuickTileDefaults.mirrorWallhavenCategories(getIt<SettingsLocalDataSource>()),
      ]);
    } catch (e, stackTrace) {
      logger.e('Failed to save quick tile settings', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      toasts.error(context.l10n.wallpaperQuickTileSaveError);
    }
  }

  Future<void> _prepareCategoryChoices() async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final items = await OfflineWallpaperCatalog.instance.search(
        _selectedCategoryName,
        limit: OfflineWallpaperCatalog.maxRecords,
      );
      final paths = await OfflineAssetStore.instance.localPaths();
      final candidates = categoryTileCandidates(
        items,
        category: _selectedCategoryName,
        source: _selectedCategorySource,
        retainedPaths: paths,
      );
      final selectedPaths = <String, String>{for (final url in candidates) url: paths[url]!};
      await NativeAssetPathsStore.replaceGroup('category', selectedPaths);
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (!await prefs.setString('quick_tile.category.wall_urls', jsonEncode(candidates))) {
        throw StateError('Prepared category wallpapers could not be persisted');
      }
    } catch (error, stackTrace) {
      logger.w('Could not prepare offline category tile choices', error: error, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(title: context.l10n.wallpaperQuickTilesTitle, body: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_loading) return PrismSkeleton.cards(count: 4, height: 150);
    if (_loadFailed) {
      return GlintState(
        kind: GlintStateKind.error,
        title: context.l10n.wallpaperQuickTilesLoadError,
        body: context.l10n.wallpaperCheckConnection,
        actionLabel: context.l10n.wallpaperTryAgain,
        onAction: () {
          setState(() {
            _loading = true;
            _loadFailed = false;
          });
          _loadConfig();
        },
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(PrismSpace.page, PrismSpace.xs, PrismSpace.page, PrismSpace.xl),
      children: <Widget>[
        _TileCard(
          title: context.l10n.wallpaperQuickShuffleTitle,
          description: context.l10n.wallpaperQuickShuffleDescription,
          category: Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              // The tile keeps a saved category that the remote list dropped, so the picker keeps showing it.
              if (!CategoryCatalog.current.any((cat) => cat.name == _selectedCategoryName))
                PrismChip(label: categoryDisplayName(_selectedCategoryName, context.l10n), selected: true),
              for (final cat in CategoryCatalog.current)
                PrismChip(
                  label: categoryDisplayName(cat.name, context.l10n),
                  selected: cat.name == _selectedCategoryName,
                  onTap: () {
                    setState(() {
                      _selectedCategoryName = cat.name;
                      _selectedCategorySource = cat.source;
                    });
                    unawaited(_saveAll());
                  },
                ),
            ],
          ),
          value: _categoryTarget,
          onAddToQuickSettings: _canAddTile ? () => _addTile(QuickTileKind.shuffle) : null,
          onChanged: (v) {
            setState(() => _categoryTarget = v);
            unawaited(_saveAll());
          },
        ),
        const SizedBox(height: PrismSpace.md),
        _TileCard(
          title: context.l10n.wallpaperQuickWotdTitle,
          description: context.l10n.wallpaperQuickWotdDescription,
          value: _wotdTarget,
          onAddToQuickSettings: _canAddTile ? () => _addTile(QuickTileKind.wotd) : null,
          onChanged: (v) {
            setState(() => _wotdTarget = v);
            unawaited(_saveAll());
          },
        ),
        const SizedBox(height: PrismSpace.md),
        _TileCard(
          title: context.l10n.wallpaperQuickFavouriteTitle,
          description: context.l10n.wallpaperQuickFavouriteDescription,
          value: _favsTarget,
          onAddToQuickSettings: _canAddTile ? () => _addTile(QuickTileKind.favs) : null,
          onChanged: (v) {
            setState(() => _favsTarget = v);
            unawaited(_saveAll());
          },
        ),
        const SizedBox(height: PrismSpace.md),
        _HowToCard(),
      ],
    );
  }
}

@visibleForTesting
List<String> categoryTileCandidates(
  Iterable<FeedItemEntity> items, {
  required String category,
  required WallpaperSource source,
  required Map<String, String> retainedPaths,
}) {
  final String expectedCategory = category.trim().toLowerCase();
  return <String>{
    for (final FeedItemEntity item in items)
      if (item.source == source &&
          item.wallpaperCore.category?.trim().toLowerCase() == expectedCategory &&
          retainedPaths.containsKey(item.fullUrl))
        item.fullUrl,
  }.take(100).toList(growable: false);
}

class _TileCard extends StatelessWidget {
  const _TileCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.onAddToQuickSettings,
    this.category,
  });

  final String title;
  final String description;
  final WallpaperTarget value;
  final ValueChanged<WallpaperTarget> onChanged;
  final VoidCallback? onAddToQuickSettings;

  /// The category picker, for the tile that has one.
  final Widget? category;

  @override
  Widget build(BuildContext context) {
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: PrismTextStyles.cardTitle(context)),
          const SizedBox(height: PrismSpace.xxs),
          Text(description, style: PrismTextStyles.body(context)),
          if (category != null) ...<Widget>[
            const SizedBox(height: PrismSpace.md),
            Text(context.l10n.wallpaperCategory, style: PrismTextStyles.rowTitle(context)),
            const SizedBox(height: PrismSpace.xs),
            category!,
          ],
          const SizedBox(height: PrismSpace.md),
          Text(context.l10n.wallpaperApplyTo, style: PrismTextStyles.rowTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          PrismSegmented<WallpaperTarget>(
            values: const <WallpaperTarget>[WallpaperTarget.home, WallpaperTarget.lock, WallpaperTarget.both],
            selected: value,
            labelOf: (t) => switch (t) {
              WallpaperTarget.home => context.l10n.wallpaperQuickTargetHome,
              WallpaperTarget.lock => context.l10n.wallpaperQuickTargetLock,
              WallpaperTarget.both => context.l10n.wallpaperQuickTargetBoth,
            },
            iconOf: (t) => switch (t) {
              WallpaperTarget.home => Icons.home_rounded,
              WallpaperTarget.lock => Icons.lock_rounded,
              WallpaperTarget.both => Icons.layers_rounded,
            },
            onChanged: onChanged,
          ),
          if (onAddToQuickSettings != null) ...<Widget>[
            const SizedBox(height: PrismSpace.md),
            PrismButton(
              label: context.l10n.wallpaperQuickAddAction,
              icon: Icons.add_rounded,
              variant: PrismButtonVariant.tonal,
              size: PrismButtonSize.compact,
              onPressed: onAddToQuickSettings,
            ),
          ],
        ],
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(context.l10n.wallpaperQuickHowToTitle, style: PrismTextStyles.cardTitle(context)),
          const SizedBox(height: PrismSpace.sm),
          for (final (int i, String step) in <String>[
            context.l10n.wallpaperQuickStepShade,
            context.l10n.wallpaperQuickStepEdit,
            context.l10n.wallpaperQuickStepFindPrism,
          ].indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : PrismSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: cs.onSurface.withValues(alpha: 0.08), shape: BoxShape.circle),
                    child: Text(
                      NumberFormat.decimalPattern(context.l10n.localeName).format(i + 1),
                      style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: PrismSpace.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(step, style: PrismTextStyles.body(context)),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
