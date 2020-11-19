import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:animations/animations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;

final databaseReference = Firestore.instance;
List<Color> colors = [
  const Color(0xFFFF0000),
  const Color(0xFFF44436),
  const Color(0xFFe91e63),
  const Color(0xFF9c27b0),
  const Color(0xFF673ab7),
  const Color(0xFF0000FF),
  const Color(0xFF1976D2),
  const Color(0xFF03a9f4),
  const Color(0xFF00bcd4),
  const Color(0xFF009688),
  const Color(0xFF4caf50),
  const Color(0xFF00FF00),
  const Color(0xFF8bc34a),
  const Color(0xFFcddc39),
  const Color(0xFFffeb3b),
  const Color(0xFFffc107),
  const Color(0xFFff9800),
  const Color(0xFFff5722),
  const Color(0xFF795548),
  const Color(0xFF9e9e9e),
  const Color(0xFF607d8b),
  const Color(0xFF000000),
  const Color(0xFFFFFFFF)
];
List<Color> accentColors = [
  const Color(0xFFFF0000),
  const Color(0xFFF44436),
  const Color(0xFFe91e63),
  const Color(0xFF9c27b0),
  const Color(0xFF673ab7),
  const Color(0xFF0000FF),
  const Color(0xFF1976D2),
  const Color(0xFF03a9f4),
  const Color(0xFF00bcd4),
  const Color(0xFF009688),
  const Color(0xFF4caf50),
  const Color(0xFF00FF00),
  const Color(0xFF8bc34a),
  const Color(0xFFcddc39),
  const Color(0xFFffeb3b),
  const Color(0xFFffc107),
  const Color(0xFFff9800),
  const Color(0xFFff5722),
  const Color(0xFF795548),
  const Color(0xFF9e9e9e),
  const Color(0xFF607d8b),
  const Color(0xFFE57697),
];
Color currentColor = const Color(0xFFFF0000);

Color showColors(BuildContext context) {
  final AlertDialog colorPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    content: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
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
                borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(10),
                    topRight: Radius.circular(10)),
                color: Theme.of(context).hintColor),
            child: const FlareActor(
              "assets/animations/Color.flr",
              animation: "color",
            ),
          ),
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                child: Text(
                  "Select a color",
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: Theme.of(context).accentColor),
                ),
              ),
            ],
          ),
          const SizedBox(
            height: 5,
          ),
          Wrap(
            children: <Widget>[
              for (var color in colors)
                GestureDetector(
                  onTap: () {
                    currentColor = color;
                    debugPrint(navStack.toString());
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      colorRoute,
                      arguments: [
                        color
                            .toString()
                            .replaceAll(
                                "MaterialColor(primary value: Color(0xff", "")
                            .replaceAll("Color(0xff", "")
                            .replaceAll(")", ""),
                      ],
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.white38,
                      ),
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const SizedBox(
                      width: 41,
                      height: 41,
                    ),
                  ),
                )
            ],
          ),
        ],
      ),
    ),
    actions: [
      FlatButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: config.Colors().mainAccentColor(1),
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text(
          'CLOSE',
          style: TextStyle(fontSize: 16.0, color: Colors.white),
        ),
      ),
    ],
    contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    backgroundColor: Theme.of(context).primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
  );
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => colorPopUp);
}
