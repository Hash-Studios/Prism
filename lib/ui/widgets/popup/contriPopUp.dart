import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/pages/profile/aboutScreen.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;
import 'package:Prism/main.dart' as main;
import 'package:github/github.dart';
import 'package:url_launcher/url_launcher.dart';

void showContributorDetails(BuildContext context, String username) {
  Future<User> getUser(String username) async {
    final github = GitHub();
    User user;
    await github.users.getUser(username).then((value) {
      user = value;
    });
    print(user.blog);
    return user;
  }

  final Dialog userPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: FutureBuilder<User>(
          future: getUser(username),
          builder: (context, snapshot) {
            if (snapshot == null) {
              debugPrint("snapshot null");
              return SizedBox(height: 300, child: Center(child: Loader()));
            }
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.none) {
              debugPrint("snapshot none, waiting");
              return SizedBox(height: 300, child: Center(child: Loader()));
            } else {
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    height: 150,
                    width: MediaQuery.of(context).size.width * .78,
                    decoration: BoxDecoration(
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20)),
                        color: Theme.of(context).hintColor),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 20,
                        ),
                        CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(
                              snapshot.data.avatarUrl ?? ""),
                          radius: 40,
                        ),
                        const SizedBox(
                          width: 20,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: MediaQuery.of(context).size.width * 0.4,
                              child: Text(
                                snapshot.data.name,
                                maxLines: 2,
                                textAlign: TextAlign.center,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyText2
                                    .copyWith(fontSize: 20),
                              ),
                            ),
                            Container(
                                width: MediaQuery.of(context).size.width * 0.4,
                                child: Text(
                                  snapshot.data.login,
                                  textAlign: TextAlign.center,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyText2
                                      .copyWith(
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(0.5)),
                                )),
                            const SizedBox(
                              height: 5,
                            ),
                            snapshot.data.location != null
                                ? Row(
                                    children: [
                                      Icon(JamIcons.map_marker,
                                          color: Theme.of(context)
                                              .accentColor
                                              .withOpacity(0.5)),
                                      Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width *
                                              0.3,
                                          child: Text(
                                            snapshot.data.location,
                                            textAlign: TextAlign.center,
                                            overflow: TextOverflow.ellipsis,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyText2
                                                .copyWith(
                                                    color: Theme.of(context)
                                                        .accentColor
                                                        .withOpacity(0.5)),
                                          )),
                                    ],
                                  )
                                : Container(),
                          ],
                        )
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                        child: Container(
                          width: MediaQuery.of(context).size.width * 0.6,
                          child: Text(
                            snapshot.data.bio,
                            style: TextStyle(
                                fontSize: 14,
                                color: Theme.of(context).accentColor),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 10,
                  ),
                  Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      snapshot.data.blog != null && snapshot.data.blog != ""
                          ? ActionButton(
                              icon: JamIcons.link,
                              link: "https://${snapshot.data.blog}",
                              text: "WEBSITE")
                          : Container(),
                      ActionButton(
                          icon: JamIcons.github_circle,
                          link: snapshot.data.htmlUrl,
                          text: "GITHUB"),
                      snapshot.data.twitterUsername != null
                          ? ActionButton(
                              icon: JamIcons.twitter_circle,
                              link:
                                  "https://www.twitter.com/${snapshot.data.twitterUsername}",
                              text: "TWITTER")
                          : Container(),
                    ],
                  ),
                  const SizedBox(
                    height: 15,
                  ),
                ],
              );
            }
          }),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => userPopUp);
}
