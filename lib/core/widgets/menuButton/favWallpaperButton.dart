import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/widgets/animated/favouriteIcon.dart';
import 'package:Prism/core/widgets/popup/signInPopUp.dart';
import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/features/favourite_walls/views/favourite_walls_bloc_adapter.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:flutter/material.dart';
import 'package:hive_io/hive_io.dart';

class FavouriteWallpaperButton extends StatefulWidget {
  final String id;
  final String provider;
  final WallPaper? wallhaven;
  final WallPaperP? pexels;
  final Map? prism;
  final bool trash;
  const FavouriteWallpaperButton({
    required this.id,
    required this.provider,
    required this.trash,
    this.wallhaven,
    this.pexels,
    this.prism,
    super.key,
  });

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
                BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 4, offset: const Offset(0, 4))
              ],
              borderRadius: BorderRadius.circular(500),
            ),
            padding: const EdgeInsets.all(17),
            child: FavoriteIcon(
              valueChanged: () {
                if (globals.prismUser.loggedIn == false) {
                  googleSignInPopUp(context, () {
                    onFav(widget.id, widget.provider, widget.wallhaven, widget.pexels, widget.prism);
                  });
                } else {
                  onFav(widget.id, widget.provider, widget.wallhaven, widget.pexels, widget.prism);
                }
                if (widget.trash) {
                  Navigator.pop(context);
                }
              },
              iconColor: Theme.of(context).colorScheme.secondary,
              iconSize: 30,
              isFavorite: box.get(widget.id, defaultValue: false) as bool,
            )),
        Positioned(
            top: 0, left: 0, height: 53, width: 53, child: isLoading ? const CircularProgressIndicator() : Container())
      ],
    );
  }

  Future<void> onFav(String id, String provider, WallPaper? wallhaven, WallPaperP? pexels, Map? prism) async {
    setState(() {
      isLoading = true;
    });
    context.favouriteWallsAdapter(listen: false).favCheck(id, provider, wallhaven, pexels, prism).then((value) {
      analytics.logEvent(name: 'fav_status_changed', parameters: {'id': id, 'provider': provider});
      setState(() {
        isLoading = false;
      });
    });
  }
}
