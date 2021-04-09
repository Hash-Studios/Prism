import 'package:flutter/material.dart';

class UndefinedScreen extends StatelessWidget {
  final String? name;
  const UndefinedScreen({Key? key, this.name}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Route for $name is not defined'),
      ),
    );
  }
}
