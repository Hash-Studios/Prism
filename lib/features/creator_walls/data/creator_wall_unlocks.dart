import 'dart:async';

import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/wallpaper/wallpaper_variants.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';

/// What the signed-in user may do with a wall's original.
enum CreatorWallAccess {
  /// No price: the normal download and set rules apply.
  free,

  /// The creator's own wall.
  owner,

  /// The user bought it.
  unlocked,

  /// Priced and not bought. Download and set are replaced by the unlock button.
  locked,

  /// The unlock marker is being read.
  checking,
}

/// The user's unlock markers (`usersv2/{uid}/creatorWallUnlocks/{wallDocId}`), read once per wall and kept per account.
/// The server checks the marker again on every download, so this only picks which buttons to show.
class CreatorWallUnlocks {
  CreatorWallUnlocks({
    Future<Map<String, dynamic>?> Function(String uid, String wallDocId)? read,
    String Function()? owner,
  }) : _read = read ?? _readMarker,
       _owner = owner ?? (() => app_state.prismUser.id);

  static final CreatorWallUnlocks instance = CreatorWallUnlocks();

  final Future<Map<String, dynamic>?> Function(String uid, String wallDocId) _read;
  final String Function() _owner;
  final Map<String, (String wallId, bool unlocked)> _unlocked = <String, (String, bool)>{};
  final Map<String, String> _serverDenied = <String, String>{};
  final Set<String> _loading = <String>{};
  final Set<String> _failed = <String>{};
  final Map<String, int> _entryGeneration = <String, int>{};
  int _sessionGeneration = 0;

  /// Bumps whenever a marker is read or an unlock lands.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  String _key(String uid, String wallDocId) => '$uid/$wallDocId';

  String get currentOwner => _owner().trim();

  CreatorWallAccess accessFor(PrismWallpaper wall) {
    if (!wall.isCreatorPriced) return CreatorWallAccess.free;
    final String uid = _owner().trim();
    if (uid.isEmpty) return CreatorWallAccess.locked;
    if (wall.core.authorUid == uid) return CreatorWallAccess.owner;
    final String wallDocId = wall.firestoreDocumentId?.trim() ?? '';
    if (wallDocId.isEmpty) return CreatorWallAccess.locked;
    final String key = _key(uid, wallDocId);
    final (String, bool)? cached = _unlocked[key];
    if (cached != null && cached.$1 != wall.id) {
      _unlocked.remove(key);
      _failed.remove(key);
    }
    final String? deniedWallId = _serverDenied[key];
    if (deniedWallId != null) {
      if (deniedWallId == wall.id) return CreatorWallAccess.locked;
      _serverDenied.remove(key);
    }
    final (String, bool)? known = cached?.$1 == wall.id ? cached : null;
    if (known == null) {
      if (!_failed.contains(key)) {
        unawaited(_load(uid, wallDocId, wall.id));
        return CreatorWallAccess.checking;
      }
      return CreatorWallAccess.locked;
    }
    return known.$2 ? CreatorWallAccess.unlocked : CreatorWallAccess.locked;
  }

  /// Called after the server confirmed an unlock, so the wall opens without another read.
  void markUnlocked(String wallDocId, {required String wallId, String? ownerUid}) {
    final String uid = _owner().trim();
    if (uid.isEmpty || wallDocId.isEmpty || (ownerUid != null && ownerUid != uid)) return;
    final String key = _key(uid, wallDocId);
    _serverDenied.remove(key);
    _unlocked[key] = (wallId, true);
    changes.value++;
  }

  /// Drops a cached result so callers can retry after a transient read failure or account-state change.
  void invalidate(String wallDocId, {String? ownerUid}) {
    final String uid = (ownerUid ?? _owner()).trim();
    if (uid.isEmpty || wallDocId.isEmpty) return;
    final String key = _key(uid, wallDocId);
    _unlocked.remove(key);
    _failed.remove(key);
    changes.value++;
  }

  /// Replaces stale positive access with an authoritative locked result for this session. The denied result is not
  /// re-read from Firestore, where an old marker may still exist while its refund or wall-incarnation update settles.
  /// This is called after a remote original-access response, never for a local file hit.
  void serverDenied({required String ownerUid, required String wallDocId, required String wallId}) {
    final String uid = _owner().trim();
    if (uid.isEmpty || uid != ownerUid || wallDocId.isEmpty || wallId.isEmpty) return;
    final String key = _key(uid, wallDocId);
    final (String, bool)? cached = _unlocked[key];
    if (cached == null || cached.$1 != wallId || !cached.$2) return;
    _unlocked[key] = (wallId, false);
    _serverDenied[key] = wallId;
    _failed.remove(key);
    _entryGeneration[key] = (_entryGeneration[key] ?? 0) + 1;
    _loading.remove(key);
    changes.value++;
  }

  /// Clears cached access and invalidates outstanding reads when the authenticated session ends.
  void resetSession() {
    _sessionGeneration++;
    _unlocked.clear();
    _serverDenied.clear();
    _loading.clear();
    _failed.clear();
    _entryGeneration.clear();
    changes.value++;
  }

  Future<void> _load(String uid, String wallDocId, String wallId) async {
    final String key = _key(uid, wallDocId);
    if (!_loading.add(key)) return;
    final int generation = _sessionGeneration;
    final int entryGeneration = _entryGeneration[key] ?? 0;
    bool? unlocked;
    bool failed = false;
    try {
      final Map<String, dynamic>? marker = await _read(uid, wallDocId);
      unlocked =
          marker != null &&
          marker['wallDocId'] == wallDocId &&
          marker['wallId'] == wallId &&
          marker['refundedAt'] == null;
    } catch (error) {
      failed = true;
      logger.w('[CreatorWalls] unlock marker unreadable: $error');
    } finally {
      if (generation == _sessionGeneration && entryGeneration == (_entryGeneration[key] ?? 0)) _loading.remove(key);
    }
    if (generation != _sessionGeneration || entryGeneration != (_entryGeneration[key] ?? 0) || _owner().trim() != uid) {
      return;
    }
    if (failed) _failed.add(key);
    if (unlocked != null) _unlocked.putIfAbsent(key, () => (wallId, unlocked!));
    changes.value++;
  }

  static Future<Map<String, dynamic>?> _readMarker(String uid, String wallDocId) =>
      firestoreClient.getById<Map<String, dynamic>>(
        '${FirebaseCollections.usersV2}/$uid/creatorWallUnlocks',
        wallDocId,
        (data, _) => data,
        sourceTag: 'creator_walls.unlock_marker',
      );
}
