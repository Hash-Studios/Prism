import 'package:Prism/routing_constants.dart';
import 'package:Prism/ui/widgets/onboardButton.dart';
import 'package:Prism/ui/widgets/onboardCaption.dart';
import 'package:Prism/ui/widgets/onboardHeading.dart';
import 'package:Prism/ui/widgets/onboardPageIndicator.dart';
import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;

class OnboardScreen3 extends StatefulWidget {
  @override
  _OnboardScreen3State createState() => _OnboardScreen3State();
}

class _OnboardScreen3State extends State<OnboardScreen3> {
  double opacity = 0;
  String heading = 'Eco-friendly';
  int index = 3;
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
          gradient: config.Colors().mildSea,
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
                      padding: const EdgeInsets.all(20.0),
                      child: OnboardHeading(heading: heading),
                    ),
                    Container(
                      width: width,
                      child: AnimatedOpacity(
                        duration: Duration(seconds: 1),
                        opacity: opacity,
                        curve: Curves.easeInBack,
                        child: AnimatedPadding(
                          duration: Duration(seconds: 1),
                          padding: opacity == 0
                              ? EdgeInsets.only(bottom: 0)
                              : EdgeInsets.fromLTRB(40, 40, 40, 50),
                          curve: Curves.easeInBack,
                          child: Image(
                              image: AssetImage("assets/images/onboard3.png"),
                              fit: BoxFit.fitWidth),
                        ),
                      ),
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
                        width: width,
                        buttonText: "Next",
                        func: () {
                          // Navigator.pushNamedAndRemoveUntil(
                          //     context, SignUpLandingRoute, (context) => false);
                        }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
