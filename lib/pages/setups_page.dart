import 'package:flutter/material.dart';
import 'package:scroll_app_bar/scroll_app_bar.dart';

class SetupsPage extends StatelessWidget {
  const SetupsPage({Key? key, required this.controller}) : super(key: key);

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    return Snap(
      controller: controller.appBar,
      child: ListView.builder(
        controller: controller,
        itemCount: 200,
        itemBuilder: (context, index) => Card(
          margin: const EdgeInsets.all(16),
          child: SizedBox(
            height: 100,
            child: Center(
              child: Text('$index'),
            ),
          ),
        ),
      ),
    );
  }
}
