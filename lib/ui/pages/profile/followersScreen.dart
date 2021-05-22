import 'package:flutter/material.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FollowersScreen extends StatefulWidget {
  final List? arguments;
  const FollowersScreen({required this.arguments});

  @override
  _FollowersScreenState createState() => _FollowersScreenState();
}

class _FollowersScreenState extends State<FollowersScreen> {
  List? followers;
  // Stream<QuerySnapshot>? _stream;
  // late CollectionReference users;
  // final Firestore firestore = Firestore.instance;
  @override
  void initState() {
    followers = widget.arguments![0] as List;
    followers!.sort();
    // users = firestore.collection('users');
    // _stream = users.snapshots();
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
            body:
                // StreamBuilder<QuerySnapshot>(
                //   stream: _stream,
                //   builder:
                //       (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
                //     if (!snapshot.hasData) {
                //       return Center(
                //         child: Loader(),
                //       );
                //     } else {
                //       return
                ListView.builder(
                    itemCount: followers!.length,
                    itemBuilder: (BuildContext context, int index) {
                      return
                          // FutureBuilder(
                          //   future: compute(processingFollowers, <String, dynamic>{
                          //     "documents": snapshot.data!.documents,
                          //     "followers": followers,
                          //     "index": index,
                          //   }),
                          //   builder:
                          //       (BuildContext context, AsyncSnapshot snapshot) {
                          //     final user = snapshot.data;
                          //     return user != null
                          //         ?
                          ListTile(
                        leading: CircleAvatar(
                          child: ClipOval(
                            child: SvgPicture.network(
                                "https://avatars.dicebear.com/api/avataaars/$index.svg?background=transparent"),
                          ),
                          // backgroundImage:
                          // CachedNetworkImageProvider(

                          //     // user["userPhoto"] as String? ??
                          //     "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2FnoUser.png?alt=media"
                          // ),
                        ),
                        title: Text(
                          followers![index].toString(),
                          // user['name'].toString(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyText2!
                              .copyWith(color: Theme.of(context).accentColor),
                        ),
                        // subtitle: Text(
                        //   followers![index].toString(),
                        //   // user['email'].toString(),
                        //   style: Theme.of(context)
                        //       .textTheme
                        //       .bodyText2!
                        //       .copyWith(
                        //           color: Theme.of(context)
                        //               .accentColor
                        //               .withOpacity(0.5)),
                        // ),
                        onTap: () {
                          Navigator.pushNamed(context, followerProfileRoute,
                              arguments: [
                                // user["name"],
                                followers![index].toString()
                                // user["email"],
                                // user["userPhoto"] ??
                                //     "https://firebasestorage.googleapis.com/v0/b/prism-wallpapers.appspot.com/o/Replacement%20Thumbnails%2FnoUser.png?alt=media",
                                // false,
                                // if (user["twitter"] != null &&
                                //     user["twitter"] != "")
                                //   user["twitter"].toString().split(
                                //       "https://www.twitter.com/")[1]
                                // else
                                //   "",
                                // if (user["instagram"] != null &&
                                //     user["instagram"] != "")
                                //   user["instagram"].toString().split(
                                //       "https://www.instagram.com/")[1]
                                // else
                                //   "",
                              ]);
                        },
                      )
                          //         : Container();
                          //   },
                          // )
                          ;
                    })
            // ;
            //     }
            //   },
            // ),
            ));
  }
}

// Map processingFollowers(
//   Map<String, dynamic> params,
// ) {
//   final List<DocumentSnapshot> documents =
//       params["documents"] as List<DocumentSnapshot>;
//   final List? followers = params["followers"] as List?;
//   final int? index = params["index"] as int?;
//   final List<DocumentSnapshot> users = documents
//       .where((element) => element.data['email'] == followers![index!])
//       .toList();
//   final Map user = users == null ? {} : users[0].data;
//   return user;
// }
