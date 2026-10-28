import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/favourite_icon.dart';
import 'package:Prism/core/widgets/animated/glint_toast.dart';
import 'package:Prism/core/widgets/glint/glint.dart';
import 'package:Prism/core/widgets/menu_button/circular_menu_button.dart';
import 'package:Prism/features/favourite_walls/biz/bloc/favourite_walls_bloc.j.dart';
import 'package:Prism/features/favourite_walls/data/guest_favourites_store.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/features/folders/views/widgets/folder_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FavouriteWallpaperButton extends StatefulWidget {
  final FavouriteWallEntity? wall;
  final bool trash;
  final VoidCallback? onFavourited;
  const FavouriteWallpaperButton({required this.wall, required this.trash, this.onFavourited, super.key});

  @override
  _FavouriteWallpaperButtonState createState() => _FavouriteWallpaperButtonState();
}

class _FavouriteWallpaperButtonState extends State<FavouriteWallpaperButton> {
  final FavoritesLocalDataSource _favoritesLocal = getIt<FavoritesLocalDataSource>();
  late bool isLoading;
  Timer? _tapLock;

  @override
  void initState() {
    isLoading = false;
    super.initState();
  }

  @override
  void dispose() {
    _tapLock?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when a save made elsewhere, such as the folder sheet, changes this wall's favourite.
    // Some hosts have no FavouriteWallsBloc; the heart then reads the local store only.
    context.select<FavouriteWallsBloc?, bool>(
      (bloc) => bloc?.state.items.any((item) => item.id == widget.wall?.id) ?? false,
    );
    final bool isFavorite = _favoritesLocal.isWallFavourite(app_state.prismUser.id, widget.wall?.id ?? '');
    // The glass action bar keeps the heart of the current app: the theme ink, 30 points, in a 53 point target.
    final bool flat = FlatMenuButtons.of(context);
    final ColorScheme cs = Theme.of(context).colorScheme;
    final FavouriteWallEntity? wall = widget.wall;
    final VoidCallback? openFolders = wall == null || wall is LegacyFavouriteWall
        ? null
        : () => unawaited(showFolderSheet(context, wall));
    return Semantics(
      onLongPressHint: context.l10n.foldersSaveToFolder,
      onLongPress: openFolders,
      child: GestureDetector(onLongPress: openFolders, child: _heart(context, isFavorite, flat, cs)),
    );
  }

  Widget _heart(BuildContext context, bool isFavorite, bool flat, ColorScheme cs) {
    return CircularMenuButton(
      label: context.l10n.coreFavourite,
      selected: isFavorite,
      isLoading: isLoading,
      padding: EdgeInsets.zero,
      child: FavoriteIcon(
        tapTargetExtent: flat ? 53 : CircularMenuButton.size,
        valueChanged: () {
          if (_tapLock?.isActive ?? false) return;
          _tapLock = Timer(const Duration(milliseconds: 300), () {});
          if (isFavorite) {
            PrismHaptics.tap();
          } else {
            PrismHaptics.impact();
          }
          onFav(widget.wall, desired: !isFavorite);
        },
        iconColor: flat || !isFavorite ? cs.onSurface : cs.primary,
        iconSize: flat ? 30 : 32,
        isFavorite: isFavorite,
      ),
    );
  }

  Future<bool> onFav(FavouriteWallEntity? wall, {required bool desired}) async {
    if (wall == null) return false;
    final AppLocalizations l10n = context.l10n;
    setState(() {
      isLoading = true;
    });
    bool success = false;
    try {
      final adapter = context.favouriteWallsAdapter(listen: false);
      success = await adapter.favCheck(wall, desired: desired);
    } catch (error, stackTrace) {
      logger.w('Favourite toggle failed', error: error, stackTrace: stackTrace);
    }
    if (success) {
      // The write already landed. Each follow-up runs on its own, so one failure does not skip the others,
      // hide the save, or leave the spinner on.
      _followUp(
        () => analytics.track(
          FavStatusChangedEvent(wallId: wall.id, provider: wall.source.legacyProviderString, isFavourite: desired),
        ),
      );
      if (_favoritesLocal.isWallFavourite(app_state.prismUser.id, wall.id)) {
        _followUp(() => widget.onFavourited?.call());
      }
      if (desired) {
        if (mounted) {
          _followUp(() => showGlintToast(context, mood: GlintMood.love));
          _followUp(() => _offerFolders(l10n, wall));
        }
        if (app_state.prismUser.id.isEmpty) {
          try {
            await _noteGuestSave(l10n);
          } catch (error, stackTrace) {
            logger.w('Favourite follow-up failed', error: error, stackTrace: stackTrace);
          }
        }
      }
    } else {
      toasts.error(l10n.coreCouldNotUpdateFavourites);
    }
    if (!mounted) return success;
    setState(() {
      isLoading = false;
    });
    if (success && widget.trash) {
      Navigator.pop(context);
    }
    return success;
  }

  void _offerFolders(AppLocalizations l10n, FavouriteWallEntity wall) {
    if (wall is LegacyFavouriteWall) return;
    toasts.success(
      l10n.wallpaperFavouriteAddedToast,
      haptic: false,
      action: (
        label: l10n.foldersAddToFolder,
        onPressed: () {
          if (mounted) unawaited(showFolderSheet(context, wall));
        },
      ),
    );
  }

  void _followUp(VoidCallback step) {
    try {
      step();
    } catch (error, stackTrace) {
      logger.w('Favourite follow-up failed', error: error, stackTrace: stackTrace);
    }
  }

  Future<void> _noteGuestSave(AppLocalizations l10n) async {
    _followUp(() => analytics.track(const FavouriteSavedAsGuestEvent()));
    final int saved = (await getIt<GuestFavouritesStore>().readAll()).length;
    if (saved == 3) toasts.info(l10n.coreSignInToSyncFavourites);
  }
}
