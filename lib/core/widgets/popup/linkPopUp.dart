import 'package:Prism/auth/google_auth.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/widgets/animated/loader.dart';
import 'package:Prism/data/links/model/linksModel.dart';
import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:Prism/logger/logger.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

void showLinksPopUp(BuildContext context, String id) {
  Future<List<LinksModel>> getLinks(String id) async {
    List<LinksModel> links = [];
    logger.d(id);
    final userData = await firestoreClient.getById<Map<String, dynamic>>(
      USER_NEW_COLLECTION,
      id,
      (data, _) => data,
      sourceTag: 'profile.linksPopup.get',
    );
    links = linksToModel(userData?["links"] as Map? ?? <String, dynamic>{});
    logger.d(links.toString());
    return links;
  }

  final AlertDialog linkPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: FutureBuilder<List<LinksModel>>(
        future: getLinks(id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none) {
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
                        .map((e) => ActionButton(icon: e.icon, link: e.link, text: "@${e.username}"))
                        .toList(),
                  ),
                ],
              );
            }
            Navigator.pop(context);
            return Container();
          }
        },
      ),
    ),
    backgroundColor: Theme.of(context).primaryColor,
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
  );
  showModal(context: context, builder: (BuildContext context) => linkPopUp);
}
