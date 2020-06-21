import 'package:flutter/material.dart';

class OnboardCaption extends StatelessWidget {
  const OnboardCaption({
    Key key,
    @required this.caption,
  }) : super(key: key);

  final String caption;

  @override
  Widget build(BuildContext context) {
    return Text(
      caption,
      textAlign: TextAlign.center,
      style:
          Theme.of(context).textTheme.bodyText2.copyWith(color: Colors.white70),
    );
  }
}