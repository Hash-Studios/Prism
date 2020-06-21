import 'package:Prism/routing_constants.dart';
import 'package:Prism/ui/widgets/onBoardButton.dart';
import 'package:Prism/ui/widgets/onBoardCaption.dart';
import 'package:Prism/ui/widgets/onBoardHeading.dart';
import 'package:Prism/ui/widgets/onBoardPageIndicator.dart';
import 'package:flutter/material.dart';

import 'package:Prism/theme/config.dart' as config;

class OnboardScreen2 extends StatefulWidget {
  @override
  _OnboardScreen2State createState() => _OnboardScreen2State();
}

class _OnboardScreen2State extends State<OnboardScreen2> {
  double opacity = 0;
  String heading = 'Eco-friendly';
  int index = 2;
  String buttonText = "Next";
  void func() {
    Navigator.pushNamed(context, OnboardRoute3);
  }

  String caption =
      "One of the first conditions of happiness\nlink between man & nature.";

  void setOpacity() {
    setState(() {
      opacity = 0;
    });
    Future.delayed(Duration(seconds: 0)).then((value) {
      setState(() {
        opacity = 1;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    setOpacity();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      floatingActionButton: Stack(
        children: <Widget>[
          Positioned(
            top: 40,
            left: 20,
            child: FloatingActionButton(
              onPressed: () {
                Navigator.pop(context);
              },
              backgroundColor: Colors.transparent,
              child: Icon(
                Icons.arrow_back,
                color: Theme.of(context).primaryColor,
              ),
              elevation: 0,
              highlightElevation: 0,
              disabledElevation: 0,
              focusElevation: 0,
              splashColor: Colors.transparent,
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: config.Colors().peachy,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 70,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                      child: OnboardHeading(heading: heading),
                    ),
                    OnboardCaption(caption: caption),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 95.0),
                      child: Container(
                        width: width,
                        child: AnimatedOpacity(
                          duration: Duration(seconds: 1),
                          opacity: opacity,
                          curve: Curves.easeInBack,
                          child: AnimatedPadding(
                            duration: Duration(seconds: 1),
                            padding: opacity == 0
                                ? EdgeInsets.fromLTRB(50, 50, 50, 20)
                                : EdgeInsets.fromLTRB(110, 50, 110, 20),
                            curve: Curves.easeInBack,
                            child: Image(
                                image: AssetImage("assets/images/onboard2.png"),
                                fit: BoxFit.fitWidth),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 60,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      OnboardPageIndicator(index: index),
                      OnboardButton(
                          width: width, buttonText: buttonText, func: func),
                    ]),
              )
            ],
          ),
        ),
      ),
    );
  }
}
