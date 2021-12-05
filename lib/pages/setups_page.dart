import 'package:flutter/material.dart';
import 'package:prism/widgets/inherited_container.dart';
import 'package:prism/widgets/scroll_navigation_bar_controller.dart';
import 'package:scroll_app_bar/scroll_app_bar.dart';

class SetupsPage extends StatelessWidget {
  const SetupsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ScrollController controller =
        InheritedContainer.of(context)!.controller;
    return Snap(
      controller: controller.bottomNavigationBar,
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
