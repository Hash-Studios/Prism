import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/jam_icons_icons.dart';
// import 'package:Prism/ui/widgets/popup/proPopUp.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:flutter/material.dart';

class PremiumList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        main.prefs.get("premium") == true
            ? Container()
            : Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Premium',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).accentColor,
                    ),
                  ),
                ),
              ),
        main.prefs.get("premium") == true
            ? Container()
            : ListTile(
                onTap: () {
                  if (!main.prefs.get("isLoggedin")) {
                    googleSignInPopUp(context, () {
                      if (main.prefs.get("premium")) {
                        main.RestartWidget.restartApp(context);
                      } else {
                        Navigator.pushNamed(context, PremiumRoute);
                        // premiumPopUp(context, () {
                        //   main.RestartWidget.restartApp(context);
                        // });
                      }
                    });
                  } else {
                    Navigator.pushNamed(context, PremiumRoute);
                    // premiumPopUp(context, () {
                    //   main.RestartWidget.restartApp(context);
                    // });
                  }
                },
                leading: Icon(JamIcons.instant_picture_f),
                title: Text(
                  "Buy Premium",
                  style: TextStyle(
                      color: Theme.of(context).accentColor,
                      fontWeight: FontWeight.w500,
                      fontFamily: "Proxima Nova"),
                ),
                subtitle: Text(
                  "Get unlimited setups and filters.",
                  style: TextStyle(fontSize: 12),
                ),
              ),
      ],
    );
  }
}
