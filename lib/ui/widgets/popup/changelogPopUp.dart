import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';

void showChangelog(BuildContext context, Function func) {
  final controller = ScrollController();
  Dialog aboutPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 150,
            width: MediaQuery.of(context).size.width * .78,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                color: Theme.of(context).hintColor),
            child: FlareActor(
              "assets/animations/Changelog.flr",
              isPaused: false,
              alignment: Alignment.center,
              animation: "changelog",
            ),
          ),
          SizedBox(
            height: 400,
            child: Scrollbar(
              controller: controller,
              isAlwaysShown: true,
              child: SingleChildScrollView(
                controller: controller,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ChangeVersion(number: 'v2.5.5'),
                  Change(
                      icon: JamIcons.upload,
                      text: "Premium uploads get reviewed instantly now."),
                  Change(
                      icon: JamIcons.instant_picture,
                      text:
                          "Added collections, find similar wallpapers easily."),
                  Change(
                      icon: JamIcons.bug,
                      text: "Major bug fixes and improvements."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.5.4'),
                  Change(
                      icon: JamIcons.instant_picture,
                      text:
                          "Added wallpaper editing options before uploading."),
                  Change(
                      icon: JamIcons.history,
                      text:
                          "Improved overall caching, leading to low internet usage."),
                  Change(icon: JamIcons.bug, text: "Major bug fixes."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.5.3'),
                  Change(
                      icon: JamIcons.instant_picture,
                      text: "Added long press to crop wallpapers."),
                  Change(
                      icon: JamIcons.bell,
                      text: "Added ability to unsubscribe notifications."),
                  Change(icon: JamIcons.bug, text: "Minor bug fixes."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.5.2'),
                  Change(
                      icon: JamIcons.instant_picture,
                      text: "Added carousel widget in home screen."),
                  Change(
                      icon: JamIcons.download,
                      text:
                          "Added rewarded video ads for wallpaper downloads."),
                  Change(
                      icon: JamIcons.bell,
                      text: "Added all-new notifications center."),
                  Change(icon: JamIcons.bug, text: "Minor bug fixes."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.5.1'),
                  Change(
                      icon: JamIcons.dashboard,
                      text:
                          "Added option to switch to high-quality thumbnails."),
                  Change(
                      icon: JamIcons.world,
                      text: "Added no network indicator."),
                  Change(icon: JamIcons.bug, text: "Minor bug fixes."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.5.0'),
                  Change(
                      icon: JamIcons.user,
                      text: "Added option to view other users' profile."),
                  Change(
                      icon: JamIcons.brush,
                      text: "Added option to copy color codes by long-press."),
                  Change(
                      icon: JamIcons.bug,
                      text: "Major bug fixes and improvements."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.9'),
                  Change(
                      icon: JamIcons.bug,
                      text: "Fixed excessive requests and rebuilding."),
                  Change(
                      icon: JamIcons.arrow_circle_up,
                      text: "Added scroll to top button."),
                  Change(
                      icon: JamIcons.database,
                      text: "Added dynamic categories."),
                  Change(
                      icon: JamIcons.history, text: "Added cache to images."),
                  Change(icon: JamIcons.bug, text: "Minor bug fixes."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.8'),
                  Change(
                      icon: JamIcons.coin,
                      text: "Added new payments experience."),
                  Change(
                      icon: JamIcons.instant_picture,
                      text: "Wallpapers are now sorted by latest."),
                  Change(
                      icon: JamIcons.phone,
                      text:
                          "Simplified UI, easily switch between different categories."),
                  Change(
                      icon: JamIcons.search,
                      text:
                          "Added option to change search provider (WallHaven & Pexels)."),
                  Change(icon: JamIcons.bug, text: "Minor bug fixes."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.7'),
                  Change(
                      icon: JamIcons.crown,
                      text:
                          "Added Prism Premium, for the personalisation lords."),
                  Change(
                      icon: JamIcons.instant_picture,
                      text: "Setups added, change the way of personalisation."),
                  Change(
                      icon: JamIcons.heart,
                      text: "Favourites moved to profile."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.6'),
                  Change(
                    icon: JamIcons.database,
                    text: "Improved data caching.",
                  ),
                  Change(
                    icon: JamIcons.world,
                    text: "Fixed excessive internet usage.",
                  ),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.5'),
                  Change(
                      icon: JamIcons.bell,
                      text: "Removed excessive notifications."),
                  Change(
                      icon: JamIcons.world,
                      text: "Added Internet connectivity checks."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.4'),
                  Change(
                      icon: JamIcons.database,
                      text: "Added upto 24 new Categories."),
                  Change(icon: JamIcons.upload, text: "Added upload section."),
                  Change(icon: JamIcons.wrench, text: "Added new themes page."),
                  Change(icon: JamIcons.clock, text: "Added new animations."),
                  Change(
                      icon: JamIcons.user,
                      text: "Redesigned Profile section UI."),
                  Change(icon: JamIcons.bug, text: "Major bug fixes."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.3'),
                  Change(
                      icon: JamIcons.picture,
                      text: "Added over 300+ exclusive wallpapers."),
                  Change(
                      icon: JamIcons.pictures,
                      text:
                          "Added Variants, lets switch between color variants of a wallpaper."),
                  Change(
                      icon: JamIcons.bell,
                      text: "Added new notification center."),
                  Change(
                      icon: JamIcons.user,
                      text: "Improved user experience overall."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.2'),
                  Change(
                      icon: JamIcons.bell,
                      text: "Improved overall notifications."),
                  Change(
                    icon: JamIcons.bug,
                    text: "Minor bug fixes.",
                  ),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.1'),
                  Change(icon: JamIcons.bug, text: "Minor bug fixes."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.4.0'),
                  Change(
                      icon: JamIcons.bug,
                      text: "Major bug fixes and improvements."),
                  Change(
                      icon: JamIcons.mountain,
                      text: "Redesigned the wallpaper info sheet."),
                  Change(
                      icon: JamIcons.home,
                      text: "Added swipe to change categories."),
                  Change(
                      icon: JamIcons.bar_chart,
                      text: "Added Firebase analytics."),
                  Change(
                      icon: JamIcons.bell,
                      text: "Added notifications support."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.3.5'),
                  Change(
                      icon: JamIcons.bug,
                      text: "Major bug fixes and improvements."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.3.0'),
                  Change(icon: JamIcons.brush, text: "Changed app icon."),
                  Change(
                      icon: JamIcons.history,
                      text: "Added backwards compatibility."),
                  Change(
                      icon: JamIcons.user, text: "Redesigned profile page UI."),
                  Change(
                      icon: JamIcons.heart,
                      text: "Fixed favourites and downloads."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.2.0'),
                  Change(
                      icon: JamIcons.clock,
                      text: "Added clock overlay to test wallpapers."),
                  Change(
                      icon: JamIcons.share_alt,
                      text: "Added ability to share wallpapers."),
                  Change(
                      icon: JamIcons.pie_chart_alt,
                      text: "Added ability to clear app cache."),
                  Change(
                      icon: JamIcons.bug, text: "Major bug fixes and tweaks."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.0.0'),
                  Change(
                      icon: JamIcons.phone,
                      text: "Completely new redesigned UI."),
                  Change(
                      icon: JamIcons.camera, text: "Added Pexels API support."),
                  Change(
                      icon: JamIcons.search, text: "Added new color search."),
                  Change(icon: JamIcons.brush, text: "Added new themes."),
                  Change(
                      icon: JamIcons.pictures, text: "Added 1M+ wallpapers."),
                  Change(
                      icon: JamIcons.google,
                      text: "Added non intrusive sign in support."),
                  Change(
                      icon: JamIcons.settings_alt,
                      text: "Added new quick wallpaper actions."),
                  Change(
                      icon: JamIcons.eyedropper,
                      text: "Added new palette generator."),
                ]),
              ),
            ),
          ),
          SizedBox(
            height: 25,
          ),
          FlatButton(
            shape: StadiumBorder(),
            color: Color(0xFFE57697),
            onPressed: () {
              Navigator.of(context).pop();
              func();
            },
            child: Text(
              'CLOSE',
              style: TextStyle(
                fontSize: 16.0,
                color: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 15,
          ),
        ],
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => aboutPopUp);
}

class ChangeVersion extends StatelessWidget {
  final String number;
  ChangeVersion({@required this.number});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
              child: Text(
                number,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Theme.of(context).accentColor),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 20,
        ),
      ],
    );
  }
}

class Change extends StatelessWidget {
  final IconData icon;
  final String text;
  Change({@required this.icon, @required this.text});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: 20,
            ),
            Icon(
              icon,
              size: 22,
              color: Color(0xFFE57697),
            ),
            SizedBox(
              width: 20,
            ),
            Container(
              width: MediaQuery.of(context).size.width * 0.6,
              child: Text(
                text,
                style: Theme.of(context)
                    .textTheme
                    .headline6
                    .copyWith(color: Theme.of(context).accentColor),
              ),
            ),
          ],
        ),
        SizedBox(
          height: 10,
        ),
      ],
    );
  }
}
