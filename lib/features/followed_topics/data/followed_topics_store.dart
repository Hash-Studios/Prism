import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/data/categories/category_definition.dart';
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
import 'package:Prism/features/moods/domain/entities/wall_mood.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/notifications/notification_retention.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

enum TopicFollowResult { done, limit, failed }

/// The one owner of the signed-in user's followed topics.
///
/// The list lives in `usersv2/{uid}/private/session.followedTopics`, so every device of the account shares it. Writes
/// use array union and remove, so two devices never overwrite each other. `followedTopicsOffset` is the UTC offset
/// the daily push job queries; it exists only while the list is not empty. A guest follows nothing.
@lazySingleton
class FollowedTopicsStore extends ChangeNotifier {
  FollowedTopicsStore(this._settings, this._firestore);

  static const String topicsField = 'followedTopics';
  static const String offsetField = 'followedTopicsOffset';
  static const String _seenPrefix = 'followed_topics.seen.';

  final SettingsLocalDataSource _settings;
  final FirestoreClient _firestore;

  List<FollowedTopic> _topics = const <FollowedTopic>[];
  Map<String, int> _latestMs = const <String, int>{};
  String? _loadedFor;
  final Map<String, Future<void>> _loading = <String, Future<void>>{};
  final Map<String, int> _seenGenerations = <String, int>{};
  final Map<String, Future<void>> _mutationTails = <String, Future<void>>{};

  /// Followed topics in follow order. Empty for a guest.
  List<FollowedTopic> get topics =>
      app_state.prismUser.loggedIn && _loadedFor == app_state.prismUser.id ? _topics : const <FollowedTopic>[];

  bool isFollowed(FollowedTopic topic) => topics.contains(topic);

  /// A Prism wall landed in [topic] after the user last opened its page on this device.
  bool hasNew(FollowedTopic topic) =>
      app_state.prismUser.loggedIn &&
      _loadedFor == app_state.prismUser.id &&
      (_latestMs[topic.key] ?? 0) > _seenMs(topic);

  String _sessionPath(String uid) => '${FirebaseCollections.usersV2}/$uid/private';

  static int get _deviceOffset => roundedTimezoneOffsetMinutes(DateTime.now().timeZoneOffset);

  /// Reads the account list once per signed-in user. A second call for the same user does nothing.
  Future<void> ensureLoaded() {
    if (!app_state.prismUser.loggedIn) return Future<void>.value();
    if (_loadedFor == app_state.prismUser.id) return Future<void>.value();
    return _startLoad(app_state.prismUser.id);
  }

  /// Reads the account list and the topic news again, for example when the app comes back to the front. It waits
  /// for a follow or unfollow in flight, so it never replaces that change with an older copy.
  Future<void> refresh() {
    if (!app_state.prismUser.loggedIn) return Future<void>.value();
    final String uid = app_state.prismUser.id;
    final int generation = _seenGenerations[uid] ?? 0;
    return _enqueueMutation<void>(uid, () async {
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != uid ||
          generation != (_seenGenerations[uid] ?? 0)) {
        return;
      }
      await _startLoad(uid);
    });
  }

  Future<void> _startLoad(String uid) {
    final Future<void>? pending = _loading[uid];
    if (pending != null) return pending;
    late final Future<void> loading;
    loading = _load(uid).whenComplete(() {
      if (identical(_loading[uid], loading)) _loading.remove(uid);
    });
    _loading[uid] = loading;
    return loading;
  }

  Future<void> _load(String uid) async {
    final int generation = _seenGenerations[uid] ?? 0;
    try {
      final (List<FollowedTopic>, Object?)? session = await _firestore.getById(
        '${FirebaseCollections.usersV2}/$uid/private',
        'session',
        (data, _) => (_parseTopics(data[topicsField]), data[offsetField]),
        sourceTag: 'followed_topics.load',
      );
      final Map<String, int> latest = await _readNews();
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != uid ||
          generation != (_seenGenerations[uid] ?? 0)) {
        return;
      }
      _topics = session?.$1 ?? const <FollowedTopic>[];
      _latestMs = latest;
      _loadedFor = uid;
      for (final FollowedTopic topic in _topics) {
        if (_settings.get<int?>(_seenKey(uid, topic)) == null) {
          await _markSeenAt(uid, topic, latest[topic.key] ?? 0, generation: generation);
        }
      }
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != uid ||
          generation != (_seenGenerations[uid] ?? 0)) {
        return;
      }
      notifyListeners();
      // The user changed time zone since the last write: move the daily push to the new 16:00.
      if ((_topics.isNotEmpty && session?.$2 != _deviceOffset) || (_topics.isEmpty && session?.$2 != null)) {
        await _syncOffset(uid, generation);
      }
    } catch (error, stackTrace) {
      logger.w('Followed topics did not load.', tag: 'Topics', error: error, stackTrace: stackTrace);
    }
  }

  Future<Map<String, int>> _readNews() async {
    try {
      return await _firestore.getById('topicNews', 'current', (data, _) {
            final Object? latest = data['latest'];
            return <String, int>{
              if (latest is Map)
                for (final MapEntry<Object?, Object?> entry in latest.entries)
                  if (entry.key is String && entry.value is num) entry.key! as String: (entry.value! as num).toInt(),
            };
          }, sourceTag: 'followed_topics.news') ??
          const <String, int>{};
    } catch (error, stackTrace) {
      logger.w('Topic news did not load.', tag: 'Topics', error: error, stackTrace: stackTrace);
      return const <String, int>{};
    }
  }

  static List<FollowedTopic> _parseTopics(Object? raw) => raw is List
      ? raw.map(FollowedTopic.parse).whereType<FollowedTopic>().toSet().toList(growable: false)
      : const <FollowedTopic>[];

  /// Follows [topic] for the signed-in user. The list stays at most [FollowedTopic.maxFollowed] long.
  Future<TopicFollowResult> follow(FollowedTopic topic) {
    if (!app_state.prismUser.loggedIn) return Future<TopicFollowResult>.value(TopicFollowResult.failed);
    final String uid = app_state.prismUser.id;
    final int generation = _seenGenerations[uid] ?? 0;
    return _enqueueMutation<TopicFollowResult>(uid, () async {
      if (generation != (_seenGenerations[uid] ?? 0)) return TopicFollowResult.failed;
      await ensureLoaded();
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != uid ||
          _loadedFor != uid ||
          generation != (_seenGenerations[uid] ?? 0)) {
        return TopicFollowResult.failed;
      }
      if (isFollowed(topic)) return TopicFollowResult.done;
      if (topics.length >= FollowedTopic.maxFollowed) return TopicFollowResult.limit;
      final List<FollowedTopic> before = _topics;
      _topics = List<FollowedTopic>.unmodifiable(<FollowedTopic>[..._topics, topic]);
      await _markSeenAt(uid, topic, DateTime.now().millisecondsSinceEpoch, generation: generation);
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != uid ||
          generation != (_seenGenerations[uid] ?? 0)) {
        return TopicFollowResult.failed;
      }
      notifyListeners();
      final TopicFollowResult result = await _changeTopic(uid, topic, generation: generation, follow: true);
      if (result == TopicFollowResult.done) return result;
      if (app_state.prismUser.id == uid && _loadedFor == uid && generation == (_seenGenerations[uid] ?? 0)) {
        _topics = before;
        notifyListeners();
      }
      // Another device can fill the list after this one loaded it; then the account, not the cache, is full.
      return result;
    });
  }

  /// Stops following [topic]. Returns false when the account did not save the change.
  Future<bool> unfollow(FollowedTopic topic) {
    if (!app_state.prismUser.loggedIn) return Future<bool>.value(true);
    final String uid = app_state.prismUser.id;
    final int generation = _seenGenerations[uid] ?? 0;
    return _enqueueMutation<bool>(uid, () async {
      if (!app_state.prismUser.loggedIn ||
          app_state.prismUser.id != uid ||
          _loadedFor != uid ||
          generation != (_seenGenerations[uid] ?? 0)) {
        return false;
      }
      if (!isFollowed(topic)) return true;
      final List<FollowedTopic> before = _topics;
      _topics = List<FollowedTopic>.unmodifiable(_topics.where((t) => t != topic));
      notifyListeners();
      final bool saved =
          await _changeTopic(uid, topic, generation: generation, follow: false) == TopicFollowResult.done;
      if (saved) return true;
      if (app_state.prismUser.id == uid && _loadedFor == uid && generation == (_seenGenerations[uid] ?? 0)) {
        _topics = before;
        notifyListeners();
      }
      return false;
    });
  }

  /// The user opened the page of [topic]: its dot goes away until a newer wall lands.
  Future<void> markSeen(FollowedTopic topic) async {
    if (!app_state.prismUser.loggedIn || _loadedFor != app_state.prismUser.id) return;
    if (!hasNew(topic)) return;
    final String uid = app_state.prismUser.id;
    final int generation = _seenGenerations[uid] ?? 0;
    await _markSeenAt(uid, topic, _latestMs[topic.key] ?? 0, generation: generation);
    if (!app_state.prismUser.loggedIn ||
        app_state.prismUser.id != uid ||
        _loadedFor != uid ||
        generation != (_seenGenerations[uid] ?? 0)) {
      return;
    }
    notifyListeners();
  }

  /// Removes this account's local new-wall markers when it signs out or is deleted.
  Future<void> clearLocalSeenForUser(String uid) async {
    _seenGenerations[uid] = (_seenGenerations[uid] ?? 0) + 1;
    _loading.remove(uid);
    for (final String key in <String>[
      for (final String category in prismClassifierCategories) ...<String>[
        '$_seenPrefix$uid.category:$category',
        '${_seenPrefix}category:$category',
      ],
      for (final WallMood mood in WallMood.values) ...<String>[
        '$_seenPrefix$uid.mood:${mood.id}',
        '${_seenPrefix}mood:${mood.id}',
      ],
    ]) {
      try {
        await _settings.delete(key);
      } catch (error, stackTrace) {
        logger.w('Followed topic state did not clear.', tag: 'Topics', error: error, stackTrace: stackTrace);
      }
    }
    if (_loadedFor == uid) {
      _topics = const <FollowedTopic>[];
      _latestMs = const <String, int>{};
      _loadedFor = null;
      notifyListeners();
    }
  }

  String _seenKey(String uid, FollowedTopic topic) => '$_seenPrefix$uid.${topic.key}';

  int _seenMs(FollowedTopic topic) =>
      app_state.prismUser.loggedIn ? _settings.get<int?>(_seenKey(app_state.prismUser.id, topic)) ?? 0 : 0;

  Future<void> _markSeenAt(String uid, FollowedTopic topic, int ms, {required int generation}) async {
    if (generation != (_seenGenerations[uid] ?? 0)) return;
    final String key = _seenKey(uid, topic);
    try {
      await _settings.set(key, ms);
      if (generation != (_seenGenerations[uid] ?? 0)) await _settings.delete(key);
    } catch (error, stackTrace) {
      logger.w('Followed topic state did not save.', tag: 'Topics', error: error, stackTrace: stackTrace);
    }
  }

  Future<T> _enqueueMutation<T>(String uid, Future<T> Function() operation) {
    final Future<void> previous = _mutationTails[uid] ?? Future<void>.value();
    final Future<T> result = previous.then((_) => operation());
    late final Future<void> tail;
    tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    _mutationTails[uid] = tail;
    return result.whenComplete(() {
      if (identical(_mutationTails[uid], tail)) _mutationTails.remove(uid);
    });
  }

  Future<void> _syncOffset(String uid, int generation) async {
    try {
      await _firestore.runTransaction<void>(
        (FirestoreTransaction transaction) async {
          final Map<String, dynamic>? session = await transaction.getDoc(_sessionPath(uid), 'session');
          if (!app_state.prismUser.loggedIn ||
              app_state.prismUser.id != uid ||
              generation != (_seenGenerations[uid] ?? 0)) {
            return;
          }
          final Object? rawTopics = session?[topicsField];
          final bool hasTopics = rawTopics is List && rawTopics.isNotEmpty;
          if (hasTopics) {
            if (session?[offsetField] != _deviceOffset) {
              transaction.updateDoc(_sessionPath(uid), 'session', <String, dynamic>{offsetField: _deviceOffset});
            }
          } else if (session?.containsKey(offsetField) == true) {
            transaction.updateDoc(_sessionPath(uid), 'session', <String, dynamic>{
              offsetField: FirestoreSentinels.delete(),
            });
          }
        },
        sourceTag: 'followed_topics.sync_offset',
        collection: _sessionPath(uid),
        docId: 'session',
      );
    } catch (error, stackTrace) {
      logger.w('Followed topics offset did not sync.', tag: 'Topics', error: error, stackTrace: stackTrace);
    }
  }

  Future<TopicFollowResult> _changeTopic(
    String uid,
    FollowedTopic topic, {
    required int generation,
    required bool follow,
  }) async {
    try {
      return await _firestore.runTransaction<TopicFollowResult>(
        (FirestoreTransaction transaction) async {
          final Map<String, dynamic>? session = await transaction.getDoc(_sessionPath(uid), 'session');
          if (!app_state.prismUser.loggedIn ||
              app_state.prismUser.id != uid ||
              generation != (_seenGenerations[uid] ?? 0)) {
            return TopicFollowResult.failed;
          }
          final Object? rawTopics = session?[topicsField];
          final List<Object?> keys = rawTopics is List ? List<Object?>.of(rawTopics) : <Object?>[];
          final bool alreadyFollowed = keys.contains(topic.key);
          if (follow && alreadyFollowed) return TopicFollowResult.done;
          if (!follow && !alreadyFollowed && keys.isNotEmpty) return TopicFollowResult.done;
          if (!follow && !alreadyFollowed && session?.containsKey(offsetField) != true) return TopicFollowResult.done;
          if (follow && keys.toSet().length >= FollowedTopic.maxFollowed) return TopicFollowResult.limit;

          final List<Object?> remaining = follow
              ? <Object?>[...keys, topic.key]
              : keys.where((Object? key) => key != topic.key).toList(growable: false);
          transaction.setDoc(_sessionPath(uid), 'session', <String, dynamic>{
            topicsField: follow
                ? FirestoreSentinels.arrayUnion(<Object?>[topic.key])
                : FirestoreSentinels.arrayRemove(<Object?>[topic.key]),
            if (follow) offsetField: _deviceOffset,
            if (!follow && remaining.isEmpty) offsetField: FirestoreSentinels.delete(),
          }, merge: true);
          return TopicFollowResult.done;
        },
        sourceTag: follow ? 'followed_topics.follow' : 'followed_topics.unfollow',
        collection: _sessionPath(uid),
        docId: 'session',
      );
    } catch (error, stackTrace) {
      logger.w('Followed topics did not save.', tag: 'Topics', error: error, stackTrace: stackTrace);
      return TopicFollowResult.failed;
    }
  }
}
