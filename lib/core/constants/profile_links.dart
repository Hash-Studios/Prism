import 'package:Prism/theme/jam_icons_icons.dart';
import 'package:flutter/widgets.dart';

enum ProfileLinkType {
  behance('behance'),
  bioLink('bio.link'),
  buyMeACoffee('buymeacoffee'),
  custom('custom link'),
  deviantArt('deviantart'),
  dribbble('dribbble'),
  email('email'),
  github('github'),
  gitlab('gitlab'),
  instagram('instagram'),
  linkedin('linkedin'),
  linktree('linktree'),
  medium('medium'),
  patreon('patreon'),
  paypal('paypal'),
  reddit('reddit'),
  spotify('spotify'),
  telegram('telegram'),
  trello('trello'),
  twitch('twitch'),
  twitter('twitter'),
  unsplash('unsplash'),
  youtube('youtube');

  const ProfileLinkType(this.wireName);

  /// Stable key used by profile documents and link validation.
  final String wireName;
}

class ProfileLinkKind {
  const ProfileLinkKind(this.type, this.placeholder, this.icon, this.validator);

  final ProfileLinkType type;
  final String placeholder;
  final IconData icon;
  final String validator;

  /// Stable key used by profile documents and link validation.
  String get name => type.wireName;
}

const String customLinkName = 'custom link';

/// Fewest characters a username can have.
const int minUsernameLength = 3;

/// Every link type a profile can carry, sorted by [ProfileLinkKind.name].
const List<ProfileLinkKind> profileLinkKinds = <ProfileLinkKind>[
  ProfileLinkKind(ProfileLinkType.behance, 'https://behance.net/username', JamIcons.behance, 'behance.net'),
  ProfileLinkKind(ProfileLinkType.bioLink, 'https://bio.link/username', JamIcons.world, 'bio.link'),
  ProfileLinkKind(
    ProfileLinkType.buyMeACoffee,
    'https://buymeacoffee.com/username',
    JamIcons.coffee,
    'buymeacoffee.com',
  ),
  ProfileLinkKind(ProfileLinkType.custom, '', JamIcons.link, ''),
  ProfileLinkKind(ProfileLinkType.deviantArt, 'https://deviantart.com/username', JamIcons.deviantart, 'deviantart'),
  ProfileLinkKind(ProfileLinkType.dribbble, 'https://dribbble.com/username', JamIcons.basketball, 'dribbble'),
  ProfileLinkKind(ProfileLinkType.email, 'your@email.com', JamIcons.inbox, '@'),
  ProfileLinkKind(ProfileLinkType.github, 'https://github.com/username', JamIcons.github, 'github'),
  ProfileLinkKind(ProfileLinkType.gitlab, 'https://gitlab.com/username', JamIcons.gitlab, 'gitlab'),
  ProfileLinkKind(ProfileLinkType.instagram, 'https://instagram.com/username', JamIcons.instagram, 'instagram'),
  ProfileLinkKind(ProfileLinkType.linkedin, 'https://linkedin.com/in/username', JamIcons.linkedin, 'linkedin'),
  ProfileLinkKind(ProfileLinkType.linktree, 'https://linktr.ee/username', JamIcons.tree_alt, 'linktr.ee'),
  ProfileLinkKind(ProfileLinkType.medium, 'https://username.medium.com/', JamIcons.medium, 'medium'),
  ProfileLinkKind(ProfileLinkType.patreon, 'https://patreon.com/username', JamIcons.patreon, 'patreon'),
  ProfileLinkKind(ProfileLinkType.paypal, 'https://paypal.me/username', JamIcons.paypal, 'paypal'),
  ProfileLinkKind(ProfileLinkType.reddit, 'https://reddit.com/user/username', JamIcons.reddit, 'reddit'),
  ProfileLinkKind(ProfileLinkType.spotify, 'https://open.spotify.com/user/username', JamIcons.spotify, 'open.spotify'),
  ProfileLinkKind(ProfileLinkType.telegram, 'https://t.me/username', JamIcons.paper_plane, 't.me'),
  ProfileLinkKind(ProfileLinkType.trello, 'https://trello.com/username', JamIcons.trello, 'trello'),
  ProfileLinkKind(ProfileLinkType.twitch, 'https://twitch.tv/username', JamIcons.twitch, 'twitch.tv'),
  ProfileLinkKind(ProfileLinkType.twitter, 'https://twitter.com/username', JamIcons.twitter, 'twitter'),
  ProfileLinkKind(ProfileLinkType.unsplash, 'https://unsplash.com/username', JamIcons.unsplash, 'unsplash'),
  ProfileLinkKind(ProfileLinkType.youtube, 'https://youtube.com/channel/username', JamIcons.youtube, 'youtube'),
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
  if (kind.type == ProfileLinkType.buyMeACoffee) {
    const Set<String> hosts = <String>{
      'buymeacoffee.com',
      'www.buymeacoffee.com',
      'buymeacoff.ee',
      'www.buymeacoff.ee',
    };
    if (!hosts.contains(uri.host.toLowerCase())) return null;
  } else if (!value.toLowerCase().contains(kind.validator.toLowerCase())) {
    return null;
  }
  return uri.toString();
}
