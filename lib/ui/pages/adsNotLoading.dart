import 'package:Prism/logger/logger.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/popup/signInPopUp.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/main.dart' as main;

class AdsNotLoading extends StatelessWidget {
  const AdsNotLoading({Key? key}) : super(key: key);

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    logger.d(navStack.toString());
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(JamIcons.close),
              onPressed: () {
                navStack.removeLast();
                logger.d(navStack.toString());
                Navigator.pop(context);
              }),
          title: Text(
            "Ads Error",
            style: Theme.of(context).textTheme.headline3,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: SizedBox(
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.height,
            child: Column(
              children: [
                const Spacer(),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child:
                      Center(child: Text("🥲", style: TextStyle(fontSize: 80))),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "Unable to load reward ad",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyText2!.copyWith(
                      color: Theme.of(context).accentColor, fontSize: 24),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Divider(),
                const SizedBox(
                  height: 10,
                ),
                Container(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Text(
                    "Possible Reasons",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headline3,
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "➡️ Google has put ads on hold for us (common).",
                        textAlign: TextAlign.left,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2!
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "➡️ Your device's network connection is poor.",
                        textAlign: TextAlign.left,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2!
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "➡️ You're running an AdBlocker which is preventing us from loading ads.",
                        textAlign: TextAlign.left,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2!
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                    ),
                    const SizedBox(
                      height: 32,
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text(
                        "Please check your network settings and try again. We have although downloaded the wall for you, because we get it, that it's frustating when the ads don't laod.",
                        textAlign: TextAlign.left,
                        style: Theme.of(context)
                            .textTheme
                            .bodyText2!
                            .copyWith(color: Theme.of(context).accentColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                const Divider(),
                const SizedBox(
                  height: 10,
                ),
                const SizedBox(
                  height: 10,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    FlatButton(
                      shape: const StadiumBorder(),
                      color: Theme.of(context).errorColor,
                      onPressed: () {
                        if (globals.prismUser.loggedIn == false) {
                          googleSignInPopUp(context, () {
                            Navigator.of(context).pop();
                            Navigator.pushNamed(context, premiumRoute);
                          });
                        } else {
                          Navigator.of(context).pop();
                          Navigator.pushNamed(context, premiumRoute);
                        }
                      },
                      child: Text(
                        'BUY PREMIUM',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                    ),
                    FlatButton(
                      shape: const StadiumBorder(),
                      color: Theme.of(context).errorColor,
                      onPressed: () {
                        main.RestartWidget.restartApp(context);
                      },
                      child: Text(
                        'RESTART APP',
                        style: TextStyle(
                          fontSize: 16.0,
                          color: Theme.of(context).accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            )),
        // bottomNavigationBar: SizedBox(
        //   width: MediaQuery.of(context).size.width,
        //   child: Padding(
        //     padding: const EdgeInsets.all(8.0),
        //     child: Text(
        //       "Your download is complete.",
        //       textAlign: TextAlign.center,
        //       style: Theme.of(context)
        //           .textTheme
        //           .bodyText2!
        //           .copyWith(color: Theme.of(context).accentColor),
        //     ),
        //   ),
        // ),
      ),
    );
  }
}
