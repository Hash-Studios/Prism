import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/popup/contriPopUp.dart';
import 'package:Prism/features/public_profile/views/widgets/prism_list.dart';
import 'package:Prism/features/theme_mode/views/theme_mode_bloc_utils.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';

class AboutScreen extends StatelessWidget {
  Future<List<Contributor>> printStream() async {
    final github = GitHub();
    final Stream<Contributor> contri = github.repositories.listContributors(RepositorySlug("Hash-Studios", "Prism"));
    final List<Contributor> listContri = [];
    await for (final value in contri) {
      listContri.add(value);
    }
    return listContri;
  }

  Future<bool> onWillPop() async {
    popNavStackIfPossible();
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
                popNavStack();
                Navigator.pop(context);
              }),
          title: Text(
            "About",
            style: Theme.of(context).textTheme.displaySmall,
          ),
        ),
        backgroundColor: Theme.of(context).primaryColor,
        body: SizedBox(
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
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "Prism Wallpapers",
                  textAlign: TextAlign.center,
                  style:
                      Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
                ),
                Text(
                  "Version ${globals.currentAppVersion}+${globals.currentAppVersionCode}",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
                ),
                const SizedBox(
                  height: 10,
                ),
                Text(
                  "A feature-rich wallpaper and setup manager for Android.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
                ),
                const SizedBox(
                  height: 10,
                ),
                const Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    ActionButton(
                      icon: JamIcons.github,
                      text: "GITHUB",
                      link: "https://www.github.com/Hash-Studios/Prism",
                    ),
                    ActionButton(
                      icon: JamIcons.star_full,
                      text: "RATE",
                      link: "https://play.google.com/store/apps/details?id=com.hash.prism",
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
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                FutureBuilder<List<Contributor>>(
                  future: printStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting ||
                        snapshot.connectionState == ConnectionState.none) {
                      logger.d("snapshot none, waiting");
                      return SizedBox(height: 250, child: Center(child: Loader()));
                    } else {
                      final List<Widget> tiles = [];
                      tiles.add(Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ContributorWidget(
                            contributor: snapshot.data![1],
                            radius: 35,
                          ),
                          ContributorWidget(
                            contributor: snapshot.data![0],
                            radius: 45,
                          ),
                          ContributorWidget(
                            contributor: snapshot.data![2],
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
                            style: Theme.of(context).textTheme.displaySmall,
                          ),
                        ),
                      );
                      for (final Contributor c in snapshot.data!) {
                        if (snapshot.data!.indexOf(c) == 0 ||
                            snapshot.data!.indexOf(c) == 1 ||
                            snapshot.data!.indexOf(c) == 2) {
                        } else {
                          tiles.add(ListTile(
                            leading: CircleAvatar(
                              backgroundImage: CachedNetworkImageProvider(c.avatarUrl!),
                            ),
                            title: Text(
                              c.login!,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(color: Theme.of(context).colorScheme.secondary),
                            ),
                            subtitle: Text(
                              c.contributions == 1 ? "${c.contributions} commit" : "${c.contributions} commits",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
                            ),
                            onTap: () {
                              launch(c.htmlUrl!);
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
        bottomNavigationBar: SizedBox(
          width: MediaQuery.of(context).size.width,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              "Made with ❤ in India with Flutter!",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
        ),
      ),
    );
  }
}

class ContributorWidget extends StatelessWidget {
  const ContributorWidget({
    super.key,
    required this.contributor,
    required this.radius,
  });
  final Contributor contributor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showContributorDetails(context, contributor.login!);
      },
      child: Column(
        children: [
          CircleAvatar(
            backgroundImage: CachedNetworkImageProvider(contributor.avatarUrl ?? ""),
            radius: radius,
          ),
          const SizedBox(
            height: 5,
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Text(
              contributor.login!,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(color: Theme.of(context).colorScheme.secondary),
            ),
          ),
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.3,
            child: Text(
              "${contributor.contributions} commits",
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.link,
    required this.text,
  });
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
            color: context.prismModeStyleForContext() == "Dark" && context.prismIsAmoledDark()
                ? Theme.of(context).colorScheme.error == Colors.black
                    ? Theme.of(context).colorScheme.secondary
                    : Theme.of(context).colorScheme.error
                : Theme.of(context).colorScheme.error,
          ),
          label: Text(
            text,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
          ),
          onPressed: () {
            if (link.contains("@gmail.com")) {
              launch("mailto:$link");
            } else {
              launch(link);
            }
          }),
    );
  }
}
