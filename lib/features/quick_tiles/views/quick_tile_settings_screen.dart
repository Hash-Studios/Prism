import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/prism/prism_ui.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

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
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final (catConfig, wotdConfig, favsConfig) = await (
        QuickTileConfigService.loadCategoryTileConfig(),
        QuickTileConfigService.loadWotdTileConfig(),
        QuickTileConfigService.loadFavsTileConfig(),
      ).wait;

      if (!mounted) return;
      setState(() {
        if (catConfig != null) {
          _selectedCategoryName = catConfig.categoryName;
          _selectedCategorySource = catConfig.source;
          _categoryTarget = catConfig.target;
        }
        if (wotdConfig != null) {
          _wotdTarget = wotdConfig.target;
        }
        if (favsConfig != null) {
          _favsTarget = favsConfig.target;
        }
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
    setState(() => _saving = true);
    try {
      await Future.wait([
        QuickTileConfigService.saveCategoryTileConfig(
          categoryName: _selectedCategoryName,
          source: _selectedCategorySource,
          target: _categoryTarget,
        ),
        QuickTileConfigService.saveWotdTileConfig(target: _wotdTarget),
        QuickTileConfigService.saveFavsTileConfig(target: _favsTarget),
      ]);
      if (!mounted) return;
      toasts.success('Quick tile settings saved');
    } catch (e, stackTrace) {
      logger.e('Failed to save quick tile settings', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      toasts.error('Could not save quick tile settings');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PrismPage(
      title: 'Quick tiles',
      bottomBar: _loading || _loadFailed
          ? null
          : PrismButton(label: 'Save', expand: true, loading: _saving, onPressed: _saving ? null : _saveAll),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_loading) return PrismSkeleton.cards(count: 4, height: 150);
    if (_loadFailed) {
      return GlintState(
        kind: GlintStateKind.error,
        title: "Couldn't load your quick tiles",
        body: 'Check your connection and try again.',
        actionLabel: 'Try again',
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
          title: 'Shuffle wallpaper tile',
          description: 'Tap the tile to apply a random wallpaper from the category you pick.',
          category: Wrap(
            spacing: PrismSpace.xs,
            runSpacing: PrismSpace.xs,
            children: <Widget>[
              for (final cat in categoryDefinitions)
                PrismChip(
                  label: cat.name,
                  selected: cat.name == _selectedCategoryName,
                  onTap: () => setState(() {
                    _selectedCategoryName = cat.name;
                    _selectedCategorySource = cat.source;
                  }),
                ),
            ],
          ),
          value: _categoryTarget,
          onChanged: (v) => setState(() => _categoryTarget = v),
        ),
        const SizedBox(height: PrismSpace.md),
        _TileCard(
          title: 'Wall of the Day tile',
          description: "Applies today's Wall of the Day. Open Prism once a day to cache the latest one.",
          value: _wotdTarget,
          onChanged: (v) => setState(() => _wotdTarget = v),
        ),
        const SizedBox(height: PrismSpace.md),
        _TileCard(
          title: 'Random favourite tile',
          description: 'Applies a random wallpaper from your favourites. Sign in and favourite some wallpapers first.',
          value: _favsTarget,
          onChanged: (v) => setState(() => _favsTarget = v),
        ),
        const SizedBox(height: PrismSpace.md),
        const _HowToCard(),
      ],
    );
  }
}

class _TileCard extends StatelessWidget {
  const _TileCard({
    required this.title,
    required this.description,
    required this.value,
    required this.onChanged,
    this.category,
  });

  final String title;
  final String description;
  final WallpaperTarget value;
  final ValueChanged<WallpaperTarget> onChanged;

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
            Text('Category', style: PrismTextStyles.rowTitle(context)),
            const SizedBox(height: PrismSpace.xs),
            category!,
          ],
          const SizedBox(height: PrismSpace.md),
          Text('Apply to', style: PrismTextStyles.rowTitle(context)),
          const SizedBox(height: PrismSpace.xs),
          PrismSegmented<WallpaperTarget>(
            values: const <WallpaperTarget>[WallpaperTarget.home, WallpaperTarget.lock, WallpaperTarget.both],
            selected: value,
            labelOf: (t) => switch (t) {
              WallpaperTarget.home => 'Home',
              WallpaperTarget.lock => 'Lock',
              WallpaperTarget.both => 'Both',
            },
            iconOf: (t) => switch (t) {
              WallpaperTarget.home => Icons.home_rounded,
              WallpaperTarget.lock => Icons.lock_rounded,
              WallpaperTarget.both => Icons.layers_rounded,
            },
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _HowToCard extends StatelessWidget {
  const _HowToCard();

  static const List<String> _steps = <String>[
    'Pull down the notification shade twice.',
    'Tap the pencil or edit icon.',
    'Find the Prism tiles and drag them to your active tiles.',
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return PrismCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('How to add a tile', style: PrismTextStyles.cardTitle(context)),
          const SizedBox(height: PrismSpace.sm),
          for (int i = 0; i < _steps.length; i++)
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
                      '${i + 1}',
                      style: PrismTextStyles.caption(context).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: PrismSpace.sm),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(_steps[i], style: PrismTextStyles.body(context)),
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
