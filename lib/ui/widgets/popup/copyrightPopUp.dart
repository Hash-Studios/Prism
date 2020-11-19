import 'package:flutter/material.dart';
import 'package:Prism/theme/config.dart' as config;

class CopyrightPopUp extends StatelessWidget {
  final bool setup;
  const CopyrightPopUp({@required this.setup});
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: Text(
        "LICENSE",
        style: Theme.of(context)
            .textTheme
            .headline6
            .copyWith(color: Theme.of(context).accentColor),
      ),
      content: SingleChildScrollView(
        child: Text(
          setup == true
              ? "This setup is a property of their respective owner. You can use it for your personal use only. Any distribution or sharing is not allowed without the permission of the owner."
              : "This wallpaper is a property of their respective owner. You can use it for your personal use only. Any distribution or sharing is not allowed without the permission of the owner.",
          style: Theme.of(context)
              .textTheme
              .headline6
              .copyWith(color: Theme.of(context).accentColor),
        ),
      ),
      actions: [
        FlatButton(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
          color: config.Colors().mainAccentColor(1),
          onPressed: () {
            Navigator.pop(context);
          },
          child: Text("OK",
              style: TextStyle(
                color: Theme.of(context).accentColor,
              )),
        )
      ],
      backgroundColor: Theme.of(context).primaryColor,
      actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
    );
  }
}
