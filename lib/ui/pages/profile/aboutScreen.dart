import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/theme.dart';
import 'package:Prism/theme/themeModel.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/ui/widgets/popup/contriPopUp.dart';
import 'package:Prism/ui/widgets/profile/prismList.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:github/github.dart';
import 'package:provider/provider.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  Future<List<Contributor>> printStream() async {
    final github = GitHub();
    final Stream<Contributor> contri = github.repositories
        .listContributors(RepositorySlug("Hash-Studios", "Prism"));
    final List<Contributor> listContri = [];
    await for (final value in contri) {
      listContri.add(value);
    }
    return listContri;
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
          leading: IconButton(
              icon: const Icon(JamIcons.close),
              onPressed: () {
                navStack.removeLast();
                debugPrint(navStack.toString());
                Navigator.pop(context);
              }),
          title: Text(
            "About",
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
                    child: Image.asset(
                      "assets/images/prism.png",
                      height: 70,
                    )
                    //  SvgPicture.string(
                    //   prismRoundedSquareIcon,
                    //   height: 70,
                    // ),
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
                Wrap(
                  alignment: WrapAlignment.center,
                  children: const [
                    ActionButton(
                      icon: JamIcons.github,
                      text: "GITHUB",
                      link: "https://www.github.com/Hash-Studios/Prism",
                    ),
                    ActionButton(
                      icon: JamIcons.star_full,
                      text: "RATE",
                      link:
                          "https://play.google.com/store/apps/details?id=com.hash.prism",
                    ),
                    ActionButton(
                      icon: JamIcons.twitter,
                      text: "TWITTER",
                      link: "https://twitter.com/PrismWallpapers",
                    ),
                    ActionButton(
                      icon: JamIcons.instagram,
                      text: "INSTAGRAM",
                      link: "https://www.instagram.com/prismwallpapers",
                    ),
                    ActionButton(
                      icon: JamIcons.paper_plane,
                      text: "TELEGRAM",
                      link: "http://t.me/PrismWallpapers",
                    ),
                  ],
                ),
                const SizedBox(
                  height: 10,
                ),
                const Divider(),
                Container(
                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Text(
                    "The Team",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headline3,
                  ),
                ),
                FutureBuilder<List<Contributor>>(
                  future: printStream(),
                  builder: (context, snapshot) {
                    if (snapshot == null) {
                      debugPrint("snapshot null");
                      return SizedBox(
                          height: 250, child: Center(child: Loader()));
                    }
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        snapshot.connectionState == ConnectionState.none) {
                      debugPrint("snapshot none, waiting");
                      return SizedBox(
                          height: 250, child: Center(child: Loader()));
                    } else {
                      final List<Widget> tiles = [];
                      tiles.add(Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ContributorWidget(
                            contributor: snapshot.data[1],
                            radius: 35,
                          ),
                          ContributorWidget(
                            contributor: snapshot.data[0],
                            radius: 45,
                          ),
                          ContributorWidget(
                            contributor: snapshot.data[2],
                            radius: 35,
                          ),
                        ],
                      ));
                      tiles.add(
                        const SizedBox(
                          height: 10,
                        ),
                      );
                      tiles.add(
                        const Divider(),
                      );
                      tiles.add(
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          width: MediaQuery.of(context).size.width * 0.9,
                          child: Text(
                            "Other Contributors",
                            style: Theme.of(context).textTheme.headline3,
                          ),
                        ),
                      );
                      for (final Contributor c in snapshot.data) {
                        if (snapshot.data.indexOf(c) == 0 ||
                            snapshot.data.indexOf(c) == 1 ||
                            snapshot.data.indexOf(c) == 2) {
                        } else {
                          tiles.add(ListTile(
                            leading: CircleAvatar(
                              backgroundImage:
                                  CachedNetworkImageProvider(c.avatarUrl),
                            ),
                            title: Text(
                              c.login,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText2
                                  .copyWith(
                                      color: Theme.of(context).accentColor),
                            ),
                            subtitle: Text(
                              c.contributions == 1
                                  ? "${c.contributions} commit"
                                  : "${c.contributions} commits",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyText2
                                  .copyWith(
                                      color: Theme.of(context)
                                          .accentColor
                                          .withOpacity(0.5)),
                            ),
                            onTap: () {
                              launch(c.htmlUrl);
                            },
                          ));
                        }
                      }
                      return Column(children: tiles);
                    }
                  },
                ),
                const Divider(),
                PrismList(),
              ],
            )),
        bottomNavigationBar: Container(
          width: MediaQuery.of(context).size.width,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Made with ❤ in India with Flutter!",
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyText2
                  .copyWith(color: Theme.of(context).accentColor),
            ),
          ),
        ),
      ),
    );
  }
}

class ContributorWidget extends StatelessWidget {
  const ContributorWidget({
    Key key,
    @required this.contributor,
    @required this.radius,
  }) : super(key: key);
  final Contributor contributor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showContributorDetails(context, contributor.login);
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundImage:
                CachedNetworkImageProvider(contributor.avatarUrl ?? ""),
            radius: radius,
          ),
          const SizedBox(
            height: 5,
          ),
          Container(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Text(
              contributor.login,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyText2
                  .copyWith(color: Theme.of(context).accentColor),
            ),
          ),
          Container(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Text(
              "${contributor.contributions} commits",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyText2.copyWith(
                  color: Theme.of(context).accentColor.withOpacity(0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    Key key,
    @required this.icon,
    @required this.link,
    @required this.text,
  }) : super(key: key);
  final IconData icon;
  final String text;
  final String link;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ActionChip(
          avatar: Icon(
            icon,
            color: Provider.of<ThemeModel>(context).currentTheme == kDarkTheme2
                ? config.Colors().mainAccentColor(1) == Colors.black
                    ? Theme.of(context).accentColor
                    : config.Colors().mainAccentColor(1)
                : config.Colors().mainAccentColor(1),
          ),
          label: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyText2.copyWith(
                color: Theme.of(context).accentColor,
                fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            launch(link);
          }),
    );
  }
}
