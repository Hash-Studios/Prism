import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/core/state/app_state.dart';
import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:Prism/theme/contrast.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

void showNoLoadLinksPopUp(BuildContext context, Map link) {
  final AlertDialog linkPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    title: Text(
      'More links',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Theme.of(context).colorScheme.secondary),
    ),
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.error,
          foregroundColor: onColor(Theme.of(context).colorScheme.error),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('Close', style: TextStyle(fontSize: 16.0)),
      ),
    ],
    content: Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).primaryColor),
      width: MediaQuery.of(context).size.width * .78,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Wrap(
            alignment: WrapAlignment.center,
            children: link.keys
                .toList()
                .map(
                  (e) => ActionButton(
                    icon: profileLinkIcon(e.toString()),
                    link: link[e].toString(),
                    text: e.toString().inCaps,
                  ),
                )
                .toList(),
          ),
        ],
      ),
    ),
    backgroundColor: Theme.of(context).primaryColor,
    actionsPadding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
  );
  showModal(context: context, builder: (BuildContext context) => linkPopUp);
}
