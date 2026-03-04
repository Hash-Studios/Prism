import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/persistence/data_sources/favorites_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/favouriteIcon.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:flutter/material.dart';

class FavIconButton extends StatefulWidget {
  final String? id;
  final FavouriteWallEntity? wall;
  const FavIconButton({required this.id, this.wall, super.key});

  @override
  _FavIconButtonState createState() => _FavIconButtonState();
}

class _FavIconButtonState extends State<FavIconButton> {
  final FavoritesLocalDataSource _favoritesLocal = getIt<FavoritesLocalDataSource>();

  @override
  void initState() => super.initState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FavoriteIcon(
          valueChanged: () {
            if (app_state.prismUser.loggedIn == false) {
              googleSignInPopUp(context, () {
                onFav(widget.wall);
              });
            } else {
              onFav(widget.wall);
            }
          },
          iconColor: Theme.of(context).colorScheme.secondary,
          iconSize: 30,
          isFavorite: _favoritesLocal.isWallFavourite(app_state.prismUser.id, widget.id ?? ''),
        ),
      ],
    );
  }

  Future<void> onFav(FavouriteWallEntity? wall) async {
    setState(() {});
    if (wall == null) {
      return;
    }
    context.favouriteWallsAdapter(listen: false).favCheck(wall).then((value) {
      analytics.track(FavStatusChangedEvent(wallId: wall.id, provider: wall.source.legacyProviderString));
      setState(() {});
    });
  }
}
