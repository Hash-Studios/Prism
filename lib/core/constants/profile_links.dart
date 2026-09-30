import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/widgets.dart';

class ProfileLinkKind {
  const ProfileLinkKind(this.name, this.placeholder, this.icon, this.validator);

  final String name;
  final String placeholder;
  final IconData icon;
  final String validator;
}

const String customLinkName = 'custom link';

/// Every link type a profile can carry, sorted by [ProfileLinkKind.name].
const List<ProfileLinkKind> profileLinkKinds = <ProfileLinkKind>[
  ProfileLinkKind('behance', 'https://behance.net/username', JamIcons.behance, 'behance.net'),
  ProfileLinkKind('bio.link', 'https://bio.link/username', JamIcons.world, 'bio.link'),
  ProfileLinkKind('buymeacoffee', 'https://buymeacoff.ee/username', JamIcons.coffee, 'buymeacoff.ee'),
  ProfileLinkKind('custom link', '', JamIcons.link, ''),
  ProfileLinkKind('deviantart', 'https://deviantart.com/username', JamIcons.deviantart, 'deviantart'),
  ProfileLinkKind('dribbble', 'https://dribbble.com/username', JamIcons.basketball, 'dribbble'),
  ProfileLinkKind('email', 'your@email.com', JamIcons.inbox, '@'),
  ProfileLinkKind('github', 'https://github.com/username', JamIcons.github, 'github'),
  ProfileLinkKind('gitlab', 'https://gitlab.com/username', JamIcons.gitlab, 'gitlab'),
  ProfileLinkKind('instagram', 'https://instagram.com/username', JamIcons.instagram, 'instagram'),
  ProfileLinkKind('linkedin', 'https://linkedin.com/in/username', JamIcons.linkedin, 'linkedin'),
  ProfileLinkKind('linktree', 'https://linktr.ee/username', JamIcons.tree_alt, 'linktr.ee'),
  ProfileLinkKind('medium', 'https://username.medium.com/', JamIcons.medium, 'medium'),
  ProfileLinkKind('patreon', 'https://patreon.com/username', JamIcons.patreon, 'patreon'),
  ProfileLinkKind('paypal', 'https://paypal.me/username', JamIcons.paypal, 'paypal'),
  ProfileLinkKind('reddit', 'https://reddit.com/user/username', JamIcons.reddit, 'reddit'),
  ProfileLinkKind('spotify', 'https://open.spotify.com/user/username', JamIcons.spotify, 'open.spotify'),
  ProfileLinkKind('telegram', 'https://t.me/username', JamIcons.paper_plane, 't.me'),
  ProfileLinkKind('trello', 'https://trello.com/username', JamIcons.trello, 'trello'),
  ProfileLinkKind('twitch', 'https://twitch.tv/username', JamIcons.twitch, 'twitch.tv'),
  ProfileLinkKind('twitter', 'https://twitter.com/username', JamIcons.twitter, 'twitter'),
  ProfileLinkKind('unsplash', 'https://unsplash.com/username', JamIcons.unsplash, 'unsplash'),
  ProfileLinkKind('youtube', 'https://youtube.com/channel/username', JamIcons.youtube, 'youtube'),
];

IconData profileLinkIcon(String name) {
  for (final ProfileLinkKind kind in profileLinkKinds) {
    if (kind.name == name) {
      return kind.icon;
    }
  }
  return JamIcons.link;
}
