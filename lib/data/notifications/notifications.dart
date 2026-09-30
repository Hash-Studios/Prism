import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators_filter.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';

const int _defaultNotifLimit = 50;

const Duration _syncCooldown = Duration(seconds: 45);

final Map<String, Future<void>> _syncInFlightByKey = <String, Future<void>>{};
final Map<String, DateTime> _lastSyncEndedAtByKey = <String, DateTime>{};

/// Clears in-flight sync futures and cooldown timestamps for every account key.
///
/// Call when the session becomes signed out so another account does not inherit
/// cooldown or await another user's sync future.
void clearInAppNotificationSyncGateAll() {
  _syncInFlightByKey.clear();
  _lastSyncEndedAtByKey.clear();
}

Map<String, dynamic> _asMap(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return raw;
  }
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return <String, dynamic>{};
}

String _notificationAudienceTag() => app_state.prismUser.premium ? 'premium' : 'free';

/// Stable key for sync gating: same identity + premium tier as [_notificationModifiers] audience.
String _notificationSyncGateKey() {
  final u = app_state.prismUser;
  final String stableId = u.id.trim().isNotEmpty ? u.id.trim() : u.email.trim().toLowerCase();
  if (stableId.isEmpty) {
    return '';
  }
  return '$stableId|${_notificationAudienceTag()}';
}

List<String> _notificationModifiers() {
  final String audience = _notificationAudienceTag();
  return <String>[
    audience,
    'all',
    app_state.currentAppVersion.trim(),
    app_state.prismUser.email.trim(),
  ].where((value) => value.isNotEmpty).toSet().toList(growable: false);
}

Future<List<Map<String, dynamic>>> _fetchNotificationsSince({
  required DateTime sinceUtc,
  required String sourceTag,
  int limit = _defaultNotifLimit,
  FirestoreCachePolicy cachePolicy = FirestoreCachePolicy.networkOnly,
}) async {
  final List<String> modifiers = _notificationModifiers();
  if (modifiers.isEmpty) {
    return <Map<String, dynamic>>[];
  }
  return firestoreClient.query<Map<String, dynamic>>(
    FirestoreQuerySpec(
      collection: FirebaseCollections.notifications,
      sourceTag: sourceTag,
      filters: <FirestoreFilter>[
        FirestoreFilter(field: 'createdAt', op: FirestoreFilterOp.isGreaterThan, value: sinceUtc),
        FirestoreFilter(field: 'modifier', op: FirestoreFilterOp.whereIn, value: modifiers),
      ],
      orderBy: const <FirestoreOrderBy>[FirestoreOrderBy(field: 'createdAt', descending: true)],
      limit: limit,
      dedupeWindowMs: 1500,
      cachePolicy: cachePolicy,
    ),
    (data, _) => data,
  );
}

bool _isNotificationFromBlockedCreator(InAppNotificationEntity e, Set<String> blockedLowercaseEmails) {
  if (blockedLowercaseEmails.isEmpty) {
    return false;
  }
  final String? fe = e.followerEmail;
  return BlockedCreatorsFilter.hidesCreatorEmail(fe, blockedLowercaseEmails);
}

List<InAppNotificationEntity> _filterBlockedActors(
  List<InAppNotificationEntity> entities,
  Set<String> blockedLowercaseEmails,
) {
  if (blockedLowercaseEmails.isEmpty) {
    return entities;
  }
  return entities
      .where((InAppNotificationEntity e) => !_isNotificationFromBlockedCreator(e, blockedLowercaseEmails))
      .toList(growable: false);
}

Future<Set<String>> _blockedCreatorEmails({required bool waitForInitialLoad}) {
  return getIt<UserBlockRepository>().getBlockedCreatorEmails(waitForInitialLoad: waitForInitialLoad);
}

Future<void> pruneBlockedNotificationsCache({
  bool waitForInitialLoad = false,
  NotificationsLocalDataSource? notificationsLocal,
}) async {
  final Set<String> blocked = await _blockedCreatorEmails(waitForInitialLoad: waitForInitialLoad);
  if (blocked.isEmpty) {
    return;
  }
  final NotificationsLocalDataSource local = notificationsLocal ?? getIt<NotificationsLocalDataSource>();
  await local.removeWhere((InAppNotificationEntity item) => _isNotificationFromBlockedCreator(item, blocked));
}

Future<void> _replaceAllPreservingReadState(
  NotificationsLocalDataSource notificationsLocal,
  List<InAppNotificationEntity> incoming,
) async {
  final Set<String> readIds = (await notificationsLocal.readAll())
      .where((item) => item.read)
      .map((item) => item.id)
      .toSet();
  final List<InAppNotificationEntity> merged =
      incoming.map((item) => readIds.contains(item.id) ? item.copyWith(read: true) : item).toList(growable: false)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  await notificationsLocal.writeAll(merged);
}

DateTime _createdAtFrom(Object? value) {
  if (value is Map && value.containsKey('_seconds')) {
    final int seconds = value['_seconds'] as int? ?? 0;
    final int nanoseconds = value['_nanoseconds'] as int? ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000 + nanoseconds ~/ 1000000);
  }
  return parseDateTime(value) ?? DateTime.now();
}

InAppNotificationEntity _toEntity(Map<String, dynamic> raw) {
  final Map<String, dynamic> data = _asMap(raw['data']);
  final Map<String, dynamic> notification = _asMap(raw['notification']);
  final DateTime createdAt = _createdAtFrom(raw['createdAt']).toUtc();
  final String title = notification['title']?.toString() ?? '';
  final String body = notification['body']?.toString() ?? '';
  final String pageName = data['pageName']?.toString() ?? '';
  final String url = data['url']?.toString() ?? '';
  final String imageUrl = data['imageUrl']?.toString().trim() ?? '';
  final Object? arguments = data['arguments'];
  return InAppNotificationEntity(
    id: buildInAppNotificationId(title: title, body: body, pageName: pageName, url: url, createdAt: createdAt),
    title: title,
    pageName: pageName,
    body: body,
    imageUrl: (Uri.tryParse(imageUrl)?.host.isNotEmpty ?? false) ? imageUrl : '',
    arguments: arguments is List ? arguments.whereType<Object>().toList(growable: false) : const <Object>[],
    url: url,
    createdAt: createdAt,
    read: false,
    route: data['route']?.toString(),
    wallId: data['wall_id']?.toString(),
    followerEmail: (data['follower_email'] ?? data['profile_identifier'] ?? data['username'])?.toString(),
  );
}

Future<void> syncInAppNotificationsFromRemote({bool force = false}) async {
  if (!app_state.prismUser.loggedIn) {
    logger.d('Skipping in-app notification sync — user not signed in');
    return;
  }
  final String gateKey = _notificationSyncGateKey();
  if (gateKey.isEmpty) {
    logger.d('Skipping in-app notification sync — missing user id/email');
    return;
  }
  final Future<void>? existing = _syncInFlightByKey[gateKey];
  if (existing != null) {
    await existing;
    return;
  }
  final DateTime now = DateTime.now();
  final DateTime? lastEnd = _lastSyncEndedAtByKey[gateKey];
  if (!force && lastEnd != null && now.difference(lastEnd) < _syncCooldown) {
    return;
  }

  Future<void> runOne() async {
    final bool ok = await _syncInAppNotificationsFromRemoteBody(force: force);
    if (ok) {
      _lastSyncEndedAtByKey[gateKey] = DateTime.now();
    }
  }

  final Future<void> run = runOne();
  _syncInFlightByKey[gateKey] = run;
  try {
    await run;
  } finally {
    if (identical(_syncInFlightByKey[gateKey], run)) {
      _syncInFlightByKey.remove(gateKey);
    }
  }
}

/// Returns `true` if local state was updated from remote without error.
Future<bool> _syncInAppNotificationsFromRemoteBody({required bool force}) async {
  logger.d('Fetching in-app notifications');
  try {
    final NotificationsLocalDataSource notificationsLocal = getIt<NotificationsLocalDataSource>();
    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime? lastFetchTime = notificationsLocal.lastFetchAtUtc();
    final Set<String> blocked = await _blockedCreatorEmails(waitForInitialLoad: true);

    if (blocked.isNotEmpty) {
      await notificationsLocal.removeWhere(
        (InAppNotificationEntity item) => _isNotificationFromBlockedCreator(item, blocked),
      );
    }

    if (force || lastFetchTime == null) {
      final List<Map<String, dynamic>> snap = await _fetchNotificationsSince(
        sinceUtc: nowUtc.subtract(const Duration(days: 30)),
        sourceTag: force ? 'notifications.force_backfill' : 'notifications.last_month',
      );
      final entities = _filterBlockedActors(snap.map(_asMap).map(_toEntity).toList(growable: false), blocked);
      await _replaceAllPreservingReadState(notificationsLocal, entities);
      await notificationsLocal.setLastFetchAtUtc(nowUtc);
      return true;
    }

    final List<Map<String, dynamic>> snap = await _fetchNotificationsSince(
      sinceUtc: lastFetchTime,
      sourceTag: 'notifications.latest',
      cachePolicy: FirestoreCachePolicy.memoryFirst,
    );
    final entities = _filterBlockedActors(snap.map(_asMap).map(_toEntity).toList(growable: false), blocked);
    if (entities.isNotEmpty) {
      await notificationsLocal.upsertAll(entities);
    }
    await notificationsLocal.setLastFetchAtUtc(nowUtc);
    return true;
  } on FirestoreError catch (e) {
    logger.w('syncInAppNotificationsFromRemote failed (code=${e.code}): ${e.message}');
    return false;
  } catch (e) {
    logger.w('syncInAppNotificationsFromRemote failed: $e');
    return false;
  }
}
