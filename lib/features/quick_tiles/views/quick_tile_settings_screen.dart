import 'package:Prism/core/motion/prism_motion.dart';
import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/data/categories/categories.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/app_tokens.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

const String _fontFamily = 'Proxima Nova';

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
      if (mounted) setState(() => _loading = false);
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
      toasts.success('Quick tile settings saved!');
    } catch (e, stackTrace) {
      logger.e('Failed to save quick tile settings', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      toasts.success('Failed to save settings');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.error == Colors.black ? theme.colorScheme.primary : theme.colorScheme.error;

    return Scaffold(
      backgroundColor: theme.primaryColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        elevation: 0,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(
          'Quick Tile Settings',
          style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontFamily: _fontFamily),
        ),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _saveAll,
              child: AnimatedSwitcher(
                duration: context.motion(PrismDurations.fast),
                child: _saving
                    ? SizedBox.square(
                        key: const ValueKey('saving'),
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                      )
                    : Text(
                        'Save',
                        key: const ValueKey('label'),
                        style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontFamily: _fontFamily),
                      ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const GlintState(kind: GlintStateKind.loading, title: 'Loading quick tiles')
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                _TargetSection(
                  title: 'Shuffle Wallpaper Tile',
                  description: 'Tap the tile to apply a random wallpaper from the selected category.',
                  accentColor: accentColor,
                  value: _categoryTarget,
                  onChanged: (v) => setState(() => _categoryTarget = v),
                  beforeTarget: [
                    const _FieldLabel('Category'),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: categoryDefinitions.length,
                        separatorBuilder: (sepCtx, sepIdx) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final cat = categoryDefinitions[index];
                          final selected = cat.name == _selectedCategoryName;
                          return ChoiceChip(
                            label: Text(cat.name),
                            selected: selected,
                            selectedColor: accentColor,
                            labelStyle: TextStyle(
                              color: selected ? PrismColors.onPrimary : theme.colorScheme.secondary,
                              fontFamily: _fontFamily,
                              fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) {
                              setState(() {
                                _selectedCategoryName = cat.name;
                                _selectedCategorySource = cat.source;
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),
                _TargetSection(
                  title: 'Wall of the Day Tile',
                  description:
                      "Applies today's curated Wall of the Day. Open Prism once a day to cache the latest URL.",
                  accentColor: accentColor,
                  value: _wotdTarget,
                  onChanged: (v) => setState(() => _wotdTarget = v),
                ),
                const Divider(height: 32),
                _TargetSection(
                  title: 'Random Favourite Tile',
                  description:
                      'Picks a random wallpaper from your saved favourites. Sign in and favourite some wallpapers first.',
                  accentColor: accentColor,
                  value: _favsTarget,
                  onChanged: (v) => setState(() => _favsTarget = v),
                ),
                const SizedBox(height: 24),
                const _FieldLabel('How to add quick tiles'),
                const _Hint(
                  '1. Pull down the notification shade twice\n'
                  '2. Tap the pencil/edit icon\n'
                  '3. Scroll to find the Prism tiles and drag them to your active tiles',
                  vertical: 6,
                  height: 1.6,
                ),
              ],
            ),
    );
  }
}

class _TargetSection extends StatelessWidget {
  const _TargetSection({
    required this.title,
    required this.description,
    required this.accentColor,
    required this.value,
    required this.onChanged,
    this.beforeTarget = const [],
  });

  final String title;
  final String description;
  final Color accentColor;
  final WallpaperTarget value;
  final ValueChanged<WallpaperTarget> onChanged;
  final List<Widget> beforeTarget;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            title,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor, fontFamily: _fontFamily),
          ),
        ),
        _Hint(description),
        if (beforeTarget.isEmpty)
          const SizedBox(height: 12)
        else ...[
          const SizedBox(height: 8),
          ...beforeTarget,
          const SizedBox(height: 16),
        ],
        const _FieldLabel('Apply to'),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _TargetSelector(value: value, accentColor: accentColor, onChanged: onChanged),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.secondary,
          fontFamily: _fontFamily,
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text, {this.vertical = 4, this.height});

  final String text;
  final double vertical;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: vertical),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.7),
          height: height,
        ),
      ),
    );
  }
}

class _TargetSelector extends StatelessWidget {
  const _TargetSelector({required this.value, required this.accentColor, required this.onChanged});

  final WallpaperTarget value;
  final Color accentColor;
  final ValueChanged<WallpaperTarget> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<WallpaperTarget>(
      segments: const [
        ButtonSegment(value: WallpaperTarget.home, label: Text('Home'), icon: Icon(Icons.home_outlined, size: 16)),
        ButtonSegment(value: WallpaperTarget.lock, label: Text('Lock'), icon: Icon(Icons.lock_outline, size: 16)),
        ButtonSegment(value: WallpaperTarget.both, label: Text('Both'), icon: Icon(Icons.layers_outlined, size: 16)),
      ],
      selected: {value},
      onSelectionChanged: (Set<WallpaperTarget> selected) {
        if (selected.isNotEmpty) onChanged(selected.first);
      },
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentColor;
          return null;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return PrismColors.onPrimary;
          return Theme.of(context).colorScheme.secondary;
        }),
      ),
    );
  }
}
