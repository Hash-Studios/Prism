import 'dart:async';
import 'package:Prism/data/profile/wallpaper/profileWallProvider.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/profile/profileLoader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/main.dart' as main;
import 'package:provider/provider.dart';

class UserProfile extends StatefulWidget {
  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ProfileChild(),
    );
  }
}

class ProfileChild extends StatefulWidget {
  @override
  _ProfileChildState createState() => _ProfileChildState();
}

class _ProfileChildState extends State<ProfileChild> {
  int profileCount = 0;
  final ScrollController scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
  }

  Future<bool> onWillPop() async {
    if (navStack.length > 1) navStack.removeLast();
    print(navStack);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: onWillPop,
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => <Widget>[
              SliverAppBar(
                backgroundColor: Color(0xFFE57697),
                automaticallyImplyLeading: false,
                pinned: false,
                expandedHeight: 260.0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        color: Color(0xFFE57697),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 25.0),
                        child: Container(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Spacer(flex: 5),
                              main.prefs.get("googleimage") == null
                                  ? Container()
                                  : Container(
                                      decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(5000),
                                          boxShadow: [
                                            BoxShadow(
                                                blurRadius: 16,
                                                offset: Offset(0, 4),
                                                color: Color(0xFF000000)
                                                    .withOpacity(0.24))
                                          ]),
                                      child: CircleAvatar(
                                        radius: 50,
                                        backgroundImage: NetworkImage(
                                            main.prefs.get("googleimage")),
                                      ),
                                    ),
                              Spacer(flex: 2),
                              main.prefs.get("name") == null
                                  ? Container()
                                  : !main.prefs.get('premium')
                                      ? Text(
                                          main.prefs.get("name"),
                                          style: TextStyle(
                                              fontFamily: "Proxima Nova",
                                              color: Colors.white,
                                              fontSize: 32,
                                              fontWeight: FontWeight.w700),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: <Widget>[
                                            Text(
                                              main.prefs.get("name"),
                                              style: TextStyle(
                                                  fontFamily: "Proxima Nova",
                                                  color: Colors.white,
                                                  fontSize: 32,
                                                  fontWeight: FontWeight.w700),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  left: 8.0),
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                    vertical: 3, horizontal: 5),
                                                decoration: BoxDecoration(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50),
                                                    color: Color(0xFFFFFFFF)),
                                                child: Text(
                                                  "PRO",
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyText2
                                                      .copyWith(
                                                          fontSize: 10,
                                                          color: Color(
                                                              0xFFE57697)),
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                              Spacer(flex: 1),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: <Widget>[
                                  Spacer(flex: 3),
                                  Row(
                                    children: <Widget>[
                                      Text(
                                        Provider.of<ProfileWallProvider>(
                                                    context)
                                                .len
                                                .toString() +
                                            " ",
                                        style: TextStyle(
                                            fontFamily: "Proxima Nova",
                                            fontSize: 24,
                                            color: Colors.white70,
                                            fontWeight: FontWeight.normal),
                                      ),
                                      Icon(
                                        JamIcons.picture,
                                        color: Colors.white70,
                                      ),
                                    ],
                                  ),
                                  Spacer(flex: 3),
                                ],
                              ),
                              Spacer(flex: 4),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            body: Padding(
              padding: const EdgeInsets.only(top: 5.0),
              child: ProfileLoader(
                future: Provider.of<ProfileWallProvider>(context, listen: false)
                    .getProfileWalls(),
              ),
            ),
          ),
        ));
  }
}
