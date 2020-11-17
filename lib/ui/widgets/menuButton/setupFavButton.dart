import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/data/favourites/provider/favouriteSetupProvider.dart';
import 'package:Prism/data/setups/provider/setupProvider.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:Prism/main.dart' as main;

class SetupFavButton extends StatefulWidget {
  const SetupFavButton({
    Key key,
    @required this.index,
  }) : super(key: key);

  final int index;
  @override
  _SetupFavButtonState createState() => _SetupFavButtonState();
}

class _SetupFavButtonState extends State<SetupFavButton> {
  Future<void> onFavSetup(String id, Map setupMap) async {
    Provider.of<FavouriteSetupProvider>(context, listen: false)
        .favCheck(id, setupMap)
        .then((value) {
      analytics.logEvent(name: 'setup_fav_status_changed', parameters: {
        'id': id,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (main.prefs.get("isLoggedin") == false) {
          googleSignInPopUp(context, () {
            onFavSetup(
                Provider.of<SetupProvider>(context, listen: false)
                    .setups[widget.index]["id"]
                    .toString(),
                Provider.of<SetupProvider>(context, listen: false)
                    .setups[widget.index] as Map);
          });
        } else {
          onFavSetup(
              Provider.of<SetupProvider>(context, listen: false)
                  .setups[widget.index]["id"]
                  .toString(),
              Provider.of<SetupProvider>(context, listen: false)
                  .setups[widget.index] as Map);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor,
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(.25),
                blurRadius: 4,
                offset: const Offset(0, 4))
          ],
          borderRadius: BorderRadius.circular(500),
        ),
        padding: const EdgeInsets.all(17),
        child: Icon(
          JamIcons.heart,
          color: Theme.of(context).accentColor,
          size: 20,
        ),
      ),
    );
  }
}
