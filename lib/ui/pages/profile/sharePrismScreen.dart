import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/popup/contriPopUp.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';

class SharePrismScreen extends StatelessWidget {
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
            child: ListView(
              children: [
                const SizedBox(
                  height: 20,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SvgPicture.string(
                    prismRoundedSquareIcon,
                    height: 70,
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "Prism Wallpapers",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyText2
                      .copyWith(color: Theme.of(context).accentColor),
                ),
                Text(
                  "Version ${globals.currentAppVersion}+${globals.currentAppVersionCode}",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyText2.copyWith(
                      color: Theme.of(context).accentColor.withOpacity(0.5)),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "A feature-rich wallpaper and setup manager for Android.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyText2.copyWith(
                      color: Theme.of(context).accentColor.withOpacity(0.5)),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Divider(),
              ],
            )),
      ),
    );
  }
}
