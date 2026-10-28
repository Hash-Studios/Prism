import 'dart:async';

import 'package:Prism/core/coins/coins_service.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/platform/ios_widget_channel.dart';
import 'package:Prism/core/platform/pigeon/prism_widget_api.g.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:flutter/foundation.dart';

/// Mirrors the signed-in user's streak to the iOS Lock Screen widgets, so they stay right after midnight without the
/// app. Never throws.
class StreakWidgetSync {
  const StreakWidgetSync._();

  @visibleForTesting
  static ValueListenable<StreakStatus> Function() streak = () => CoinsService.instance.streakNotifier;

  @visibleForTesting
  static bool Function() isSignedIn = () => app_state.prismUser.loggedIn;

  @visibleForTesting
  static String Function() ownerId = () => app_state.prismUser.id;

  @visibleForTesting
  static Stream<String?> Function() ownerChanges = () {
    if (!getIt.isRegistered<SessionRepository>()) return const Stream<String?>.empty();
    return getIt<SessionRepository>().watchCurrentUser().map((user) => user.loggedIn ? user.id : null);
  };

  static ValueListenable<StreakStatus>? _listening;
  static StreamSubscription<String?>? _ownerSubscription;
  static String? _lastScheduledKey;
  static String? _activeOwner;
  static String? _blockedOwner;
  static StreakStatus? _awaitingOwnerStatus;
  static StreakStatus? _lastStatus;
  static bool _clearPending = false;
  static int _observedGeneration = 0;
  static bool _hasActiveOwner = false;

  static void start() {
    _ownerSubscription ??= ownerChanges().listen((_) => _write());
    final ValueListenable<StreakStatus> current = streak();
    if (!identical(_listening, current)) {
      _listening?.removeListener(_write);
      current.addListener(_write);
      _listening = current;
    }
    _write();
  }

  static void _write() {
    unawaited(_send());
  }

  static Future<void> _send() async {
    final bool signedIn = isSignedIn();
    final String? owner = signedIn ? ownerId() : null;
    final StreakStatus status = streak().value;
    final bool hasFreshStatus = !identical(status, _lastStatus);
    _lastStatus = status;
    if (IosWidgetChannel.streakGeneration != _observedGeneration) {
      _observedGeneration = IosWidgetChannel.streakGeneration;
      // A clear from account deletion must also block later updates from that account.
      _blockedOwner = owner;
      _clearPending = true;
    }
    if (!_hasActiveOwner) {
      _activeOwner = owner;
      _hasActiveOwner = true;
    } else if (owner != _activeOwner) {
      _activeOwner = owner;
      _blockedOwner = null;
      _awaitingOwnerStatus = hasFreshStatus ? null : status;
      unawaited(_clearForOwner(owner));
      if (!hasFreshStatus) return;
    }
    if (_clearPending) {
      await _clearForOwner(owner);
      if (!_clearPending) _write();
      return;
    }
    if (owner != null && owner == _blockedOwner) return;

    if (_awaitingOwnerStatus != null) {
      if (identical(status, _awaitingOwnerStatus)) return;
      _awaitingOwnerStatus = null;
    }
    final bool hasStatus = signedIn && !identical(status, StreakStatus.empty);
    final StreakWidgetSnapshot? snapshot = hasStatus ? snapshotFor(status, signedIn: true) : null;
    final String key = hasStatus
        ? '${owner ?? ''}|${IosWidgetChannel.streakGeneration}|${snapshot!.count}|${snapshot.lastKeptDay}|'
              '${snapshot.utcOffsetMinutes}|${snapshot.freezes}'
        : '${owner ?? ''}|${IosWidgetChannel.streakGeneration}|clear';
    if (key == _lastScheduledKey) return;
    _lastScheduledKey = key;
    final bool succeeded = await IosWidgetChannel.setStreak(snapshot);
    if (!succeeded && key == _lastScheduledKey) {
      _lastScheduledKey = null;
    }
  }

  static Future<void> clear() async {
    final String? owner = isSignedIn() ? ownerId() : null;
    _blockedOwner = owner;
    await _clearForOwner(owner);
  }

  static Future<void> _clearForOwner(String? owner) async {
    final Future<bool> clear = IosWidgetChannel.requestClearStreak();
    _observedGeneration = IosWidgetChannel.streakGeneration;
    final String key = '${owner ?? ''}|${IosWidgetChannel.streakGeneration}|clear';
    _lastScheduledKey = key;
    final bool succeeded = await clear;
    _clearPending = !succeeded;
    if (!succeeded && key == _lastScheduledKey) _lastScheduledKey = null;
  }

  @visibleForTesting
  static StreakWidgetSnapshot? snapshotFor(StreakStatus status, {required bool signedIn}) {
    if (!signedIn) return null;
    return StreakWidgetSnapshot(
      count: status.count,
      lastKeptDay: status.lastClaimDate,
      utcOffsetMinutes: status.timezoneOffsetMinutes,
      freezes: status.freezes,
    );
  }

  @visibleForTesting
  static void resetForTest() {
    _listening?.removeListener(_write);
    _listening = null;
    unawaited(_ownerSubscription?.cancel());
    _ownerSubscription = null;
    _lastScheduledKey = null;
    _activeOwner = null;
    _blockedOwner = null;
    _awaitingOwnerStatus = null;
    _lastStatus = null;
    _clearPending = false;
    _observedGeneration = IosWidgetChannel.streakGeneration;
    _hasActiveOwner = false;
  }
}
