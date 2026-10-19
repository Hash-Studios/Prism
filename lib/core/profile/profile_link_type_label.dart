import 'package:Prism/core/constants/profile_links.dart';
import 'package:Prism/l10n/l10n.dart';

String profileLinkTypeLabel(AppLocalizations l10n, ProfileLinkType type) => switch (type) {
  ProfileLinkType.behance => l10n.accountLinkTypeBehance,
  ProfileLinkType.bioLink => l10n.accountLinkTypeBioLink,
  ProfileLinkType.buyMeACoffee => l10n.accountLinkTypeBuyMeACoffee,
  ProfileLinkType.custom => l10n.accountLinkTypeCustom,
  ProfileLinkType.deviantArt => l10n.accountLinkTypeDeviantArt,
  ProfileLinkType.dribbble => l10n.accountLinkTypeDribbble,
  ProfileLinkType.email => l10n.accountLinkTypeEmail,
  ProfileLinkType.github => l10n.accountLinkTypeGithub,
  ProfileLinkType.gitlab => l10n.accountLinkTypeGitlab,
  ProfileLinkType.instagram => l10n.accountLinkTypeInstagram,
  ProfileLinkType.linkedin => l10n.accountLinkTypeLinkedin,
  ProfileLinkType.linktree => l10n.accountLinkTypeLinktree,
  ProfileLinkType.medium => l10n.accountLinkTypeMedium,
  ProfileLinkType.patreon => l10n.accountLinkTypePatreon,
  ProfileLinkType.paypal => l10n.accountLinkTypePaypal,
  ProfileLinkType.reddit => l10n.accountLinkTypeReddit,
  ProfileLinkType.spotify => l10n.accountLinkTypeSpotify,
  ProfileLinkType.telegram => l10n.accountLinkTypeTelegram,
  ProfileLinkType.trello => l10n.accountLinkTypeTrello,
  ProfileLinkType.twitch => l10n.accountLinkTypeTwitch,
  ProfileLinkType.twitter => l10n.accountLinkTypeTwitter,
  ProfileLinkType.unsplash => l10n.accountLinkTypeUnsplash,
  ProfileLinkType.youtube => l10n.accountLinkTypeYoutube,
};
