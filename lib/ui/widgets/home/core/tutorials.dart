import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/animated_focus_light.dart';
import 'package:tutorial_coach_mark/target_position.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

void initTargets(List<TargetFocus> targets, var width, var height) {
  targets.add(TargetFocus(
    identify: "Target 0",
    targetPosition: TargetPosition(Size(0, 0), Offset(0, 0)),
    contents: [
      ContentTarget(
          align: AlignContent.bottom,
          child: SizedBox(
            height: height,
            child: Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    "🎉",
                    style: TextStyle(fontSize: 100),
                  ),
                  SizedBox(height: 20),
                  Text(
                    "Hey! Welcome to Prism.",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 20.0),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 10.0),
                    child: RichText(
                      text: TextSpan(
                        text:
                            "➜ Let's start your beautiful journey with a quick intro.\n\n➜ Tap anywhere on the screen to continue.",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  SizedBox(height: 120),
                ],
              ),
            ),
          ))
    ],
    shape: ShapeLightFocus.Circle,
  ));
  targets.add(TargetFocus(
    identify: "Target 1",
    targetPosition: TargetPosition(Size(width, 60), Offset(0, 20)),
    contents: [
      ContentTarget(
          align: AlignContent.bottom,
          child: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(height: 20),
                Text(
                  "This is the Categories Bar.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: RichText(
                    text: TextSpan(
                        text: "➜ Here you can find all ",
                        style: TextStyle(color: Colors.white),
                        children: [
                          TextSpan(
                            text: "notifications, wallpapers, collections ",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: "and "),
                          TextSpan(
                            text: "categories.",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ]),
                  ),
                )
              ],
            ),
          ))
    ],
    shape: ShapeLightFocus.RRect,
  ));
  targets.add(TargetFocus(
    identify: "Target 2",
    targetPosition: TargetPosition(Size(width, height - 400), Offset(0, 70)),
    contents: [
      ContentTarget(
          align: AlignContent.bottom,
          child: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "This is the Wallpapers Feed.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: RichText(
                    text: TextSpan(
                        text: "➜ Swipe ",
                        style: TextStyle(color: Colors.white),
                        children: [
                          TextSpan(
                            text: "vertically ",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                              text:
                                  "to see all the wallpapers in a category.\n\n"),
                          TextSpan(text: "➜ Swipe "),
                          TextSpan(
                            text: "horizontally ",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                              text:
                                  "to switch between wallpapers and collections.\n\n"),
                        ]),
                  ),
                )
              ],
            ),
          ))
    ],
    shape: ShapeLightFocus.RRect,
  ));
  targets.add(TargetFocus(
    targetPosition:
        TargetPosition(Size(width * 0.5, width * 0.5 / 0.6625), Offset(0, 270)),
    identify: "Target 3",
    contents: [
      ContentTarget(
          align: AlignContent.bottom,
          child: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "Tap on a wallpaper to view it.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: RichText(
                    text: TextSpan(
                        text: "➜ You can also ",
                        style: TextStyle(color: Colors.white),
                        children: [
                          TextSpan(
                            text: "apply, favorite,",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: " and"),
                          TextSpan(
                            text: " download",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                              text: " it directly from the 3-dots menu.\n\n"),
                          TextSpan(text: "➜ You can also "),
                          TextSpan(
                            text: "tap and hold ",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                              text:
                                  "any wallpaper to quickly copy its sharing link.\n\n"),
                        ]),
                  ),
                )
              ],
            ),
          ))
    ],
    shape: ShapeLightFocus.RRect,
  ));
  targets.add(TargetFocus(
    targetPosition:
        TargetPosition(Size(292, 90), Offset((width - 292) / 2, height - 90)),
    identify: "Target 4",
    contents: [
      ContentTarget(
          align: AlignContent.top,
          child: Container(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  "This is the navigation bar.",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 20.0),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: RichText(
                    text: TextSpan(
                        text: "➜ Here you can ",
                        style: TextStyle(color: Colors.white),
                        children: [
                          TextSpan(
                            text: "access, upload,",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: " and"),
                          TextSpan(
                            text: " search",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: " for more wallpapers.\n\n"),
                          TextSpan(text: "➜ You can also view "),
                          TextSpan(
                            text: "home screen setups ",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: "from here.\n\n"),
                          TextSpan(text: "➜ You can also access your "),
                          TextSpan(
                            text: "profile ",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: "from here.\n\n"),
                        ]),
                  ),
                )
              ],
            ),
          ))
    ],
    shape: ShapeLightFocus.RRect,
  ));
}
