import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class FavouriteWallpaperButton extends StatelessWidget {
  const FavouriteWallpaperButton({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        print("Fav");
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.25),
                blurRadius: 4,
                offset: Offset(0, 4))
          ],
          borderRadius: BorderRadius.circular(500),
        ),
        padding: EdgeInsets.all(17),
        child: Icon(
          JamIcons.heart,
          color: Theme.of(context).accentColor,
          size: 30,
        ),
      ),
    );
  }
}
