import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;

class OnboardButton extends StatelessWidget {
  const OnboardButton({
    Key key,
    @required this.width,
    @required this.buttonText,
    @required this.func,
  }) : super(key: key);

  final double width;
  final String buttonText;
  final func;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'OnboardButton',
      transitionOnUserGestures: true,
      child: Padding(
        padding: const EdgeInsets.only(top: 10.0),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                  color: Color(0xFFEFF5FF).withOpacity(0.4),
                  blurRadius: 16,
                  offset: Offset(0, 4)),
            ],
            borderRadius: BorderRadius.circular(500),
          ),
          child: FlatButton(
            colorBrightness: Brightness.light,
            padding: EdgeInsets.all(0),
            shape: StadiumBorder(),
            onPressed: func,
            child: SizedBox(
              width: width * 0.75,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 15.0),
                child: Text(
                  buttonText,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.button.copyWith(
                        color: config.Colors().mainColor(1),
                      ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}