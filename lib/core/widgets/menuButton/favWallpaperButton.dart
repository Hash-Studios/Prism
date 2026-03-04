import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/core/widgets/animated/favouriteIcon.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/features/favourite_walls/domain/entities/favourite_wall_entity.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/material.dart';
import 'package:hive_io/hive_io.dart';

class FavouriteWallpaperButton extends StatefulWidget {
  final FavouriteWallEntity? wall;
  final bool trash;
  const FavouriteWallpaperButton({required this.wall, required this.trash, super.key});

  @override
  _FavouriteWallpaperButtonState createState() => _FavouriteWallpaperButtonState();
}

class _FavouriteWallpaperButtonState extends State<FavouriteWallpaperButton> {
  late bool isLoading;
  late Box box;

  @override
  void initState() {
    isLoading = false;
    box = Hive.box('localFav');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4)),
            ],
            borderRadius: BorderRadius.circular(500),
          ),
          padding: const EdgeInsets.all(17),
          child: FavoriteIcon(
            valueChanged: () {
              if (app_state.prismUser.loggedIn == false) {
                googleSignInPopUp(context, () {
                  onFav(widget.wall);
                });
              } else {
                onFav(widget.wall);
              }
              if (widget.trash) {
                Navigator.pop(context);
              }
            },
            iconColor: Theme.of(context).colorScheme.secondary,
            iconSize: 30,
            isFavorite: box.get(widget.wall?.id ?? '', defaultValue: false) as bool,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          height: 53,
          width: 53,
          child: isLoading ? const CircularProgressIndicator() : Container(),
        ),
      ],
    );
  }

  Future<void> onFav(FavouriteWallEntity? wall) async {
    setState(() {
      isLoading = true;
    });
    if (wall == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }
    context.favouriteWallsAdapter(listen: false).favCheck(wall).then((value) {
      analytics.track(FavStatusChangedEvent(wallId: wall.id, provider: wall.source.legacyProviderString));
      setState(() {
        isLoading = false;
      });
    });
  }
}
