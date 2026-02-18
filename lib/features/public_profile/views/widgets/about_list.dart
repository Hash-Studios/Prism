import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

class AboutList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(JamIcons.info),
      title: Text(
        "About Prism",
        style: TextStyle(
          color: Theme.of(context).colorScheme.secondary,
          fontWeight: FontWeight.w500,
          fontFamily: "Proxima Nova",
        ),
      ),
      subtitle: const Text("GitHub, website & more!", style: TextStyle(fontSize: 12)),
      trailing: const Icon(JamIcons.chevron_right),
      onTap: () {
        context.router.push(const AboutRoute());
      },
    );
  }
}
