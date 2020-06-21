import 'package:Prism/routing_constants.dart';
import 'package:Prism/ui/widgets/onBoardButton.dart';
import 'package:Prism/ui/widgets/onBoardCaption.dart';
import 'package:Prism/ui/widgets/onBoardHeading.dart';
import 'package:Prism/ui/widgets/onBoardPageIndicator.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;

class OnboardScreen1 extends StatefulWidget {
  @override
  _OnboardScreen1State createState() => _OnboardScreen1State();
}

class _OnboardScreen1State extends State<OnboardScreen1> {
  double opacity = 0;
  String heading = 'Eco-friendly';
  int index = 1;
  String buttonText = "Next";
  void func() {
    Navigator.pushNamed(context, OnboardRoute2);
  }

  String caption =
      "Look deep into nature, and then you will\nunderstand everything better.";

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
      body: Container(
        decoration: BoxDecoration(
          gradient: config.Colors().nebula,
        ),
        child: Center(
          child: Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              Positioned(
                top: 30,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: width,
                      child: AnimatedOpacity(
                        duration: Duration(seconds: 1),
                        opacity: opacity,
                        curve: Curves.easeInBack,
                        child: AnimatedPadding(
                          duration: Duration(seconds: 1),
                          padding: opacity == 0
                              ? EdgeInsets.only(top: 0, bottom: 20)
                              : EdgeInsets.only(top: 40, bottom: 20),
                          curve: Curves.easeInBack,
                          child: Image(
                              image: AssetImage("assets/images/onboard1.png"),
                              fit: BoxFit.fitWidth),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 0, 0, 20),
                      child: OnboardHeading(heading: heading),
                    ),
                    OnboardCaption(caption: caption),
                  ],
                ),
              ),
              Positioned(
                bottom: 60,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      OnboardPageIndicator(index: index),
                      OnboardButton(
                          width: width, buttonText: buttonText, func: func)
                    ]),
              )
            ],
          ),
        ),
      ),
    );
  }
}
