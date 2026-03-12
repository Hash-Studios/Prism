import 'package:Prism/core/platform/quick_tile_config_service.dart';
import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/categories/categories.dart';
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
  // Category tile state
  late String _selectedCategoryName;
  late WallpaperSource _selectedCategorySource;
  late WallpaperTarget _categoryTarget;

  // WOTD tile state
  late WallpaperTarget _wotdTarget;

  // Favs tile state
  late WallpaperTarget _favsTarget;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedCategoryName = categoryDefinitions.first.name;
    _selectedCategorySource = categoryDefinitions.first.source;
    _categoryTarget = WallpaperTarget.both;
    _wotdTarget = WallpaperTarget.both;
    _favsTarget = WallpaperTarget.both;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final catConfig = await QuickTileConfigService.loadCategoryTileConfig();
    final wotdConfig = await QuickTileConfigService.loadWotdTileConfig();
    final favsConfig = await QuickTileConfigService.loadFavsTileConfig();

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
      toasts.codeSend('Quick tile settings saved!');
    } catch (e) {
      if (!mounted) return;
      toasts.codeSend('Failed to save settings');
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.router.maybePop(),
        ),
        title: Text(
          'Quick Tile Settings',
          style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold, fontFamily: 'Proxima Nova'),
        ),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _saving ? null : _saveAll,
              child: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                    )
                  : Text(
                      'Save',
                      style: TextStyle(color: accentColor, fontWeight: FontWeight.bold, fontFamily: 'Proxima Nova'),
                    ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                // ── Category Tile Section ───────────────────────────────
                _SectionHeader(label: 'Shuffle Wallpaper Tile', accentColor: accentColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Tap the tile to apply a random wallpaper from the selected category.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                      fontFamily: 'Proxima Nova',
                    ),
                  ),
                ),
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
                          color: selected ? Colors.white : theme.colorScheme.secondary,
                          fontFamily: 'Proxima Nova',
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
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Apply to',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                      fontFamily: 'Proxima Nova',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TargetSelector(
                    value: _categoryTarget,
                    accentColor: accentColor,
                    onChanged: (v) => setState(() => _categoryTarget = v),
                  ),
                ),
                const Divider(height: 32),

                // ── WOTD Tile Section ───────────────────────────────────
                _SectionHeader(label: 'Wall of the Day Tile', accentColor: accentColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    "Applies today's curated Wall of the Day. Open Prism once a day to cache the latest URL.",
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Apply to',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                      fontFamily: 'Proxima Nova',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TargetSelector(
                    value: _wotdTarget,
                    accentColor: accentColor,
                    onChanged: (v) => setState(() => _wotdTarget = v),
                  ),
                ),
                const Divider(height: 32),

                // ── Favourites Tile Section ─────────────────────────────
                _SectionHeader(label: 'Random Favourite Tile', accentColor: accentColor),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Text(
                    'Picks a random wallpaper from your saved favourites. Sign in and favourite some wallpapers first.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.secondary.withValues(alpha: 0.7)),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Apply to',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                      fontFamily: 'Proxima Nova',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _TargetSelector(
                    value: _favsTarget,
                    accentColor: accentColor,
                    onChanged: (v) => setState(() => _favsTarget = v),
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'How to add quick tiles',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.secondary,
                      fontFamily: 'Proxima Nova',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Text(
                    '1. Pull down the notification shade twice\n'
                    '2. Tap the pencil/edit icon\n'
                    '3. Scroll to find the Prism tiles and drag them to your active tiles',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.secondary.withValues(alpha: 0.7),
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label, required this.accentColor});

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor, fontFamily: 'Proxima Nova'),
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
          if (states.contains(WidgetState.selected)) return Colors.white;
          return Theme.of(context).colorScheme.secondary;
        }),
      ),
    );
  }
}
