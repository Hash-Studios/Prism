import 'package:flutter/material.dart';

class UndefinedScreen extends StatelessWidget {
  final String? name;
  const UndefinedScreen({super.key, this.name});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text('Route for $name is not defined'),
      ),
    );
  }
}
