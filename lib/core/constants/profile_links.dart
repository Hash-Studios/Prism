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

/// Fewest characters a username can have.
const int minUsernameLength = 3;

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

final RegExp _bareEmail = RegExp(r'^[^\s@/:]+@[^\s@/:]+\.[^\s@/:.]+$');
final RegExp _hasScheme = RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*:');

/// Parses [raw] into a link that is safe to open: https or http with a host, or mailto with an address.
/// A bare address becomes mailto and a bare domain becomes https. Returns null for anything else.
Uri? safeProfileLinkUri(String raw) {
  final String value = raw.trim();
  if (value.isEmpty) return null;
  if (_bareEmail.hasMatch(value)) return Uri(scheme: 'mailto', path: value);
  final Uri? uri = Uri.tryParse(_hasScheme.hasMatch(value) ? value : 'https://$value');
  if (uri == null) return null;
  final String scheme = uri.scheme.toLowerCase();
  if (scheme == 'mailto') return _bareEmail.hasMatch(uri.path) ? uri : null;
  if ((scheme == 'https' || scheme == 'http') && uri.host.isNotEmpty) return uri;
  return null;
}

/// The value to store for a profile link of [kind], or null when [raw] is not a valid link for it.
/// Email links stay a bare address so builds that already shipped can still open them.
String? sanitizeProfileLink(ProfileLinkKind kind, String raw) {
  final String value = raw.trim();
  if (kind.name == 'email') {
    final String address = value.toLowerCase().startsWith('mailto:') ? value.substring(7) : value;
    return _bareEmail.hasMatch(address) ? address : null;
  }
  final Uri? uri = safeProfileLinkUri(value);
  if (uri == null) return null;
  if (uri.scheme == 'mailto' && kind.name != customLinkName) return null;
  if (!value.toLowerCase().contains(kind.validator.toLowerCase())) return null;
  return uri.toString();
}
