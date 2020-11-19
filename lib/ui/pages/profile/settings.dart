import 'package:Prism/routes/router.dart';
import 'package:Prism/ui/widgets/home/core/headingChipBar.dart';
import 'package:Prism/ui/widgets/profile/generalList.dart';
import 'package:Prism/ui/widgets/profile/premiumList.dart';
import 'package:Prism/ui/widgets/profile/studioList.dart';
import 'package:Prism/ui/widgets/profile/userList.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        if (navStack.length > 1) navStack.removeLast();
        debugPrint(navStack.toString());
        return true;
      },
      child: Scaffold(
          backgroundColor: Theme.of(context).primaryColor,
          appBar: const PreferredSize(
            preferredSize: Size(double.infinity, 55),
            child: HeadingChipBar(
              current: "Settings",
            ),
          ),
          body: ListView(children: <Widget>[
            PremiumList(),
            const GeneralList(
              expanded: true,
            ),
            UserList(
              expanded: true,
            ),
            const StudioList(),
          ])),
    );
  }
}
