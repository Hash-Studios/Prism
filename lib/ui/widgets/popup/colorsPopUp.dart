import 'package:Prism/routes/router.dart';
import 'package:Prism/routes/routing_constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flare_flutter/flare_actor.dart';
import 'package:flutter/material.dart';

final databaseReference = Firestore.instance;
List<Color> colors = [
  Color(0xFFFF0000),
  Color(0xFFF44436),
  Color(0xFFe91e63),
  Color(0xFF9c27b0),
  Color(0xFF673ab7),
  Color(0xFF0000FF),
  Color(0xFF1976D2),
  Color(0xFF03a9f4),
  Color(0xFF00bcd4),
  Color(0xFF009688),
  Color(0xFF4caf50),
  Color(0xFF00FF00),
  Color(0xFF8bc34a),
  Color(0xFFcddc39),
  Color(0xFFffeb3b),
  Color(0xFFffc107),
  Color(0xFFff9800),
  Color(0xFFff5722),
  Color(0xFF795548),
  Color(0xFF9e9e9e),
  Color(0xFF607d8b),
  Color(0xFF000000),
  Color(0xFFFFFFFF)
];
Color currentColor = Color(0xFFFF0000);

Color showColors(BuildContext context) {
  Dialog colorPopUp = Dialog(
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
              "assets/animations/Color.flr",
              isPaused: false,
              alignment: Alignment.center,
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
          SizedBox(
            height: 5,
          ),
          Wrap(
            children: <Widget>[
              for (var color in colors)
                GestureDetector(
                  child: Container(
                    margin: EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.white38,
                          width: 1,
                          style: BorderStyle.solid),
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: SizedBox(
                      width: 41,
                      height: 41,
                    ),
                  ),
                  onTap: () {
                    currentColor = color;
                    print(navStack);
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      ColorRoute,
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
                )
            ],
          ),
          SizedBox(
            height: 15,
          ),
          FlatButton(
            shape: StadiumBorder(),
            color: Color(0xFFE57697),
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text(
              'CLOSE',
              style: TextStyle(fontSize: 16.0, color: Colors.white),
            ),
          ),
          SizedBox(
            height: 15,
          ),
        ],
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => colorPopUp);
}
