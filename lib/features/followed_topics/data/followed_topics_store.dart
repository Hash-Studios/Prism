import 'dart:async';

import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_sentinels.dart';
import 'package:Prism/core/persistence/data_sources/settings_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/followed_topics/domain/entities/followed_topic.dart';
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
  Future<void>? _loading;

  /// Followed topics in follow order. Empty for a guest.
  List<FollowedTopic> get topics =>
      app_state.prismUser.loggedIn && _loadedFor == app_state.prismUser.id ? _topics : const <FollowedTopic>[];

  bool isFollowed(FollowedTopic topic) => topics.contains(topic);

  /// A Prism wall landed in [topic] after the user last opened its page on this device.
  bool hasNew(FollowedTopic topic) => (_latestMs[topic.key] ?? 0) > _seenMs(topic);

  String get _sessionPath => '${FirebaseCollections.usersV2}/${app_state.prismUser.id}/private';

  static int get _deviceOffset => roundedTimezoneOffsetMinutes(DateTime.now().timeZoneOffset);

  /// Reads the account list once per signed-in user. A second call for the same user does nothing.
  Future<void> ensureLoaded() {
    if (!app_state.prismUser.loggedIn) return Future<void>.value();
    if (_loadedFor == app_state.prismUser.id) return Future<void>.value();
    return _loading ??= _load(app_state.prismUser.id).whenComplete(() => _loading = null);
  }

  Future<void> _load(String uid) async {
    try {
      final (List<FollowedTopic>, Object?)? session = await _firestore.getById(
        '${FirebaseCollections.usersV2}/$uid/private',
        'session',
        (data, _) => (_parseTopics(data[topicsField]), data[offsetField]),
        sourceTag: 'followed_topics.load',
      );
      final Map<String, int> latest = await _readNews();
      if (app_state.prismUser.id != uid) return;
      _topics = session?.$1 ?? const <FollowedTopic>[];
      _latestMs = latest;
      _loadedFor = uid;
      for (final FollowedTopic topic in _topics) {
        if (_settings.get<int?>('$_seenPrefix${topic.key}') == null) await _markSeenAt(topic, latest[topic.key] ?? 0);
      }
      notifyListeners();
      // The user changed time zone since the last write: move the daily push to the new 16:00.
      if (_topics.isNotEmpty && session?.$2 != _deviceOffset) {
        await _write(<String, dynamic>{offsetField: _deviceOffset}, 'followed_topics.sync_offset');
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
  Future<TopicFollowResult> follow(FollowedTopic topic) async {
    if (!app_state.prismUser.loggedIn) return TopicFollowResult.failed;
    await ensureLoaded();
    if (isFollowed(topic)) return TopicFollowResult.done;
    if (topics.length >= FollowedTopic.maxFollowed) return TopicFollowResult.limit;
    final List<FollowedTopic> before = _topics;
    _topics = List<FollowedTopic>.unmodifiable(<FollowedTopic>[..._topics, topic]);
    await _markSeenAt(topic, DateTime.now().millisecondsSinceEpoch);
    notifyListeners();
    final bool saved = await _write(<String, dynamic>{
      topicsField: FirestoreSentinels.arrayUnion(<Object?>[topic.key]),
      offsetField: _deviceOffset,
    }, 'followed_topics.follow');
    if (saved) return TopicFollowResult.done;
    _topics = before;
    notifyListeners();
    return TopicFollowResult.failed;
  }

  /// Stops following [topic]. Returns false when the account did not save the change.
  Future<bool> unfollow(FollowedTopic topic) async {
    if (!isFollowed(topic)) return true;
    final List<FollowedTopic> before = _topics;
    _topics = List<FollowedTopic>.unmodifiable(_topics.where((t) => t != topic));
    notifyListeners();
    final bool saved = await _write(<String, dynamic>{
      topicsField: FirestoreSentinels.arrayRemove(<Object?>[topic.key]),
      if (_topics.isEmpty) offsetField: FirestoreSentinels.delete(),
    }, 'followed_topics.unfollow');
    if (saved) return true;
    _topics = before;
    notifyListeners();
    return false;
  }

  /// The user opened the page of [topic]: its dot goes away until a newer wall lands.
  Future<void> markSeen(FollowedTopic topic) async {
    if (!hasNew(topic)) return;
    await _markSeenAt(topic, _latestMs[topic.key] ?? 0);
    notifyListeners();
  }

  int _seenMs(FollowedTopic topic) => _settings.get<int?>('$_seenPrefix${topic.key}') ?? 0;

  Future<void> _markSeenAt(FollowedTopic topic, int ms) => _settings.set('$_seenPrefix${topic.key}', ms);

  Future<bool> _write(Map<String, dynamic> data, String sourceTag) async {
    try {
      await _firestore.setDoc(_sessionPath, 'session', data, merge: true, sourceTag: sourceTag);
      return true;
    } catch (error, stackTrace) {
      logger.w('Followed topics did not save.', tag: 'Topics', error: error, stackTrace: stackTrace);
      return false;
    }
  }
}
