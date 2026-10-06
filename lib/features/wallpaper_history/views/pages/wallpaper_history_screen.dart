import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_history/data/wallpaper_history_store.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

@RoutePage()
class WallpaperHistoryScreen extends StatefulWidget {
  const WallpaperHistoryScreen({super.key});

  @override
  State<WallpaperHistoryScreen> createState() => _WallpaperHistoryScreenState();
}

class _WallpaperHistoryScreenState extends State<WallpaperHistoryScreen> {
  late List<AppliedWallpaper> _items = WallpaperHistoryStore.instance.items();

  void _reload() => setState(() => _items = WallpaperHistoryStore.instance.items());

  Future<void> _setAgain(AppliedWallpaper item) async {
    PrismHaptics.tap();
    await SetWallpaperFlow.run(context, url: item.fullUrl, thumbnailUrl: item.thumbnailUrl, forceSheet: true);
    if (mounted) _reload();
  }

  Future<void> _confirmClear() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('This removes the list of wallpapers you set. Your wallpapers stay as they are.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Clear')),
        ],
      ),
    );
    if (confirmed != true) return;
    await WallpaperHistoryStore.instance.clear();
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text('Wallpaper history', style: theme.textTheme.displaySmall),
        backgroundColor: theme.primaryColor,
        actions: <Widget>[
          if (_items.isNotEmpty)
            TextButton(
              onPressed: _confirmClear,
              child: Text('Clear history', style: TextStyle(color: theme.colorScheme.error)),
            ),
        ],
      ),
      backgroundColor: theme.primaryColor,
      body: _items.isEmpty
          ? const GlintState(
              kind: GlintStateKind.empty,
              title: 'No wallpapers yet',
              body: 'Wallpapers you set will show up here, so you can set them again.',
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.52,
              ),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final AppliedWallpaper item = _items[index];
                return AppliedWallpaperTile(key: ValueKey(item.id), item: item, onTap: () => _setAgain(item));
              },
            ),
    );
  }
}
