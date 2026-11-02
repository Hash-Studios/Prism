import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/layout_prefs/domain/entities/layout_prefs.dart';
import 'package:Prism/features/personalized_feed/domain/entities/home_feed_chip.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// The one owner of [LayoutPrefs]. It reads the device copy at once, so the first frame already has the user's
/// layout, and syncs the bar and grid with `usersv2/{uid}.layoutPrefs` the same way the theme syncs: the last change
/// wins. A guest keeps the device copy only.
@lazySingleton
class LayoutPrefsStore extends ValueNotifier<LayoutPrefs> {
  LayoutPrefsStore(this._settings, this._firestore) : super(_read(_settings));

  static const String accountField = 'layoutPrefs';
  static const String _layoutKey = 'layout.prefs';
  static const String _feedTabKey = 'layout.feed_tab';
  static const String _changedAtKey = 'layout.changed_at';

  final SettingsLocalDataSource _settings;
  final FirestoreClient _firestore;

  static LayoutPrefs _read(SettingsLocalDataSource settings) {
    try {
      final HomeFeedChip feedTab =
          HomeFeedChip.values.asNameMap()[settings.get<String?>(_feedTabKey)] ?? HomeFeedChip.forYou;
      final String? raw = settings.get<String?>(_layoutKey);
      final Object? decoded = raw == null ? null : jsonDecode(raw);
      return decoded is Map ? LayoutPrefs.fromMap(decoded, feedTab: feedTab) : LayoutPrefs(feedTab: feedTab);
    } catch (error, stackTrace) {
      logger.w('Layout settings did not load.', tag: 'Layout', error: error, stackTrace: stackTrace);
      return const LayoutPrefs();
    }
  }

  /// Saves a new bar or grid layout on this device and, for a signed-in user, on the account.
  Future<void> update(LayoutPrefs next) async {
    final LayoutPrefs layout = next.copyWith(feedTab: value.feedTab);
    if (layout == value) return;
    value = layout;
    final int changedAt = DateTime.now().millisecondsSinceEpoch;
    await _settings.set(_layoutKey, jsonEncode(layout.toLayoutMap()));
    await _settings.set(_changedAtKey, changedAt);
    if (app_state.prismUser.loggedIn) {
      unawaited(_push(app_state.prismUser.id, layout, changedAt));
    }
  }

  /// Remembers the Home feed tab on this device. A push or link calls it too, so it wins over the remembered tab.
  Future<void> setFeedTab(HomeFeedChip chip) async {
    if (chip == value.feedTab) return;
    value = value.copyWith(feedTab: chip);
    await _settings.set(_feedTabKey, chip.name);
  }

  /// Applies the account copy when it is newer than the last change on this device, else uploads the device copy.
  Future<void> syncWithAccount(String userId) async {
    final Object? raw = await _firestore.getById<Object?>(
      FirebaseCollections.usersV2,
      userId,
      (data, _) => data[accountField],
      sourceTag: 'layout_prefs.read_account_layout',
    );
    final int? accountChangedAt = raw is Map ? _asInt(raw['changedAt']) : null;
    final int? localChangedAt = _settings.get<int?>(_changedAtKey);
    if (raw is Map && accountChangedAt != null && (localChangedAt == null || accountChangedAt >= localChangedAt)) {
      final LayoutPrefs account = LayoutPrefs.fromMap(raw, feedTab: value.feedTab);
      value = account;
      await _settings.set(_layoutKey, jsonEncode(account.toLayoutMap()));
      await _settings.set(_changedAtKey, accountChangedAt);
    } else if (localChangedAt != null) {
      await _push(userId, value, localChangedAt);
    }
  }

  Future<void> _push(String userId, LayoutPrefs layout, int changedAt) async {
    try {
      await _firestore.updateDoc(FirebaseCollections.usersV2, userId, {
        accountField: <String, Object>{...layout.toLayoutMap(), 'changedAt': changedAt},
      }, sourceTag: 'layout_prefs.push_account_layout');
    } catch (error, stackTrace) {
      logger.w('Layout did not upload to the account.', tag: 'Layout', error: error, stackTrace: stackTrace);
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.truncateToDouble()) return value.toInt();
    return null;
  }
}
