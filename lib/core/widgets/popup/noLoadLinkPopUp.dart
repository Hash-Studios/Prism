// import 'package:Prism/data/links/model/linksModel.dart';
import 'package:Prism/core/state/app_state.dart';
import 'package:Prism/features/public_profile/public_profile.dart';
import 'package:Prism/features/session/views/pages/about_screen.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

void showNoLoadLinksPopUp(BuildContext context, Map link) {
  // List<LinksModel> links = [];
  // void getLinks(Map link) {
  //   links = linksToModel(link);
  // }

  // getLinks(link);
  final AlertDialog linkPopUp = AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    title: Text(
      'More links',
      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Theme.of(context).colorScheme.secondary),
    ),
    actions: [
      MaterialButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: Theme.of(context).colorScheme.error,
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text('CLOSE', style: TextStyle(fontSize: 16.0, color: Colors.white)),
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
                    icon: linksIconData[e] ?? JamIcons.link,
                    link: link[e].toString(),
                    text: (linksData[e] ?? {})["name"].toString().inCaps,
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

Map<String, Map<String, String>> linksData = {
  'github': {'name': 'github', 'link': 'https://github.com/username', 'value': '', 'validator': 'github'},
  'twitter': {'name': 'twitter', 'link': 'https://twitter.com/username', 'value': '', 'validator': 'twitter'},
  'instagram': {'name': 'instagram', 'link': 'https://instagram.com/username', 'value': '', 'validator': 'instagram'},
  'email': {'name': 'email', 'link': 'your@email.com', 'value': '', 'validator': '@'},
  'telegram': {'name': 'telegram', 'link': 'https://t.me/username', 'value': '', 'validator': 't.me'},
  'dribbble': {'name': 'dribbble', 'link': 'https://dribbble.com/username', 'value': '', 'validator': 'dribbble'},
  'linkedin': {'name': 'linkedin', 'link': 'https://linkedin.com/in/username', 'value': '', 'validator': 'linkedin'},
  'bio.link': {'name': 'bio.link', 'link': 'https://bio.link/username', 'value': '', 'validator': 'bio.link'},
  'patreon': {'name': 'patreon', 'link': 'https://patreon.com/username', 'value': '', 'validator': 'patreon'},
  'trello': {'name': 'trello', 'link': 'https://trello.com/username', 'value': '', 'validator': 'trello'},
  'reddit': {'name': 'reddit', 'link': 'https://reddit.com/user/username', 'value': '', 'validator': 'reddit'},
  'behance': {'name': 'behance', 'link': 'https://behance.net/username', 'value': '', 'validator': 'behance.net'},
  'deviantart': {
    'name': 'deviantart',
    'link': 'https://deviantart.com/username',
    'value': '',
    'validator': 'deviantart',
  },
  'gitlab': {'name': 'gitlab', 'link': 'https://gitlab.com/username', 'value': '', 'validator': 'gitlab'},
  'medium': {'name': 'medium', 'link': 'https://username.medium.com/', 'value': '', 'validator': 'medium'},
  'paypal': {'name': 'paypal', 'link': 'https://paypal.me/username', 'value': '', 'validator': 'paypal'},
  'spotify': {
    'name': 'spotify',
    'link': 'https://open.spotify.com/user/username',
    'value': '',
    'validator': 'open.spotify',
  },
  'twitch': {'name': 'twitch', 'link': 'https://twitch.tv/username', 'value': '', 'validator': 'twitch.tv'},
  'unsplash': {'name': 'unsplash', 'link': 'https://unsplash.com/username', 'value': '', 'validator': 'unsplash'},
  'youtube': {'name': 'youtube', 'link': 'https://youtube.com/channel/username', 'value': '', 'validator': 'youtube'},
  'linktree': {'name': 'linktree', 'link': 'https://linktr.ee/username', 'value': '', 'validator': 'linktr.ee'},
  'buymeacoffee': {
    'name': 'buymeacoffee',
    'link': 'https://buymeacoff.ee/username',
    'value': '',
    'validator': 'buymeacoff.ee',
  },
  'custom link': {'name': 'custom link', 'link': '', 'value': '', 'validator': ''},
};
