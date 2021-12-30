import 'package:flutter/material.dart';

class SetupsPage extends StatelessWidget {
  const SetupsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final ScrollController controller = ScrollController();
    return ListView.builder(
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
    );
  }
}
