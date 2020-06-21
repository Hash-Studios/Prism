import 'package:flutter/material.dart';

class MainWidget extends StatelessWidget {
  const MainWidget({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        title: Text('Material App Bar'),
        elevation: 0,
      ),
    );
  }
}
