import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:Prism/global/globals.dart' as globals;
import 'package:Prism/theme/config.dart' as config;

final databaseReference = Firestore.instance;

void showUpdate(BuildContext context) {
  Dialog aboutPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            height: 150,
            width: MediaQuery.of(context).size.width * .78,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20)),
                color: Theme.of(context).hintColor),
            child: FlareActor(
              "assets/animations/Update.flr",
              isPaused: false,
              alignment: Alignment.center,
              animation: "update",
            ),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                child: Text(
                  'New version ' +
                      globals.versionInfo["version_number"] +
                      ' Available!',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Theme.of(context).accentColor),
                ),
              ),
            ],
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    'Version ' +
                        globals.versionInfo["version_number"] +
                        ' includes -',
                    style: TextStyle(
                        fontSize: 14, color: Theme.of(context).accentColor),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 20,
          ),
          for (var feature in globals.versionInfo["version_desc"].split("^*^"))
            Padding(
              padding: const EdgeInsets.only(bottom: 10.0),
              child: (Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                  ),
                  Icon(
                    JamIcons.arrow_right,
                    size: 22,
                    color: config.Colors().mainAccentColor(1),
                  ),
                  SizedBox(
                    width: 20,
                  ),
                  Container(
                    width: MediaQuery.of(context).size.width * 0.6,
                    child: Text(
                      feature.toString(),
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                  ),
                ],
              )),
            ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.6,
                  child: Text(
                    'Update now available on the Google Play Store.',
                    style: TextStyle(
                        fontSize: 14, color: Theme.of(context).accentColor),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 25,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: <Widget>[
              FlatButton(
                shape: StadiumBorder(),
                color: config.Colors().mainAccentColor(1),
                onPressed: () async {
                  Navigator.of(context).pop();
                  const url =
                      'https://play.google.com/store/apps/details?id=com.hash.prism';
                  if (await canLaunch(url)) {
                    await launch(url);
                  } else {
                    throw 'Could not launch $url';
                  }
                },
                child: Text(
                  'UPDATE',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: Colors.white,
                  ),
                ),
              ),
              FlatButton(
                shape: StadiumBorder(),
                color: Colors.transparent,
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text(
                  'CLOSE',
                  style: TextStyle(
                    fontSize: 16.0,
                    color: config.Colors().mainAccentColor(1),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 15,
          ),
        ],
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => aboutPopUp);
}
