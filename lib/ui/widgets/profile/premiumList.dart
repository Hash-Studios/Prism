import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:flutter/material.dart';

class PremiumList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        if (main.prefs.get("premium") == true)
          Container()
        else
          ListTile(
            onTap: () {
              if (main.prefs.get("isLoggedin") == false) {
                googleSignInPopUp(context, () {
                  if (main.prefs.get("premium") == true) {
                    main.RestartWidget.restartApp(context);
                  } else {
                    Navigator.pushNamed(context, premiumRoute);
                  }
                });
              } else {
                Navigator.pushNamed(context, premiumRoute);
              }
            },
            leading: const Icon(JamIcons.instant_picture_f),
            title: Text(
              "Buy Premium",
              style: TextStyle(
                  color: Theme.of(context).accentColor,
                  fontWeight: FontWeight.w500,
                  fontFamily: "Proxima Nova"),
            ),
            subtitle: const Text(
              "Get unlimited setups and filters.",
              style: TextStyle(fontSize: 12),
            ),
          ),
      ],
    );
  }
}
