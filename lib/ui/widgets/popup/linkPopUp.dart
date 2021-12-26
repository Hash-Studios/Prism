import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/data/links/model/linksModel.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/ui/pages/profile/aboutScreen.dart';
import 'package:Prism/ui/widgets/animated/loader.dart';
import 'package:animations/animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

void showLinksPopUp(BuildContext context, String id) {
  Future<List<LinksModel>> getLinks(String id) async {
    List<LinksModel> links = [];
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    logger.d(id);
    await firestore.collection(USER_NEW_COLLECTION).doc(id).get().then((value) {
      links = linksToModel(value.data()!["links"] as Map);
      logger.d(links.toString());
    });
    return links;
  }

  final AlertDialog linkPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: FutureBuilder<List<LinksModel>>(
          future: getLinks(id),
          builder: (context, snapshot) {
            if (snapshot == null) {
              logger.d("snapshot null");
              return SizedBox(height: 300, child: Center(child: Loader()));
            }
            if (snapshot.connectionState == ConnectionState.waiting ||
                snapshot.connectionState == ConnectionState.none) {
              logger.d("snapshot none, waiting");
              return SizedBox(height: 300, child: Center(child: Loader()));
            } else {
              if (snapshot.data!.isNotEmpty) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Wrap(
                      alignment: WrapAlignment.center,
                      children: snapshot.data!
                          .map(
                            (e) => ActionButton(
                              icon: e.icon,
                              link: e.link,
                              text: "@${e.username}",
                            ),
                          )
                          .toList(),
                    ),
                  ],
                );
              }
              Navigator.pop(context);
              return Container();
            }
          }),
    ),
    backgroundColor: Theme.of(context).primaryColor,
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
  );
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => linkPopUp);
}
