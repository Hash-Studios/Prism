import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

void showChangelog(BuildContext context, Function func) {
  Dialog aboutPopUp = Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: SingleChildScrollView(
      child: Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Theme.of(context).primaryColor),
        width: MediaQuery.of(context).size.width * .75,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              height: 150,
              width: MediaQuery.of(context).size.width * .75,
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20)),
                  color: Theme.of(context).hintColor),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Image.asset(
                  'assets/images/appIcon.png',
                  fit: BoxFit.scaleDown,
                ),
              ),
            ),
            Row(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 0, 4),
                  child: Text(
                    'v2.0.0',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: Theme.of(context).accentColor),
                  ),
                ),
              ],
            ),
            SizedBox(
              height: 20,
            ),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Padding(
                padding: EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Icon(
                      JamIcons.phone,
                      size: 22,
                      color: Color(0xFFE57697),
                    ),
                    SizedBox(height: 10),
                    Icon(
                      JamIcons.camera,
                      size: 22,
                      color: Color(0xFFE57697),
                    ),
                    SizedBox(height: 10),
                    Icon(
                      JamIcons.search,
                      size: 22,
                      color: Color(0xFFE57697),
                    ),
                    SizedBox(height: 10),
                    Icon(
                      JamIcons.brush,
                      size: 22,
                      color: Color(0xFFE57697),
                    ),
                    SizedBox(height: 10),
                    Icon(
                      JamIcons.pictures,
                      size: 22,
                      color: Color(0xFFE57697),
                    ),
                    SizedBox(height: 10),
                    Icon(
                      JamIcons.google,
                      size: 22,
                      color: Color(0xFFE57697),
                    ),
                    SizedBox(height: 10),
                    Icon(
                      JamIcons.settings_alt,
                      size: 22,
                      color: Color(0xFFE57697),
                    ),
                    SizedBox(height: 10),
                    Icon(
                      JamIcons.eyedropper,
                      size: 22,
                      color: Color(0xFFE57697),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.only(right: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      "Completely new redesigned UI.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                    SizedBox(height: 13),
                    Text(
                      "Added Pexels API support.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                    SizedBox(height: 13),
                    Text(
                      "Added new color search.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                    SizedBox(height: 13),
                    Text(
                      "Added new themes.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                    SizedBox(height: 13),
                    Text(
                      "Added 1M+ wallpapers.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                    SizedBox(height: 13),
                    Text(
                      "Added non intrusive sign in support.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                    SizedBox(height: 13),
                    Text(
                      "Added new quick wallpaper actions.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                    SizedBox(height: 13),
                    Text(
                      "Added new palette generator.",
                      style: Theme.of(context)
                          .textTheme
                          .headline6
                          .copyWith(color: Theme.of(context).accentColor),
                    ),
                  ],
                ),
              ),
            ]),
            SizedBox(
              height: 25,
            ),
            FlatButton(
              shape: StadiumBorder(),
              color: Color(0xFFE57697),
              onPressed: () {
                Navigator.of(context).pop();
                func();
              },
              child: Text(
                'CLOSE',
                style: TextStyle(
                  fontSize: 16.0,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(
              height: 15,
            ),
          ],
        ),
      ),
    ),
  );
  showDialog(context: context, builder: (BuildContext context) => aboutPopUp);
}
