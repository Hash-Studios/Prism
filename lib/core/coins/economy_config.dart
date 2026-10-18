import 'dart:async';
import 'dart:math';

import 'package:Prism/core/coins/daily_chest.dart';
import 'package:Prism/core/coins/spin_wheel.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';

const int _maxPrice = 10000;
const int _maxAward = 1000;

int _int(Object? raw, int fallback, {int min = 0, int max = _maxPrice}) {
  if (raw is! num || !raw.isFinite) return fallback;
  final int value = raw.truncate();
  return value < min || value > max ? fallback : value;
}

double _double(Object? raw, double fallback) => raw is num && raw.isFinite && raw >= 0 ? raw.toDouble() : fallback;

bool _bool(Object? raw, bool fallback) => raw is bool ? raw : fallback;

String _string(Object? raw, String fallback) => raw is String ? raw : fallback;

List<String> _strings(Object? raw, List<String> fallback) =>
    raw is List && raw.every((Object? e) => e is String) ? List<String>.unmodifiable(raw.cast<String>()) : fallback;

/// UTC calendar day, `YYYY-MM-DD`. Mirrors `dayKey` in functions/src/economy.ts.
String economyDayKey(DateTime time) => time.toUtc().toIso8601String().substring(0, 10);

/// ISO week key in UTC, `YYYY-Www`, weeks start on Monday. Mirrors `weekKey` in functions/src/economy.ts.
String economyWeekKey(DateTime time) {
  final DateTime utc = time.toUtc();
  final DateTime day = DateTime.utc(utc.year, utc.month, utc.day);
  final DateTime thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
  final int week = (thursday.difference(DateTime.utc(thursday.year)).inDays ~/ 7) + 1;
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

/// Pro pays half, rounded up, never zero for a positive price. Mirrors `proPrice` in functions/src/economy.ts.
int proPrice(int price, bool isPro) => !isPro || price <= 0 ? price : max(1, (price / 2).ceil());

class EconomySpend {
  const EconomySpend({
    this.wallpaperDownload = 10,
    this.premiumWallpaperDownload = 25,
    this.liveWallpaperStyle = 20,
    this.premiumFilter = 5,
    this.premiumPreview24h = 10,
    this.autoRotatePass7d = 50,
    this.streakFreeze = 50,
    this.streakRescue = 100,
    this.aiFast = 10,
    this.aiBalanced = 75,
    this.aiQuality = 100,
    this.dropWall = 30,
    this.dropPack = 150,
    this.boostWall = 100,
    this.giftPremiumPass = 50,
    this.drawTicket = 20,
    this.spinWheel = 10,
    this.dailyChest = 8,
  });

  factory EconomySpend.fromMap(Map<String, dynamic> m) {
    const EconomySpend d = EconomySpend();
    return EconomySpend(
      wallpaperDownload: _int(m['wallpaperDownload'], d.wallpaperDownload),
      premiumWallpaperDownload: _int(m['premiumWallpaperDownload'], d.premiumWallpaperDownload),
      liveWallpaperStyle: _int(m['liveWallpaperStyle'], d.liveWallpaperStyle),
      premiumFilter: _int(m['premiumFilter'], d.premiumFilter),
      premiumPreview24h: _int(m['premiumPreview24h'], d.premiumPreview24h),
      autoRotatePass7d: _int(m['autoRotatePass7d'], d.autoRotatePass7d),
      streakFreeze: _int(m['streakFreeze'], d.streakFreeze),
      streakRescue: _int(m['streakRescue'], d.streakRescue),
      aiFast: _int(m['aiFast'], d.aiFast),
      aiBalanced: _int(m['aiBalanced'], d.aiBalanced),
      aiQuality: _int(m['aiQuality'], d.aiQuality),
      dropWall: _int(m['dropWall'], d.dropWall),
      dropPack: _int(m['dropPack'], d.dropPack),
      boostWall: _int(m['boostWall'], d.boostWall),
      giftPremiumPass: _int(m['giftPremiumPass'], d.giftPremiumPass),
      drawTicket: _int(m['drawTicket'], d.drawTicket),
      spinWheel: _int(m['spinWheel'], d.spinWheel),
      dailyChest: _int(m['dailyChest'], d.dailyChest),
    );
  }

  final int wallpaperDownload;
  final int premiumWallpaperDownload;
  final int liveWallpaperStyle;
  final int premiumFilter;
  final int premiumPreview24h;
  final int autoRotatePass7d;
  final int streakFreeze;
  final int streakRescue;
  final int aiFast;
  final int aiBalanced;
  final int aiQuality;
  final int dropWall;
  final int dropPack;
  final int boostWall;
  final int giftPremiumPass;
  final int drawTicket;

  /// What a paid spin of the wheel costs.
  final int spinWheel;

  /// What the daily chest costs before today's quests are done.
  final int dailyChest;
}

class SpinSegment {
  const SpinSegment({required this.coins, required this.weight});

  final int coins;
  final double weight;
}

class EconomyAward {
  const EconomyAward({
    this.rewardedAd = 10,
    this.rewardedAdFirstOfDay = 20,
    this.rewardedAdMaxPerDay = 20,
    this.firstWallpaperUpload = 50,
    this.profileCompletion = 25,
    this.referral = 100,
    this.referralMaxPerDay = 3,
    this.referralMaxLifetime = 20,
    this.streakDaily = const <int>[3, 3, 5, 5, 8, 8, 10],
    this.streakChestMin = 15,
    this.streakChestMax = 40,
    this.proStreakMultiplier = 1.5,
    this.proSpin = const <SpinSegment>[
      SpinSegment(coins: 20, weight: 40),
      SpinSegment(coins: 30, weight: 25),
      SpinSegment(coins: 50, weight: 20),
      SpinSegment(coins: 75, weight: 10),
      SpinSegment(coins: 100, weight: 5),
    ],
    this.spinWheel = defaultWheel,
    this.spinWheelMaxPerDay = 5,
    this.dailyChest = defaultChest,
    this.questCoins = 2,
    this.questXp = 25,
    this.weeklyQuestCoins = 30,
    this.weeklyQuestXp = 150,
    this.graceDownloads = 3,
  });

  factory EconomyAward.fromMap(Map<String, dynamic> m) {
    const EconomyAward d = EconomyAward();
    int award(String key, int fallback) => _int(m[key], fallback, max: _maxAward);
    final Object? daily = m['streakDaily'];
    final Object? spin = m['proSpin'];
    final List<SpinSegment>? segments =
        spin is List &&
            spin.isNotEmpty &&
            spin.every((Object? s) => s is Map && s['coins'] is num && s['weight'] is num && (s['weight'] as num) >= 0)
        ? spin.map((Object? s) {
            final Map<String, dynamic> seg = toJsonMap(s);
            return SpinSegment(coins: (seg['coins'] as num).truncate(), weight: (seg['weight'] as num).toDouble());
          }).toList()
        : null;
    int streakChestMin = award('streakChestMin', d.streakChestMin);
    int streakChestMax = award('streakChestMax', d.streakChestMax);
    if (streakChestMin > streakChestMax) (streakChestMin, streakChestMax) = (d.streakChestMin, d.streakChestMax);
    return EconomyAward(
      rewardedAd: award('rewardedAd', d.rewardedAd),
      rewardedAdFirstOfDay: award('rewardedAdFirstOfDay', d.rewardedAdFirstOfDay),
      rewardedAdMaxPerDay: award('rewardedAdMaxPerDay', d.rewardedAdMaxPerDay),
      firstWallpaperUpload: award('firstWallpaperUpload', d.firstWallpaperUpload),
      profileCompletion: award('profileCompletion', d.profileCompletion),
      referral: award('referral', d.referral),
      referralMaxPerDay: award('referralMaxPerDay', d.referralMaxPerDay),
      referralMaxLifetime: award('referralMaxLifetime', d.referralMaxLifetime),
      streakDaily:
          daily is List &&
              daily.length == 7 &&
              daily.every((Object? n) => n is num && n.isFinite && n >= 0 && n <= _maxAward)
          ? List<int>.unmodifiable(daily.map((Object? n) => (n! as num).truncate()))
          : d.streakDaily,
      streakChestMin: streakChestMin,
      streakChestMax: streakChestMax,
      proStreakMultiplier: _double(m['proStreakMultiplier'], d.proStreakMultiplier),
      proSpin: segments != null && segments.fold<double>(0, (double sum, SpinSegment s) => sum + s.weight) > 0
          ? List<SpinSegment>.unmodifiable(segments)
          : d.proSpin,
      spinWheel: parseWheel(m['spinWheel']) ?? d.spinWheel,
      spinWheelMaxPerDay: award('spinWheelMaxPerDay', d.spinWheelMaxPerDay),
      dailyChest: parseWheel(m['dailyChest']) ?? d.dailyChest,
      questCoins: award('questCoins', d.questCoins),
      questXp: award('questXp', d.questXp),
      weeklyQuestCoins: award('weeklyQuestCoins', d.weeklyQuestCoins),
      weeklyQuestXp: award('weeklyQuestXp', d.weeklyQuestXp),
      graceDownloads: award('graceDownloads', d.graceDownloads),
    );
  }

  final int rewardedAd;
  final int rewardedAdFirstOfDay;
  final int rewardedAdMaxPerDay;
  final int firstWallpaperUpload;
  final int profileCompletion;
  final int referral;
  final int referralMaxPerDay;
  final int referralMaxLifetime;

  /// Coins for cycle days 1..7, always seven entries.
  final List<int> streakDaily;
  final int streakChestMin;
  final int streakChestMax;
  final double proStreakMultiplier;
  final List<SpinSegment> proSpin;

  /// The wheel in wheel order, clockwise. Index 0 sits under the pointer at rest.
  final List<WheelSegment> spinWheel;

  /// Paid spins per UTC day. The free Pro spin does not count.
  final int spinWheelMaxPerDay;

  /// The daily chest's slots, in the wheel table's shape.
  final List<WheelSegment> dailyChest;
  final int questCoins;
  final int questXp;
  final int weeklyQuestCoins;
  final int weeklyQuestXp;
  final int graceDownloads;
}

class RankDef {
  const RankDef({required this.id, required this.min});

  final String id;
  final int min;
}

class EconomyXp {
  const EconomyXp({
    this.perCoinEarned = 1,
    this.ranks = const <RankDef>[
      RankDef(id: 'bronze', min: 0),
      RankDef(id: 'silver', min: 500),
      RankDef(id: 'gold', min: 2000),
      RankDef(id: 'prism', min: 6000),
    ],
  });

  factory EconomyXp.fromMap(Map<String, dynamic> m) {
    const EconomyXp d = EconomyXp();
    final Object? ranks = m['ranks'];
    final List<RankDef> parsed =
        ranks is List &&
            ranks.isNotEmpty &&
            ranks.every((Object? r) => r is Map && r['id'] is String && r['min'] is num && (r['min'] as num).isFinite)
        ? (ranks.map((Object? r) {
            final Map<String, dynamic> rank = toJsonMap(r);
            return RankDef(id: rank['id'] as String, min: (rank['min'] as num).truncate());
          }).toList()..sort((RankDef a, RankDef b) => a.min.compareTo(b.min)))
        : d.ranks;
    return EconomyXp(
      perCoinEarned: _double(m['perCoinEarned'], d.perCoinEarned),
      ranks: List<RankDef>.unmodifiable(parsed),
    );
  }

  final double perCoinEarned;

  /// Sorted by [RankDef.min], lowest first.
  final List<RankDef> ranks;
}

class EconomyFlags {
  const EconomyFlags({
    this.drawEnabled = false,
    this.dropsEnabled = true,
    this.foundersUntil = '2026-11-30T00:00:00Z',
    this.legacyPricingUntil = '2027-01-31T00:00:00Z',
  });

  factory EconomyFlags.fromMap(Map<String, dynamic> m) {
    const EconomyFlags d = EconomyFlags();
    return EconomyFlags(
      drawEnabled: _bool(m['drawEnabled'], d.drawEnabled),
      dropsEnabled: _bool(m['dropsEnabled'], d.dropsEnabled),
      foundersUntil: _string(m['foundersUntil'], d.foundersUntil),
      legacyPricingUntil: _string(m['legacyPricingUntil'], d.legacyPricingUntil),
    );
  }

  final bool drawEnabled;
  final bool dropsEnabled;

  /// ISO 8601 end of the founders sale.
  final String foundersUntil;

  /// ISO 8601 end of legacy prices for clients that send no `pricingVersion`.
  final String legacyPricingUntil;

  DateTime? get foundersUntilAt => DateTime.tryParse(foundersUntil)?.toUtc();
}

/// The rank for an XP total. [progress] runs 0..1 toward [next] and is 1 at the top rank.
class Rank {
  const Rank({required this.id, required this.min, required this.next, required this.progress});

  final String id;
  final int min;
  final RankDef? next;
  final double progress;
}

/// Every price, award and flag of the coin economy. Mirrors `EconomyConfig` in functions/src/economy.ts.
class EconomyConfig {
  const EconomyConfig({
    this.version = 2,
    this.spend = const EconomySpend(),
    this.proDiscountActions = const <String>['aiGeneration', 'dropWall', 'dropPack'],
    this.proBypassActions = const <String>[
      'wallpaperDownload',
      'premiumWallpaperDownload',
      'liveWallpaperStyle',
      'premiumFilter',
      'premiumPreview24h',
      'autoRotatePass7d',
    ],
    this.award = const EconomyAward(),
    this.xp = const EconomyXp(),
    this.flags = const EconomyFlags(),
    this.shopPrices = const <String, int>{},
  });

  /// Reads a raw `economyConfig/current` doc. Each missing or malformed field falls back to its default.
  factory EconomyConfig.fromMap(Map<String, dynamic>? raw) {
    if (raw == null) return defaults;
    final Object? prices = raw['shopPrices'];
    return EconomyConfig(
      version: _int(raw['version'], defaults.version),
      spend: raw['spend'] is Map ? EconomySpend.fromMap(toJsonMap(raw['spend'])) : defaults.spend,
      proDiscountActions: _strings(raw['proDiscountActions'], defaults.proDiscountActions),
      proBypassActions: List<String>.unmodifiable(
        _strings(raw['proBypassActions'], defaults.proBypassActions).where((String a) => !_neverBypassed.contains(a)),
      ),
      award: raw['award'] is Map ? EconomyAward.fromMap(toJsonMap(raw['award'])) : defaults.award,
      xp: raw['xp'] is Map ? EconomyXp.fromMap(toJsonMap(raw['xp'])) : defaults.xp,
      flags: raw['flags'] is Map ? EconomyFlags.fromMap(toJsonMap(raw['flags'])) : defaults.flags,
      shopPrices: prices is Map
          ? Map<String, int>.unmodifiable(<String, int>{
              for (final MapEntry<Object?, Object?> e in prices.entries)
                if (_int(e.value, -1) >= 0) e.key.toString(): _int(e.value, 0),
            })
          : defaults.shopPrices,
    );
  }

  static const EconomyConfig defaults = EconomyConfig();
  static const Set<String> _neverBypassed = <String>{'aiGeneration', 'dropWall', 'dropPack'};
  static const Duration loadBudget = Duration(seconds: 3);

  /// The loaded config. Defaults until [load] succeeds.
  static EconomyConfig get current => notifier.value;
  static set current(EconomyConfig value) => notifier.value = value;
  static final ValueNotifier<EconomyConfig> notifier = ValueNotifier<EconomyConfig>(defaults);
  static DateTime? _loadedAt;

  final int version;
  final EconomySpend spend;
  final List<String> proDiscountActions;
  final List<String> proBypassActions;
  final EconomyAward award;
  final EconomyXp xp;
  final EconomyFlags flags;
  final Map<String, int> shopPrices;

  Rank rankFor(int xpTotal) {
    RankDef rank = xp.ranks.first;
    RankDef? next;
    for (int i = 0; i < xp.ranks.length; i++) {
      if (xpTotal >= xp.ranks[i].min) {
        rank = xp.ranks[i];
        next = i + 1 < xp.ranks.length ? xp.ranks[i + 1] : null;
      }
    }
    final double progress = next == null ? 1 : ((xpTotal - rank.min) / (next.min - rank.min)).clamp(0, 1).toDouble();
    return Rank(id: rank.id, min: rank.min, next: next, progress: progress);
  }

  /// Reads `economyConfig/current` within [loadBudget]. Any failure keeps the config already loaded.
  static Future<void> load() async {
    try {
      final Map<String, dynamic>? raw = await firestoreClient
          .getById<Map<String, dynamic>>(
            FirebaseCollections.economyConfig,
            'current',
            (data, _) => data,
            sourceTag: 'economy.config.load',
          )
          .timeout(loadBudget);
      current = EconomyConfig.fromMap(raw);
      _loadedAt = DateTime.now();
    } catch (error) {
      logger.w('Economy config load failed; keeping the current values.', tag: 'Economy', error: error);
    }
  }

  /// Loads again when the copy is older than [maxAge] or was never loaded. The Rewards tab calls this on open.
  static Future<void> refreshIfStale({Duration maxAge = const Duration(hours: 1)}) async {
    final DateTime? at = _loadedAt;
    if (at != null && DateTime.now().difference(at) < maxAge) return;
    await load();
  }

  @visibleForTesting
  static void resetForTest() {
    current = defaults;
    _loadedAt = null;
  }
}
