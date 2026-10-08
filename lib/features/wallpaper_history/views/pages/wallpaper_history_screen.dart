import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/widgets/glint/glint_state.dart';
import 'package:Prism/core/widgets/menu_button/set_wallpaper_button.dart';
import 'package:Prism/features/wallpaper_history/biz/bloc/wallpaper_history_bloc.j.dart';
import 'package:Prism/features/wallpaper_history/domain/entities/applied_wallpaper.dart';
import 'package:Prism/features/wallpaper_history/views/widgets/applied_wallpaper_tile.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

@RoutePage()
class WallpaperHistoryScreen extends StatelessWidget {
  const WallpaperHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WallpaperHistoryBloc>(
      create: (_) => getIt<WallpaperHistoryBloc>()..add(const WallpaperHistoryEvent.started()),
      child: const _WallpaperHistoryView(),
    );
  }
}

class _WallpaperHistoryView extends StatelessWidget {
  const _WallpaperHistoryView();

  Future<void> _setAgain(BuildContext context, AppliedWallpaper item) async {
    PrismHaptics.tap();
    await SetWallpaperFlow.run(context, url: item.fullUrl, thumbnailUrl: item.thumbnailUrl, forceSheet: true);
    if (context.mounted) context.read<WallpaperHistoryBloc>().add(const WallpaperHistoryEvent.started());
  }

  void _remove(BuildContext context, AppliedWallpaper item) {
    PrismHaptics.tap();
    final WallpaperHistoryBloc bloc = context.read<WallpaperHistoryBloc>();
    bloc.add(WallpaperHistoryEvent.removed(item.id));
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Removed from history'),
          action: SnackBarAction(label: 'Undo', onPressed: () => bloc.add(WallpaperHistoryEvent.restored(item))),
        ),
      );
  }

  Future<void> _confirmClear(BuildContext context) async {
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
    if (context.mounted) context.read<WallpaperHistoryBloc>().add(const WallpaperHistoryEvent.cleared());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AppliedWallpaper> items = context.select((WallpaperHistoryBloc bloc) => bloc.state.items);
    final Set<String> currentIds = <String>{
      ?currentWallpaperFor(items, 'home')?.id,
      ?currentWallpaperFor(items, 'lock')?.id,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text('Wallpaper history', style: theme.textTheme.displaySmall),
        backgroundColor: theme.primaryColor,
        actions: <Widget>[
          if (items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context),
              child: Text('Clear history', style: TextStyle(color: theme.colorScheme.error)),
            ),
        ],
      ),
      backgroundColor: theme.primaryColor,
      body: items.isEmpty
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
              itemCount: items.length,
              itemBuilder: (context, index) {
                final AppliedWallpaper item = items[index];
                return Dismissible(
                  key: ValueKey(item.id),
                  background: const _RemoveBackground(alignment: Alignment.centerLeft),
                  secondaryBackground: const _RemoveBackground(alignment: Alignment.centerRight),
                  onDismissed: (_) => _remove(context, item),
                  child: AppliedWallpaperTile(
                    item: item,
                    isCurrent: currentIds.contains(item.id),
                    onTap: () => _setAgain(context, item),
                    onRemove: () => _remove(context, item),
                  ),
                );
              },
            ),
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(color: scheme.error.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
      child: Icon(JamIcons.trash_alt, color: scheme.error),
    );
  }
}
