import 'package:Prism/env/env.dart';
import 'package:Prism/features/theme_mode/views/widgets/diwali_decor.dart';
import 'package:Prism/features/theme_mode/views/widgets/spooky_decor.dart';
import 'package:Prism/features/theme_mode/views/widgets/winter_decor.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/prism_theme_options.dart';
import 'package:Prism/theme/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// The clock the seasons read when no date is given. Tests set it, so they do not depend on the real date.
@visibleForTesting
DateTime Function() seasonClock = _defaultSeasonClock;

DateTime seasonNow() => seasonClock();

/// `PRISM_SEASON_DATE` (yyyyMMddHHmm) moves the season clock in debug and profile builds, for QA on a shared device. Time still runs.
final Duration _debugSeasonOffset = () {
  const int d = Env.seasonDate;
  if (kReleaseMode || d <= 0) return Duration.zero;
  final DateTime forced = DateTime(d ~/ 100000000, d ~/ 1000000 % 100, d ~/ 10000 % 100, d ~/ 100 % 100, d % 100);
  return forced.difference(DateTime.now());
}();

DateTime _defaultSeasonClock() => DateTime.now().add(_debugSeasonOffset);

/// A span of local wall-clock time, [start] inclusive and [end] exclusive. A UTC instant is read in the phone's zone.
/// The bounds keep their wall-clock fields, so a change of time zone while the app runs does not move them.
@immutable
class SeasonWindow {
  SeasonWindow(DateTime start, DateTime end) : _start = _fields(start), _end = _fields(end);

  final DateTime _start;
  final DateTime _end;

  /// [_start] and [_end] as instants in the phone's current zone, for timers.
  DateTime get start => _local(_start);
  DateTime get end => _local(_end);

  bool contains(DateTime now) => !_fields(now).isBefore(_start) && _fields(now).isBefore(_end);

  bool isUpcoming(DateTime now) => _fields(now).isBefore(_start);

  bool hasEnded(DateTime now) => !_fields(now).isBefore(_end);

  /// The local wall-clock fields of [time], held in a UTC DateTime so comparisons ignore the zone.
  static DateTime _fields(DateTime time) {
    final DateTime local = time.toLocal();
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  static DateTime _local(DateTime fields) => DateTime(
    fields.year,
    fields.month,
    fields.day,
    fields.hour,
    fields.minute,
    fields.second,
    fields.millisecond,
    fields.microsecond,
  );
}

/// A free theme with a season. Its home card and its update announcement run in [promo], a span of local time.
/// When [revertsAtEnd] is set, a user still on the theme after [window] ends goes back to the theme they had before.
class SeasonalTheme {
  SeasonalTheme({
    required this.name,
    required this.themeId,
    required this.theme,
    required this.window,
    required this.bannerArt,
    required this.bannerTitle,
    required this.bannerSubtitle,
    required this.announcementTitle,
    required this.announcementBody,
    this.lightThemeId,
    this.lightTheme,
    SeasonWindow? promo,
    this.revertsAtEnd = false,
  }) : promo = promo ?? window;

  /// Short stable name. It keys the carousel page, the analytics source and the settings flags.
  final String name;

  /// The dark variant.
  final String themeId;
  final ThemeData theme;

  /// The light variant, or null when the season has only a dark theme.
  final String? lightThemeId;
  final ThemeData? lightTheme;

  final SeasonWindow window;
  final SeasonWindow promo;
  final bool revertsAtEnd;
  final Widget bannerArt;
  final String Function(AppLocalizations l10n) bannerTitle;
  final String Function(AppLocalizations l10n) bannerSubtitle;
  final String Function(AppLocalizations l10n) announcementTitle;
  final String Function(AppLocalizations l10n) announcementBody;

  String get announcementId => 'local_${name}_theme_2026';
  String get announcedKey => '${name}ThemeAnnounced2026';
  String get pendingKey => '${name}ThemeAnnouncementPending2026';
  String previousThemeKey(Brightness brightness) =>
      '${name}ThemePrevious2026${brightness == Brightness.dark ? 'Dark' : 'Light'}';

  DateTime get seasonEnd => window.end;

  /// True while the home card and the announcement can show.
  bool inSeason([DateTime? now]) => promo.contains(now ?? seasonNow());

  String? themeIdFor(Brightness brightness) => brightness == Brightness.dark ? themeId : lightThemeId;

  /// True when the theme in [context] is this one. It reads the page colour, so it needs no theme bloc above it.
  bool isActive(BuildContext context) {
    final Color surface = Theme.of(context).colorScheme.surface;
    return surface == theme.colorScheme.surface || surface == lightTheme?.colorScheme.surface;
  }
}

final SeasonalTheme winterSeason = SeasonalTheme(
  name: 'winter',
  themeId: prismWinterDarkThemeId,
  theme: kDarkTheme11,
  lightThemeId: prismWinterLightThemeId,
  lightTheme: kLightTheme5,
  window: SeasonWindow(DateTime(2026, 12), DateTime(2027, 1, 7)),
  // Wrapped launches on 1 December with its own card and push. Winter waits one day.
  promo: SeasonWindow(DateTime(2026, 12, 2), DateTime(2027, 1, 7)),
  revertsAtEnd: true,
  bannerArt: const WinterBannerArt(),
  bannerTitle: (l10n) => l10n.winterBannerTitle,
  bannerSubtitle: (l10n) => l10n.winterBannerSubtitle,
  announcementTitle: (l10n) => l10n.winterAnnouncementTitle,
  announcementBody: (l10n) => l10n.winterAnnouncementBody,
);

/// 31 December and 1 January, local time. Winter adds a small New Year greeting on Home.
final SeasonWindow newYearWindow = SeasonWindow(DateTime(2026, 12, 31), DateTime(2027, 1, 2));

final SeasonalTheme diwaliSeason = SeasonalTheme(
  name: 'diwali',
  themeId: prismDiwaliThemeId,
  theme: kDarkTheme10,
  window: SeasonWindow(DateTime(2026), DateTime(2026, 11, 12)),
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
  window: SeasonWindow(DateTime(2026), DateTime(2026, 11, 3)),
  bannerArt: const SpookyBannerArt(),
  bannerTitle: (l10n) => l10n.spookyBannerTitle,
  bannerSubtitle: (l10n) => l10n.spookyBannerSubtitle,
  announcementTitle: (l10n) => l10n.spookyAnnouncementTitle,
  announcementBody: (l10n) => l10n.spookyAnnouncementBody,
);

/// In priority order. An app update announces only the first one that is in season and not yet announced.
final List<SeasonalTheme> seasonalThemes = <SeasonalTheme>[winterSeason, diwaliSeason, spookySeason];
