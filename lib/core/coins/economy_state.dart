import 'dart:math';

import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';

DateTime? _msToDate(Object? raw) {
  final int ms = parseIntOr(raw);
  return ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;
}

String? _nonEmpty(Object? raw) => raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

/// Lifetime XP, this week's XP and the rank, read from the root user doc.
class XpStatus {
  const XpStatus({required this.xp, required this.weekXp, required this.rank});

  /// Week XP counts only while `xpWeek.weekKey` is the current ISO week.
  factory XpStatus.fromUserData(Map<String, dynamic> data, {DateTime? now}) {
    final int xp = max(0, parseIntOr(data['xp']));
    final Map<String, dynamic> week = toJsonMap(data['xpWeek']);
    final bool thisWeek = week['weekKey'] == economyWeekKey(now ?? DateTime.now());
    return XpStatus(xp: xp, weekXp: thisWeek ? parseIntOr(week['xp']) : 0, rank: EconomyConfig.current.rankFor(xp));
  }

  factory XpStatus.empty() => XpStatus(xp: 0, weekXp: 0, rank: EconomyConfig.current.rankFor(0));

  final int xp;
  final int weekXp;
  final Rank rank;
}

/// Quest events. Only [clientReported] events are sent by the app; the server counts the rest.
enum QuestEvent {
  setWallpaper,
  favourite,
  viewWotd,
  colourSearch,
  viewTrending,
  share,
  download,
  viewWallpaper,
  watchAd,
  proSpin;

  String get wireValue => name.replaceAllMapped(RegExp('[A-Z]'), (Match m) => '_${m[0]!.toLowerCase()}');

  bool get clientReported =>
      this == QuestEvent.viewWotd || this == QuestEvent.colourSearch || this == QuestEvent.viewTrending;

  static QuestEvent? fromWire(Object? raw) {
    for (final QuestEvent event in values) {
      if (event.wireValue == raw) return event;
    }
    return null;
  }
}

class QuestItem {
  const QuestItem({
    required this.id,
    required this.event,
    required this.target,
    required this.progress,
    required this.claimed,
  });

  /// Null when the item is malformed or its event is unknown to this build.
  static QuestItem? fromMap(Object? raw) {
    final Map<String, dynamic> m = toJsonMap(raw);
    final String? id = _nonEmpty(m['id']);
    final QuestEvent? event = QuestEvent.fromWire(m['event']);
    if (id == null || event == null) return null;
    final int target = parseIntOr(m['target'], fallback: 1).clamp(1, 1000);
    return QuestItem(
      id: id,
      event: event,
      target: target,
      progress: parseIntOr(m['progress']).clamp(0, target),
      claimed: m['claimed'] == true,
    );
  }

  final String id;
  final QuestEvent event;
  final int target;
  final int progress;
  final bool claimed;

  bool get isDone => claimed || progress >= target;
}

/// Today's quests, the bonus item, the chest and the weekly quest, from `private/economy.quests`.
class QuestState {
  const QuestState({
    required this.dayKey,
    required this.items,
    required this.chestOpened,
    required this.chestDoubled,
    required this.weekKey,
    this.bonus,
    this.weekly,
  });

  static QuestState? fromMap(Object? raw) {
    final Map<String, dynamic> m = toJsonMap(raw);
    final String? dayKey = _nonEmpty(m['dayKey']);
    if (dayKey == null) return null;
    final Object? items = m['items'];
    return QuestState(
      dayKey: dayKey,
      items: List<QuestItem>.unmodifiable(
        items is List ? items.map(QuestItem.fromMap).whereType<QuestItem>() : const <QuestItem>[],
      ),
      bonus: QuestItem.fromMap(m['bonus']),
      chestOpened: m['chestOpened'] == true,
      chestDoubled: m['chestDoubled'] == true,
      weekKey: _nonEmpty(m['weekKey']) ?? '',
      weekly: QuestItem.fromMap(m['weekly']),
    );
  }

  final String dayKey;
  final List<QuestItem> items;
  final QuestItem? bonus;
  final bool chestOpened;
  final bool chestDoubled;
  final String weekKey;
  final QuestItem? weekly;

  QuestState withBonus(QuestItem bonus) => QuestState(
    dayKey: dayKey,
    items: items,
    bonus: bonus,
    chestOpened: chestOpened,
    chestDoubled: chestDoubled,
    weekKey: weekKey,
    weekly: weekly,
  );

  /// Every daily item is claimed and the chest is still closed.
  bool get chestReady => items.isNotEmpty && items.every((QuestItem q) => q.claimed) && !chestOpened;
}

/// Coins and XP one quest item paid.
class QuestAward {
  const QuestAward({required this.id, required this.coins, required this.xp});

  final String id;
  final int coins;
  final int xp;
}

enum CosmeticSlot { frame, nameGlow }

/// Owned shop items (private doc) and the equipped cosmetics (root `cosmetics`).
class Inventory {
  const Inventory({required this.owned, this.frame, this.nameGlow});

  static const Inventory empty = Inventory(owned: <String>{});

  final Set<String> owned;
  final String? frame;
  final String? nameGlow;

  bool owns(String itemId) => owned.contains(itemId);

  String? equipped(CosmeticSlot slot) => slot == CosmeticSlot.frame ? frame : nameGlow;

  Inventory withOwned(Set<String> owned) => Inventory(owned: owned, frame: frame, nameGlow: nameGlow);

  Inventory withEquipped({required String? frame, required String? nameGlow}) =>
      Inventory(owned: owned, frame: frame, nameGlow: nameGlow);
}

/// A Drop wall the user unlocked, with its full image url.
class DropUnlock {
  const DropUnlock({required this.wallId, required this.weekKey, required this.url});

  final String wallId;
  final String weekKey;
  final String url;
}

/// Time-limited unlocks from `private/economy.passes`.
class Passes {
  const Passes({this.premiumPassUntil, this.autoRotatePassUntil, this.liveStyles = const <String, DateTime>{}});

  factory Passes.fromMap(Object? raw) {
    final Map<String, dynamic> m = toJsonMap(raw);
    final Map<String, DateTime> styles = <String, DateTime>{};
    toJsonMap(m['liveStyles']).forEach((String id, Object? until) {
      final DateTime? at = _msToDate(until);
      if (at != null) styles[id] = at;
    });
    return Passes(
      premiumPassUntil: _msToDate(m['premiumPassUntil']),
      autoRotatePassUntil: _msToDate(m['autoRotatePassUntil']),
      liveStyles: Map<String, DateTime>.unmodifiable(styles),
    );
  }

  static const Passes empty = Passes();

  final DateTime? premiumPassUntil;
  final DateTime? autoRotatePassUntil;

  /// Paid live wallpaper style id to the end of its 7-day unlock.
  final Map<String, DateTime> liveStyles;

  bool premiumPassActive(DateTime now) => premiumPassUntil?.isAfter(now) ?? false;

  bool autoRotatePassActive(DateTime now) => autoRotatePassUntil?.isAfter(now) ?? false;

  bool liveStyleActive(String styleId, DateTime now) => liveStyles[styleId]?.isAfter(now) ?? false;

  Passes copyWith({DateTime? premiumPassUntil, DateTime? autoRotatePassUntil, Map<String, DateTime>? liveStyles}) =>
      Passes(
        premiumPassUntil: premiumPassUntil ?? this.premiumPassUntil,
        autoRotatePassUntil: autoRotatePassUntil ?? this.autoRotatePassUntil,
        liveStyles: liveStyles ?? this.liveStyles,
      );
}

enum ChestOutcome { opened, locked, alreadyOpened, failed }

class ChestResult {
  const ChestResult(this.outcome, {this.coins = 0, this.doubled = false, this.itemId, this.reason = ''});

  final ChestOutcome outcome;
  final int coins;
  final bool doubled;

  /// A cosmetic the chest added to the inventory, if any.
  final String? itemId;
  final String reason;
}

enum ShopPurchaseOutcome { purchased, owned, proOnly, rankLocked, expired, insufficient, failed }

class ShopPurchaseResult {
  const ShopPurchaseResult(this.outcome, {this.owned = const <String>{}, this.reason = ''});

  final ShopPurchaseOutcome outcome;

  /// Every owned item id after the call.
  final Set<String> owned;
  final String reason;
}

enum DropUnlockOutcome { unlocked, alreadyUnlocked, notLive, insufficient, failed }

class DropUnlockResult {
  const DropUnlockResult(this.outcome, {this.unlocked = const <DropUnlock>[], this.reason = ''});

  final DropUnlockOutcome outcome;

  /// The walls this call unlocked.
  final List<DropUnlock> unlocked;
  final String reason;
}

enum BoostOutcome { boosted, active, notOwner, notApproved, slotsFull, insufficient, failed }

class BoostResult {
  const BoostResult(this.outcome, {this.endsAt, this.nextFreeAt, this.reason = ''});

  final BoostOutcome outcome;
  final DateTime? endsAt;

  /// With [BoostOutcome.slotsFull]: when the first boost slot frees up.
  final DateTime? nextFreeAt;
  final String reason;
}

enum GiftOutcome { sent, limit, recipientPremium, senderTooNew, blocked, insufficient, failed }

class GiftResult {
  const GiftResult(this.outcome, {this.expiresAt, this.reason = ''});

  final GiftOutcome outcome;
  final DateTime? expiresAt;
  final String reason;
}

enum DrawTicketOutcome { bought, limit, disabled, closed, proNotEligible, insufficient, failed }

class DrawTicketResult {
  const DrawTicketResult(this.outcome, {this.tickets = 0, this.closesAt, this.weekKey = '', this.reason = ''});

  final DrawTicketOutcome outcome;

  /// The user's tickets in this week's draw.
  final int tickets;
  final DateTime? closesAt;
  final String weekKey;
  final String reason;
}
