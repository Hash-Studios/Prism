import 'dart:async';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/ui/widgets/profile/userProfileLoader.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:Prism/data/profile/wallpaper/getUserProfile.dart' as UserData;

class UserProfile extends StatefulWidget {
  final List arguments;
  UserProfile(this.arguments);
  @override
  _UserProfileState createState() => _UserProfileState();
}

class _UserProfileState extends State<UserProfile> {
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
        body: UserProfileChild(arguments: widget.arguments),
      ),
    );
  }
}

class UserProfileChild extends StatefulWidget {
  final List arguments;
  UserProfileChild({@required this.arguments});
  @override
  _UserProfileChildState createState() => _UserProfileChildState();
}

class _UserProfileChildState extends State<UserProfileChild> {
  String name;
  String email;
  String userPhoto;
  final ScrollController scrollController = ScrollController();
  @override
  void initState() {
    name = widget.arguments[0];
    email = widget.arguments[1];
    userPhoto = widget.arguments[2];
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
                automaticallyImplyLeading: true,
                pinned: true,
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
                              userPhoto == null
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
                                        backgroundImage:
                                            NetworkImage(userPhoto),
                                      ),
                                    ),
                              Spacer(flex: 2),
                              name == null
                                  ? Container()
                                  : Text(
                                      name,
                                      style: TextStyle(
                                          fontFamily: "Proxima Nova",
                                          color: Colors.white,
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700),
                                    ),
                              Spacer(flex: 1),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: <Widget>[
                                  Spacer(flex: 3),
                                  Row(
                                    children: <Widget>[
                                      FutureBuilder(
                                          future:
                                              UserData.getProfileWallsLength(
                                                  email),
                                          builder: (context, snapshot) {
                                            return Text(
                                              snapshot.data == null
                                                  ? "0 "
                                                  : snapshot.data.toString() +
                                                      " ",
                                              style: TextStyle(
                                                  fontFamily: "Proxima Nova",
                                                  fontSize: 24,
                                                  color: Colors.white70,
                                                  fontWeight:
                                                      FontWeight.normal),
                                            );
                                          }),
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
              child: UserProfileLoader(
                email: email,
                future: UserData.getuserProfileWalls(email),
              ),
            ),
          ),
        ));
  }
}
