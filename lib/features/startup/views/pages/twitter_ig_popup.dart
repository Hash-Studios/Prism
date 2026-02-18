import 'dart:convert';

import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/widgets/animated/showUp.dart';
import 'package:Prism/env/env.dart';
import 'package:Prism/features/startup/views/pages/splash_widget.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OptionalInfo3 extends StatefulWidget {
  final String heading;
  final String subheading;
  final bool showSkip;
  final String? skipText;
  final String? doneText;
  const OptionalInfo3({
    required this.heading,
    required this.subheading,
    required this.showSkip,
    this.skipText,
    required this.doneText,
  });
  @override
  _OptionalInfo3State createState() => _OptionalInfo3State();
}

class _OptionalInfo3State extends State<OptionalInfo3> {
  Image? image1;
  void _navigateToSplash(BuildContext ctx) {
    Navigator.pushReplacement(ctx, MaterialPageRoute(builder: (context) => const SplashWidget()));
  }

  bool? isFollow1;
  bool? isFollow2;
  bool? isFollow3;

  @override
  void initState() {
    isFollow1 = false;
    isFollow2 = false;
    isFollow3 = false;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateToSplash(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFE57697),
        body: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                  padding: const EdgeInsets.fromLTRB(0, 90, 0, 8),
                  child: Column(
                    children: [
                      ShowUpTransition(
                        forward: true,
                        slideSide: SlideFromSlide.bottom,
                        delay: const Duration(milliseconds: 150),
                        child: Text(
                          widget.heading,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 7,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: ShowUpTransition(
                          forward: true,
                          slideSide: SlideFromSlide.bottom,
                          delay: const Duration(milliseconds: 200),
                          child: Text(
                            widget.subheading,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              fontFamily: "Roboto",
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(
                        height: 17,
                      ),
                      const FollowHeaderCard(
                        email: "hk3ToN_Prism@gmail.com",
                        url: "https://pbs.twimg.com/profile_images/1278264820450680833/LKoAc7nh_400x400.jpg",
                        name: "Hk3ToN",
                        img1: Env.user3Image1,
                        img2: Env.user3Image2,
                        img3: Env.user3Image3,
                      ),
                      const FollowHeaderCard(
                        email: "akshaymaurya3006@gmail.com",
                        url:
                            "https://lh3.googleusercontent.com/a-/AOh14Gh7a-JaBRpAI9SPmSBJQmOeggj6ic2mub3DKala_g=s96-c",
                        name: "Akshay Maurya",
                        img1: Env.user2Image1,
                        img2: Env.user2Image2,
                        img3: Env.user2Image3,
                      ),
                      const FollowHeaderCard(
                        email: "maurya.abhay30@gmail.com",
                        url:
                            "https://lh3.googleusercontent.com/a-/AOh14GgTe5pUi3k-cdvxoCoJ2kKWafu0RXDN3sUVTp3Z58c=s96-c",
                        name: "Abhay Maurya",
                        img1: Env.user1Image1,
                        img2: Env.user1Image2,
                        img3: Env.user1Image3,
                      ),
                      const FollowHeaderCard(
                        email: "inderpalsansoa.1993@gmail.com",
                        url: "https://lh3.googleusercontent.com/a-/AOh14GjUOpZ14V9UdM58LCz1nx87N_3SDYSHQwTOec-I=s96-c",
                        name: "ShankyGotThatArt",
                        img1: Env.user4Image1,
                        img2: Env.user4Image2,
                        img3: Env.user4Image3,
                      ),
                      const FollowHeaderCard(
                        email: "yyo17341@gmail.com",
                        url: "https://lh3.googleusercontent.com/a-/AOh14GizSGAXOap5UIqWKX16JNSKe56y1X_mKNb0Snaf=s96-c",
                        name: "Megh Dave",
                        img1: Env.user5Image1,
                        img2: Env.user5Image2,
                        img3: Env.user5Image3,
                      ),
                      const FollowHeaderCard(
                        email: "techpool007@gmail.com",
                        url:
                            "https://lh3.googleusercontent.com/a-/AOh14GhcT-AssZM3Kk6jz4OTbbAPz3gS-2tvPjLhkAj83w=s96-c",
                        name: "Dennis Wilson",
                        img1: Env.user6Image1,
                        img2: Env.user6Image2,
                        img3: Env.user6Image3,
                      ),
                    ],
                  )),
              if (widget.showSkip == true)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (context) => const SplashWidget()));
                      },
                      style: ButtonStyle(overlayColor: WidgetStateColor.resolveWith((states) => Colors.white10)),
                      child: SizedBox(
                        width: 75,
                        child: Text(
                          widget.skipText ?? "Skip",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (context) => const SplashWidget()));
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateColor.resolveWith((states) => Colors.white),
                      ),
                      child: SizedBox(
                        width: 60,
                        child: Text(
                          widget.doneText ?? 'DONE',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFE57697),
                            fontSize: 15,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pushReplacement(
                            context, MaterialPageRoute(builder: (context) => const SplashWidget()));
                      },
                      style: ButtonStyle(
                        backgroundColor: WidgetStateColor.resolveWith((states) => Colors.white),
                      ),
                      child: const SizedBox(
                        width: 60,
                        child: Text(
                          'DONE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFE57697),
                            fontSize: 15,
                            fontFamily: "Roboto",
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(
                height: 24,
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.miniEndTop,
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.transparent,
          focusElevation: 0,
          highlightElevation: 0,
          elevation: 0,
          mini: true,
          onPressed: () {
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const SplashWidget()));
          },
          child: const Icon(
            JamIcons.close,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class FollowHeaderCard extends StatelessWidget {
  const FollowHeaderCard({
    super.key,
    required this.url,
    required this.email,
    required this.name,
    required this.img1,
    required this.img2,
    required this.img3,
  });

  final String url;
  final String email;
  final String name;
  final String img1;
  final String img2;
  final String img3;

  @override
  Widget build(BuildContext context) {
    return ShowUpTransition(
      forward: true,
      slideSide: SlideFromSlide.bottom,
      delay: const Duration(milliseconds: 200),
      child: Column(
        children: [
          Card(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            color: Colors.white,
            elevation: 4,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 60,
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundImage: CachedNetworkImageProvider(url),
                    ),
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Color(0xFFE57697),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  StreamBuilder<List<_FirestoreDoc>>(
                    stream: firestoreClient.watchQuery<_FirestoreDoc>(
                      FirestoreQuerySpec(
                        collection: USER_NEW_COLLECTION,
                        sourceTag: 'startup.follow.currentUser',
                        filters: <FirestoreFilter>[
                          FirestoreFilter(
                              field: "email", op: FirestoreFilterOp.isEqualTo, value: globals.prismUser.email),
                        ],
                        isStream: true,
                        limit: 1,
                      ),
                      (data, docId) => _FirestoreDoc(docId, data),
                    ),
                    builder: (BuildContext context, AsyncSnapshot<List<_FirestoreDoc>> snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Container();
                      } else {
                        final _FirestoreDoc currentUserDoc = snapshot.data!.first;
                        final Map<String, dynamic> currentUserData = currentUserDoc.data;
                        final List<dynamic> following = List<dynamic>.from(currentUserData['following'] as List? ?? []);
                        if (following.contains(email)) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: () {},
                              style: ButtonStyle(
                                shape: WidgetStateProperty.resolveWith(
                                    (states) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                backgroundColor: WidgetStateColor.resolveWith((states) => Colors.white),
                              ),
                              child: const SizedBox(
                                width: 65,
                                child: Icon(
                                  JamIcons.check,
                                  color: Color(0xFFE57697),
                                ),
                              ),
                            ),
                          );
                        } else {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: () async {
                                following.add(email);
                                await firestoreClient.updateDoc(
                                  USER_NEW_COLLECTION,
                                  currentUserDoc.id,
                                  <String, dynamic>{'following': following},
                                  sourceTag: 'startup.follow.currentUser.update',
                                );
                                final users = await firestoreClient.query<_FirestoreDoc>(
                                  FirestoreQuerySpec(
                                    collection: USER_NEW_COLLECTION,
                                    sourceTag: 'startup.follow.target.lookup',
                                    filters: <FirestoreFilter>[
                                      FirestoreFilter(field: "email", op: FirestoreFilterOp.isEqualTo, value: email),
                                    ],
                                    limit: 1,
                                  ),
                                  (data, docId) => _FirestoreDoc(docId, data),
                                );
                                if (users.isNotEmpty) {
                                  final Map<String, dynamic> userData = users.first.data;
                                  final List<dynamic> followers =
                                      List<dynamic>.from(userData['followers'] as List? ?? []);
                                  followers.add(globals.prismUser.email);
                                  await firestoreClient.updateDoc(
                                    USER_NEW_COLLECTION,
                                    users.first.id,
                                    <String, dynamic>{'followers': followers},
                                    sourceTag: 'startup.follow.target.update',
                                  );
                                }
                                http.post(
                                  Uri.parse(
                                    'https://fcm.googleapis.com/fcm/send',
                                  ),
                                  headers: <String, String>{
                                    'Content-Type': 'application/json',
                                    'Authorization': 'key=${Env.fcmServerKey}',
                                  },
                                  body: jsonEncode(
                                    <String, dynamic>{
                                      'notification': <String, dynamic>{
                                        'title': '🎉 New Follower!',
                                        'body': '${globals.prismUser.username} is now following you.',
                                        'color': "#e57697",
                                        'image': globals.prismUser.profilePhoto,
                                        'android_channel_id': "followers",
                                        'tag': '${globals.prismUser.username} Follow',
                                        'icon': '@drawable/ic_follow',
                                      },
                                      'priority': 'high',
                                      'data': <String, dynamic>{
                                        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
                                        'id': '1',
                                        'status': 'done'
                                      },
                                      'to': "/topics/${email.split("@")[0]}"
                                    },
                                  ),
                                );
                                toasts.codeSend("Followed $name!");
                              },
                              style: ButtonStyle(
                                shape: WidgetStateProperty.resolveWith(
                                    (states) => RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                                backgroundColor: WidgetStateColor.resolveWith((states) => const Color(0xFFE57697)),
                              ),
                              child: const SizedBox(
                                width: 65,
                                child: Text(
                                  'FOLLOW',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontFamily: "Roboto",
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
          Card(
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(10),
                bottomRight: Radius.circular(10),
              ),
            ),
            color: Colors.white,
            elevation: 4,
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.width * 0.8 / 3,
              child: Row(
                children: [
                  FollowImage(img1: img1),
                  FollowImage(img1: img2),
                  FollowImage(img1: img3),
                ],
              ),
            ),
          ),
          const SizedBox(
            height: 17,
          )
        ],
      ),
    );
  }
}

class _FirestoreDoc {
  const _FirestoreDoc(this.id, this.data);

  final String id;
  final Map<String, dynamic> data;
}

class FollowImage extends StatelessWidget {
  const FollowImage({
    super.key,
    required this.img1,
  });

  final String img1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: (MediaQuery.of(context).size.width * 0.8 - 48) / 3,
          width: (MediaQuery.of(context).size.width * 0.8 - 48) / 3,
          child: CachedNetworkImage(
            imageUrl: img1,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
//  OptionalInfo(
//   img: Image.asset(
//       'assets/images/first.png'),
//   heading:
//       'Interact with community',
//   subheading:
//       'Add your twitter or instagram handles below',
//   showSkip: true,
//   skipText: "Skip",
//   doneText: "DONE",
//   )

// OptionalInfo2(
//   img: Image.asset(
//       'assets/images/first.png'),
//   heading:
//       'Get paid for your work!',
//   subheading:
//       'Apply to become a verified user below',
//   showSkip: true,
//   skipText: "Skip",
//   doneText: "DONE",
// )
