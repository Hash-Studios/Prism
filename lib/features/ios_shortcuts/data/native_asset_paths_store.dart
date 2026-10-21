import 'dart:async';
import 'dart:convert';

import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:shared_preferences/shared_preferences.dart';

class NativeAssetPathsStore {
  const NativeAssetPathsStore._();

  static const String preferenceKey = 'offline.native_asset_paths';
  static const String privateOwnerKey = '$preferenceKey.private_owner';
  static const List<String> _groups = <String>['favourites', 'shortcuts', 'wotd', 'category'];
  static Future<void> _tail = Future<void>.value();
  static int _generation = 0;

  static Future<void> replaceGroup(String group, Map<String, String> paths) {
    if (!_groups.contains(group)) throw ArgumentError.value(group, 'group');
    final int generation = _generation;
    return _enqueue(() async {
      if (generation != _generation) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final Map<String, String> combined = <String, String>{};
      for (final String name in _groups) {
        final String raw = name == group ? jsonEncode(paths) : prefs.getString('$preferenceKey.$name') ?? '{}';
        try {
          final Object? decoded = jsonDecode(raw);
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              if (entry.key is String && entry.value is String) combined[entry.key as String] = entry.value as String;
            }
          }
        } on FormatException {
          continue;
        }
      }
      if (generation != _generation) return;
      if (!await prefs.setString('$preferenceKey.$group', jsonEncode(paths)) ||
          !await prefs.setString(preferenceKey, jsonEncode(combined))) {
        throw StateError('Native retained asset paths could not be persisted');
      }
      if ((group == 'favourites' || group == 'shortcuts') && app_state.prismUser.loggedIn) {
        await prefs.setString(privateOwnerKey, app_state.prismUser.id.trim());
      }
    });
  }

  static Future<void> clearForUser(String userId) async {
    final String owner = userId.trim();
    if (owner.isEmpty || _otherOwnerIsActive(owner)) return;
    _generation++;
    await _enqueue(() async {
      if (_otherOwnerIsActive(owner)) return;
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (_otherOwnerIsActive(owner) || _otherPrivateOwnerIsActive(prefs, owner)) return;
      if (!await prefs.setString('$preferenceKey.favourites', '{}') ||
          !await prefs.setString('$preferenceKey.shortcuts', '{}')) {
        throw StateError('Private native retained asset paths could not be cleared');
      }
      if (_otherOwnerIsActive(owner) || _otherPrivateOwnerIsActive(prefs, owner)) return;
      final Map<String, String> combined = <String, String>{};
      for (final String group in const <String>['wotd', 'category']) {
        try {
          final Object? decoded = jsonDecode(prefs.getString('$preferenceKey.$group') ?? '{}');
          if (decoded is Map) {
            for (final entry in decoded.entries) {
              if (entry.key is String && entry.value is String) combined[entry.key as String] = entry.value as String;
            }
          }
        } on FormatException {
          continue;
        }
      }
      if (_otherOwnerIsActive(owner) || _otherPrivateOwnerIsActive(prefs, owner)) return;
      if (!await prefs.setString(preferenceKey, jsonEncode(combined))) {
        throw StateError('Private native retained asset paths could not be cleared');
      }
    });
  }

  static bool _otherOwnerIsActive(String owner) {
    final String activeOwner = app_state.prismUser.loggedIn ? app_state.prismUser.id.trim() : '';
    return activeOwner.isNotEmpty && activeOwner != owner;
  }

  static bool _otherPrivateOwnerIsActive(SharedPreferences prefs, String owner) {
    final String savedOwner = prefs.getString(privateOwnerKey)?.trim() ?? '';
    return savedOwner.isNotEmpty && savedOwner != owner;
  }

  static Future<void> _enqueue(Future<void> Function() operation) {
    final Future<void> result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }
}
