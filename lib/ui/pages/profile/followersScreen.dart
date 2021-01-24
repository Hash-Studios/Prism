import 'package:flutter/material.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:cached_network_image/cached_network_image.dart';

class FollowersScreen extends StatefulWidget {
  final List arguments;
  const FollowersScreen({@required this.arguments});

  @override
  _FollowersScreenState createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List followers;
  Stream<QuerySnapshot> _stream;
  CollectionReference users;
  final Firestore firestore = Firestore.instance;
  @override
  void initState() {
    followers = widget.arguments[0] as List;
    users = firestore.collection('users');
    _stream = users.snapshots();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (navStack.length > 1) navStack.removeLast();
          debugPrint(navStack.toString());
          return true;
        },
        child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: const PreferredSize(
            preferredSize: Size(double.infinity, 55),
            child: HeadingChipBar(
              current: "Followers",
            ),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: _stream,
            builder:
                (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
              print('building');

              if (!snapshot.hasData) {
                return Center(
                  child: Loader(),
                );
              } else {
                return ListView.builder(
                    itemCount: followers.length,
                    itemBuilder: (BuildContext context, int index) {
                      List<DocumentSnapshot> users = snapshot.data.documents
                          .where((element) =>
                              element.data['email'] == followers[index])
                          .toList();
                      Map user = users[0].data;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundImage: CachedNetworkImageProvider(user[
                                  "userPhoto"] as String ??
                              "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2FnoUser.png?alt=media"),
                        ),
                        title: Text(
                          user['name'].toString(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyText2
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                        subtitle: Text(
                          user['email'].toString(),
                          style: Theme.of(context).textTheme.bodyText2.copyWith(
                              color: Theme.of(context)
                                  .accentColor
                                  .withOpacity(0.5)),
                        ),
                        onTap: () {
                          Navigator.pushNamed(context, photographerProfileRoute,
                              arguments: [
                                user["name"],
                                user["email"],
                                user["userPhoto"] ??
                                    "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2FnoUser.png?alt=media",
                                false,
                                user["twitter"] != null && user["twitter"] != ""
                                    ? user["twitter"]
                                        .toString()
                                        .split("https://www.twitter.com/")[1]
                                    : "",
                                user["instagram"] != null &&
                                        user["instagram"] != ""
                                    ? user["instagram"]
                                        .toString()
                                        .split("https://www.instagram.com/")[1]
                                    : "",
                              ]);
                        },
                      );
                    });
              }
            },
          ),
        ));
  }
}
