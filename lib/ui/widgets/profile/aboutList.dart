import 'package:Prism/routes/routing_constants.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/material.dart';

class AboutList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
        leading: const Icon(JamIcons.info),
        title: Text(
          "About Prism",
          style: TextStyle(
              color: Theme.of(context).accentColor,
              fontWeight: FontWeight.w500,
              fontFamily: "Proxima Nova"),
        ),
        subtitle: const Text(
          "GitHub, website & more!",
          style: TextStyle(fontSize: 12),
        ),
        trailing: const Icon(JamIcons.chevron_right),
        onTap: () {
          Navigator.pushNamed(context, aboutRoute);
        });
  }
}
