import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/coins/coin_action.dart';
import 'package:Prism/core/coins/coin_policy.dart';
import 'package:Prism/core/coins/coin_transaction_entry.dart';
import 'package:Prism/core/coins/downloaded_link_lookup.dart';
import 'package:Prism/core/coins/economy_config.dart';
import 'package:Prism/core/coins/economy_snapshot_store.dart';
import 'package:Prism/core/coins/economy_state.dart';
import 'package:Prism/core/coins/pending_download.dart';
import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/firestore/firestore_server_read.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/network/connectivity_service.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/profile/profile_completeness_evaluator.dart';
import 'package:Prism/core/purchases/subscription_tier.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_charge_mode.dart';
import 'package:Prism/features/ai_wallpaper/domain/entities/ai_quality_tier.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_pref_keys.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';

export 'package:Prism/core/coins/economy_state.dart';

class CoinMutationResult {
  const CoinMutationResult({
    required this.success,
    required this.changed,
    required this.previousBalance,
    required this.currentBalance,
    required this.delta,
    this.bypassed = false,
    this.insufficientBalance = false,
    this.reason = '',
    this.transactionId = '',
    this.unknownOutcomeTransactionId = '',
    this.pendingDownloadTxId = '',
    this.adsRemaining,
    this.graceDownloadsLeft,
    this.passUntil,
  });

  final bool success;
  final bool changed;
  final bool bypassed;
  final bool insufficientBalance;
  final int previousBalance;
  final int currentBalance;
  final int delta;
  final String reason;
  final String transactionId;

  /// Set when a spend got no answer: the debit may have committed under this server transaction id.
  final String unknownOutcomeTransactionId;

  /// The key of the ledger entry that a charged download spend wrote, exactly as the ledger stores it. Empty when the
  /// spend was not a tracked download or did not charge.
  final String pendingDownloadTxId;

  /// Rewarded ads the user can still watch today. Only the `rewardedAd` award reply sets it.
  final int? adsRemaining;

  /// Free downloads left after a spend reply that reports them.
  final int? graceDownloadsLeft;

  /// End of the pass a pass spend (auto-rotate, live wallpaper style) bought.
  final DateTime? passUntil;

  CoinMutationResult withPendingDownloadTxId(String txId) => CoinMutationResult(
    success: success,
    changed: changed,
    bypassed: bypassed,
    insufficientBalance: insufficientBalance,
    previousBalance: previousBalance,
    currentBalance: currentBalance,
    delta: delta,
    reason: reason,
    transactionId: transactionId,
    unknownOutcomeTransactionId: unknownOutcomeTransactionId,
    pendingDownloadTxId: txId,
    adsRemaining: adsRemaining,
    graceDownloadsLeft: graceDownloadsLeft,
    passUntil: passUntil,
  );

  // ignore: prefer_constructors_over_static_methods
  static CoinMutationResult noChange({
    required int balance,
    String reason = '',
    bool success = true,
    String unknownOutcomeTransactionId = '',
  }) {
    return CoinMutationResult(
      success: success,
      changed: false,
      previousBalance: balance,
      currentBalance: balance,
      delta: 0,
      reason: reason,
      unknownOutcomeTransactionId: unknownOutcomeTransactionId,
    );
  }
}

class _AiGenerationReservationResult {
  const _AiGenerationReservationResult({required this.mode, required this.mutation, this.transactionId});

  final AiChargeMode mode;
  final CoinMutationResult mutation;
  final String? transactionId;

  bool get success => mode != AiChargeMode.insufficient && mutation.success;

  /// The charge may have gone through but the reply never arrived. A refund is queued for it.
  bool get refundPending => mutation.unknownOutcomeTransactionId.isNotEmpty;

  int get coinsSpent => mode == AiChargeMode.coinSpend && mutation.changed ? -mutation.delta : 0;
}

class _PrivateEconomyRead {
  const _PrivateEconomyRead(this.data, {this.authoritativeMissing = false});

  final Map<String, dynamic>? data;
  final bool authoritativeMissing;
}

/// One-time earn rewards the user already got, read from `coinState`.
class CoinEarnFlags {
  const CoinEarnFlags({required this.firstUploadRewarded, required this.profileCompletionRewarded});

  static const CoinEarnFlags empty = CoinEarnFlags(firstUploadRewarded: false, profileCompletionRewarded: false);

  factory CoinEarnFlags.fromCoinState(Map<String, dynamic> coinState) => CoinEarnFlags(
    firstUploadRewarded: coinState['firstWallpaperUploadRewarded'] == true,
    profileCompletionRewarded: coinState['profileCompletionRewarded'] == true,
  );

  final bool firstUploadRewarded;
  final bool profileCompletionRewarded;

  @override
  bool operator ==(Object other) =>
      other is CoinEarnFlags &&
      other.firstUploadRewarded == firstUploadRewarded &&
      other.profileCompletionRewarded == profileCompletionRewarded;

  @override
  int get hashCode => Object.hash(firstUploadRewarded, profileCompletionRewarded);
}

class StreakStatus {
  const StreakStatus({
    required this.streakDay,
    required this.active,
    required this.claimedToday,
    required this.reminderEnabled,
    required this.timezoneOffsetMinutes,
    required this.lastClaimDate,
    this.nextReminderAtUtc,
    this.count = 0,
    this.best = 0,
    this.freezes = 0,
  });

  /// Day inside the 7-day cycle (1..7).
  final int streakDay;

  /// Uncapped streak length.
  final int count;
  final int best;

  /// Held streak freezes (0..2).
  final int freezes;
  final bool active;
  final bool claimedToday;
  final bool reminderEnabled;
  final int timezoneOffsetMinutes;
  final String lastClaimDate;
  final DateTime? nextReminderAtUtc;

  static const StreakStatus empty = StreakStatus(
    streakDay: 0,
    active: false,
    claimedToday: false,
    reminderEnabled: true,
    timezoneOffsetMinutes: 0,
    lastClaimDate: '',
  );

  StreakStatus copyWith({
    int? streakDay,
    bool? active,
    bool? claimedToday,
    bool? reminderEnabled,
    int? timezoneOffsetMinutes,
    String? lastClaimDate,
    DateTime? nextReminderAtUtc,
    int? count,
    int? best,
    int? freezes,
  }) {
    return StreakStatus(
      count: count ?? this.count,
      best: best ?? this.best,
      freezes: freezes ?? this.freezes,
      streakDay: streakDay ?? this.streakDay,
      active: active ?? this.active,
      claimedToday: claimedToday ?? this.claimedToday,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      timezoneOffsetMinutes: timezoneOffsetMinutes ?? this.timezoneOffsetMinutes,
      lastClaimDate: lastClaimDate ?? this.lastClaimDate,
      nextReminderAtUtc: nextReminderAtUtc ?? this.nextReminderAtUtc,
    );
  }
}

class StreakClaimResult {
  const StreakClaimResult({
    required this.claimed,
    required this.alreadyClaimedToday,
    required this.streakDay,
    required this.streakCount,
    required this.previousStreakCount,
    required this.streakBest,
    required this.streakBroken,
    required this.freezesUsed,
    required this.freezesLeft,
    required this.isWeekComplete,
    required this.dailyReward,
    required this.streakBonusReward,
    required this.proBonusReward,
    required this.totalReward,
    required this.newBalance,
    this.milestone,
    this.isChest = false,
  });

  /// Reads a claimDailyStreak payload. Fields an older backend does not send get safe defaults.
  factory StreakClaimResult.fromPayload(Map<String, dynamic> payload) {
    bool asBool(Object? v) => v is bool ? v : const <String>['true', '1'].contains(v?.toString().toLowerCase().trim());
    final int cycleDay = min(7, max(0, parseIntOr(payload['streakDay'])));
    final int count = payload['streakCount'] == null ? cycleDay : max(0, parseIntOr(payload['streakCount']));
    return StreakClaimResult(
      claimed: asBool(payload['claimed']),
      alreadyClaimedToday: asBool(payload['alreadyClaimedToday']),
      streakDay: cycleDay,
      streakCount: count,
      previousStreakCount: payload['previousStreakCount'] == null
          ? max(0, count - 1)
          : max(0, parseIntOr(payload['previousStreakCount'])),
      streakBest: payload['streakBest'] == null ? count : max(count, parseIntOr(payload['streakBest'])),
      streakBroken: asBool(payload['streakBroken']),
      freezesUsed: max(0, parseIntOr(payload['freezesUsed'])),
      freezesLeft: max(0, parseIntOr(payload['freezesLeft'])),
      isWeekComplete: payload['isWeekComplete'] == null ? cycleDay == 7 : asBool(payload['isWeekComplete']),
      milestone: payload['milestone'] == null ? null : parseIntOr(payload['milestone']),
      isChest: asBool(payload['isChest']),
      dailyReward: parseIntOr(payload['dailyReward']),
      streakBonusReward: parseIntOr(payload['streakBonusReward']),
      proBonusReward: parseIntOr(payload['proBonusReward']),
      totalReward: parseIntOr(payload['totalReward']),
      newBalance: parseIntOr(payload['newBalance']),
    );
  }

  final bool claimed;
  final bool alreadyClaimedToday;
  final int streakDay;
  final int streakCount;
  final int previousStreakCount;
  final int streakBest;
  final bool streakBroken;
  final int freezesUsed;
  final int freezesLeft;
  final bool isWeekComplete;
  final bool isChest;
  final int? milestone;
  final int dailyReward;
  final int streakBonusReward;
  final int proBonusReward;
  final int totalReward;
  final int newBalance;

  List<StreakLifecycleEvent> get lifecycleEvents => !claimed
      ? const <StreakLifecycleEvent>[]
      : <StreakLifecycleEvent>[
          if (streakBroken)
            StreakLifecycleEvent(action: 'break', streakCount: streakCount, previousCount: previousStreakCount),
          StreakLifecycleEvent(
            action: streakCount == 1 ? 'start' : 'increment',
            streakCount: streakCount,
            previousCount: previousStreakCount,
          ),
          if (freezesUsed > 0)
            StreakLifecycleEvent(
              action: 'freeze_used',
              streakCount: streakCount,
              freezesUsed: freezesUsed,
              freezesLeft: freezesLeft,
            ),
          if (milestone != null && milestone! > 0)
            StreakLifecycleEvent(action: 'milestone', streakCount: streakCount, milestone: milestone),
        ];
}

enum StreakFreezeOutcome { success, insufficientBalance, atCap, unavailable, failed }

class StreakFreezePurchase {
  const StreakFreezePurchase(this.outcome, {this.freezes = 0, this.message = ''});

  final StreakFreezeOutcome outcome;
  final int freezes;
  final String message;

  bool get isSuccess => outcome == StreakFreezeOutcome.success;
}

class CoinsService with WidgetsBindingObserver {
  CoinsService._();

  static final CoinsService instance = CoinsService._();
  EconomySnapshotStore _economySnapshots = EconomySnapshotStore();
  int _economySessionGeneration = 0;

  static const String _coinStateField = 'coinState';
  static const String _txCollection = FirebaseCollections.coinTransactions;
  static const String _pendingReferralInviterPrefKey = 'pendingReferralInviterId';
  // The queue first held only AI refunds. The storage key stays so entries written by older builds still load.
  static const String _pendingRefundsPrefKey = 'pendingAiRefunds';
  static const String _pendingDownloadsPrefKey = 'pendingDownloads_v2';
  // The first ledger design held one entry under this key. Reads still merge it and the next write removes it.
  static const String _legacyPendingDownloadPrefKey = 'pendingDownloadMarker';
  static const Duration _refundWindow = Duration(minutes: 10);
  static const String _spendTransactionPrefix = 'spend_';
  static const String _awardTransactionPrefix = 'award_';
  static const int _maxLabelLength = 60;
  static const Duration _pendingRewardWindow = Duration(hours: 24);
  static const String _streakReminderEnabledField = 'streakReminderEnabled';
  static const String _streakTimezoneOffsetMinutesField = 'streakTimezoneOffsetMinutes';
  static const String _streakReminderNextAtUtcField = 'streakReminderNextAtUtc';
  static const Duration _deltaAnimationDuration = Duration(milliseconds: 1400);

  /// Spends the server can refund (`REFUNDABLE_ACTIONS` in coinsCallables.ts). Only these go to the refund queue.
  static const Set<CoinSpendAction> refundableSpendActions = <CoinSpendAction>{
    CoinSpendAction.wallpaperDownload,
    CoinSpendAction.premiumWallpaperDownload,
    CoinSpendAction.aiGeneration,
  };

  /// Spends whose request id is stored until a definite reply, so a retry replays the same charge.
  static const Set<CoinSpendAction> _replayedSpendActions = <CoinSpendAction>{
    CoinSpendAction.wallpaperDownload,
    CoinSpendAction.premiumWallpaperDownload,
    CoinSpendAction.premiumFilter,
    CoinSpendAction.liveWallpaperStyle,
    CoinSpendAction.autoRotatePass7d,
  };
  final Queue<Completer<void>> _refundQueueWaiters = Queue<Completer<void>>();
  bool _refundQueueHeld = false;
  bool _pendingRetryInFlight = false;
  Timer? _pendingRetryTimer;
  Timer? _downloadRecoveryTimer;
  bool _downloadRecoveryInFlight = false;

  /// Ids of paid downloads whose tap still runs in this process. Recovery skips them, because the native save may
  /// still finish, for example while the Photos permission dialog stays open. An id leaves the set only after the
  /// write that settles it is stored, so a failed write keeps the protection until the app restarts. The set is empty
  /// after a restart, so recovery then treats every stored entry as abandoned.
  final Set<String> _liveDownloadTxIds = <String>{};
  StreamSubscription<bool>? _connectivitySubscription;
  bool _observingLifecycle = false;

  /// How long to wait before the next retry while the pending queue holds entries.
  @visibleForTesting
  Duration pendingRetryInterval = const Duration(seconds: 30);

  /// How old a paid download must be before recovery counts it as abandoned and refunds it.
  @visibleForTesting
  Duration abandonedDownloadAfter = const Duration(minutes: 2);

  DownloadedLinkCheck isLinkDownloaded = isLinkInDownloadedIndex;

  @visibleForTesting
  VerifiedLegacyNativeDownloadCheck verifiedLegacyNativeDownloadCheck = hasVerifiedLegacyNativeDownload;
  int? _adsRemaining;
  String _adsRemainingDay = '';
  final ValueNotifier<int> balanceNotifier = ValueNotifier<int>(app_state.prismUser.coins);
  final ValueNotifier<int> deltaNotifier = ValueNotifier<int>(0);
  final ValueNotifier<StreakStatus> streakNotifier = ValueNotifier<StreakStatus>(StreakStatus.empty);
  final ValueNotifier<CoinEarnFlags> earnFlagsNotifier = ValueNotifier<CoinEarnFlags>(CoinEarnFlags.empty);

  /// Set only when a daily claim really paid out. The UI shows the daily sheet, then calls [consumeLastClaim].
  final ValueNotifier<StreakClaimResult?> lastClaimNotifier = ValueNotifier<StreakClaimResult?>(null);
  String? _pendingClaimUserId;
  final Set<(String, String)> _publishedClaimDays = <(String, String)>{};
  String? _pendingFreezeUserId;
  String? _pendingFreezeRequestId;

  final ValueNotifier<XpStatus> xpNotifier = ValueNotifier<XpStatus>(XpStatus.empty());
  final ValueNotifier<QuestState?> questsNotifier = ValueNotifier<QuestState?>(null);

  /// Quest items the server just paid. The UI shows them, then calls [consumeQuestAwards].
  final ValueNotifier<List<QuestAward>> questAwardsNotifier = ValueNotifier<List<QuestAward>>(const <QuestAward>[]);
  final ValueNotifier<Inventory> inventoryNotifier = ValueNotifier<Inventory>(Inventory.empty);

  /// Unlocked Drop walls by wall id.
  final ValueNotifier<Map<String, DropUnlock>> dropsUnlockedNotifier = ValueNotifier<Map<String, DropUnlock>>(
    const <String, DropUnlock>{},
  );
  final ValueNotifier<Passes> passesNotifier = ValueNotifier<Passes>(Passes.empty);
  String _economyUserId = '';

  /// The user whose root XP was read, so a later rise can be announced as a rank up.
  String _xpUserId = '';
  XpStatus _confirmedXp = XpStatus.empty();
  String _confirmedXpWeek = '';
  int _xpMutationGeneration = 0;
  int _economyRev = -1;
  int _economyMutationGeneration = 0;
  int _graceDownloadsUsed = 0;
  String? _adsTodayDay;
  int _adsTodayCount = 0;
  final Map<String, String> _pendingEconomyRequests = <String, String>{};
  final Set<String> _spendRequestsInFlight = <String>{};
  final Map<(String, int), Future<void>> _rankRewardSyncs = <(String, int), Future<void>>{};
  final Set<(String, int)> _rankRewardSyncRequested = <(String, int)>{};

  /// The cached economy state belongs to the signed-in user.
  bool get _ownsEconomyState => _canMutateCoins() && _economyUserId == app_state.prismUser.id;

  /// Free downloads the user has left. Until the signed-in user's own count loads, a new account's allowance.
  int get graceDownloadsLeft =>
      _ownsEconomyState ? max(0, CoinPolicy.graceDownloads - _graceDownloadsUsed) : CoinPolicy.graceDownloads;

  /// The signed-in user's passes. Empty while the cached passes belong to someone else.
  Passes get currentPasses => _ownsEconomyState ? passesNotifier.value : Passes.empty;

  /// Premium collections and premium walls are open: Pro or an active premium pass.
  bool get premiumContentUnlocked => app_state.prismUser.premium || currentPasses.premiumPassActive(DateTime.now());

  /// Auto-rotate is open: Pro or an active auto-rotate pass.
  bool get autoRotateUnlocked => app_state.prismUser.premium || currentPasses.autoRotatePassActive(DateTime.now());

  /// What the next rewarded ad pays: more for the first ad of the UTC day.
  int get adsRewardNow {
    final String? day = _adsTodayDay;
    if (day != null) {
      return day == _utcDayKey() && _adsTodayCount > 0 ? CoinPolicy.rewardedAd : CoinPolicy.rewardedAdFirstOfDay;
    }
    final int? remaining = adsRemainingToday;
    return remaining == null || remaining == EconomyConfig.current.award.rewardedAdMaxPerDay
        ? CoinPolicy.rewardedAdFirstOfDay
        : CoinPolicy.rewardedAd;
  }

  void consumeQuestAwards() => questAwardsNotifier.value = const <QuestAward>[];

  /// Sets the passes as the signed-in user's own, as a sync from the server would.
  @visibleForTesting
  void setPassesForTest(Passes passes) {
    _ensureEconomyUser(app_state.prismUser.id);
    passesNotifier.value = passes;
  }

  /// Clears every per-user value at once. Sign-out calls it; the next sign-in loads the new user's state.
  void resetSession() {
    _economySessionGeneration++;
    consumeLastClaim();
    balanceNotifier.value = app_state.prismUser.coins;
    streakNotifier.value = StreakStatus.empty;
    earnFlagsNotifier.value = CoinEarnFlags.empty;
    _adsRemaining = null;
    _adsRemainingDay = '';
    _resetEconomy('');
  }

  StreakClaimResult? get pendingClaimForCurrentUser {
    if (!_canMutateCoins() || _pendingClaimUserId != app_state.prismUser.id) consumeLastClaim();
    return lastClaimNotifier.value;
  }

  void consumeLastClaim() {
    lastClaimNotifier.value = null;
    _pendingClaimUserId = null;
  }

  SettingsLocalDataSource get _settings => getIt<SettingsLocalDataSource>();

  int _deltaVersion = 0;

  CoinMutationResult get _notLoggedIn =>
      CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'not_logged_in');

  String? get pendingReferralInviterId {
    final String inviter = _settings.get<String>(_pendingReferralInviterPrefKey, defaultValue: '').trim();
    return inviter.isEmpty ? null : inviter;
  }

  Future<void> setPendingReferralInviterId(String inviterUserId) async {
    final String inviter = inviterUserId.trim();
    if (inviter.isEmpty) {
      return;
    }
    await _settings.set(_pendingReferralInviterPrefKey, inviter);
  }

  Future<void> clearPendingReferralInviterId() => _settings.delete(_pendingReferralInviterPrefKey);

  Future<void> setStreakReminderPreference(
    bool enabled, {
    String sourceTag = 'coins.streak_reminder.preference',
  }) async {
    if (_settings.isOpen) {
      await _settings.set(NotificationPrefKeys.streakReminders, enabled);
    }
    if (!_canMutateCoins()) {
      streakNotifier.value = streakNotifier.value.copyWith(reminderEnabled: enabled);
      return;
    }
    final String userId = app_state.prismUser.id;
    final int timezoneOffsetMinutes = _deviceTimezoneOffsetMinutes();
    await firestoreClient.runTransaction<void>(
      (tx) async {
        final Map<String, dynamic>? data = await tx.getDoc(FirebaseCollections.usersV2, userId);
        if (data == null) {
          return;
        }
        final Map<String, dynamic> coinState = toJsonMap(data[_coinStateField]);
        final int effectiveTimezoneOffset =
            parseInt(coinState['streakClaimTimezoneOffsetMinutes']) ?? timezoneOffsetMinutes;
        final DateTime nowUtc = DateTime.now().toUtc();
        final String todayLocalKey = _offsetDayKey(nowUtc, effectiveTimezoneOffset);
        final String lastClaimDate = (coinState['lastDailyClaimDate'] as String? ?? '').trim();
        final int streakDay = _clampStreakDay(parseIntOr(coinState['streakDay']));
        final int count = _streakCount(coinState, streakDay);
        final bool active =
            count > 0 &&
            isStreakAlive(lastClaimDate, todayLocalKey, _clampFreezes(parseIntOr(coinState['streakFreezes'])));
        // Rules only allow the client to write these specific coinState leaves, never the whole map.
        final Map<String, dynamic> updates = <String, dynamic>{
          '$_coinStateField.$_streakReminderEnabledField': enabled,
          '$_coinStateField.$_streakTimezoneOffsetMinutesField': timezoneOffsetMinutes,
        };
        if (enabled && active) {
          updates['$_coinStateField.$_streakReminderNextAtUtcField'] = _computeNextReminderAtUtc(
            nowUtc: nowUtc,
            timezoneOffsetMinutes: effectiveTimezoneOffset,
            lastClaimDate: lastClaimDate,
            todayLocalKey: todayLocalKey,
            activeStreak: true,
          );
        } else {
          updates['$_coinStateField.$_streakReminderNextAtUtcField'] = FirestoreSentinels.delete();
        }
        tx.updateDoc(FirebaseCollections.usersV2, userId, updates);
      },
      sourceTag: sourceTag,
      collection: FirebaseCollections.usersV2,
      docId: userId,
    );
    await refreshStreakStatus();
  }

  Future<void> bootstrapForCurrentUser() async {
    if (!_canMutateCoins()) {
      return;
    }
    final String userId = app_state.prismUser.id;
    _ensureEconomyUser(userId);
    final int generation = _economySessionGeneration;
    final int mutationGeneration = _economyMutationGeneration;
    final int xpGeneration = _xpMutationGeneration;
    final Map<String, dynamic>? rootSnapshot = await _readRootEconomySnapshot(userId);
    if (!_isCurrentOwner(userId, generation)) return;
    if (rootSnapshot != null && _economyMutationGeneration == mutationGeneration) {
      _syncRootProjection(userId, rootSnapshot, syncXp: _xpMutationGeneration == xpGeneration);
    }
    final EconomySnapshot? saved = await _readEconomySnapshot(userId);
    if (!_isCurrentOwner(userId, generation)) return;
    if (saved != null && _economyMutationGeneration == mutationGeneration && saved.revision >= _economyRev) {
      _syncPrivateEconomy(userId, <String, dynamic>{...saved.data, 'rev': saved.revision});
    }
    startPendingRetryWatch();
    final Future<_PrivateEconomyRead> privateEconomy = _readPrivateEconomy(
      userId,
    ).timeout(const Duration(seconds: 8), onTimeout: () => const _PrivateEconomyRead(null));
    // The server owns coinState defaults now; the rules block writing it from the client,
    // so this only reads and defaults locally/in-memory instead of persisting anything.
    final Map<String, dynamic>? data = await firestoreClient
        .getById<Map<String, dynamic>>(
          FirebaseCollections.usersV2,
          userId,
          (value, _) => value,
          sourceTag: 'coins.bootstrap',
        )
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
    final _PrivateEconomyRead privateRead = await privateEconomy;
    final Map<String, dynamic>? privateData = privateRead.data;
    if (!_isCurrentOwner(userId, generation)) return;
    if (privateData != null &&
        _economyMutationGeneration == mutationGeneration &&
        parseIntOr(privateData['rev']) >= max(saved?.revision ?? -1, _economyRev)) {
      _syncPrivateEconomy(userId, privateData);
      if (!_isCurrentOwner(userId, generation)) return;
      await _persistEconomy(userId, privateData, authoritative: true);
      if (!_isCurrentOwner(userId, generation)) return;
    } else if (privateRead.authoritativeMissing && _economyMutationGeneration == mutationGeneration) {
      _resetEconomy(userId, resetXp: false);
      if (rootSnapshot != null) {
        _syncRootProjection(userId, rootSnapshot, syncXp: _xpMutationGeneration == xpGeneration);
      }
      await _invalidateEconomySnapshot(userId);
      if (!_isCurrentOwner(userId, generation)) return;
    }
    if (_pendingClaimUserId != userId) consumeLastClaim();
    if (data == null) {
      await reconcileRankRewards();
      return;
    }
    _applyLocalBalance(parseIntOr(data['coins']), delta: 0);
    if (_economyMutationGeneration == mutationGeneration) {
      final bool syncXp = _xpMutationGeneration == xpGeneration;
      _syncStreakFromUserData(data, syncXp: syncXp);
      await _persistRootEconomySnapshot(userId, data, includeXp: syncXp, merge: !syncXp);
      if (!_isCurrentOwner(userId, generation)) return;
    }
    await retryPendingRefunds();
    if (!_isCurrentOwner(userId, generation)) return;
    await reconcileRankRewards();
  }

  Future<void> restoreLocalEconomyForCurrentUser() async {
    final String userId = app_state.prismUser.id;
    if (!_canMutateCoins() || userId.trim().isEmpty) return;
    _ensureEconomyUser(userId);
    final int generation = _economySessionGeneration;
    final int mutationGeneration = _economyMutationGeneration;
    final int xpGeneration = _xpMutationGeneration;
    final Map<String, dynamic>? rootSnapshot = await _readRootEconomySnapshot(userId);
    if (!_isCurrentOwner(userId, generation)) return;
    if (rootSnapshot != null && _economyMutationGeneration == mutationGeneration) {
      _syncRootProjection(userId, rootSnapshot, syncXp: _xpMutationGeneration == xpGeneration);
    }
    final EconomySnapshot? saved = await _readEconomySnapshot(userId);
    if (!_isCurrentOwner(userId, generation)) return;
    if (saved != null && _economyMutationGeneration == mutationGeneration && saved.revision >= _economyRev) {
      _syncPrivateEconomy(userId, <String, dynamic>{...saved.data, 'rev': saved.revision});
    }
    if (_economyMutationGeneration != mutationGeneration) return;
  }

  bool _isCurrentOwner(String userId, int generation) =>
      generation == _economySessionGeneration && _canMutateCoins() && userId == app_state.prismUser.id;

  Future<void> clearForUser(String userId) async {
    if (app_state.prismUser.id == userId || _economyUserId == userId) {
      _economySessionGeneration++;
    }
    if (_economyUserId == userId) {
      _resetEconomy('');
    }
    await _economySnapshots.clearForUser(userId);
  }

  @visibleForTesting
  void setEconomySnapshotStoreForTest(EconomySnapshotStore store) {
    _economySnapshots = store;
  }

  Future<void> _persistEconomy(String userId, Map<String, dynamic> data, {bool authoritative = false}) async {
    if (!_canMutateCoins() || app_state.prismUser.id != userId) return;
    final int revision = max(0, data.containsKey('rev') ? parseIntOr(data['rev']) : _economyRev);
    try {
      if (authoritative) {
        await _economySnapshots.replace(userId, revision, data);
      } else {
        await _economySnapshots.write(userId, revision, data);
      }
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.private_economy.persist', error: error, stackTrace: stackTrace);
    }
  }

  Future<Map<String, dynamic>?> _readRootEconomySnapshot(String userId) async {
    try {
      return await _economySnapshots.readRoot(userId);
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.root_economy.restore', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _persistRootEconomySnapshot(
    String userId,
    Map<String, dynamic> userData, {
    bool merge = false,
    bool includeXp = true,
  }) async {
    try {
      await _economySnapshots.writeRoot(userId, <String, dynamic>{
        if (includeXp && userData.containsKey('xp')) 'xp': userData['xp'],
        if (includeXp && userData.containsKey('xpWeek')) 'xpWeek': userData['xpWeek'],
        if (!includeXp || userData.containsKey('cosmetics')) 'cosmetics': userData['cosmetics'],
      }, merge: merge);
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.root_economy.persist', error: error, stackTrace: stackTrace);
    }
  }

  Future<EconomySnapshot?> _readEconomySnapshot(String userId) async {
    try {
      return await _economySnapshots.read(userId);
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.private_economy.restore', error: error, stackTrace: stackTrace);
      return null;
    }
  }

  Future<void> _invalidateEconomySnapshot(String userId) async {
    try {
      await _economySnapshots.invalidateForUser(userId);
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.private_economy.invalidate', error: error, stackTrace: stackTrace);
    }
  }

  Future<int> refreshBalance() async {
    if (!_canMutateCoins()) {
      return app_state.prismUser.coins;
    }
    final String userId = app_state.prismUser.id;
    _ensureEconomyUser(userId);
    final int generation = _economySessionGeneration;
    final int mutationGeneration = _economyMutationGeneration;
    final int xpGeneration = _xpMutationGeneration;
    final Map<String, dynamic>? rootSnapshot = await _readRootEconomySnapshot(userId);
    if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
    if (rootSnapshot != null && _economyMutationGeneration == mutationGeneration) {
      _syncRootProjection(userId, rootSnapshot, syncXp: _xpMutationGeneration == xpGeneration);
    }
    final EconomySnapshot? saved = await _readEconomySnapshot(userId);
    if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
    if (saved != null && _economyMutationGeneration == mutationGeneration && saved.revision >= _economyRev) {
      _syncPrivateEconomy(userId, <String, dynamic>{...saved.data, 'rev': saved.revision});
    }
    final Future<_PrivateEconomyRead> privateEconomy = _readPrivateEconomy(
      userId,
    ).timeout(const Duration(seconds: 8), onTimeout: () => const _PrivateEconomyRead(null));
    final Map<String, dynamic>? userData = await firestoreClient
        .getById<Map<String, dynamic>>(
          FirebaseCollections.usersV2,
          userId,
          (data, _) => data,
          sourceTag: 'coins.refresh_balance',
        )
        .timeout(const Duration(seconds: 8), onTimeout: () => null);
    if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
    final _PrivateEconomyRead privateRead = await privateEconomy;
    if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
    final Map<String, dynamic>? privateData = privateRead.data;
    if (privateData != null &&
        _economyMutationGeneration == mutationGeneration &&
        parseIntOr(privateData['rev']) >= max(saved?.revision ?? -1, _economyRev)) {
      _syncPrivateEconomy(userId, privateData);
      if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
      await _persistEconomy(userId, privateData, authoritative: true);
      if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
    } else if (privateRead.authoritativeMissing && _economyMutationGeneration == mutationGeneration) {
      _resetEconomy(userId, resetXp: false);
      if (rootSnapshot != null) {
        _syncRootProjection(userId, rootSnapshot, syncXp: _xpMutationGeneration == xpGeneration);
      }
      await _invalidateEconomySnapshot(userId);
      if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
    }
    if (userData == null) {
      await reconcileRankRewards();
      return app_state.prismUser.coins;
    }
    final int coins = parseIntOr(userData['coins']);
    _applyLocalBalance(coins, delta: 0);
    if (_economyMutationGeneration == mutationGeneration) {
      final bool syncXp = _xpMutationGeneration == xpGeneration;
      _syncStreakFromUserData(userData, syncXp: syncXp);
      await _persistRootEconomySnapshot(userId, userData, includeXp: syncXp, merge: !syncXp);
      if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
    }
    await reconcileRankRewards();
    if (!_isCurrentOwner(userId, generation)) return app_state.prismUser.coins;
    return coins;
  }

  Future<StreakStatus> refreshStreakStatus() async {
    if (!_canMutateCoins()) {
      resetSession();
      return StreakStatus.empty;
    }
    final String userId = app_state.prismUser.id;
    final Map<String, dynamic>? userData = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data,
      sourceTag: 'coins.refresh_streak',
    );
    if (!_canMutateCoins() || userId != app_state.prismUser.id) return StreakStatus.empty;
    if (userData == null) {
      return streakNotifier.value;
    }
    return _syncStreakFromUserData(userData);
  }

  Future<List<CoinTransactionEntry>> fetchTransactions({int limit = 100, bool fresh = false}) async {
    if (!_canMutateCoins()) {
      return const <CoinTransactionEntry>[];
    }
    final String userId = app_state.prismUser.id;
    try {
      final rows = await firestoreClient.query<CoinTransactionEntry>(
        FirestoreQuerySpec(
          collection: _txCollection,
          sourceTag: 'coins.transactions.fetch',
          filters: <FirestoreFilter>[FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId)],
          orderBy: <FirestoreOrderBy>[const FirestoreOrderBy(field: 'createdAt', descending: true)],
          limit: limit,
          dedupeWindowMs: fresh ? 0 : 1500,
        ),
        (data, docId) => CoinTransactionEntry.fromJson(data, fallbackId: docId),
      );
      return rows;
    } on FirestoreError catch (error, stackTrace) {
      if (error.code != 'failed-precondition') {
        rethrow;
      }
      logCoinError(sourceTag: 'coins.transactions.fetch.missing_index_fallback', error: error, stackTrace: stackTrace);
      final fallbackRows = await firestoreClient.query<CoinTransactionEntry>(
        FirestoreQuerySpec(
          collection: _txCollection,
          sourceTag: 'coins.transactions.fetch.missing_index_fallback',
          filters: <FirestoreFilter>[FirestoreFilter(field: 'userId', op: FirestoreFilterOp.isEqualTo, value: userId)],
          dedupeWindowMs: fresh ? 0 : 1500,
        ),
        (data, docId) => CoinTransactionEntry.fromJson(data, fallbackId: docId),
      );
      fallbackRows.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (limit <= 0 || fallbackRows.length <= limit) {
        return fallbackRows;
      }
      return fallbackRows.sublist(0, limit);
    }
  }

  Future<CoinMutationResult> award(
    CoinEarnAction action, {
    String sourceTag = 'coins.award',
    int? amountOverride,
    String? reason,
    String? transactionId,
    String? requestId,
  }) async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final bool isRefund = action == CoinEarnAction.refund;
    // Refunds are keyed by the debit's transactionId; the server ignores amount for them.
    final int? amount = isRefund ? null : (amountOverride ?? action.defaultAmount());
    if (!isRefund && (amount ?? 0) <= 0) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'invalid_amount');
    }
    final CoinMutationResult result = await _callCoinMutation(
      userId: userId,
      callableName: 'awardCoins',
      amount: amount,
      action: action.name,
      sourceTag: sourceTag,
      reason: reason ?? action.name,
      transactionId: transactionId,
      requestId: requestId,
    );
    if (action == CoinEarnAction.rewardedAd) {
      final String prefix = '$_awardTransactionPrefix${userId}_';
      if (result.unknownOutcomeTransactionId.startsWith(prefix)) {
        await _rememberPendingReward(result.unknownOutcomeTransactionId.substring(prefix.length), userId: userId);
      }
    }
    if (!_isCurrentOwner(userId, generation)) return _notLoggedIn;
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (action == CoinEarnAction.rewardedAd) {
      _noteAdsRemaining(result.adsRemaining);
      if (result.changed) {
        _noteAdWatched();
        _markBonusQuestDone(QuestEvent.watchAd);
      }
    }
    if (result.changed) {
      _logEarn(
        action: action,
        amount: result.delta > 0 ? result.delta : amount ?? 0,
        sourceTag: sourceTag,
        reason: reason,
      );
      if (!isRefund) unawaited(reconcileRankRewards());
    }
    return result;
  }

  Future<CoinMutationResult> spend(
    CoinSpendAction action, {
    String sourceTag = 'coins.spend',
    int? amountOverride,
    String? reason,
    String? label,
    String? pendingDownloadLink,
    String? styleId,
  }) async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final int amount = amountOverride ?? action.cost();
    if (amount < 0) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'invalid_amount');
    }

    final String requestKey = 'pendingSpendRequest.${action.name}.${styleId ?? ''}.${app_state.prismUser.id}';
    // A second tap while the first still runs gets its own request, so two purchases never share one charge.
    final bool replayed = _replayedSpendActions.contains(action) && _spendRequestsInFlight.add(requestKey);
    final CoinMutationResult result;
    try {
      result = await _spendOnce(
        action,
        amount: amount,
        requestKey: replayed ? requestKey : null,
        sourceTag: sourceTag,
        reason: reason,
        label: label,
        pendingDownloadLink: pendingDownloadLink,
        styleId: styleId,
      );
    } finally {
      if (replayed) _spendRequestsInFlight.remove(requestKey);
    }
    // The replayed debit was refunded while its reply was lost. The stored request is gone, so this charges anew.
    if (replayed && result.reason == 'spend_refunded') {
      return spend(
        action,
        sourceTag: sourceTag,
        amountOverride: amountOverride,
        reason: reason,
        label: label,
        pendingDownloadLink: pendingDownloadLink,
        styleId: styleId,
      );
    }
    return result;
  }

  /// One spend call. A non-null [requestKey] stores the request id until a definite reply and replays it on retry.
  Future<CoinMutationResult> _spendOnce(
    CoinSpendAction action, {
    required int amount,
    required String? requestKey,
    required String sourceTag,
    required String? reason,
    required String? label,
    required String? pendingDownloadLink,
    required String? styleId,
  }) async {
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final SettingsLocalDataSource settings = _settings;
    String? requestId;
    if (requestKey != null) {
      final String stored = settings.isOpen ? settings.get<String>(requestKey, defaultValue: '') : '';
      requestId = _pendingEconomyRequests[requestKey] ??= stored.isNotEmpty ? stored : _newRequestId();
      try {
        if (settings.isOpen) await settings.set(requestKey, requestId);
      } catch (error, stackTrace) {
        // Without the stored id a lost reply cannot be replayed after a restart. The spend still runs.
        logCoinError(sourceTag: 'coins.spend.request_store', error: error, stackTrace: stackTrace);
      }
      if (!_isCurrentOwner(userId, generation)) return _notLoggedIn;
    } else if (pendingDownloadLink != null) {
      requestId = _newRequestId();
    }
    final String? pendingTxId = pendingDownloadLink == null || requestId == null
        ? null
        : '$_spendTransactionPrefix${userId}_$requestId';
    if (pendingDownloadLink != null && pendingTxId != null) {
      final bool persisted = await _updatePendingDownloads('coins.download.ledger_write', (
        Map<String, PendingDownload> ledger,
      ) {
        ledger[pendingTxId] = PendingDownload(
          txId: pendingTxId,
          userId: userId,
          link: pendingDownloadLink,
          action: action.name,
          at: DateTime.now().millisecondsSinceEpoch,
        );
        _liveDownloadTxIds.add(pendingTxId);
        return true;
      });
      if (!_isCurrentOwner(userId, generation)) {
        if (persisted) {
          await _updatePendingDownloads('coins.download.ledger_owner_changed', (Map<String, PendingDownload> ledger) {
            final PendingDownload? entry = ledger[pendingTxId];
            return entry != null && entry.userId == userId && ledger.remove(pendingTxId) != null;
          }, onPersisted: () => _liveDownloadTxIds.remove(pendingTxId));
        }
        _liveDownloadTxIds.remove(pendingTxId);
        return _notLoggedIn;
      }
      if (!persisted) {
        _liveDownloadTxIds.remove(pendingTxId);
        return CoinMutationResult.noChange(
          balance: app_state.prismUser.coins,
          success: false,
          reason: 'pending_download_storage_failed',
        );
      }
    }
    try {
      final CoinMutationResult result = await _callCoinMutation(
        userId: userId,
        callableName: 'spendCoins',
        amount: amount,
        action: action.name,
        sourceTag: sourceTag,
        reason: reason ?? action.name,
        allowPremiumBypass: true,
        label: label,
        requestId: requestId,
        extra: <String, Object?>{if (styleId != null) 'styleId': styleId},
      );

      if (result.success &&
          _isCurrentOwner(userId, generation) &&
          (result.changed || result.graceDownloadsLeft != null || result.passUntil != null)) {
        _economyMutationGeneration++;
      }
      if (requestKey != null && result.unknownOutcomeTransactionId.isEmpty) {
        if (_pendingEconomyRequests[requestKey] == requestId) _pendingEconomyRequests.remove(requestKey);
        if (settings.isOpen && settings.get<String>(requestKey, defaultValue: '') == requestId) {
          await settings.delete(requestKey);
        }
        // A replay that landed settles the earlier lost reply, so its queued refund must not run.
        if (result.success && result.changed) {
          await _forgetPendingRefund('$_spendTransactionPrefix${userId}_$requestId');
        }
      }
      if (_isCurrentOwner(userId, generation)) _applyLocalBalance(result.currentBalance, delta: result.delta);
      if (result.unknownOutcomeTransactionId.isNotEmpty) {
        await _rememberPendingRefund(
          result.unknownOutcomeTransactionId,
          userId: userId,
          action: action,
          reason: _failedRefundReason(action),
        );
      }
      if (_isCurrentOwner(userId, generation)) await _applySpendState(userId, action, result, styleId: styleId);
      final bool charged = result.success && result.changed;
      if (pendingTxId != null && !charged) {
        await _updatePendingDownloads(
          'coins.download.ledger_remove',
          (Map<String, PendingDownload> ledger) => ledger.remove(pendingTxId) != null,
          onPersisted: () => _liveDownloadTxIds.remove(pendingTxId),
        );
      }
      if (!_isCurrentOwner(userId, generation)) {
        if (pendingTxId != null) await releasePendingDownload(pendingTxId);
        return _notLoggedIn;
      }
      if (result.changed) _logSpend(action: action, amount: -result.delta, sourceTag: sourceTag, reason: reason);
      return pendingTxId != null && charged ? result.withPendingDownloadTxId(pendingTxId) : result;
    } catch (_) {
      // No caller gets the txId, so no save will run. The stored entry stays for recovery to refund.
      if (pendingTxId != null) await releasePendingDownload(pendingTxId);
      rethrow;
    }
  }

  /// Rewarded ads left today, as the last `rewardedAd` reply told. Null when unknown or from an earlier UTC day.
  int? get adsRemainingToday => _adsRemainingDay == _utcDayKey() ? _adsRemaining : null;

  void _noteAdsRemaining(int? remaining) {
    if (remaining == null) return;
    _adsRemaining = remaining;
    _adsRemainingDay = _utcDayKey();
  }

  String _utcDayKey() => _offsetDayKey(DateTime.now().toUtc(), 0);

  Future<CoinMutationResult> refundSpend(
    CoinSpendAction action, {
    required String sourceTag,
    required String transactionId,
    String? reason,
  }) {
    if (transactionId.trim().isEmpty) {
      return Future.value(
        CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'missing_transaction_id'),
      );
    }
    return award(
      CoinEarnAction.refund,
      sourceTag: sourceTag,
      reason: reason ?? 'refund_${action.name}',
      transactionId: transactionId,
    );
  }

  Future<_AiGenerationReservationResult> reserveForAiGeneration({
    required AiQualityTier qualityTier,
    String? operationId,
    String sourceTag = 'coins.reserve.ai_generation',
  }) async {
    if (!_canMutateCoins()) {
      return _AiGenerationReservationResult(
        mode: AiChargeMode.insufficient,
        mutation: CoinMutationResult.noChange(
          balance: app_state.prismUser.coins,
          success: false,
          reason: 'not_logged_in',
        ),
      );
    }
    final String reservingUserId = app_state.prismUser.id;
    // The server prices the tier (Pro pays half); the reply delta is the real charge.
    final CoinMutationResult mutation = await _callCoinMutation(
      userId: reservingUserId,
      callableName: 'spendCoins',
      action: CoinSpendAction.aiGeneration.name,
      sourceTag: sourceTag,
      reason: 'ai_generation_reserved',
      extra: <String, Object?>{'qualityTier': qualityTier.apiValue},
    );
    _applyLocalBalance(mutation.currentBalance, delta: mutation.delta);
    if (mutation.unknownOutcomeTransactionId.isNotEmpty) {
      await _rememberPendingRefund(mutation.unknownOutcomeTransactionId, userId: reservingUserId);
    }
    final _AiGenerationReservationResult result = _AiGenerationReservationResult(
      mode: mutation.changed ? AiChargeMode.coinSpend : AiChargeMode.insufficient,
      mutation: mutation,
      transactionId: mutation.transactionId,
    );
    if (result.mode == AiChargeMode.coinSpend && mutation.changed) {
      _logSpend(
        action: CoinSpendAction.aiGeneration,
        amount: result.coinsSpent,
        sourceTag: sourceTag,
        reason: 'ai_generation',
      );
    }
    analytics.track(
      AiChargeReservedEvent(
        operationId: operationId,
        chargeTransactionId: result.transactionId,
        mode: result.mode,
        coinsSpent: result.coinsSpent,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
      ),
    );
    return result;
  }

  Future<CoinMutationResult> rollbackAiGenerationReservation(
    AiChargeMode mode, {
    String sourceTag = 'coins.rollback.ai_generation',
    String? reservationTransactionId,
    String? operationId,
  }) async {
    if (mode == AiChargeMode.insufficient) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'no_reservation_to_rollback');
    }

    if (mode == AiChargeMode.coinSpend) {
      final CoinMutationResult refund = await refundSpend(
        CoinSpendAction.aiGeneration,
        transactionId: reservationTransactionId ?? '',
        sourceTag: sourceTag,
        reason: 'ai_generation_failed_refund',
      );
      if (refund.changed) {
        analytics.track(
          AiChargeRolledBackEvent(
            operationId: operationId,
            chargeTransactionId: reservationTransactionId,
            mode: mode,
            coinsRefunded: refund.delta,
            balance: app_state.prismUser.coins,
            sourceTag: sourceTag,
          ),
        );
      } else if (_isRetryableRefundFailure(refund)) {
        await _rememberPendingRefund(reservationTransactionId ?? '');
      }
      return refund;
    }

    return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'no_reservation_to_rollback');
  }

  static String aiRefundOutcome(CoinMutationResult refund, {bool charged = true}) {
    if (!charged || refund.reason == 'no_reservation_to_rollback') return 'not_required';
    if (refund.changed) return 'refunded';
    if (refund.reason == 'already_refunded') return 'already_refunded';
    if (const <String>{
      'failed-precondition',
      'invalid-argument',
      'permission-denied',
      'refund_daily_limit',
      'missing_transaction_id',
      'not_logged_in',
      'refund_denied_generation_succeeded',
    }.contains(refund.reason))
      return 'denied';
    return refund.success ? 'failed' : 'pending';
  }

  bool _isRetryableRefundFailure(CoinMutationResult refund) => aiRefundOutcome(refund) == 'pending';

  List<Map<String, dynamic>> _readPendingEntries() {
    if (!_settings.isOpen) return <Map<String, dynamic>>[];
    final String raw = _settings.get<String>(_pendingRefundsPrefKey, defaultValue: '');
    if (raw.isEmpty) return <Map<String, dynamic>>[];
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, dynamic>>[];
      return decoded.whereType<Map>().map((Map e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> _writePendingEntries(List<Map<String, dynamic>> entries) async {
    if (!_settings.isOpen) return;
    if (entries.isEmpty) {
      await _settings.delete(_pendingRefundsPrefKey);
    } else {
      await _settings.set(_pendingRefundsPrefKey, jsonEncode(entries));
    }
  }

  static bool _isRewardEntry(Map<String, dynamic> entry) => entry['kind'] == 'reward';

  /// The id that names an entry: the debit for a refund, the request for a reward.
  static String _entryKey(Map<String, dynamic> entry) =>
      (_isRewardEntry(entry) ? entry['requestId'] : entry['transactionId'])?.toString() ?? '';

  static String _failedRefundReason(CoinSpendAction action) =>
      action == CoinSpendAction.aiGeneration ? 'ai_generation_failed_refund' : 'download_failed_refund';

  Future<void> _rememberPendingRefund(
    String transactionId, {
    String? userId,
    CoinSpendAction action = CoinSpendAction.aiGeneration,
    String? reason,
  }) {
    if (!refundableSpendActions.contains(action)) return Future<void>.value();
    return _rememberPending(
      key: transactionId,
      userId: userId,
      entry: <String, dynamic>{
        'transactionId': transactionId,
        'action': action.name,
        'reason': reason ?? _failedRefundReason(action),
      },
    );
  }

  Future<void> _forgetPendingRefund(String transactionId) => _withRefundQueueLock(() async {
    final List<Map<String, dynamic>> entries = _readPendingEntries();
    final int before = entries.length;
    entries.removeWhere((Map<String, dynamic> e) => !_isRewardEntry(e) && _entryKey(e) == transactionId);
    if (entries.length != before) await _writePendingEntries(entries);
  });

  Future<void> _rememberPendingReward(String requestId, {String? userId}) => _rememberPending(
    key: requestId,
    userId: userId,
    entry: <String, dynamic>{'kind': 'reward', 'requestId': requestId},
  );

  Future<void> _rememberPending({required String key, required Map<String, dynamic> entry, String? userId}) {
    final String ownerId = userId ?? app_state.prismUser.id;
    if (key.isEmpty || ownerId.isEmpty || (userId == null && !_canMutateCoins())) return Future<void>.value();
    return _withRefundQueueLock(() async {
      final List<Map<String, dynamic>> entries = _readPendingEntries();
      if (entries.any((Map<String, dynamic> e) => _entryKey(e) == key)) return;
      entries.add(<String, dynamic>{'userId': ownerId, ...entry, 'atMs': DateTime.now().millisecondsSinceEpoch});
      await _writePendingEntries(entries);
      startPendingRetryWatch();
    });
  }

  Future<void> _withRefundQueueLock(Future<void> Function() action) async {
    if (_refundQueueHeld) {
      final Completer<void> turn = Completer<void>();
      _refundQueueWaiters.add(turn);
      await turn.future;
    } else {
      _refundQueueHeld = true;
    }
    try {
      await action();
    } finally {
      if (_refundQueueWaiters.isEmpty) {
        _refundQueueHeld = false;
      } else {
        _refundQueueWaiters.removeFirst().complete();
      }
    }
  }

  /// Retries refunds and ad rewards that could not reach the server. The server only refunds debits younger than 10
  /// minutes. It keeps a reward request for good, so a reward retries for 24 hours.
  Future<void> retryPendingRefunds() async {
    if (!_canMutateCoins() || _pendingRetryInFlight) return;
    _pendingRetryInFlight = true;
    try {
      await _retryPendingEntries();
    } finally {
      _pendingRetryInFlight = false;
      _schedulePendingRetry();
    }
  }

  Future<void> _retryPendingEntries() async {
    await refundAbandonedDownload();
    final String userId = app_state.prismUser.id;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final List<Map<String, dynamic>> snapshot = <Map<String, dynamic>>[];
    await _withRefundQueueLock(() async => snapshot.addAll(_readPendingEntries()));
    final Set<String> resolvedKeys = <String>{};
    for (final Map<String, dynamic> entry in snapshot) {
      final String entryUser = entry['userId']?.toString() ?? '';
      final String key = _entryKey(entry);
      final bool isReward = _isRewardEntry(entry);
      final int atMs = parseIntOr(entry['atMs']);
      final Duration window = isReward ? _pendingRewardWindow : _refundWindow;
      if (key.isEmpty || nowMs - atMs > window.inMilliseconds) {
        if (key.isNotEmpty) resolvedKeys.add(key);
        continue;
      }
      if (entryUser != userId) continue;
      if (app_state.prismUser.id != userId || !_canMutateCoins()) break;
      final CoinMutationResult result;
      if (isReward) {
        result = await award(CoinEarnAction.rewardedAd, sourceTag: 'coins.reward.retry', requestId: key);
        if (result.changed) toasts.success('Your ad reward was added.');
      } else {
        final CoinSpendAction action =
            CoinSpendAction.values.asNameMap()[entry['action']?.toString()] ?? CoinSpendAction.aiGeneration;
        result = await refundSpend(
          action,
          sourceTag: 'coins.rollback.retry',
          transactionId: key,
          reason: entry['reason']?.toString() ?? 'ai_generation_failed_refund',
        );
        if (app_state.prismUser.id == userId &&
            action == CoinSpendAction.aiGeneration &&
            (result.changed || result.reason == 'already_refunded')) {
          analytics.track(
            AiChargeRolledBackEvent(
              chargeTransactionId: key,
              mode: AiChargeMode.coinSpend,
              coinsRefunded: result.delta,
              balance: app_state.prismUser.coins,
              sourceTag: 'coins.rollback.retry',
            ),
          );
        }
      }
      if (app_state.prismUser.id != userId) break;
      if (result.changed || !_isRetryableRefundFailure(result)) resolvedKeys.add(key);
    }
    await _withRefundQueueLock(() async {
      final List<Map<String, dynamic>> latest = _readPendingEntries();
      latest.removeWhere((Map<String, dynamic> e) => _entryKey(e).isEmpty || resolvedKeys.contains(_entryKey(e)));
      await _writePendingEntries(latest);
    });
  }

  void _schedulePendingRetry() {
    if (_pendingRetryTimer?.isActive ?? false) return;
    if (_readPendingEntries().isEmpty && !_hasAbandonedDownloads()) return;
    _pendingRetryTimer = Timer(pendingRetryInterval, () {
      _pendingRetryTimer = null;
      unawaited(retryPendingRefunds());
    });
  }

  /// Retries pending refunds and rewards when the app resumes, when the network returns and on a timer while the
  /// queue holds entries. Safe to call again.
  void startPendingRetryWatch() {
    if (!_observingLifecycle) {
      try {
        WidgetsBinding.instance.addObserver(this);
        _observingLifecycle = true;
      } catch (_) {
        // No widgets binding yet. The next call tries again.
      }
    }
    unawaited(_connectivitySubscription?.cancel());
    _connectivitySubscription = null;
    if (getIt.isRegistered<ConnectivityService>()) {
      _connectivitySubscription = getIt<ConnectivityService>().onConnectionChange.listen((bool online) {
        if (online) unawaited(retryPendingRefunds());
      });
    }
    _pendingRetryTimer?.cancel();
    _pendingRetryTimer = null;
    _schedulePendingRetry();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(retryPendingRefunds());
    unawaited(EconomyConfig.refreshIfStale());
  }

  Map<String, PendingDownload> _readPendingDownloads() {
    final Map<String, PendingDownload> ledger = <String, PendingDownload>{};
    if (!_settings.isOpen) return ledger;
    final String legacy = _settings.get<String>(_legacyPendingDownloadPrefKey, defaultValue: '');
    if (legacy.isNotEmpty) {
      try {
        final PendingDownload? migrated = PendingDownload.fromJson(jsonDecode(legacy));
        if (migrated != null) ledger[migrated.txId] = migrated.asLegacy();
      } on FormatException {
        // An unreadable marker holds nothing to refund. The next write removes it.
      }
    }
    for (final PendingDownload entry in PendingDownload.decodeList(
      _settings.get<String>(_pendingDownloadsPrefKey, defaultValue: ''),
    )) {
      ledger[entry.txId] = entry;
    }
    return ledger;
  }

  Future<void> _writePendingDownloads(Map<String, PendingDownload> ledger) async {
    if (ledger.isEmpty) {
      await _settings.delete(_pendingDownloadsPrefKey);
    } else {
      await _settings.set(_pendingDownloadsPrefKey, PendingDownload.encodeList(ledger.values));
    }
    await _settings.delete(_legacyPendingDownloadPrefKey);
  }

  /// Runs [change] on the ledger under the queue lock and saves the result when [change] returns true or an old
  /// marker still waits to move. Returns false when settings are closed or a read/write fails. [onPersisted] runs under
  /// the lock once the save went through, or at once when nothing needed saving. Failures are logged.
  Future<bool> _updatePendingDownloads(
    String sourceTag,
    bool Function(Map<String, PendingDownload> ledger) change, {
    VoidCallback? onPersisted,
  }) async {
    bool persisted = false;
    try {
      if (!_settings.isOpen) return false;
      await _withRefundQueueLock(() async {
        final Map<String, PendingDownload> ledger = _readPendingDownloads();
        final bool hasLegacyMarker = _settings.get<String>(_legacyPendingDownloadPrefKey, defaultValue: '').isNotEmpty;
        if (change(ledger) || hasLegacyMarker) await _writePendingDownloads(ledger);
        onPersisted?.call();
        persisted = true;
      });
      _scheduleDownloadRecovery();
    } catch (error, stackTrace) {
      logCoinError(sourceTag: sourceTag, error: error, stackTrace: stackTrace);
    }
    return persisted;
  }

  /// Marks the download paid by [txId] as saved. Call it as soon as the native save or enqueue reports success, so a
  /// crash from here on never leads to a refund. An unknown [txId] changes nothing. The id stays protected from
  /// recovery until the saved flag is stored.
  Future<void> markPendingDownloadSaved(String txId) async {
    await _updatePendingDownloads('coins.download.ledger_mark', (Map<String, PendingDownload> ledger) {
      final PendingDownload? entry = ledger[txId];
      if (entry == null || entry.saved) return false;
      ledger[txId] = entry.asSaved();
      return true;
    }, onPersisted: () => _liveDownloadTxIds.remove(txId));
  }

  /// Drops the download paid by [txId]. Call it once the download finished or its refund was confirmed. An unknown
  /// [txId] changes nothing. The id stays protected from recovery until the removal is stored.
  Future<void> clearPendingDownload(String txId) async {
    await _updatePendingDownloads(
      'coins.download.ledger_clear',
      (Map<String, PendingDownload> ledger) => ledger.remove(txId) != null,
      onPersisted: () => _liveDownloadTxIds.remove(txId),
    );
  }

  /// Ends the running status of the download paid by [txId] and starts a recovery pass. Call it when the tap that paid
  /// ends with no confirmed save and no confirmed refund. The stored entry stays, so recovery refunds it once it is
  /// older than [abandonedDownloadAfter].
  Future<void> releasePendingDownload(String txId) async {
    if (!_liveDownloadTxIds.remove(txId)) return;
    await refundAbandonedDownload();
  }

  /// Refunds the paid downloads that never finished, for example when the app closed mid-download. An entry waits
  /// [abandonedDownloadAfter] after its payment and is skipped while its tap still runs. A refund that may succeed on a later try keeps its entry for the
  /// retry loop.
  Future<void> refundAbandonedDownload() async {
    if (_downloadRecoveryInFlight) return;
    _downloadRecoveryInFlight = true;
    try {
      await _recoverPendingDownloads();
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.download.abandoned_refund', error: error, stackTrace: stackTrace);
    } finally {
      _downloadRecoveryInFlight = false;
      _scheduleDownloadRecovery();
      _schedulePendingRetry();
    }
  }

  Future<void> _recoverPendingDownloads() async {
    if (!_canMutateCoins() || !_settings.isOpen) return;
    final String userId = app_state.prismUser.id;
    final List<PendingDownload> snapshot = <PendingDownload>[];
    await _updatePendingDownloads('coins.download.ledger_read', (Map<String, PendingDownload> ledger) {
      snapshot.addAll(ledger.values.where((PendingDownload entry) => !_liveDownloadTxIds.contains(entry.txId)));
      return false;
    });
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    final Set<String> resolved = <String>{};
    for (final PendingDownload entry in snapshot) {
      if (entry.userId != userId) continue;
      if (entry.saved) {
        resolved.add(entry.txId);
        continue;
      }
      if (entry.remaining(nowMs, abandonedDownloadAfter) > Duration.zero) continue;
      if (entry.legacy) {
        final bool hasSavedNativeFile = await verifiedLegacyNativeDownloadCheck(entry.link);
        if (app_state.prismUser.id != userId || !_canMutateCoins()) break;
        if (hasSavedNativeFile) {
          resolved.add(entry.txId);
          continue;
        }
      }
      if (app_state.prismUser.id != userId || !_canMutateCoins()) break;
      final CoinMutationResult refund = await refundSpend(
        CoinSpendAction.values.asNameMap()[entry.action] ?? CoinSpendAction.wallpaperDownload,
        sourceTag: 'coins.download.abandoned_refund',
        transactionId: entry.txId,
        reason: 'download_failed_refund',
      );
      if (refund.changed) toasts.info('Your last download did not finish. Coins returned.');
      if (app_state.prismUser.id != userId) break;
      if (refund.changed || !_isRetryableRefundFailure(refund)) resolved.add(entry.txId);
    }
    if (resolved.isEmpty) return;
    await _updatePendingDownloads('coins.download.ledger_remove', (Map<String, PendingDownload> ledger) {
      final int before = ledger.length;
      ledger.removeWhere((String txId, PendingDownload _) => resolved.contains(txId));
      return ledger.length != before;
    });
  }

  /// Wakes the recovery when the soonest unsaved entry of the signed-in user comes of age. Entries that are of age
  /// already belong to the retry loop, so they never arm this timer.
  void _scheduleDownloadRecovery() {
    _downloadRecoveryTimer?.cancel();
    _downloadRecoveryTimer = null;
    if (!_canMutateCoins()) return;
    final String userId = app_state.prismUser.id;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    Duration? soonest;
    for (final PendingDownload entry in _readPendingDownloads().values) {
      if (entry.userId != userId || entry.saved) continue;
      final Duration wait = entry.remaining(nowMs, abandonedDownloadAfter);
      if (wait > Duration.zero && (soonest == null || wait < soonest)) soonest = wait;
    }
    if (soonest == null) return;
    _downloadRecoveryTimer = Timer(soonest, () {
      _downloadRecoveryTimer = null;
      unawaited(refundAbandonedDownload());
    });
  }

  bool _hasAbandonedDownloads() {
    if (!_canMutateCoins()) return false;
    final String userId = app_state.prismUser.id;
    final int nowMs = DateTime.now().millisecondsSinceEpoch;
    return _readPendingDownloads().values.any(
      (PendingDownload entry) =>
          entry.userId == userId &&
          !entry.saved &&
          !_liveDownloadTxIds.contains(entry.txId) &&
          entry.remaining(nowMs, abandonedDownloadAfter) == Duration.zero,
    );
  }

  void commitAiGenerationReservation({
    required AiChargeMode mode,
    required int coinsSpent,
    String? operationId,
    String? chargeTransactionId,
    String sourceTag = 'coins.commit.ai_generation',
  }) {
    analytics.track(
      AiChargeCommittedEvent(
        operationId: operationId,
        chargeTransactionId: chargeTransactionId,
        mode: mode,
        coinsSpent: coinsSpent,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
      ),
    );
  }

  Future<bool> hasPremiumPreviewAccessForCollection(String collectionKey) async {
    final String normalizedKey = _normalizeCollectionKey(collectionKey);
    if (normalizedKey.isEmpty) {
      return false;
    }
    if (premiumContentUnlocked) {
      return true;
    }
    if (!_canMutateCoins()) {
      return false;
    }
    final String userId = app_state.prismUser.id;
    final Map<String, dynamic>? userData = await firestoreClient.getById<Map<String, dynamic>>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data,
      sourceTag: 'coins.preview.check',
    );
    if (userData == null) {
      return false;
    }
    final bool isPremium = _isPremiumUserData(userData);
    if (isPremium) {
      return true;
    }
    final Map<String, int> previewUnlocks = _previewUnlocksFromState(toJsonMap(userData[_coinStateField]));
    return (previewUnlocks[normalizedKey] ?? 0) > DateTime.now().millisecondsSinceEpoch;
  }

  Future<CoinMutationResult> unlockPremiumPreview24hForCollection({
    required String collectionKey,
    String sourceTag = 'coins.preview.unlock',
  }) async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final String normalizedKey = _normalizeCollectionKey(collectionKey);
    if (normalizedKey.isEmpty) {
      return CoinMutationResult.noChange(
        balance: app_state.prismUser.coins,
        success: false,
        reason: 'invalid_collection_key',
      );
    }
    final String userId = app_state.prismUser.id;
    final bool hasAccess = await hasPremiumPreviewAccessForCollection(normalizedKey);
    if (!_canMutateCoins() || userId != app_state.prismUser.id) return _notLoggedIn;
    if (hasAccess) {
      return CoinMutationResult.noChange(
        balance: app_state.prismUser.coins,
        reason: 'premium_preview_already_unlocked',
      );
    }
    // The server charges and writes the unlock in one transaction; the client never writes coinState.
    const String reason = 'premium_preview_unlock_24h';
    final CoinMutationResult result;
    try {
      final HttpsCallableResult<dynamic> response = await appFunctions.httpsCallable('unlockPremiumPreview').call(
        <String, dynamic>{'collectionKey': normalizedKey, 'sourceTag': sourceTag, 'pricingVersion': 2},
      );
      if (!_canMutateCoins() || userId != app_state.prismUser.id) return _notLoggedIn;
      final Map<String, dynamic> data = toJsonMap(response.data);
      result = CoinMutationResult(
        success: data['success'] == true,
        changed: data['changed'] == true,
        bypassed: data['bypassed'] == true,
        insufficientBalance: data['insufficientBalance'] == true,
        previousBalance: parseIntOr(data['previousBalance']),
        currentBalance: parseIntOr(data['currentBalance']),
        delta: parseIntOr(data['delta']),
        reason: data['reason']?.toString() ?? reason,
        transactionId: data['transactionId']?.toString() ?? '',
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      logCoinError(sourceTag: '$sourceTag.callable', error: error, stackTrace: stackTrace);
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: error.code);
    }
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    return result;
  }

  Future<CoinMutationResult> claimDailyLoginAndStreakIfEligible() async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final int previousBalance = app_state.prismUser.coins;
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final int timezoneOffsetMinutes = _deviceTimezoneOffsetMinutes();
    final bool reminderEnabled = _preferredStreakReminderEnabled();
    try {
      final HttpsCallable callable = appFunctions.httpsCallable(
        'claimDailyStreak',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 20)),
      );
      final HttpsCallableResult<dynamic> response = await callable.call(<String, dynamic>{
        'timezoneOffsetMinutes': timezoneOffsetMinutes,
        'reminderEnabled': reminderEnabled,
      });
      if (!_isCurrentOwner(userId, generation)) return _notLoggedIn;
      final Map<String, dynamic> payload = toJsonMap(response.data);
      final StreakClaimResult result = StreakClaimResult.fromPayload(payload);
      final bool claimed = result.claimed;
      final int streakDay = result.streakDay;
      final int dailyReward = result.dailyReward;
      final int streakBonusReward = result.streakBonusReward;
      final int totalReward = result.totalReward;
      final int newBalance = result.newBalance;
      final int effectiveTimezoneOffset =
          parseInt(payload['timezoneOffsetMinutes']) ??
          (streakNotifier.value.lastClaimDate.isNotEmpty
              ? streakNotifier.value.timezoneOffsetMinutes
              : timezoneOffsetMinutes);
      final String todayLocalKey = (payload['todayLocalKey']?.toString() ?? '').trim();
      final int? nextReminderAtUtcMillis = payload['nextReminderAtUtcMillis'] == null
          ? null
          : parseIntOr(payload['nextReminderAtUtcMillis']);
      final int delta = newBalance - previousBalance;

      _applyLocalBalance(newBalance, delta: delta);
      streakNotifier.value = StreakStatus(
        streakDay: streakDay,
        count: result.streakCount,
        best: result.streakBest,
        freezes: result.freezesLeft,
        active: result.streakCount > 0,
        claimedToday: claimed || result.alreadyClaimedToday,
        reminderEnabled: reminderEnabled,
        timezoneOffsetMinutes: effectiveTimezoneOffset,
        lastClaimDate: todayLocalKey,
        nextReminderAtUtc: nextReminderAtUtcMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(nextReminderAtUtcMillis, isUtc: true),
      );
      if (claimed) _grantLocalXp(_xpForCoins(totalReward));
      if (claimed && _publishedClaimDays.add((userId, todayLocalKey))) {
        for (final event in result.lifecycleEvents) {
          analytics.track(event);
        }
        _pendingClaimUserId = userId;
        lastClaimNotifier.value = result;
      }

      if (claimed) {
        String dailyReason = 'daily_login';
        if (streakDay >= 3 && streakDay <= 6) {
          dailyReason = 'streak_mid_cycle_day_$streakDay';
        } else if (streakDay == 7) {
          dailyReason = 'streak_day_7_daily';
        }
        if (dailyReward > 0) {
          _logEarn(
            action: CoinEarnAction.dailyLogin,
            amount: dailyReward,
            sourceTag: 'coins.claim_daily_and_streak',
            reason: dailyReason,
          );
        }
        if (streakBonusReward > 0) {
          _logEarn(
            action: CoinEarnAction.streakBonus,
            amount: streakBonusReward,
            sourceTag: 'coins.claim_daily_and_streak',
            reason: 'streak_day_7_bonus',
          );
        }
      }

      return CoinMutationResult(
        success: true,
        changed: claimed,
        previousBalance: previousBalance,
        currentBalance: newBalance,
        delta: totalReward > 0 ? totalReward : delta,
        reason: claimed ? 'daily_login' : 'daily_already_claimed',
      );
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.claim_daily_and_streak.callable', error: error, stackTrace: stackTrace);
      if (_canMutateCoins() && userId == app_state.prismUser.id) await refreshStreakStatus();
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'callable_failed');
    }
  }

  Future<StreakFreezePurchase> buyStreakFreeze() async {
    if (!_canMutateCoins()) {
      return const StreakFreezePurchase(StreakFreezeOutcome.failed, message: 'not_logged_in');
    }
    final String userId = app_state.prismUser.id;
    final SettingsLocalDataSource settings = _settings;
    if (_pendingFreezeUserId != userId) _pendingFreezeRequestId = null;
    _pendingFreezeUserId = userId;
    final String pendingKey = 'pendingStreakFreezeRequest.$userId';
    final String persistedRequest = settings.isOpen ? settings.get<String>(pendingKey, defaultValue: '') : '';
    if (_pendingFreezeRequestId == null && persistedRequest.isNotEmpty) _pendingFreezeRequestId = persistedRequest;
    final String requestId = _pendingFreezeRequestId ??= _newRequestId();
    Future<void> clearPending() async {
      if (_pendingFreezeRequestId == requestId) _pendingFreezeRequestId = null;
      if (settings.isOpen && settings.get<String>(pendingKey, defaultValue: '') == requestId) {
        await settings.delete(pendingKey);
      }
    }

    try {
      if (settings.isOpen) await settings.set(pendingKey, requestId);
      if (!_canMutateCoins() || userId != app_state.prismUser.id) {
        return const StreakFreezePurchase(StreakFreezeOutcome.failed, message: 'session_changed');
      }
      final HttpsCallable callable = appFunctions.httpsCallable('buyStreakFreeze');
      final HttpsCallableResult<dynamic> response = await callable.call(<String, dynamic>{'requestId': requestId});
      final Map<String, dynamic> data = toJsonMap(response.data);
      if (_asBool(data['success']) || _asBool(data['atCap']) || _asBool(data['insufficientBalance'])) {
        await clearPending();
      }
      if (!_canMutateCoins() || userId != app_state.prismUser.id) {
        return const StreakFreezePurchase(StreakFreezeOutcome.failed, message: 'session_changed');
      }
      final int freezes = _clampFreezes(parseIntOr(data['streakFreezes']));
      _applyLocalBalance(parseIntOr(data['currentBalance']), delta: parseIntOr(data['delta']));
      streakNotifier.value = streakNotifier.value.copyWith(freezes: freezes);
      if (_asBool(data['atCap'])) {
        return StreakFreezePurchase(StreakFreezeOutcome.atCap, freezes: freezes);
      }
      if (_asBool(data['insufficientBalance'])) {
        return StreakFreezePurchase(StreakFreezeOutcome.insufficientBalance, freezes: freezes);
      }
      if (_asBool(data['success'])) {
        if (_asBool(data['changed'])) {
          _logSpend(
            action: CoinSpendAction.streakFreeze,
            amount: CoinPolicy.streakFreezeCost,
            sourceTag: 'coins.buy_streak_freeze',
          );
        }
        if (_asBool(data['changed'])) {
          analytics.track(
            StreakLifecycleEvent(
              action: 'freeze_purchased',
              streakCount: streakNotifier.value.count,
              coins: CoinPolicy.streakFreezeCost,
              freezesLeft: freezes,
              result: 'success',
            ),
          );
        }
        return StreakFreezePurchase(StreakFreezeOutcome.success, freezes: freezes);
      }
      return StreakFreezePurchase(
        StreakFreezeOutcome.failed,
        freezes: freezes,
        message: data['reason']?.toString() ?? '',
      );
    } on FirebaseFunctionsException catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.buy_streak_freeze.callable', error: error, stackTrace: stackTrace);
      if (error.code == 'not-found' || error.code == 'unimplemented') {
        await clearPending();
        return StreakFreezePurchase(StreakFreezeOutcome.unavailable, message: error.code);
      }
      return StreakFreezePurchase(StreakFreezeOutcome.failed, message: error.message ?? error.code);
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.buy_streak_freeze.callable', error: error, stackTrace: stackTrace);
      return const StreakFreezePurchase(StreakFreezeOutcome.failed);
    }
  }

  String _newRequestId() {
    final Random random = Random.secure();
    final String suffix = List<String>.generate(16, (_) => random.nextInt(36).toRadixString(36)).join();
    return '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}$suffix';
  }

  int _clampFreezes(int n) => n.clamp(0, CoinPolicy.maxStreakFreezes);

  int _streakCount(Map<String, dynamic> coinState, int streakDay) {
    final int count = parseIntOr(coinState['streakCount']);
    return count > 0 ? count : streakDay;
  }

  Future<CoinMutationResult> maybeAwardProfileCompletion() {
    if (!_canMutateCoins()) {
      return Future.value(_notLoggedIn);
    }
    if (!_isProfileComplete()) {
      return Future.value(
        CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'profile_incomplete'),
      );
    }
    return _awardFixed(
      CoinEarnAction.profileCompletion,
      sourceTag: 'coins.profile_completion',
      reason: 'profile_completion',
    );
  }

  Future<CoinMutationResult> maybeAwardFirstWallpaperUpload() {
    return _awardFixed(
      CoinEarnAction.firstWallpaperUpload,
      sourceTag: 'coins.first_wallpaper_upload',
      reason: 'first_wallpaper_upload',
    );
  }

  Future<CoinMutationResult> processPendingReferralIfEligible({String? inviterUserId}) async {
    if (inviterUserId != null && inviterUserId.trim().isNotEmpty) {
      await setPendingReferralInviterId(inviterUserId);
    }
    if (!_canMutateCoins()) {
      if (pendingReferralInviterId?.isNotEmpty ?? false) {
        analytics.track(const ReferralResultEvent(outcome: 'ineligible', role: 'referee', reason: 'not_logged_in'));
      }
      return _notLoggedIn;
    }
    final String currentUserId = app_state.prismUser.id;
    final String? pendingInviter = pendingReferralInviterId;
    if (pendingInviter == null || pendingInviter.isEmpty) {
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'no_pending_referral');
    }
    if (pendingInviter == currentUserId) {
      analytics.track(const ReferralResultEvent(outcome: 'skipped', role: 'referee', reason: 'self_referral'));
      await clearPendingReferralInviterId();
      return CoinMutationResult.noChange(balance: app_state.prismUser.coins, reason: 'self_referral');
    }

    final CoinMutationResult result = await _awardFixed(
      CoinEarnAction.referral,
      sourceTag: 'coins.process_referral',
      reason: pendingInviter,
      logReason: 'referee_reward',
      callableName: 'processReferral',
      inviterUserId: pendingInviter,
    );
    analytics.track(
      ReferralResultEvent(
        operationId: _newRequestId(),
        outcome: result.changed
            ? 'success'
            : result.reason == 'referral_inviter_daily_limit'
            ? 'retry_pending'
            : result.success
            ? 'skipped'
            : 'retry_pending',
        role: 'referee',
        reason:
            const <String>{
              'referral_already_processed',
              'referral_caller_not_new',
              'referral_inviter_not_older',
              'referral_inviter_lifetime_limit',
              'referral_inviter_daily_limit',
              'referral_inviter_not_found',
              'not_logged_in',
              'unauthenticated',
              'permission-denied',
              'unavailable',
              'deadline-exceeded',
              'resource-exhausted',
              'callable_failed',
            }.contains(result.reason)
            ? result.reason
            : result.changed
            ? 'confirmed'
            : 'unknown',
        referralId: result.transactionId.isEmpty ? null : result.transactionId,
        referrerId: pendingInviter.contains('@') ? null : pendingInviter,
        refereeId: currentUserId.contains('@') ? null : currentUserId,
      ),
    );
    if (result.changed ||
        const <String>{
          'referral_already_processed',
          'referral_caller_not_new',
          'referral_inviter_not_older',
          'referral_inviter_lifetime_limit',
        }.contains(result.reason)) {
      await clearPendingReferralInviterId();
    }
    return result;
  }

  Future<CoinMutationResult> _awardFixed(
    CoinEarnAction action, {
    required String sourceTag,
    required String reason,
    String? logReason,
    String callableName = 'awardCoins',
    String? inviterUserId,
  }) async {
    if (!_canMutateCoins()) {
      return _notLoggedIn;
    }
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final CoinMutationResult result = await _callCoinMutation(
      userId: userId,
      callableName: callableName,
      amount: action.defaultAmount(),
      action: action.name,
      sourceTag: sourceTag,
      reason: reason,
      inviterUserId: inviterUserId,
    );
    if (!_isCurrentOwner(userId, generation)) return _notLoggedIn;
    _applyLocalBalance(result.currentBalance, delta: result.delta);
    if (result.changed) {
      final CoinEarnFlags flags = earnFlagsNotifier.value;
      if (action == CoinEarnAction.firstWallpaperUpload) {
        earnFlagsNotifier.value = CoinEarnFlags(
          firstUploadRewarded: true,
          profileCompletionRewarded: flags.profileCompletionRewarded,
        );
      } else if (action == CoinEarnAction.profileCompletion) {
        earnFlagsNotifier.value = CoinEarnFlags(
          firstUploadRewarded: flags.firstUploadRewarded,
          profileCompletionRewarded: true,
        );
      }
      _logEarn(action: action, amount: result.delta, sourceTag: sourceTag, reason: logReason);
      unawaited(reconcileRankRewards());
    }
    return result;
  }

  // Coin economy v2: private economy state, quests, spin, shop, drops, boosts, gifts, draw.

  Future<_PrivateEconomyRead> _readPrivateEconomy(String userId) async {
    try {
      final Map<String, dynamic>? data = await firestoreClient.getFromServer<Map<String, dynamic>>(
        FirebaseCollections.userPrivate(userId),
        'economy',
        (data, _) => data,
        sourceTag: 'coins.private_economy',
      );
      return _PrivateEconomyRead(data, authoritativeMissing: data == null);
    } on FirestoreError catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.private_economy', error: error, stackTrace: stackTrace);
      return const _PrivateEconomyRead(null);
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.private_economy', error: error, stackTrace: stackTrace);
      return const _PrivateEconomyRead(null);
    }
  }

  void _resetEconomy(String userId, {bool resetXp = true}) {
    _economyUserId = userId;
    if (resetXp) {
      _xpUserId = '';
      _confirmedXp = XpStatus.empty();
      _confirmedXpWeek = '';
      _xpMutationGeneration++;
      xpNotifier.value = XpStatus.empty();
    }
    _economyRev = -1;
    _graceDownloadsUsed = 0;
    _adsTodayDay = null;
    _adsTodayCount = 0;
    questsNotifier.value = null;
    questAwardsNotifier.value = const <QuestAward>[];
    inventoryNotifier.value = Inventory.empty;
    dropsUnlockedNotifier.value = const <String, DropUnlock>{};
    passesNotifier.value = Passes.empty;
  }

  void _ensureEconomyUser(String userId) {
    if (_economyUserId != userId) _resetEconomy(userId);
  }

  /// Social fields on the root doc: XP, equipped cosmetics, today's ad count.
  void _syncRootEconomy(Map<String, dynamic> userData, Map<String, dynamic> coinState, {bool syncXp = true}) {
    final String userId = app_state.prismUser.id;
    _syncRootProjection(userId, userData, syncXp: syncXp);
    final Map<String, dynamic> adsToday = toJsonMap(coinState['adsToday']);
    final String? day = _optionalString(adsToday['day']);
    if (day != null) {
      _adsTodayDay = day;
      _adsTodayCount = parseIntOr(adsToday['count']);
    }
  }

  void _syncRootProjection(String userId, Map<String, dynamic> userData, {bool syncXp = true}) {
    _ensureEconomyUser(userId);
    if (syncXp) {
      _confirmXp(userData, announce: _xpUserId == userId);
      _xpUserId = userId;
    }
    final Map<String, dynamic> cosmetics = toJsonMap(userData['cosmetics']);
    inventoryNotifier.value = inventoryNotifier.value.withEquipped(
      frame: _optionalString(cosmetics['frame']),
      nameGlow: _optionalString(cosmetics['nameGlow']),
    );
  }

  /// Owner-only state from `usersv2/{uid}/private/economy`. A doc older than the state already held is ignored.
  void _syncPrivateEconomy(String userId, Map<String, dynamic>? data) {
    _ensureEconomyUser(userId);
    if (data == null) return;
    final int rev = parseIntOr(data['rev'], fallback: 0);
    if (rev < _economyRev) return;
    _economyRev = rev;
    questsNotifier.value = QuestState.fromMap(data['quests']);
    final Object? rawOwned = toJsonMap(data['inventory'])['owned'];
    final Set<String> owned = rawOwned is List
        ? rawOwned.whereType<String>().toSet()
        : toJsonMap(rawOwned).keys.toSet();
    inventoryNotifier.value = inventoryNotifier.value.withOwned(Set<String>.unmodifiable(owned));
    final Map<String, DropUnlock> unlocked = <String, DropUnlock>{};
    toJsonMap(toJsonMap(data['drops'])['unlocked']).forEach((String wallId, Object? raw) {
      final Map<String, dynamic> entry = toJsonMap(raw);
      unlocked[wallId] = DropUnlock(
        wallId: wallId,
        weekKey: entry['weekKey']?.toString() ?? '',
        url: entry['url']?.toString() ?? '',
      );
    });
    dropsUnlockedNotifier.value = Map<String, DropUnlock>.unmodifiable(unlocked);
    passesNotifier.value = Passes.fromMap(data['passes']);
    _graceDownloadsUsed = max(0, parseIntOr(data['graceDownloadsUsed']));
  }

  void _setXp(XpStatus next, {required bool announce}) {
    final XpStatus previous = xpNotifier.value;
    xpNotifier.value = next;
    if (announce && next.rank.min > previous.rank.min) {
      analytics.track(RankUpEvent(rank: next.rank.id, xp: next.xp));
    }
  }

  void _grantLocalXp(int xp) {
    if (xp <= 0) return;
    final String userId = app_state.prismUser.id;
    _ensureEconomyUser(userId);
    _xpMutationGeneration++;
    _economyMutationGeneration++;
    _setXp(xpNotifier.value.plus(xp), announce: _xpUserId == userId);
    unawaited(reconcileRankRewards());
  }

  /// Repairs rank ownership on normal refresh and after XP awards. Concurrent requests for this session share a
  /// call; work that arrives while it runs requests another pass so a later XP award cannot be missed.
  Future<void> reconcileRankRewards() {
    if (!_canMutateCoins()) return Future<void>.value();
    final String userId = app_state.prismUser.id;
    _ensureEconomyUser(userId);
    final int generation = _economySessionGeneration;
    final (String, int) key = (userId, generation);
    _rankRewardSyncRequested.add(key);
    final Future<void>? running = _rankRewardSyncs[key];
    if (running != null) return running;
    final Future<void> request = _reconcileRankRewards(userId, generation, key);
    _rankRewardSyncs[key] = request;
    return request;
  }

  Future<void> _reconcileRankRewards(String userId, int generation, (String, int) key) async {
    try {
      do {
        _rankRewardSyncRequested.remove(key);
        final int xpGeneration = _xpMutationGeneration;
        final _EconomyReply? reply = await _callEconomy(
          'reconcileRankRewards',
          const <String, Object?>{},
          userId: userId,
          sourceTag: 'coins.rank_rewards.reconcile',
          timeout: const Duration(seconds: 10),
        );
        if (!_isCurrentOwner(userId, generation)) return;
        if (reply != null && reply.success && !reply.stale && reply.data['xp'] is num) {
          if (_xpMutationGeneration == xpGeneration) {
            _confirmXp(reply.data, announce: false, protectReads: true);
            final XpStatus xp = xpNotifier.value;
            await _persistRootEconomySnapshot(userId, <String, dynamic>{
              'xp': xp.xp,
              'xpWeek': <String, Object?>{'weekKey': economyWeekKey(DateTime.now()), 'xp': xp.weekXp},
            }, merge: true);
            if (!_isCurrentOwner(userId, generation)) return;
          } else {
            _rankRewardSyncRequested.add(key);
          }
        }
      } while (_rankRewardSyncRequested.contains(key));
    } finally {
      _rankRewardSyncRequested.remove(key);
      _rankRewardSyncs.remove(key);
    }
  }

  bool _staleEconomyReply(Map<String, dynamic> data) {
    final int? revision = parseInt(data['rev']);
    return revision != null && revision < _economyRev;
  }

  void _confirmXp(Map<String, dynamic> data, {required bool announce, bool protectReads = false}) {
    final XpStatus received = XpStatus.fromUserData(data);
    final String week = economyWeekKey(DateTime.now());
    final int xp = max(_confirmedXp.xp, received.xp);
    final int weekXp = max(_confirmedXpWeek == week ? _confirmedXp.weekXp : 0, received.weekXp);
    _confirmedXp = XpStatus(xp: xp, weekXp: weekXp, rank: EconomyConfig.current.rankFor(xp));
    _confirmedXpWeek = week;
    final XpStatus previous = xpNotifier.value;
    if (protectReads && (previous.xp != xp || previous.weekXp != weekXp)) _xpMutationGeneration++;
    _setXp(_confirmedXp, announce: announce);
  }

  Future<void> _patchInventoryReply(String userId, Map<String, dynamic> data) async {
    final Object? rawOwned = data['owned'];
    if (rawOwned is! List || _staleEconomyReply(data)) return;
    final Set<String> owned = Set<String>.unmodifiable(rawOwned.whereType<String>());
    final Set<String> previous = inventoryNotifier.value.owned;
    final bool changed = owned.length != previous.length || !owned.containsAll(previous);
    final int? revision = parseInt(data['rev']);
    if (revision != null) _economyRev = revision;
    if (changed || data['inventoryChanged'] == true) _economyMutationGeneration++;
    inventoryNotifier.value = inventoryNotifier.value.withOwned(owned);
    await _persistEconomy(userId, <String, dynamic>{
      'rev': max(0, _economyRev),
      'inventory': <String, Object?>{'owned': owned.toList()},
    });
  }

  int _xpForCoins(int coins) => max(0, (coins * EconomyConfig.current.xp.perCoinEarned).round());

  /// Mirrors the server, which ticks the ad and spin bonus quests inside the ad credit and the spin.
  void _markBonusQuestDone(QuestEvent event) {
    final QuestState? quests = questsNotifier.value;
    final QuestItem? bonus = quests?.bonus;
    if (quests == null || bonus == null || bonus.event != event || bonus.claimed) return;
    if (quests.dayKey != economyDayKey(DateTime.now())) return;
    questsNotifier.value = quests.withBonus(
      QuestItem(id: bonus.id, event: bonus.event, target: bonus.target, progress: bonus.target, claimed: true),
    );
  }

  void _noteAdWatched() {
    _ensureEconomyUser(app_state.prismUser.id);
    final String today = _utcDayKey();
    _adsTodayCount = _adsTodayDay == today ? _adsTodayCount + 1 : 1;
    _adsTodayDay = today;
  }

  /// Local mirror of what a spend wrote on the server: grace downloads and passes.
  Future<void> _applySpendState(
    String userId,
    CoinSpendAction action,
    CoinMutationResult result, {
    String? styleId,
  }) async {
    if (!result.success) return;
    _ensureEconomyUser(userId);
    final int? graceLeft = result.graceDownloadsLeft;
    if (graceLeft != null) _graceDownloadsUsed = max(0, CoinPolicy.graceDownloads - graceLeft);
    final DateTime? until = result.passUntil;
    if (until == null) {
      await _persistEconomy(userId, <String, dynamic>{'graceDownloadsUsed': _graceDownloadsUsed});
      return;
    }
    final Passes passes = passesNotifier.value;
    if (action == CoinSpendAction.autoRotatePass7d) {
      passesNotifier.value = passes.copyWith(autoRotatePassUntil: until);
    } else if (action == CoinSpendAction.liveWallpaperStyle && styleId != null) {
      passesNotifier.value = passes.copyWith(
        liveStyles: Map<String, DateTime>.unmodifiable(<String, DateTime>{...passes.liveStyles, styleId: until}),
      );
    }
    await _persistEconomy(userId, <String, dynamic>{
      'passes': <String, Object?>{
        'premiumPassUntil': passesNotifier.value.premiumPassUntil?.millisecondsSinceEpoch,
        'autoRotatePassUntil': passesNotifier.value.autoRotatePassUntil?.millisecondsSinceEpoch,
        'liveStyles': <String, int>{
          for (final MapEntry<String, DateTime> entry in passesNotifier.value.liveStyles.entries)
            entry.key: entry.value.millisecondsSinceEpoch,
        },
      },
      'graceDownloadsUsed': _graceDownloadsUsed,
    });
  }

  static DateTime? _msToUtc(Object? raw) {
    final int ms = parseIntOr(raw);
    return ms > 0 ? DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true) : null;
  }

  static String? _optionalString(Object? raw) => raw is String && raw.trim().isNotEmpty ? raw.trim() : null;

  /// Calls an economy callable. Returns null when the session changed before the reply.
  Future<_EconomyReply?> _callEconomy(
    String name,
    Map<String, Object?> params, {
    required String userId,
    required String sourceTag,
    Duration? timeout,
  }) async {
    _ensureEconomyUser(userId);
    final int generation = _economySessionGeneration;
    try {
      final HttpsCallable callable = appFunctions.httpsCallable(
        name,
        options: timeout == null ? null : HttpsCallableOptions(timeout: timeout),
      );
      final HttpsCallableResult<dynamic> response = await callable.call(<String, Object?>{
        ...params,
        'sourceTag': sourceTag,
      });
      if (!_isCurrentOwner(userId, generation)) return null;
      final Map<String, dynamic> data = toJsonMap(response.data);
      final bool shopSuccess = name == 'purchaseShopItem' && data['success'] == true;
      if (_staleEconomyReply(data)) {
        if (shopSuccess) unawaited(_refreshShopBalance(userId, generation));
        return _EconomyReply(data, stale: true);
      }
      final bool shopReplay = shopSuccess && data['reason'] == 'duplicate';
      if (!shopReplay && data['currentBalance'] is num) {
        _applyLocalBalance(parseIntOr(data['currentBalance']), delta: parseIntOr(data['delta']));
      }
      if (!_isCurrentOwner(userId, generation)) return null;
      await _patchInventoryReply(userId, data);
      if (!_isCurrentOwner(userId, generation)) return null;
      if (shopReplay) unawaited(_refreshShopBalance(userId, generation));
      return _EconomyReply(data, stale: _staleEconomyReply(data));
    } on FirebaseFunctionsException catch (error, stackTrace) {
      logCoinError(sourceTag: '$sourceTag.callable', error: error, stackTrace: stackTrace);
      if (!_isCurrentOwner(userId, generation)) return null;
      return _EconomyReply(<String, dynamic>{'success': false, 'reason': error.code}, errorCode: error.code);
    } catch (error, stackTrace) {
      logCoinError(sourceTag: '$sourceTag.callable', error: error, stackTrace: stackTrace);
      if (!_isCurrentOwner(userId, generation)) return null;
      return const _EconomyReply(<String, dynamic>{'success': false, 'reason': 'unknown'}, errorCode: 'unknown');
    }
  }

  Future<void> _refreshShopBalance(String userId, int generation) async {
    if (!_isCurrentOwner(userId, generation)) return;
    try {
      await refreshBalance();
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.shop.balance_refresh', error: error, stackTrace: stackTrace);
    }
  }

  /// Calls a paid economy callable with a request id stored until a definite answer, so a retry after a crash or a
  /// lost reply replays the same purchase instead of paying twice. [scope] names the thing bought.
  Future<_EconomyReply?> _economyPurchase(
    String name,
    String scope,
    Map<String, Object?> params, {
    required String sourceTag,
  }) async {
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final String key = 'pendingEconomyRequest.$name.$scope.$userId';
    final SettingsLocalDataSource settings = _settings;
    final String stored = settings.isOpen ? settings.get<String>(key, defaultValue: '') : '';
    final String requestId = _pendingEconomyRequests[key] ??= stored.isNotEmpty ? stored : _newRequestId();
    if (settings.isOpen) await settings.set(key, requestId);
    if (!_isCurrentOwner(userId, generation)) return null;
    _EconomyReply? reply = await _callEconomy(
      name,
      <String, Object?>{...params, 'requestId': requestId},
      userId: userId,
      sourceTag: sourceTag,
    );
    if (!_isCurrentOwner(userId, generation)) return null;
    if (reply != null && _staleEconomyReply(reply.data)) reply = _EconomyReply(reply.data, stale: true);
    final int? revision = parseInt(reply?.data['rev']);
    if (revision != null && revision > _economyRev) _economyRev = revision;
    if (reply?.success == true && reply?.changed == true && reply?.stale == false) _economyMutationGeneration++;
    if (reply != null && reply.definite) {
      if (_pendingEconomyRequests[key] == requestId) _pendingEconomyRequests.remove(key);
      if (settings.isOpen && settings.get<String>(key, defaultValue: '') == requestId) {
        await settings.delete(key);
        if (!_isCurrentOwner(userId, generation)) return null;
      }
    }
    if (reply != null && _staleEconomyReply(reply.data)) {
      return _EconomyReply(reply.data, stale: true);
    }
    return reply;
  }

  void _applyQuestReply(Map<String, dynamic> data) {
    final int? rev = parseInt(data['rev']);
    if (rev != null && rev < _economyRev) return;
    if (rev != null) _economyRev = rev;
    if (data.containsKey('quests')) questsNotifier.value = QuestState.fromMap(data['quests']);
  }

  /// Reports a quest [event] (null syncs only) and refreshes [questsNotifier]. Paid items land in
  /// [questAwardsNotifier]. Never throws. Only [QuestEvent.clientReported] events are sent; the server counts the rest.
  Future<QuestState?> progressQuest(QuestEvent? event) async {
    if (!_canMutateCoins()) return null;
    if (event != null && !event.clientReported) return questsNotifier.value;
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    _ensureEconomyUser(userId);
    final _EconomyReply? reply = await _callEconomy(
      'progressQuest',
      <String, Object?>{if (event != null) 'event': event.wireValue, if (event != null) 'eventId': _newRequestId()},
      userId: userId,
      sourceTag: 'coins.quests.progress',
      timeout: const Duration(seconds: 10),
    );
    if (!_isCurrentOwner(userId, generation)) return null;
    if (reply == null || reply.errorCode != null) return questsNotifier.value;
    bool stale = reply.stale || _staleEconomyReply(reply.data);
    if (!stale && reply.success && reply.data.containsKey('quests')) _economyMutationGeneration++;
    if (!stale) _applyQuestReply(reply.data);
    if (!stale && reply.data.containsKey('quests')) {
      await _persistEconomy(userId, <String, dynamic>{'rev': _economyRev, 'quests': reply.data['quests']});
      if (!_isCurrentOwner(userId, generation)) return null;
      stale = _staleEconomyReply(reply.data);
    }
    final Object? rawAwards = reply.data['awarded'];
    final List<QuestAward> awards = <QuestAward>[
      if (rawAwards is List)
        for (final Object? raw in rawAwards)
          if (toJsonMap(raw)['id'] is String)
            QuestAward(
              id: toJsonMap(raw)['id'] as String,
              coins: parseIntOr(toJsonMap(raw)['coins']),
              xp: parseIntOr(toJsonMap(raw)['xp']),
            ),
    ];
    if (awards.isNotEmpty) {
      questAwardsNotifier.value = List<QuestAward>.unmodifiable(<QuestAward>[...questAwardsNotifier.value, ...awards]);
      for (final QuestAward award in awards) {
        analytics.track(QuestCompletedEvent(questId: award.id, coins: award.coins, xp: award.xp));
      }
      if (!stale) _grantLocalXp(awards.fold<int>(0, (int sum, QuestAward a) => sum + a.xp));
      if (stale) unawaited(reconcileRankRewards());
    }
    return questsNotifier.value;
  }

  /// Fire-and-forget quest report for UI code. A no-op for guests and for events the server counts itself.
  void reportQuestEvent(QuestEvent event) {
    if (!_canMutateCoins() || !event.clientReported) return;
    try {
      unawaited(progressQuest(event));
    } catch (error, stackTrace) {
      logCoinError(sourceTag: 'coins.quests.report', error: error, stackTrace: stackTrace);
    }
  }

  /// The Pro daily spin. The server picks the segment.
  Future<ProSpinResult> claimProSpin() async {
    if (!_canMutateCoins()) return const ProSpinResult(ProSpinOutcome.failed, reason: 'not_logged_in');
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final _EconomyReply? reply = await _economyPurchase(
      'claimProSpin',
      'daily',
      const <String, Object?>{},
      sourceTag: 'coins.pro_spin',
    );
    if (!_isCurrentOwner(userId, generation) || reply == null) {
      return const ProSpinResult(ProSpinOutcome.failed, reason: 'session_changed');
    }
    final String reason = reply.reason;
    if (!reply.success) {
      return ProSpinResult(switch (reason) {
        'pro_spin_already_claimed' => ProSpinOutcome.alreadyClaimed,
        'pro_spin_requires_premium' => ProSpinOutcome.notPro,
        _ => ProSpinOutcome.failed,
      }, reason: reason);
    }
    final int coins = parseIntOr(reply.data['coins']);
    final int segment = parseIntOr(reply.data['segment'], fallback: -1);
    if (reply.changed) {
      analytics.track(ProSpinClaimedEvent(coins: coins, segment: segment));
      _logEarn(action: CoinEarnAction.proSpin, amount: coins, sourceTag: 'coins.pro_spin');
      if (!reply.stale) _grantLocalXp(_xpForCoins(coins));
      if (reply.stale) unawaited(reconcileRankRewards());
    }
    if (!reply.stale) _markBonusQuestDone(QuestEvent.proSpin);
    return ProSpinResult(ProSpinOutcome.won, coins: coins, segment: segment, reason: reason);
  }

  /// Opens today's quest chest once the three daily items are claimed.
  Future<ChestResult> openQuestChest() async {
    if (!_canMutateCoins()) return const ChestResult(ChestOutcome.failed, reason: 'not_logged_in');
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final String dayKey = questsNotifier.value?.dayKey ?? economyDayKey(DateTime.now());
    final _EconomyReply? reply = await _economyPurchase(
      'openQuestChest',
      dayKey,
      const <String, Object?>{},
      sourceTag: 'coins.quests.chest',
    );
    if (!_isCurrentOwner(userId, generation) || reply == null) {
      return const ChestResult(ChestOutcome.failed, reason: 'session_changed');
    }
    final String reason = reply.reason;
    if (!reply.success) {
      return ChestResult(switch (reason) {
        'quest_chest_locked' => ChestOutcome.locked,
        'quest_chest_already_opened' => ChestOutcome.alreadyOpened,
        _ => ChestOutcome.failed,
      }, reason: reason);
    }
    if (!reply.stale) _applyQuestReply(reply.data);
    final int coins = parseIntOr(reply.data['coins']);
    final String? itemId = _optionalString(reply.data['itemId']);
    if (!reply.stale && itemId != null) {
      inventoryNotifier.value = inventoryNotifier.value.withOwned(
        Set<String>.unmodifiable(<String>{...inventoryNotifier.value.owned, itemId}),
      );
    }
    if (!reply.stale) {
      await _persistEconomy(userId, <String, dynamic>{
        'rev': _economyRev,
        if (reply.data.containsKey('quests')) 'quests': reply.data['quests'],
        'inventory': <String, Object?>{'owned': inventoryNotifier.value.owned.toList()},
      });
    }
    if (!_isCurrentOwner(userId, generation)) {
      return const ChestResult(ChestOutcome.failed, reason: 'session_changed');
    }
    if (reply.changed) {
      analytics.track(QuestChestOpenedEvent(coins: coins, itemId: itemId));
      _logEarn(action: CoinEarnAction.questChest, amount: coins, sourceTag: 'coins.quests.chest');
      unawaited(reconcileRankRewards());
    }
    return ChestResult(
      ChestOutcome.opened,
      coins: coins,
      doubled: reply.data['doubled'] == true,
      itemId: itemId,
      reason: reason,
    );
  }

  Future<ShopPurchaseResult> purchaseShopItem(String itemId) async {
    if (!_canMutateCoins()) return const ShopPurchaseResult(ShopPurchaseOutcome.failed, reason: 'not_logged_in');
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final _EconomyReply? reply = await _economyPurchase('purchaseShopItem', itemId, <String, Object?>{
      'itemId': itemId,
    }, sourceTag: 'coins.shop.purchase');
    if (!_isCurrentOwner(userId, generation) || reply == null) {
      return const ShopPurchaseResult(ShopPurchaseOutcome.failed, reason: 'session_changed');
    }
    if (reply.success && !reply.stale && reply.data['owned'] is! List) {
      await _patchInventoryReply(userId, <String, dynamic>{
        'owned': <String>{...inventoryNotifier.value.owned, itemId}.toList(),
      });
      if (!_isCurrentOwner(userId, generation)) {
        return const ShopPurchaseResult(ShopPurchaseOutcome.failed, reason: 'session_changed');
      }
    }
    final Set<String> owned = inventoryNotifier.value.owned;
    final String reason = reply.reason;
    if (reply.success) {
      if (reply.changed) {
        _logSpend(
          action: CoinSpendAction.shopItem,
          amount: -reply.delta,
          sourceTag: 'coins.shop.purchase',
          reason: itemId,
        );
      }
      return ShopPurchaseResult(ShopPurchaseOutcome.purchased, owned: owned, reason: reason);
    }
    return ShopPurchaseResult(
      reply.insufficient
          ? ShopPurchaseOutcome.insufficient
          : switch (reason) {
              'shop_item_owned' => ShopPurchaseOutcome.owned,
              'shop_item_pro_only' => ShopPurchaseOutcome.proOnly,
              'shop_item_rank_locked' => ShopPurchaseOutcome.rankLocked,
              'shop_item_expired' => ShopPurchaseOutcome.expired,
              _ => ShopPurchaseOutcome.failed,
            },
      owned: owned,
      reason: reason,
    );
  }

  /// Equips [itemId] in [slot], or clears the slot when [itemId] is null. Returns true when the server accepted it.
  Future<bool> equipCosmetic(CosmeticSlot slot, String? itemId) async {
    if (!_canMutateCoins()) return false;
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final _EconomyReply? reply = await _callEconomy(
      'equipCosmetic',
      <String, Object?>{'slot': slot.name, 'itemId': itemId},
      userId: userId,
      sourceTag: 'coins.shop.equip',
    );
    if (!_isCurrentOwner(userId, generation) || reply == null || !reply.success || _staleEconomyReply(reply.data)) {
      return false;
    }
    _economyMutationGeneration++;
    final Map<String, dynamic> cosmetics = reply.data.containsKey('cosmetics')
        ? toJsonMap(reply.data['cosmetics'])
        : <String, dynamic>{
            'frame': slot == CosmeticSlot.frame ? itemId : inventoryNotifier.value.frame,
            'nameGlow': slot == CosmeticSlot.nameGlow ? itemId : inventoryNotifier.value.nameGlow,
          };
    inventoryNotifier.value = inventoryNotifier.value.withEquipped(
      frame: _optionalString(cosmetics['frame']),
      nameGlow: _optionalString(cosmetics['nameGlow']),
    );
    return true;
  }

  /// Unlocks one wall of the week's Drop, or every wall left when [wallId] is null.
  Future<DropUnlockResult> unlockDrop({required String weekKey, String? wallId}) async {
    if (!_canMutateCoins()) return const DropUnlockResult(DropUnlockOutcome.failed, reason: 'not_logged_in');
    final String userId = app_state.prismUser.id;
    final int generation = _economySessionGeneration;
    final _EconomyReply? reply = await _economyPurchase(
      'unlockDrop',
      '${weekKey}_${wallId ?? 'pack'}',
      <String, Object?>{'weekKey': weekKey, 'wallId': wallId},
      sourceTag: 'coins.drops.unlock',
    );
    if (!_isCurrentOwner(userId, generation) || reply == null) {
      return const DropUnlockResult(DropUnlockOutcome.failed, reason: 'session_changed');
    }
    final String reason = reply.reason;
    final Object? rawUnlocked = reply.data['unlocked'];
    final List<DropUnlock> unlocked = <DropUnlock>[
      if (rawUnlocked is List)
        for (final Object? raw in rawUnlocked)
          if (toJsonMap(raw)['id'] is String)
            DropUnlock(
              wallId: toJsonMap(raw)['id'] as String,
              weekKey: weekKey,
              url: toJsonMap(raw)['url']?.toString() ?? '',
            ),
    ];
    if (!reply.stale && unlocked.isNotEmpty) {
      dropsUnlockedNotifier.value = Map<String, DropUnlock>.unmodifiable(<String, DropUnlock>{
        ...dropsUnlockedNotifier.value,
        for (final DropUnlock u in unlocked) u.wallId: u,
      });
    }
    if (reply.success && !reply.stale) {
      await _persistEconomy(userId, <String, dynamic>{
        'rev': _economyRev,
        'drops': <String, Object?>{
          'unlocked': <String, Object?>{
            for (final MapEntry<String, DropUnlock> entry in dropsUnlockedNotifier.value.entries)
              entry.key: <String, Object?>{'weekKey': entry.value.weekKey, 'url': entry.value.url},
          },
        },
      });
      if (!_isCurrentOwner(userId, generation)) {
        return const DropUnlockResult(DropUnlockOutcome.failed, reason: 'session_changed');
      }
    }
    if (reply.success) {
      if (!reply.changed && (reason == 'drop_wall_already_unlocked' || reason == 'drop_pack_nothing_left')) {
        return DropUnlockResult(DropUnlockOutcome.alreadyUnlocked, unlocked: unlocked, reason: reason);
      }
      if (reply.changed) {
        _logSpend(
          action: wallId == null ? CoinSpendAction.dropPack : CoinSpendAction.dropWall,
          amount: -reply.delta,
          sourceTag: 'coins.drops.unlock',
          reason: weekKey,
        );
      }
      return DropUnlockResult(DropUnlockOutcome.unlocked, unlocked: unlocked, reason: reason);
    }
    return DropUnlockResult(
      reply.insufficient
          ? DropUnlockOutcome.insufficient
          : switch (reason) {
              'drop_not_live' || 'drops_disabled' => DropUnlockOutcome.notLive,
              _ => DropUnlockOutcome.failed,
            },
      reason: reason,
    );
  }

  /// Boosts the caller's approved wall to the front of Trending for 24 hours.
  Future<BoostResult> boostWall(String wallId) async {
    if (!_canMutateCoins()) return const BoostResult(BoostOutcome.failed, reason: 'not_logged_in');
    final _EconomyReply? reply = await _economyPurchase('boostWall', wallId, <String, Object?>{
      'wallId': wallId,
    }, sourceTag: 'coins.boost');
    if (reply == null) return const BoostResult(BoostOutcome.failed, reason: 'session_changed');
    final String reason = reply.reason;
    if (reply.success) {
      if (reply.changed) {
        _logSpend(action: CoinSpendAction.boostWall, amount: -reply.delta, sourceTag: 'coins.boost', reason: wallId);
      }
      return BoostResult(BoostOutcome.boosted, endsAt: _msToUtc(reply.data['endsAt']), reason: reason);
    }
    return BoostResult(
      reply.insufficient
          ? BoostOutcome.insufficient
          : switch (reason) {
              'boost_active' => BoostOutcome.active,
              'boost_not_owner' || 'permission-denied' => BoostOutcome.notOwner,
              'boost_wall_not_approved' => BoostOutcome.notApproved,
              'boost_slots_full' => BoostOutcome.slotsFull,
              _ => BoostOutcome.failed,
            },
      endsAt: _msToUtc(reply.data['endsAt']),
      nextFreeAt: _msToUtc(reply.data['nextFreeAt']),
      reason: reason,
    );
  }

  /// Sends [recipientUid] a 24 hour premium pass.
  Future<GiftResult> giftPremiumPass(String recipientUid) async {
    if (!_canMutateCoins()) return const GiftResult(GiftOutcome.failed, reason: 'not_logged_in');
    final _EconomyReply? reply = await _economyPurchase('giftPremiumPass', recipientUid, <String, Object?>{
      'recipientUid': recipientUid,
    }, sourceTag: 'coins.gift');
    if (reply == null) return const GiftResult(GiftOutcome.failed, reason: 'session_changed');
    final String reason = reply.reason;
    if (reply.success) {
      if (reply.changed) {
        _logSpend(action: CoinSpendAction.giftPremiumPass, amount: -reply.delta, sourceTag: 'coins.gift');
      }
      return GiftResult(GiftOutcome.sent, expiresAt: _msToUtc(reply.data['expiresAt']), reason: reason);
    }
    return GiftResult(
      reply.insufficient
          ? GiftOutcome.insufficient
          : switch (reason) {
              'gift_recipient_premium' => GiftOutcome.recipientPremium,
              'gift_sender_too_new' => GiftOutcome.senderTooNew,
              'gift_blocked' => GiftOutcome.blocked,
              _ when reason.startsWith('gift_') && reason.contains('limit') => GiftOutcome.limit,
              _ => GiftOutcome.failed,
            },
      reason: reason,
    );
  }

  /// Buys one ticket for this week's Prism Draw.
  Future<DrawTicketResult> buyDrawTicket() async {
    if (!_canMutateCoins()) return const DrawTicketResult(DrawTicketOutcome.failed, reason: 'not_logged_in');
    final _EconomyReply? reply = await _economyPurchase(
      'buyDrawTicket',
      economyWeekKey(DateTime.now()),
      const <String, Object?>{},
      sourceTag: 'coins.draw.ticket',
    );
    if (reply == null) return const DrawTicketResult(DrawTicketOutcome.failed, reason: 'session_changed');
    final String reason = reply.reason;
    final int tickets = parseIntOr(reply.data['tickets']);
    final DateTime? closesAt = _msToUtc(reply.data['closesAt']);
    final String weekKey = reply.data['weekKey']?.toString() ?? '';
    if (reply.success) {
      if (reply.changed) {
        _logSpend(action: CoinSpendAction.drawTicket, amount: -reply.delta, sourceTag: 'coins.draw.ticket');
      }
      return DrawTicketResult(
        DrawTicketOutcome.bought,
        tickets: tickets,
        closesAt: closesAt,
        weekKey: weekKey,
        reason: reason,
      );
    }
    return DrawTicketResult(
      reply.insufficient
          ? DrawTicketOutcome.insufficient
          : switch (reason) {
              'draw_ticket_limit' => DrawTicketOutcome.limit,
              'draw_disabled' => DrawTicketOutcome.disabled,
              'draw_closed' => DrawTicketOutcome.closed,
              'draw_pro_not_eligible' => DrawTicketOutcome.proNotEligible,
              _ => DrawTicketOutcome.failed,
            },
      tickets: tickets,
      closesAt: closesAt,
      weekKey: weekKey,
      reason: reason,
    );
  }

  bool _canMutateCoins() {
    return app_state.prismUser.loggedIn && app_state.prismUser.id.trim().isNotEmpty;
  }

  Future<CoinMutationResult> _callCoinMutation({
    required String userId,
    required String callableName,
    int? amount,
    required String action,
    required String sourceTag,
    required String reason,
    bool allowPremiumBypass = false,
    String? inviterUserId,
    String? transactionId,
    String? label,
    String? requestId,
    Map<String, Object?> extra = const <String, Object?>{},
  }) async {
    final int generation = _economySessionGeneration;
    final bool idempotent = callableName == 'spendCoins' || (callableName == 'awardCoins' && action == 'rewardedAd');
    final String transactionPrefix = callableName == 'spendCoins' ? _spendTransactionPrefix : _awardTransactionPrefix;
    final String? effectiveRequestId = idempotent ? (requestId ?? _newRequestId()) : null;
    final String? trimmedLabel = label?.trim();
    final Map<String, dynamic> payload = <String, dynamic>{
      if (amount != null) 'amount': amount,
      'action': action,
      'reason': reason,
      'sourceTag': sourceTag,
      'allowPremiumBypass': allowPremiumBypass,
      if (inviterUserId != null) 'inviterUserId': inviterUserId,
      if (transactionId != null) 'transactionId': transactionId,
      if (effectiveRequestId != null) 'requestId': effectiveRequestId,
      if (trimmedLabel != null && trimmedLabel.isNotEmpty)
        'label': trimmedLabel.length > _maxLabelLength ? trimmedLabel.substring(0, _maxLabelLength) : trimmedLabel,
      if (callableName == 'spendCoins') 'pricingVersion': 2,
      ...extra,
    };
    final int attempts = effectiveRequestId == null ? 1 : 2;
    bool mayHaveCommitted = false;
    CoinMutationResult signedOut({required bool mayHaveDebited}) => mayHaveDebited && effectiveRequestId != null
        ? CoinMutationResult.noChange(
            balance: app_state.prismUser.coins,
            success: false,
            reason: 'not_logged_in',
            unknownOutcomeTransactionId: '$transactionPrefix${userId}_$effectiveRequestId',
          )
        : _notLoggedIn;
    for (int attempt = 1; attempt <= attempts; attempt++) {
      if (!_isCurrentOwner(userId, generation)) return signedOut(mayHaveDebited: mayHaveCommitted);
      try {
        final HttpsCallable callable = appFunctions.httpsCallable(callableName);
        final HttpsCallableResult<dynamic> response = await callable.call(payload);
        final Map<String, dynamic> data = toJsonMap(response.data);
        if (!_isCurrentOwner(userId, generation)) {
          return signedOut(mayHaveDebited: data['changed'] == true);
        }
        final int balance = parseIntOr(data['currentBalance']);
        return CoinMutationResult(
          success: data['success'] == true,
          changed: data['changed'] == true,
          bypassed: data['bypassed'] == true,
          insufficientBalance: data['insufficientBalance'] == true,
          previousBalance: parseIntOr(data['previousBalance']),
          currentBalance: balance,
          delta: parseIntOr(data['delta']),
          reason: data['reason']?.toString() ?? reason,
          transactionId: data['transactionId']?.toString() ?? '',
          adsRemaining: data['adsRemaining'] is num ? parseIntOr(data['adsRemaining']) : null,
          graceDownloadsLeft: data['graceDownloadsLeft'] is num ? parseIntOr(data['graceDownloadsLeft']) : null,
          passUntil: _msToUtc(data['passUntil']),
        );
      } on FirebaseFunctionsException catch (error, stackTrace) {
        logCoinError(sourceTag: '$sourceTag.callable', error: error, stackTrace: stackTrace);
        final bool retryable = error.code == 'deadline-exceeded' || error.code == 'unavailable';
        mayHaveCommitted = mayHaveCommitted || retryable || error.code == 'internal';
        if (retryable && attempt < attempts) continue;
        return CoinMutationResult.noChange(
          balance: app_state.prismUser.coins,
          success: false,
          reason: error.code,
          unknownOutcomeTransactionId: effectiveRequestId != null && mayHaveCommitted
              ? '$transactionPrefix${userId}_$effectiveRequestId'
              : '',
        );
      }
    }
    return CoinMutationResult.noChange(balance: app_state.prismUser.coins, success: false, reason: 'unavailable');
  }

  bool _isProfileComplete() {
    final ProfileCompletenessStatus status = ProfileCompletenessEvaluator.evaluate(
      app_state.prismUser,
      defaultProfilePhotoUrl: app_state.defaultProfilePhotoUrl,
    );
    return status.isComplete;
  }

  bool _asBool(Object? value) {
    if (value is bool) {
      return value;
    }
    final String normalized = (value?.toString() ?? '').toLowerCase().trim();
    return normalized == 'true' || normalized == '1';
  }

  bool _isPremiumUserData(Map<String, dynamic> data) {
    final bool premiumFlag = _asBool(data['premium']) || app_state.prismUser.premium;
    final SubscriptionTier tierFromGlobal = SubscriptionTier.fromValue(app_state.prismUser.subscriptionTier);
    if (tierFromGlobal.isPaid) {
      return true;
    }
    final SubscriptionTier tierFromDoc = SubscriptionTier.fromValue(data['subscriptionTier']?.toString());
    return premiumFlag || tierFromDoc.isPaid;
  }

  int _deviceTimezoneOffsetMinutes() {
    return DateTime.now().timeZoneOffset.inMinutes;
  }

  bool _preferredStreakReminderEnabled() {
    if (!_settings.isOpen) {
      return true;
    }
    return _settings.get<bool>(NotificationPrefKeys.streakReminders, defaultValue: true);
  }

  int _clampStreakDay(int day) {
    if (day < 0) {
      return 0;
    }
    if (day > 7) {
      return 7;
    }
    return day;
  }

  DateTime _offsetDateTime(DateTime utc, int timezoneOffsetMinutes) {
    return utc.add(Duration(minutes: timezoneOffsetMinutes));
  }

  String _offsetDayKey(DateTime utc, int timezoneOffsetMinutes) {
    final DateTime shifted = _offsetDateTime(utc.toUtc(), timezoneOffsetMinutes);
    final String month = shifted.month.toString().padLeft(2, '0');
    final String day = shifted.day.toString().padLeft(2, '0');
    return '${shifted.year}-$month-$day';
  }

  DateTime? _parseUtcDateTime(Object? value) => parseDateTime(value)?.toUtc();

  DateTime _computeNextReminderAtUtc({
    required DateTime nowUtc,
    required int timezoneOffsetMinutes,
    required String lastClaimDate,
    required String todayLocalKey,
    required bool activeStreak,
  }) {
    DateTime reminderLocalBase(DateTime localBase, {required bool tomorrow}) {
      final int dayOffset = tomorrow ? 1 : 0;
      // Build this in UTC so scheduling doesn't depend on the device timezone.
      return DateTime.utc(localBase.year, localBase.month, localBase.day + dayOffset, 20);
    }

    final DateTime localNow = _offsetDateTime(nowUtc, timezoneOffsetMinutes);
    final bool claimedToday = lastClaimDate == todayLocalKey;
    final bool sendTomorrow = !activeStreak || claimedToday || localNow.hour >= 20;
    final DateTime localReminder = reminderLocalBase(localNow, tomorrow: sendTomorrow);
    return localReminder.subtract(Duration(minutes: timezoneOffsetMinutes)).toUtc();
  }

  StreakStatus _syncStreakFromUserData(Map<String, dynamic> userData, {bool syncXp = true}) {
    final Map<String, dynamic> coinState = toJsonMap(userData[_coinStateField]);
    earnFlagsNotifier.value = CoinEarnFlags.fromCoinState(coinState);
    _syncRootEconomy(userData, coinState, syncXp: syncXp);
    final int timezoneOffsetMinutes =
        parseInt(coinState['streakClaimTimezoneOffsetMinutes']) ??
        parseInt(coinState[_streakTimezoneOffsetMinutesField]) ??
        _deviceTimezoneOffsetMinutes();
    final String todayLocalKey = _offsetDayKey(DateTime.now().toUtc(), timezoneOffsetMinutes);
    final String lastClaimDate = (coinState['lastDailyClaimDate'] as String? ?? '').trim();
    final int streakDay = _clampStreakDay(parseIntOr(coinState['streakDay']));
    final int count = _streakCount(coinState, streakDay);
    final int best = max(count, parseInt(coinState['streakBest']) ?? count);
    final int freezes = _clampFreezes(parseIntOr(coinState['streakFreezes']));
    final bool active = count > 0 && isStreakAlive(lastClaimDate, todayLocalKey, freezes);
    final bool claimedToday = lastClaimDate == todayLocalKey;
    final StreakStatus status = StreakStatus(
      streakDay: active ? streakDay : 0,
      count: active ? count : 0,
      best: best,
      freezes: freezes,
      active: active,
      claimedToday: claimedToday,
      reminderEnabled: _asBool(coinState[_streakReminderEnabledField] ?? _preferredStreakReminderEnabled()),
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      lastClaimDate: lastClaimDate,
      nextReminderAtUtc: _parseUtcDateTime(coinState[_streakReminderNextAtUtcField]),
    );
    streakNotifier.value = status;
    return status;
  }

  Map<String, int> _previewUnlocksFromState(Map<String, dynamic> coinState) {
    return _previewUnlocksFromRaw(coinState['premiumPreviewUnlocks']);
  }

  Map<String, int> _previewUnlocksFromRaw(Object? raw) {
    if (raw is! Map) {
      return <String, int>{};
    }
    final Map<String, int> normalized = <String, int>{};
    raw.forEach((key, value) {
      final String normalizedKey = _normalizeCollectionKey(key.toString());
      if (normalizedKey.isEmpty) {
        return;
      }
      final int expiryMillis = parseIntOr(value);
      if (expiryMillis > 0) {
        normalized[normalizedKey] = expiryMillis;
      }
    });
    return normalized;
  }

  String _normalizeCollectionKey(String rawKey) {
    return rawKey.trim().toLowerCase();
  }

  /// Applies a balance the server returned outside the coin callables, such as a badge reward.
  void applyServerBalance(int balance) {
    if (!_canMutateCoins()) return;
    if (balance == app_state.prismUser.coins) {
      balanceNotifier.value = balance;
      return;
    }
    _applyLocalBalance(balance, delta: balance - app_state.prismUser.coins);
    unawaited(reconcileRankRewards());
  }

  void _applyLocalBalance(int newBalance, {required int delta}) {
    final int previous = app_state.prismUser.coins;
    app_state.prismUser.coins = newBalance;
    balanceNotifier.value = newBalance;
    if (delta == 0 && previous == newBalance) {
      return;
    }
    if (_settings.isOpen) {
      app_state.persistPrismUser();
    }
    _deltaVersion += 1;
    final int currentVersion = _deltaVersion;
    deltaNotifier.value = delta;
    Future<void>.delayed(_deltaAnimationDuration, () {
      if (_deltaVersion == currentVersion) {
        deltaNotifier.value = 0;
      }
    });
  }

  void _logEarn({required CoinEarnAction action, required int amount, required String sourceTag, String? reason}) {
    analytics.track(
      CoinEarnedEvent(
        action: action,
        amount: amount,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
        reason: reason != null && reason.isNotEmpty ? reason : null,
      ),
    );
  }

  void _logSpend({required CoinSpendAction action, required int amount, required String sourceTag, String? reason}) {
    analytics.track(
      CoinSpentEvent(
        action: action,
        amount: amount,
        balance: app_state.prismUser.coins,
        sourceTag: sourceTag,
        reason: reason != null && reason.isNotEmpty ? reason : null,
      ),
    );
  }

  void logLowBalanceNudge({required String sourceTag, required int requiredCoins}) {
    analytics.track(
      CoinLowBalanceNudgeShownEvent(
        sourceTag: sourceTag,
        requiredCoins: requiredCoins,
        balance: app_state.prismUser.coins,
      ),
    );
  }

  void logWatchAndDownloadUsed({required bool isPremiumContent, required String sourceTag}) {
    analytics.track(CoinWatchAndDownloadUsedEvent(isPremiumContent: isPremiumContent, sourceTag: sourceTag));
  }

  void logCoinError({required String sourceTag, required Object error, StackTrace? stackTrace}) {
    logger.e(
      'Coin service error',
      tag: 'Coins',
      error: error,
      stackTrace: stackTrace,
      fields: <String, Object?>{'sourceTag': sourceTag},
    );
  }
}

class _EconomyReply {
  const _EconomyReply(this.data, {this.errorCode, this.stale = false});

  final Map<String, dynamic> data;

  /// Set when the callable threw. Null for any reply the server sent.
  final String? errorCode;

  final bool stale;

  /// The server answered for sure, so a stored request id can go. A lost or failed call may still have committed.
  bool get definite =>
      errorCode == null ||
      !const <String>{'deadline-exceeded', 'unavailable', 'internal', 'unknown'}.contains(errorCode);

  bool get success => data['success'] == true;
  bool get changed => data['changed'] == true;
  bool get insufficient => data['insufficientBalance'] == true;
  int get delta => parseIntOr(data['delta']);
  String get reason => data['reason']?.toString() ?? '';
}
