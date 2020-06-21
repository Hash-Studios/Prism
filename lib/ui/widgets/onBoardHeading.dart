import 'package:flutter/material.dart';

class OnboardHeading extends StatelessWidget {
  const OnboardHeading({
    Key key,
    @required this.heading,
  }) : super(key: key);

  final String heading;

  @override
  Widget build(BuildContext context) {
    return Text(
      heading,
      style:
          Theme.of(context).textTheme.bodyText1.copyWith(color: Colors.white),
    );
  }
}