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
  final Map<String, bool> _unlocked = <String, bool>{};
  final Set<String> _loading = <String>{};

  /// Bumps whenever a marker is read or an unlock lands.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  String _key(String uid, String wallDocId) => '$uid/$wallDocId';

  CreatorWallAccess accessFor(PrismWallpaper wall) {
    if (!wall.isCreatorPriced) return CreatorWallAccess.free;
    final String uid = _owner().trim();
    if (uid.isEmpty) return CreatorWallAccess.locked;
    if (wall.core.authorUid == uid) return CreatorWallAccess.owner;
    final String wallDocId = wall.firestoreDocumentId?.trim() ?? '';
    if (wallDocId.isEmpty) return CreatorWallAccess.locked;
    final bool? known = _unlocked[_key(uid, wallDocId)];
    if (known == null) {
      unawaited(_load(uid, wallDocId));
      return CreatorWallAccess.checking;
    }
    return known ? CreatorWallAccess.unlocked : CreatorWallAccess.locked;
  }

  /// Called after the server confirmed an unlock, so the wall opens without another read.
  void markUnlocked(String wallDocId) {
    final String uid = _owner().trim();
    if (uid.isEmpty || wallDocId.isEmpty) return;
    _unlocked[_key(uid, wallDocId)] = true;
    changes.value++;
  }

  Future<void> _load(String uid, String wallDocId) async {
    final String key = _key(uid, wallDocId);
    if (!_loading.add(key)) return;
    bool unlocked = false;
    try {
      final Map<String, dynamic>? marker = await _read(uid, wallDocId);
      unlocked = marker != null && marker['wallDocId'] == wallDocId && marker['refundedAt'] == null;
    } catch (error) {
      // Shown as locked. An unlock attempt then answers already_unlocked without charging.
      logger.w('[CreatorWalls] unlock marker unreadable: $error');
    } finally {
      _loading.remove(key);
    }
    _unlocked.putIfAbsent(key, () => unlocked);
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
