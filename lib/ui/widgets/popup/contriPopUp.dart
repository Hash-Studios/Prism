import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/pages/profile/aboutScreen.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:github/github.dart';

void showContributorDetails(BuildContext context, String username) {
  Future<User> getUser(String username) async {
    final github = GitHub();
    User user;
    await github.users.getUser(username).then((value) {
      user = value;
    });
    debugPrint(user.blog);
    return user;
  }

  final AlertDialog userPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
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
                            topLeft: Radius.circular(10),
                            topRight: Radius.circular(10)),
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
                                    .copyWith(
                                        color: Theme.of(context).accentColor,
                                        fontSize: 20),
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
                                color: Theme.of(context).accentColor,
                                fontFamily: "Proxima Nova",
                                fontWeight: FontWeight.normal),
                          ),
                        ),
                      ),
                    ],
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
                          icon: JamIcons.github,
                          link: snapshot.data.htmlUrl,
                          text: "GITHUB"),
                      snapshot.data.twitterUsername != null
                          ? ActionButton(
                              icon: JamIcons.twitter,
                              link:
                                  "https://www.twitter.com/${snapshot.data.twitterUsername}",
                              text: "TWITTER")
                          : Container(),
                    ],
                  ),
                ],
              );
            }
          }),
    ),
    backgroundColor: Theme.of(context).primaryColor,
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
  );
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => userPopUp);
}
