import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:animations/animations.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:provider/provider.dart';

void showChangelog(BuildContext context, Function func) {
  final controller = ScrollController();
  final AlertDialog aboutPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
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
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10)),
                color: Theme.of(context).hintColor),
            child: const FlareActor(
              "assets/animations/Changelog.flr",
              animation: "changelog",
            ),
          ),
          SizedBox(
            height: 300,
            child: Scrollbar(
              radius: const Radius.circular(500),
              thickness: 5,
              controller: controller,
              isAlwaysShown: true,
              child: SingleChildScrollView(
                controller: controller,
                child: Column(mainAxisSize: MainAxisSize.min, children: const [
                  ChangeVersion(number: 'v2.6.2'),
                  Change(
                      icon: JamIcons.picture,
                      text: "Improved wallpaper thumbnails."),
                  Change(
                      icon: JamIcons.info,
                      text: "Now users can report walls & setups."),
                  Change(
                      icon: JamIcons.settings_alt,
                      text: "Redesigned settings page."),
                  Change(
                      icon: JamIcons.upload,
                      text: "Fixed wallpaper uploading in setups."),
                  Change(
                      icon: JamIcons.pencil,
                      text: "Added 4 new filters (Blur, Invert & more!)"),
                  Change(icon: JamIcons.coin, text: "Redesigned premium page."),
                  Change(
                      icon: JamIcons.brush,
                      text: "Improved look & feel of the app."),
                  Change(
                      icon: JamIcons.bug,
                      text: "Minor bug fixes and improvements."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.6.1'),
                  Change(
                      icon: JamIcons.download,
                      text: "Fixed wallpaper downloading in Android 11."),
                  Change(
                      icon: JamIcons.wrench,
                      text: "Redesigned setups' info panel!"),
                  Change(
                      icon: JamIcons.instant_picture,
                      text: "Now see your uploaded setups in your profile!"),
                  Change(
                      icon: JamIcons.heart,
                      text: "Now see your favourite setups in your profile!"),
                  Change(
                      icon: JamIcons.tools, text: "Added more new animations!"),
                  Change(
                      icon: JamIcons.settings_alt,
                      text: "Turned wallpaper optimisation off by default."),
                  Change(icon: JamIcons.egg, text: "Added some easter eggs."),
                  Change(
                      icon: JamIcons.crop,
                      text: "Added new crop ratios in wallpaper upload."),
                  Change(
                      icon: JamIcons.phone,
                      text: "Added support for phones with smaller screens."),
                  Change(
                      icon: JamIcons.user_circle,
                      text: "Redesigned Profile Page."),
                  Change(
                      icon: JamIcons.bug,
                      text: "Minor bug fixes and improvements."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.6.0'),
                  Change(
                      icon: JamIcons.instant_picture,
                      text: "Setup uploading is out of beta."),
                  Change(icon: JamIcons.wrench, text: "All new themes!"),
                  Change(icon: JamIcons.brush, text: "Variants are now free!"),
                  Change(
                      icon: JamIcons.tools,
                      text: "Optimised app for faster animations!"),
                  Change(
                      icon: JamIcons.settings_alt,
                      text: "Improved settings page."),
                  Change(icon: JamIcons.home, text: "Redesigned home."),
                  Change(icon: JamIcons.grid, text: "Redesigned categories."),
                  Change(
                      icon: JamIcons.filter, text: "Added wallpaper filters."),
                  Change(
                      icon: JamIcons.database, text: "Improved data caching."),
                  Change(
                      icon: JamIcons.bug,
                      text: "Major bug fixes and improvements."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.5.7'),
                  Change(
                      icon: JamIcons.settings_alt,
                      text: "Redesigned settings screen."),
                  Change(
                      icon: JamIcons.background_color,
                      text: "Now customise accent color of the app."),
                  Change(
                      icon: JamIcons.share,
                      text: "Now share setups and profiles."),
                  Change(
                      icon: JamIcons.twitter,
                      text: "Now connect Twitter with your profile."),
                  Change(
                      icon: JamIcons.instagram,
                      text: "Now connect Instagram with your profile."),
                  Change(icon: JamIcons.android, text: "Redesigned app icon."),
                  Change(
                      icon: JamIcons.rocket,
                      text: "Redesigned splash animation."),
                  Change(
                      icon: JamIcons.paper_plane,
                      text: "Connected to Telegram group."),
                  Change(
                      icon: JamIcons.bug,
                      text: "Minor bug fixes and improvements."),
                  SizedBox(
                    height: 15,
                  ),
                  ChangeVersion(number: 'v2.5.6'),
                  Change(
                      icon: JamIcons.upload, text: "Now upload setups in-app."),
                  Change(
                      icon: JamIcons.pictures,
                      text: "Redesigned collections' screen."),
                  Change(
                      icon: JamIcons.clock, text: "Redesigned clock overlay."),
                  Change(
                      icon: JamIcons.instant_picture,
                      text: "Redesigned setups' browser."),
                  Change(
                      icon: JamIcons.refresh,
                      text: "Added wallpaper optimisation."),
                  Change(
                      icon: JamIcons.picture,
                      text: "Fixed curated wallpapers not loading."),
                  Change(
                      icon: JamIcons.bug,
                      text: "Major bug fixes and improvements."),
                  SizedBox(
                    height: 15,
                  ),
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
        ],
      ),
    ),
    actions: [
      FlatButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: config.Colors().mainAccentColor(1),
        onPressed: () {
          Navigator.of(context).pop();
          func();
        },
        child: const Text(
          'CLOSE',
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.white,
          ),
        ),
      ),
    ],
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    backgroundColor: Theme.of(context).primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
  );
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => aboutPopUp);
}

class ChangeVersion extends StatelessWidget {
  final String number;
  const ChangeVersion({@required this.number});
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
        const SizedBox(
          height: 20,
        ),
      ],
    );
  }
}

class Change extends StatelessWidget {
  final IconData icon;
  final String text;
  const Change({@required this.icon, @required this.text});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: [
            const SizedBox(
              width: 20,
            ),
            Icon(
              icon,
              size: 22,
              color:
                  Provider.of<ThemeModel>(context).currentTheme == kDarkTheme2
                      ? config.Colors().mainAccentColor(1) == Colors.black
                          ? Theme.of(context).accentColor
                          : config.Colors().mainAccentColor(1)
                      : config.Colors().mainAccentColor(1),
            ),
            const SizedBox(
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
        const SizedBox(
          height: 10,
        ),
      ],
    );
  }
}
