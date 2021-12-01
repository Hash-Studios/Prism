import 'package:Prism/global/globals.dart';
import 'package:Prism/theme/jam_icons_icons.dart';
// import 'package:Prism/data/links/model/linksModel.dart';
import 'package:Prism/ui/pages/profile/aboutScreen.dart';
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
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 16,
        color: Theme.of(context).accentColor,
      ),
    ),
    actions: [
      FlatButton(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        color: Theme.of(context).errorColor,
        onPressed: () {
          Navigator.of(context).pop();
        },
        child: const Text(
          'CLOSE',
          style: TextStyle(
            fontSize: 16.0,
            color: Colors.white,
          ),
        ),
      ),
    ],
    content: Container(
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Theme.of(context).primaryColor),
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
                    icon: (linksData[e] ?? {})["icon"] as IconData,
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
  showModal(
      context: context,
      configuration: const FadeScaleTransitionConfiguration(),
      builder: (BuildContext context) => linkPopUp);
}

Map<String, Map<String, dynamic>> linksData = {
  'github': {
    'name': 'github',
    'link': 'https://github.com/username',
    'icon': JamIcons.github,
    'value': '',
    'validator': 'github',
  },
  'twitter': {
    'name': 'twitter',
    'link': 'https://twitter.com/username',
    'icon': JamIcons.twitter,
    'value': '',
    'validator': 'twitter',
  },
  'instagram': {
    'name': 'instagram',
    'link': 'https://instagram.com/username',
    'icon': JamIcons.instagram,
    'value': '',
    'validator': 'instagram',
  },
  'email': {
    'name': 'email',
    'link': 'your@email.com',
    'icon': JamIcons.inbox,
    'value': '',
    'validator': '@',
  },
  'telegram': {
    'name': 'telegram',
    'link': 'https://t.me/username',
    'icon': JamIcons.paper_plane,
    'value': '',
    'validator': 't.me',
  },
  'dribbble': {
    'name': 'dribbble',
    'link': 'https://dribbble.com/username',
    'icon': JamIcons.basketball,
    'value': '',
    'validator': 'dribbble',
  },
  'linkedin': {
    'name': 'linkedin',
    'link': 'https://linkedin.com/in/username',
    'icon': JamIcons.linkedin,
    'value': '',
    'validator': 'linkedin',
  },
  'bio.link': {
    'name': 'bio.link',
    'link': 'https://bio.link/username',
    'icon': JamIcons.world,
    'value': '',
    'validator': 'bio.link',
  },
  'patreon': {
    'name': 'patreon',
    'link': 'https://patreon.com/username',
    'icon': JamIcons.patreon,
    'value': '',
    'validator': 'patreon',
  },
  'trello': {
    'name': 'trello',
    'link': 'https://trello.com/username',
    'icon': JamIcons.trello,
    'value': '',
    'validator': 'trello',
  },
  'reddit': {
    'name': 'reddit',
    'link': 'https://reddit.com/user/username',
    'icon': JamIcons.reddit,
    'value': '',
    'validator': 'reddit',
  },
  'behance': {
    'name': 'behance',
    'link': 'https://behance.net/username',
    'icon': JamIcons.behance,
    'value': '',
    'validator': 'behance.net',
  },
  'deviantart': {
    'name': 'deviantart',
    'link': 'https://deviantart.com/username',
    'icon': JamIcons.deviantart,
    'value': '',
    'validator': 'deviantart',
  },
  'gitlab': {
    'name': 'gitlab',
    'link': 'https://gitlab.com/username',
    'icon': JamIcons.gitlab,
    'value': '',
    'validator': 'gitlab',
  },
  'medium': {
    'name': 'medium',
    'link': 'https://username.medium.com/',
    'icon': JamIcons.medium,
    'value': '',
    'validator': 'medium',
  },
  'paypal': {
    'name': 'paypal',
    'link': 'https://paypal.me/username',
    'icon': JamIcons.paypal,
    'value': '',
    'validator': 'paypal',
  },
  'spotify': {
    'name': 'spotify',
    'link': 'https://open.spotify.com/user/username',
    'icon': JamIcons.spotify,
    'value': '',
    'validator': 'open.spotify',
  },
  'twitch': {
    'name': 'twitch',
    'link': 'https://twitch.tv/username',
    'icon': JamIcons.twitch,
    'value': '',
    'validator': 'twitch.tv',
  },
  'unsplash': {
    'name': 'unsplash',
    'link': 'https://unsplash.com/username',
    'icon': JamIcons.unsplash,
    'value': '',
    'validator': 'unsplash',
  },
  'youtube': {
    'name': 'youtube',
    'link': 'https://youtube.com/channel/username',
    'icon': JamIcons.youtube,
    'value': '',
    'validator': 'youtube',
  },
  'linktree': {
    'name': 'linktree',
    'link': 'https://linktr.ee/username',
    'icon': JamIcons.tree_alt,
    'value': '',
    'validator': 'linktr.ee',
  },
  'buymeacoffee': {
    'name': 'buymeacoffee',
    'link': 'https://buymeacoff.ee/username',
    'icon': JamIcons.coffee,
    'value': '',
    'validator': 'buymeacoff.ee',
  },
  'custom link': {
    'name': 'custom link',
    'link': '',
    'icon': JamIcons.link,
    'value': '',
    'validator': '',
  },
};
