import 'package:Prism/core/platform/wallpaper_service.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/features/category_feed/domain/entities/feed_item_entity.dart';
import 'package:Prism/features/readability/domain/readability.dart';
import 'package:flutter/foundation.dart' show listEquals;

enum DayNightSlot { day, night }

/// A time of day in whole minutes after local midnight, 0 to 1439.
final class DayTime {
  const DayTime._(this.minutes);

  factory DayTime.hm(int hour, int minute) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) throw RangeError('$hour:$minute is not a time of day');
    return DayTime._(hour * 60 + minute);
  }

  /// The wall-clock time of [instant] in the zone that is [utcOffset] from UTC.
  factory DayTime.at(DateTime instant, Duration utcOffset) {
    final DateTime wall = instant.toUtc().add(utcOffset);
    return DayTime._(wall.hour * 60 + wall.minute);
  }

  static DayTime? fromMinutes(Object? value) => value is int && value >= 0 && value < 1440 ? DayTime._(value) : null;

  final int minutes;

  int get hour => minutes ~/ 60;
  int get minute => minutes % 60;

  @override
  bool operator ==(Object other) => other is DayTime && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;

  @override
  String toString() => '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// When day and night start. The two times always differ, so every minute of the day belongs to one slot.
final class DayNightTimes {
  const DayNightTimes._(this.dayStart, this.nightStart);

  static final DayNightTimes standard = DayNightTimes._(DayTime.hm(7, 0), DayTime.hm(19, 0));

  /// Null when the times are equal.
  static DayNightTimes? tryCreate(DayTime dayStart, DayTime nightStart) =>
      dayStart == nightStart ? null : DayNightTimes._(dayStart, nightStart);

  final DayTime dayStart;
  final DayTime nightStart;

  DayTime startOf(DayNightSlot slot) => slot == DayNightSlot.day ? dayStart : nightStart;

  /// Day runs from [dayStart] up to [nightStart], wrapping past midnight when night starts first.
  DayNightSlot slotAt(DayTime time) {
    final int now = time.minutes;
    final int day = dayStart.minutes;
    final int night = nightStart.minutes;
    final bool inDay = day < night ? now >= day && now < night : now >= day || now < night;
    return inDay ? DayNightSlot.day : DayNightSlot.night;
  }

  /// The slot for [instant] on the wall clock of the zone that is [utcOffset] from UTC.
  DayNightSlot slotAtInstant(DateTime instant, Duration utcOffset) => slotAt(DayTime.at(instant, utcOffset));

  /// The slot on this device's clock now, in its current zone.
  DayNightSlot slotNow([DateTime? now]) {
    final DateTime local = (now ?? DateTime.now()).toLocal();
    return slotAtInstant(local, local.timeZoneOffset);
  }

  @override
  bool operator ==(Object other) =>
      other is DayNightTimes && other.dayStart == dayStart && other.nightStart == nightStart;

  @override
  int get hashCode => Object.hash(dayStart, nightStart);
}

/// A wall chosen for one slot. Kept small so it survives the wall leaving the feed.
final class DayNightWall {
  const DayNightWall({
    required this.id,
    required this.source,
    required this.fullUrl,
    required this.thumbnailUrl,
    this.mainColor,
    this.fixes = const <ReadabilityFix>[],
  });

  factory DayNightWall.fromFeedItem(FeedItemEntity item) => DayNightWall(
    id: item.id,
    source: item.source,
    fullUrl: item.fullUrl,
    thumbnailUrl: item.thumbnailUrl,
    mainColor: item.when(
      prism: (_, wall) => wall.colors?.firstOrNull,
      wallhaven: (_, wall) => wall.colors?.firstOrNull,
      pexels: (_, _) => null,
    ),
  );

  static DayNightWall? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? id = json['id'];
    final Object? fullUrl = json['fullUrl'];
    final Object? thumbnailUrl = json['thumbnailUrl'];
    final Object? mainColor = json['mainColor'];
    final Object? fixes = json['fixes'];
    if (id is! String || id.trim().isEmpty || fullUrl is! String || thumbnailUrl is! String) return null;
    return DayNightWall(
      id: id,
      source: WallpaperSourceX.fromWire(json['source']),
      fullUrl: fullUrl,
      thumbnailUrl: thumbnailUrl,
      mainColor: mainColor is String ? mainColor : null,
      fixes: fixes is List ? fixes.map(ReadabilityFix.fromKey).nonNulls.toList() : const <ReadabilityFix>[],
    );
  }

  final String id;
  final WallpaperSource source;
  final String fullUrl;
  final String thumbnailUrl;

  /// The most dominant stored colour: a Prism palette id or a hex value such as "#663399".
  final String? mainColor;

  /// Readability fixes the user applied. The schedule sets a fixed copy, never the wall itself.
  final List<ReadabilityFix> fixes;

  DayNightWall withFixes(List<ReadabilityFix> fixes) => DayNightWall(
    id: id,
    source: source,
    fullUrl: fullUrl,
    thumbnailUrl: thumbnailUrl,
    mainColor: mainColor,
    fixes: fixes,
  );

  /// A protected Prism original has no public https image. Only its downloaded original can serve it.
  bool get hasPublicImage => fullUrl.trim().startsWith('https://');

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source.wireValue,
    'fullUrl': fullUrl,
    'thumbnailUrl': thumbnailUrl,
    if (mainColor != null) 'mainColor': mainColor,
    if (fixes.isNotEmpty) 'fixes': <String>[for (final ReadabilityFix fix in fixes) fix.key],
  };

  @override
  bool operator ==(Object other) =>
      other is DayNightWall &&
      other.id == id &&
      other.source == source &&
      other.fullUrl == fullUrl &&
      other.thumbnailUrl == thumbnailUrl &&
      other.mainColor == mainColor &&
      listEquals(other.fixes, fixes);

  @override
  int get hashCode => Object.hash(id, source, fullUrl, thumbnailUrl, mainColor, Object.hashAll(fixes));
}

/// The user's day and night walls, the times they switch, and where they apply.
final class DayNightPair {
  DayNightPair({
    this.day,
    this.night,
    DayNightTimes? times,
    this.target = WallpaperTarget.both,
    this.enabled = false,
    this.fromVariants = false,
    this.passUntil,
  }) : times = times ?? DayNightTimes.standard;

  final DayNightWall? day;
  final DayNightWall? night;
  final DayNightTimes times;
  final WallpaperTarget target;
  final bool enabled;

  /// True while both walls came from the one-tap variant pick.
  final bool fromVariants;

  /// When the auto-rotate pass that allows the mode ends. Null for Pro and without a pass. Kept so a launch whose
  /// passes have not loaded yet does not turn the mode off.
  final DateTime? passUntil;

  bool get isComplete => day != null && night != null;

  DayNightWall? wallFor(DayNightSlot slot) => slot == DayNightSlot.day ? day : night;

  /// The wall for the current time, or null when that slot has no wall.
  DayNightWall? wallNow([DateTime? now]) => wallFor(times.slotNow(now));

  DayNightPair withWall(DayNightSlot slot, DayNightWall wall) => DayNightPair(
    day: slot == DayNightSlot.day ? wall : day,
    night: slot == DayNightSlot.night ? wall : night,
    times: times,
    target: target,
    enabled: enabled,
    passUntil: passUntil,
  );

  DayNightPair copyWith({
    DayNightWall? day,
    DayNightWall? night,
    DayNightTimes? times,
    WallpaperTarget? target,
    bool? enabled,
    bool? fromVariants,
    DateTime? Function()? passUntil,
  }) => DayNightPair(
    day: day ?? this.day,
    night: night ?? this.night,
    times: times ?? this.times,
    target: target ?? this.target,
    enabled: enabled ?? this.enabled,
    fromVariants: fromVariants ?? this.fromVariants,
    passUntil: passUntil == null ? this.passUntil : passUntil(),
  );

  @override
  bool operator ==(Object other) =>
      other is DayNightPair &&
      other.day == day &&
      other.night == night &&
      other.times == times &&
      other.target == target &&
      other.enabled == enabled &&
      other.fromVariants == fromVariants &&
      other.passUntil == passUntil;

  @override
  int get hashCode => Object.hash(day, night, times, target, enabled, fromVariants, passUntil);
}
