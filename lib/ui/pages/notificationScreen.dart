import 'package:flutter/material.dart';
import 'package:Prism/routes/router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';

class NotificationScreen extends StatefulWidget {
  @override
  _NotificationScreenState createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Notifications"),
        leading: IconButton(
          icon: Icon(JamIcons.close),
          onPressed: () {
            if (navStack.length > 1) navStack.removeLast();
            print(navStack);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }
}
