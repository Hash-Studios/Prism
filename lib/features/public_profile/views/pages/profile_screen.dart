import 'dart:convert';

import 'package:Prism/core/router/route_names.dart';
import 'package:Prism/core/utils/url_launcher_compat.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/core/widgets/popup/noLoadLinkPopUp.dart';
import 'package:Prism/data/profile/wallpaper/public_profile_data.dart';
import 'package:Prism/features/navigation/views/widgets/bottom_nav_bar.dart';
import 'package:Prism/features/navigation/views/widgets/inherited_scroll_controller_provider.dart';
import 'package:Prism/features/public_profile/views/widgets/about_list.dart';
import 'package:Prism/features/public_profile/views/widgets/download_list.dart';
import 'package:Prism/features/public_profile/views/widgets/drawer_widget.dart';
import 'package:Prism/features/public_profile/views/widgets/general_list.dart';
import 'package:Prism/features/public_profile/views/widgets/premium_list.dart';
import 'package:Prism/features/public_profile/views/widgets/user_list.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_loader.dart';
import 'package:Prism/features/public_profile/views/widgets/user_profile_setup_loader.dart';
import 'package:Prism/gitkey.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/global/svgAssets.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:rive/rive.dart';

final GlobalKey<ScaffoldState> scaffoldKey = GlobalKey();

class ProfileScreen extends StatefulWidget {
  final List? arguments;
  const ProfileScreen(this.arguments);
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? email;

  @override
  void initState() {
    email = widget.arguments![0].toString();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          popNavStackIfPossible();
        }
      },
      child: (email == globals.prismUser.email)
          ? Scaffold(
              key: scaffoldKey,
              body: BottomBar(
                child: ProfileChild(
                  ownProfile: true,
                  id: globals.prismUser.id,
                  bio: globals.prismUser.bio,
                  coverPhoto: globals.prismUser.coverPhoto,
                  email: globals.prismUser.email,
                  links: globals.prismUser.links,
                  name: globals.prismUser.name,
                  premium: globals.prismUser.premium,
                  userPhoto: globals.prismUser.profilePhoto,
                  username: globals.prismUser.username,
                  followers: globals.prismUser.followers,
                  following: globals.prismUser.following,
                ),
              ),
              endDrawer: globals.prismUser.loggedIn
                  ? SizedBox(width: MediaQuery.of(context).size.width * 0.68, child: ProfileDrawer())
                  : null,
            )
          : Scaffold(
              key: scaffoldKey,
              body: StreamBuilder<List<Map<String, dynamic>>>(
                stream: getUserProfile(email!),
                builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                  if (snapshot.hasData && snapshot.data != null) {
                    if (snapshot.data!.isEmpty) {
                      return ColoredBox(
                        color: Theme.of(context).primaryColor,
                        child: Center(
                          child: SizedBox(
                            width: MediaQuery.of(context).size.width * 0.8,
                            child: const Text(
                              "Sorry! This user is inactive on the latest version, and hence they are not currently viewable.",
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                      );
                    }
                    final data = snapshot.data!.first;
                    final Map links = data["links"] is Map ? (data["links"] as Map) : <String, dynamic>{};
                    final bool premium = data["premium"] is bool && data["premium"] as bool;
                    final List followers = data["followers"] is List ? data["followers"] as List : <dynamic>[];
                    final List following = data["following"] is List ? data["following"] as List : <dynamic>[];
                    return ProfileChild(
                      ownProfile: false,
                      id: (data['__docId'] ?? '').toString(),
                      bio: data["bio"].toString(),
                      coverPhoto: data["coverPhoto"]?.toString() ?? "",
                      email: data["email"].toString(),
                      links: links,
                      name: data["name"].toString(),
                      premium: premium,
                      userPhoto: data["profilePhoto"].toString(),
                      username: data["username"].toString(),
                      followers: followers,
                      following: following,
                    );
                  }
                  return ColoredBox(
                    color: Theme.of(context).primaryColor,
                    child: Center(
                      child: Loader(),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class ProfileChild extends StatefulWidget {
  final String? name;
  final String? username;
  final String? id;
  final String? email;
  final String? userPhoto;
  final String? coverPhoto;
  final bool? premium;
  final bool? ownProfile;
  final Map? links;
  final String? bio;
  final List? followers;
  final List? following;
  const ProfileChild({
    required this.name,
    required this.username,
    required this.id,
    required this.email,
    required this.userPhoto,
    required this.coverPhoto,
    required this.premium,
    required this.ownProfile,
    required this.links,
    required this.bio,
    required this.followers,
    required this.following,
  });
  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<ProfileChild> {
  // int favCount = main.prefs.get('userFavs') as int? ?? 0;
  // int profileCount = ((main.prefs.get('userPosts') as int?) ?? 0) +
  //     ((main.prefs.get('userSetups') as int?) ?? 0);
  final ScrollController scrollController = ScrollController();
  // int count = 0;
  @override
  void initState() {
    // count = main.prefs.get('easterCount', defaultValue: 0) as int;
    // checkFav();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final String safeCoverPhoto = (widget.coverPhoto ?? "").trim();
    final String safeUserPhoto = (widget.userPhoto ?? "").trim();
    final bool hasCoverPhoto = safeCoverPhoto.isNotEmpty;
    final bool hasUserPhoto = safeUserPhoto.isNotEmpty;
    final ScrollController? controller =
        widget.ownProfile! ? InheritedDataProvider.of(context)!.scrollController : ScrollController();

    return !widget.ownProfile! || globals.prismUser.loggedIn
        ? DefaultTabController(
            length: 2,
            child: Stack(
              children: [
                Scaffold(
                  backgroundColor: Theme.of(context).primaryColor,
                  body: NestedScrollView(
                    controller: controller,
                    headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
                      SliverAppBar(
                        toolbarHeight: MediaQuery.of(context).padding.top + kToolbarHeight + 32,
                        primary: false,
                        floating: true,
                        elevation: 0,
                        leading: !widget.ownProfile! || globals.prismUser.loggedIn == false
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: IconButton(
                                    padding: const EdgeInsets.all(2),
                                    icon: Container(
                                      padding: const EdgeInsets.all(6.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                      ),
                                      child:
                                          Icon(JamIcons.chevron_left, color: Theme.of(context).colorScheme.secondary),
                                    ),
                                    onPressed: () {
                                      Navigator.pop(context);
                                      popNavStackIfPossible();
                                    }),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: IconButton(
                                    padding: const EdgeInsets.all(2),
                                    icon: Container(
                                      padding: const EdgeInsets.all(6.0),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                      ),
                                      child: Icon(JamIcons.pencil, color: Theme.of(context).colorScheme.secondary),
                                    ),
                                    onPressed: () {
                                      context.pushNamedRoute(editProfileRoute);
                                    }),
                              ),
                        actions: !widget.ownProfile! || globals.prismUser.loggedIn == false
                            ? [
                                if (globals.prismUser.loggedIn == false)
                                  Container()
                                else
                                  Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: ((widget.followers ?? []).contains(globals.prismUser.email))
                                        ? IconButton(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.all(2),
                                            icon: Container(
                                              padding: const EdgeInsets.all(6.0),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                              ),
                                              child: Icon(JamIcons.user_remove,
                                                  color: Theme.of(context).colorScheme.secondary),
                                            ),
                                            onPressed: () {
                                              unfollow(widget.email!, widget.id!);
                                              toasts.error("Unfollowed ${widget.name}!");
                                            })
                                        : IconButton(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.all(2),
                                            icon: Container(
                                              padding: const EdgeInsets.all(6.0),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                              ),
                                              child: Icon(JamIcons.user_plus,
                                                  color: Theme.of(context).colorScheme.secondary),
                                            ),
                                            onPressed: () {
                                              follow(widget.email!, widget.id!);
                                              http.post(
                                                Uri.parse(
                                                  'https://fcm.googleapis.com/fcm/send',
                                                ),
                                                headers: <String, String>{
                                                  'Content-Type': 'application/json',
                                                  'Authorization': 'key=$fcmServerToken',
                                                },
                                                body: jsonEncode(
                                                  <String, dynamic>{
                                                    'notification': <String, dynamic>{
                                                      'title': '🎉 New Follower!',
                                                      'body': '${globals.prismUser.username} is now following you.',
                                                      'color': "#e57697",
                                                      'tag': '${globals.prismUser.username} Follow',
                                                      'image': globals.prismUser.profilePhoto,
                                                      'android_channel_id': "followers",
                                                      'icon': '@drawable/ic_follow'
                                                    },
                                                    'priority': 'high',
                                                    'data': <String, dynamic>{
                                                      'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                                                      'id': '1',
                                                      'status': 'done'
                                                    },
                                                    'to': "/topics/${widget.email!.split("@")[0]}"
                                                  },
                                                ),
                                              );
                                              toasts.codeSend("Followed ${widget.name}!");
                                            }),
                                  )
                              ]
                            : [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: IconButton(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.all(2),
                                      icon: Container(
                                        padding: const EdgeInsets.all(6.0),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                                        ),
                                        child: Icon(JamIcons.menu, color: Theme.of(context).colorScheme.secondary),
                                      ),
                                      onPressed: () {
                                        scaffoldKey.currentState!.openEndDrawer();
                                      }),
                                )
                              ],
                        backgroundColor: Theme.of(context).primaryColor,
                        automaticallyImplyLeading: false,
                        expandedHeight: (widget.links ?? {}).keys.toList().isEmpty
                            ? MediaQuery.of(context).size.height * 0.4
                            : MediaQuery.of(context).size.height * 0.46,
                        flexibleSpace: Stack(
                          children: [
                            FlexibleSpaceBar(
                              background: Stack(
                                children: [
                                  Column(children: [
                                    if (!hasCoverPhoto)
                                      SvgPicture.string(
                                        defaultHeader
                                            .replaceAll(
                                              "#181818",
                                              "#${Theme.of(context).primaryColor.toARGB32().toRadixString(16).substring(2)}",
                                            )
                                            .replaceAll(
                                              "#E77597",
                                              "#${Theme.of(context).colorScheme.error.toARGB32().toRadixString(16).substring(2)}",
                                            ),
                                        fit: BoxFit.cover,
                                        width: MediaQuery.of(context).size.width,
                                        height: MediaQuery.of(context).size.height * 0.19,
                                      )
                                    else
                                      CachedNetworkImage(
                                        imageUrl: safeCoverPhoto,
                                        fit: BoxFit.cover,
                                        width: MediaQuery.of(context).size.width,
                                        height: MediaQuery.of(context).size.height * 0.19,
                                      ),
                                    const SizedBox(
                                      width: double.maxFinite,
                                      height: 37,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                                      width: double.maxFinite,
                                      height: (widget.links ?? {}).keys.toList().isEmpty
                                          ? MediaQuery.of(context).size.height * 0.21 - 37
                                          : MediaQuery.of(context).size.height * 0.27 - 37,
                                      child: Column(
                                        children: [
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.7,
                                            child: Text(
                                              widget.name!,
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: "Proxima Nova",
                                                color: Theme.of(context).colorScheme.secondary,
                                                fontSize: 22,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 2,
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.7,
                                            child: Text(
                                              "@${widget.username}",
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: "Proxima Nova",
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                                fontSize: 16,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 8,
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.7,
                                            child: Text(
                                              widget.bio ?? "",
                                              textAlign: TextAlign.center,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontFamily: "Proxima Nova",
                                                color: Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
                                                fontSize: 14,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(
                                            height: 8,
                                          ),
                                          SizedBox(
                                            width: MediaQuery.of(context).size.width * 0.7,
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                RichText(
                                                  text: TextSpan(
                                                    text: "${(widget.following ?? []).length}",
                                                    style: TextStyle(
                                                      fontFamily: "Proxima Nova",
                                                      color:
                                                          Theme.of(context).colorScheme.secondary.withValues(alpha: 1),
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: " Following",
                                                        style: TextStyle(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .secondary
                                                              .withValues(alpha: 0.6),
                                                          fontWeight: FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(width: 24),
                                                RichText(
                                                  text: TextSpan(
                                                    text: "${(widget.followers ?? []).length}",
                                                    style: TextStyle(
                                                      fontFamily: "Proxima Nova",
                                                      color:
                                                          Theme.of(context).colorScheme.secondary.withValues(alpha: 1),
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                    children: [
                                                      TextSpan(
                                                        text: " Followers",
                                                        style: TextStyle(
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .secondary
                                                              .withValues(alpha: 0.6),
                                                          fontWeight: FontWeight.normal,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  textAlign: TextAlign.center,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if ((widget.links ?? {}).keys.toList().isNotEmpty)
                                            const SizedBox(
                                              height: 8,
                                            ),
                                          if ((widget.links ?? {}).keys.toList().isNotEmpty)
                                            SizedBox(
                                              width: MediaQuery.of(context).size.width,
                                              height: 48,
                                              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                                ...(widget.links ?? {})
                                                    .keys
                                                    .toList()
                                                    .map((e) => IconButton(
                                                        padding: const EdgeInsets.all(2),
                                                        icon: Container(
                                                          padding: const EdgeInsets.all(6.0),
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .secondary
                                                                .withValues(alpha: 0.1),
                                                          ),
                                                          child: Icon(
                                                            linksData[e]!["icon"] as IconData,
                                                            size: 20,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .secondary
                                                                .withValues(alpha: 0.8),
                                                          ),
                                                        ),
                                                        onPressed: () async {
                                                          final String link = widget.links![e].toString();
                                                          final String targetLink =
                                                              link.contains("@gmail.com") ? "mailto:$link" : link;
                                                          await launchUrl(Uri.parse(targetLink));
                                                        }))
                                                    .toList()
                                                    .sublist(
                                                      0,
                                                      (widget.links ?? {}).keys.toList().length > 3
                                                          ? 3
                                                          : (widget.links ?? {}).keys.toList().length,
                                                    ),
                                                if ((widget.links ?? {}).keys.toList().length > 3)
                                                  IconButton(
                                                      padding: const EdgeInsets.all(2),
                                                      icon: Container(
                                                        padding: const EdgeInsets.all(6.0),
                                                        decoration: BoxDecoration(
                                                          shape: BoxShape.circle,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .secondary
                                                              .withValues(alpha: 0.1),
                                                        ),
                                                        child: Icon(
                                                          JamIcons.more_horizontal,
                                                          size: 20,
                                                          color: Theme.of(context)
                                                              .colorScheme
                                                              .secondary
                                                              .withValues(alpha: 0.8),
                                                        ),
                                                      ),
                                                      onPressed: () {
                                                        showNoLoadLinksPopUp(context, widget.links ?? {});
                                                      }),
                                              ]),
                                            )
                                        ],
                                      ),
                                    )
                                  ]),
                                  Positioned(
                                    top: MediaQuery.of(context).size.height * 0.19 - 56,
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width,
                                      child: Center(
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Theme.of(context).colorScheme.error,
                                              width: 4,
                                            ),
                                            color: Theme.of(context).colorScheme.secondary,
                                          ),
                                          child: ClipOval(
                                            child: hasUserPhoto
                                                ? CachedNetworkImage(
                                                    imageUrl: safeUserPhoto,
                                                    width: 78,
                                                    height: 78,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Container(
                                                    width: 78,
                                                    height: 78,
                                                    color: Theme.of(context).primaryColor,
                                                    alignment: Alignment.center,
                                                    child: Icon(
                                                      JamIcons.user,
                                                      color: Theme.of(context).colorScheme.error,
                                                      size: 30,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: double.maxFinite,
                              height: MediaQuery.of(context).padding.top,
                              color: Theme.of(context).primaryColor.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      ),
                      SliverAppBar(
                        backgroundColor: Theme.of(context).primaryColor,
                        automaticallyImplyLeading: false,
                        pinned: true,
                        titleSpacing: 0,
                        expandedHeight: !widget.ownProfile! || globals.prismUser.loggedIn ? 50 : 0,
                        title: SizedBox(
                          width: MediaQuery.of(context).size.width,
                          height: 57,
                          child: ColoredBox(
                            color: Theme.of(context).primaryColor,
                            child: SizedBox.expand(
                              child: TabBar(
                                  indicatorColor: Theme.of(context).colorScheme.secondary,
                                  indicatorSize: TabBarIndicatorSize.label,
                                  unselectedLabelColor: const Color(0xFFFFFFFF).withValues(alpha: 0.5),
                                  labelColor: const Color(0xFFFFFFFF),
                                  tabs: [
                                    Text(
                                      "Wallpapers",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(color: Theme.of(context).colorScheme.secondary),
                                    ),
                                    Text(
                                      "Setups",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(color: Theme.of(context).colorScheme.secondary),
                                    ),
                                  ]),
                            ),
                          ),
                        ),
                      ),
                    ],
                    body: TabBarView(children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: UserProfileLoader(
                          email: widget.email,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: UserProfileSetupLoader(
                          email: widget.email,
                        ),
                      ),
                    ]),
                  ),
                ),
              ],
            ))
        : Scaffold(
            backgroundColor: Theme.of(context).primaryColor,
            body: CustomScrollView(controller: controller, slivers: <Widget>[
              SliverAppBar(
                backgroundColor: Theme.of(context).colorScheme.error,
                automaticallyImplyLeading: false,
                expandedHeight: 280.0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Stack(
                        children: <Widget>[
                          Container(
                            color: Theme.of(context).colorScheme.error,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
                            child: Center(
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width / 2,
                                child: const RiveAnimation.asset(
                                  "assets/animations/Text.flr",
                                  animations: ["Untitled"],
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverList(
                  delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: PremiumList(),
                ),
                DownloadList(),
                const GeneralList(
                  expanded: false,
                ),
                const UserList(
                  expanded: false,
                ),
                AboutList(),
                const SizedBox(
                  height: 300,
                ),
              ]))
            ]),
          );
  }
}

Map<String, Map<String, dynamic>> linksData = {
  'github': {
    'name': 'github',
    'link': 'https://github.com/username',
    'icon': JamIcons.github,
    'value': '',
    'validator': 'github',
  },
  'twitter': {
    'name': 'twitter',
    'link': 'https://twitter.com/username',
    'icon': JamIcons.twitter,
    'value': '',
    'validator': 'twitter',
  },
  'instagram': {
    'name': 'instagram',
    'link': 'https://instagram.com/username',
    'icon': JamIcons.instagram,
    'value': '',
    'validator': 'instagram',
  },
  'email': {
    'name': 'email',
    'link': 'your@email.com',
    'icon': JamIcons.inbox,
    'value': '',
    'validator': '@',
  },
  'telegram': {
    'name': 'telegram',
    'link': 'https://t.me/username',
    'icon': JamIcons.paper_plane,
    'value': '',
    'validator': 't.me',
  },
  'dribbble': {
    'name': 'dribbble',
    'link': 'https://dribbble.com/username',
    'icon': JamIcons.basketball,
    'value': '',
    'validator': 'dribbble',
  },
  'linkedin': {
    'name': 'linkedin',
    'link': 'https://linkedin.com/in/username',
    'icon': JamIcons.linkedin,
    'value': '',
    'validator': 'linkedin',
  },
  'bio.link': {
    'name': 'bio.link',
    'link': 'https://bio.link/username',
    'icon': JamIcons.world,
    'value': '',
    'validator': 'bio.link',
  },
  'patreon': {
    'name': 'patreon',
    'link': 'https://patreon.com/username',
    'icon': JamIcons.patreon,
    'value': '',
    'validator': 'patreon',
  },
  'trello': {
    'name': 'trello',
    'link': 'https://trello.com/username',
    'icon': JamIcons.trello,
    'value': '',
    'validator': 'trello',
  },
  'reddit': {
    'name': 'reddit',
    'link': 'https://reddit.com/user/username',
    'icon': JamIcons.reddit,
    'value': '',
    'validator': 'reddit',
  },
  'behance': {
    'name': 'behance',
    'link': 'https://behance.net/username',
    'icon': JamIcons.behance,
    'value': '',
    'validator': 'behance.net',
  },
  'deviantart': {
    'name': 'deviantart',
    'link': 'https://deviantart.com/username',
    'icon': JamIcons.deviantart,
    'value': '',
    'validator': 'deviantart',
  },
  'gitlab': {
    'name': 'gitlab',
    'link': 'https://gitlab.com/username',
    'icon': JamIcons.gitlab,
    'value': '',
    'validator': 'gitlab',
  },
  'medium': {
    'name': 'medium',
    'link': 'https://username.medium.com/',
    'icon': JamIcons.medium,
    'value': '',
    'validator': 'medium',
  },
  'paypal': {
    'name': 'paypal',
    'link': 'https://paypal.me/username',
    'icon': JamIcons.paypal,
    'value': '',
    'validator': 'paypal',
  },
  'spotify': {
    'name': 'spotify',
    'link': 'https://open.spotify.com/user/username',
    'icon': JamIcons.spotify,
    'value': '',
    'validator': 'open.spotify',
  },
  'twitch': {
    'name': 'twitch',
    'link': 'https://twitch.tv/username',
    'icon': JamIcons.twitch,
    'value': '',
    'validator': 'twitch.tv',
  },
  'unsplash': {
    'name': 'unsplash',
    'link': 'https://unsplash.com/username',
    'icon': JamIcons.unsplash,
    'value': '',
    'validator': 'unsplash',
  },
  'youtube': {
    'name': 'youtube',
    'link': 'https://youtube.com/channel/username',
    'icon': JamIcons.youtube,
    'value': '',
    'validator': 'youtube',
  },
  'linktree': {
    'name': 'linktree',
    'link': 'https://linktr.ee/username',
    'icon': JamIcons.tree_alt,
    'value': '',
    'validator': 'linktr.ee',
  },
  'buymeacoffee': {
    'name': 'buymeacoffee',
    'link': 'https://buymeacoff.ee/username',
    'icon': JamIcons.coffee,
    'value': '',
    'validator': 'buymeacoff.ee',
  },
  'custom link': {
    'name': 'custom link',
    'link': '',
    'icon': JamIcons.link,
    'value': '',
    'validator': '',
  },
};
