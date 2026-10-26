import 'package:Prism/features/theme_mode/views/widgets/diwali_decor.dart';
import 'package:Prism/features/theme_mode/views/widgets/spooky_decor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/material.dart';

/// The clock the seasons read when no date is given. Tests set it, so they do not depend on the real date.
@visibleForTesting
DateTime Function() seasonClock = DateTime.now;

DateTime seasonNow() => seasonClock();

/// A free dark theme with a season. Its home card and its update announcement run until [seasonEnd], a local date.
/// The theme itself stays.
class SeasonalTheme {
  SeasonalTheme({
    required this.name,
    required this.themeId,
    required this.theme,
    required this.seasonEnd,
    required this.bannerArt,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.announcementTitle,
    required this.announcementBody,
  });

  /// Short stable name. It keys the carousel page, the analytics source and the settings flags.
  final String name;
  final String themeId;
  final ThemeData theme;
  final DateTime seasonEnd;
  final Widget bannerArt;
  final String Function(AppLocalizations l10n) bannerTitle;
  final String Function(AppLocalizations l10n) bannerSubtitle;
  final String Function(AppLocalizations l10n) announcementTitle;
  final String Function(AppLocalizations l10n) announcementBody;

  String get announcementId => 'local_${name}_theme_2026';
  String get announcedKey => '${name}ThemeAnnounced2026';
  String get pendingKey => '${name}ThemeAnnouncementPending2026';

  bool inSeason([DateTime? now]) => (now ?? seasonNow()).isBefore(seasonEnd);

  /// True when the theme in [context] is this one. It reads the page colour, so it needs no theme bloc above it.
  bool isActive(BuildContext context) => Theme.of(context).colorScheme.surface == theme.colorScheme.surface;
}

final SeasonalTheme diwaliSeason = SeasonalTheme(
  name: 'diwali',
  themeId: prismDiwaliThemeId,
  theme: kDarkTheme10,
  seasonEnd: DateTime(2026, 11, 12),
  bannerArt: const DiwaliBannerArt(),
  bannerTitle: (l10n) => l10n.diwaliBannerTitle,
  bannerSubtitle: (l10n) => l10n.diwaliBannerSubtitle,
  announcementTitle: (l10n) => l10n.diwaliAnnouncementTitle,
  announcementBody: (l10n) => l10n.diwaliAnnouncementBody,
);

final SeasonalTheme spookySeason = SeasonalTheme(
  name: 'spooky',
  themeId: prismSpookyThemeId,
  theme: kDarkTheme9,
  seasonEnd: DateTime(2026, 11, 3),
  bannerArt: const SpookyBannerArt(),
  bannerTitle: (l10n) => l10n.spookyBannerTitle,
  bannerSubtitle: (l10n) => l10n.spookyBannerSubtitle,
  announcementTitle: (l10n) => l10n.spookyAnnouncementTitle,
  announcementBody: (l10n) => l10n.spookyAnnouncementBody,
);

/// In priority order. An app update announces only the first one that is in season and not yet announced.
final List<SeasonalTheme> seasonalThemes = <SeasonalTheme>[diwaliSeason, spookySeason];
