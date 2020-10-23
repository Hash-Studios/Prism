import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/animated_focus_light.dart';
import 'package:tutorial_coach_mark/target_position.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

void initTargets(List<TargetFocus> targets, double width, double height) {
  targets.add(TargetFocus(
    identify: "Target 0",
    targetPosition: TargetPosition(const Size(0, 0), const Offset(0, 0)),
    contents: [
      ContentTarget(
          child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              "🎉",
              style: TextStyle(fontSize: 100),
            ),
            const SizedBox(height: 20),
            const Text(
              "Hey! Welcome to Prism.",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 20.0),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: RichText(
                text: const TextSpan(
                  text:
                      "➜ Let's start your beautiful journey with a quick intro.\n\n➜ Tap anywhere on the screen to continue.",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 120),
          ],
        ),
      ))
    ],
    shape: ShapeLightFocus.Circle,
  ));
  targets.add(TargetFocus(
    identify: "Target 1",
    targetPosition: TargetPosition(Size(width, 60), const Offset(0, 20)),
    contents: [
      ContentTarget(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 20),
          const Text(
            "This is the Categories Bar.",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20.0),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: RichText(
              text: const TextSpan(
                  text: "➜ Here you can find all ",
                  style: TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: "notifications, wallpapers, collections ",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: "and "),
                    TextSpan(
                      text: "categories.",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ]),
            ),
          )
        ],
      ))
    ],
    shape: ShapeLightFocus.RRect,
  ));
  targets.add(TargetFocus(
    identify: "Target 2",
    targetPosition:
        TargetPosition(Size(width, height - 400), const Offset(0, 70)),
    contents: [
      ContentTarget(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            "This is the Wallpapers Feed.",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20.0),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: RichText(
              text: const TextSpan(
                  text: "➜ Swipe ",
                  style: TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: "vertically ",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                        text: "to see all the wallpapers in a category.\n\n"),
                    TextSpan(text: "➜ Swipe "),
                    TextSpan(
                      text: "horizontally ",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                        text:
                            "to switch between wallpapers and collections.\n\n"),
                  ]),
            ),
          )
        ],
      ))
    ],
    shape: ShapeLightFocus.RRect,
  ));
  targets.add(TargetFocus(
    targetPosition: TargetPosition(
        Size(width * 0.5, width * 0.5 / 0.6625), const Offset(0, 270)),
    identify: "Target 3",
    contents: [
      ContentTarget(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            "Tap on a wallpaper to view it.",
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 20.0),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 10.0),
            child: RichText(
              text: const TextSpan(
                  text: "➜ You can also ",
                  style: TextStyle(color: Colors.white),
                  children: [
                    TextSpan(
                      text: "apply, favorite,",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: " and"),
                    TextSpan(
                      text: " download",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: " it directly from the 3-dots menu.\n\n"),
                    TextSpan(text: "➜ You can also "),
                    TextSpan(
                      text: "tap and hold ",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                        text:
                            "any wallpaper to quickly copy its sharing link.\n\n"),
                  ]),
            ),
          )
        ],
      ))
    ],
    shape: ShapeLightFocus.RRect,
  ));
  targets.add(TargetFocus(
    targetPosition: TargetPosition(
        const Size(292, 90), Offset((width - 292) / 2, height - 90)),
    identify: "Target 4",
    contents: [
      ContentTarget(
          align: AlignContent.top,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                "This is the navigation bar.",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 20.0),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10.0),
                child: RichText(
                  text: const TextSpan(
                      text: "➜ Here you can ",
                      style: TextStyle(color: Colors.white),
                      children: [
                        TextSpan(
                          text: "access, upload,",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: " and"),
                        TextSpan(
                          text: " search",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: " for more wallpapers.\n\n"),
                        TextSpan(text: "➜ You can also view "),
                        TextSpan(
                          text: "home screen setups ",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: "from here.\n\n"),
                        TextSpan(text: "➜ You can also access your "),
                        TextSpan(
                          text: "profile ",
                          style: TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: "from here.\n\n"),
                      ]),
                ),
              )
            ],
          ))
    ],
    shape: ShapeLightFocus.RRect,
  ));
}
