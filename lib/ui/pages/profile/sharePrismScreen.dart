import 'package:Prism/data/share/createDynamicLink.dart';
import 'package:Prism/routes/router.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:Prism/theme/config.dart' as config;
import 'package:share/share.dart';
import 'package:Prism/theme/toasts.dart' as toasts;

class SharePrismScreen extends StatefulWidget {
  @override
  _SharePrismScreenState createState() => _SharePrismScreenState();
}

class _SharePrismScreenState extends State<SharePrismScreen> {
  String link = "";
  @override
  void initState() {
    super.initState();
    getLink();
  }

  Future<void> getLink() async {
    if (main.prefs.get("id") == "" || main.prefs.get("id") == null) {
    } else {
      await createSharingPrismLink(main.prefs.get("id").toString())
          .then((value) => setState(() {
                link = value;
              }));
    }
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    debugPrint(navStack.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            "Share",
            style: Theme.of(context).textTheme.headline3,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: Container(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  height: 20,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 2,
                      height: 70,
                      child: const FlareActor(
                        "assets/animations/Text.flr",
                        animation: "Untitled",
                      ),
                    ),
                  ),
                ),
                //TODO Replace the animation with Share animation
                Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 20),
                  child: Center(
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width / 2,
                      height: 70,
                      child: const FlareActor(
                        "assets/animations/Text.flr",
                        animation: "Untitled",
                      ),
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "Share Prism with friends",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyText2.copyWith(
                      fontSize: 18, color: Theme.of(context).accentColor),
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "Get 50 coins when your friend launches the app from the link!",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyText2.copyWith(
                        color: Theme.of(context).accentColor.withOpacity(0.5)),
                  ),
                ),
                Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    "They also get 50 coins, which you can spend on exclusives.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyText2.copyWith(
                        color: Theme.of(context).accentColor.withOpacity(0.5)),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                FlatButton(
                  disabledColor: Theme.of(context).accentColor.withOpacity(0.5),
                  shape: const StadiumBorder(),
                  color: link == ""
                      ? Theme.of(context).accentColor.withOpacity(0.5)
                      : config.Colors().mainAccentColor(1),
                  onPressed: link == ""
                      ? () {
                          toasts.error(
                            "Sign in to generate unique referral link!",
                          );
                        }
                      : () {
                          Share.share(link);
                        },
                  child: const Text(
                    'SHARE INVITE',
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                const SizedBox(
                  height: 15,
                ),
              ],
            )),
      ),
    );
  }
}
