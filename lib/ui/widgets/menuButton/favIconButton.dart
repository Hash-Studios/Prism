import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/favourites/provider/favouriteProvider.dart';
import 'package:Prism/data/pexels/model/wallpaperp.dart';
import 'package:Prism/data/wallhaven/model/wallpaper.dart';
import 'package:Prism/ui/widgets/animated/favouriteIcon.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:hive/hive.dart';
import 'package:provider/provider.dart';

class FavIconButton extends StatefulWidget {
  final String? id;
  final Map? prism;
  const FavIconButton({
    required this.id,
    this.prism,
    Key? key,
  }) : super(key: key);

  @override
  _FavIconButtonState createState() => _FavIconButtonState();
}

class _FavIconButtonState extends State<FavIconButton> {
  late Box box;

  @override
  void initState() {
    box = Hive.box('localFav');
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FavoriteIcon(
          valueChanged: () {
            if (main.prefs.get("isLoggedin") == false) {
              googleSignInPopUp(context, () {
                onFav(widget.id, "Prism", null, null, widget.prism);
              });
            } else {
              onFav(widget.id, "Prism", null, null, widget.prism);
            }
          },
          iconColor: Theme.of(context).accentColor,
          iconSize: 30,
          isFavorite: box.get(widget.id, defaultValue: false) as bool,
        ),
      ],
    );
  }

  Future<void> onFav(String? id, String provider, WallPaper? wallhaven,
      WallPaperP? pexels, Map? prism) async {
    setState(() {});
    Provider.of<FavouriteProvider>(context, listen: false)
        .favCheck(id, provider, wallhaven, pexels, prism)
        .then((value) {
      analytics.logEvent(
          name: 'fav_status_changed',
          parameters: {'id': id, 'provider': provider});
      setState(() {});
    });
  }
}
