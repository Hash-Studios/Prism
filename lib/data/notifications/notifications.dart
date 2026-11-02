import 'dart:async';

import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:Prism/core/firestore/firestore_error.dart';
import 'package:Prism/core/firestore/firestore_query_specs.dart';
import 'package:Prism/core/firestore/firestore_runtime.dart';
import 'package:Prism/core/persistence/data_sources/notifications_local_data_source.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/core/user_blocks/blocked_creators.dart';
import 'package:Prism/core/utils/json_utils.dart';
import 'package:Prism/core/wallpaper/parse_helpers.dart';
import 'package:Prism/data/notifications/notification_tombstones.dart';
import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/logger/logger.dart';

const int _defaultNotifLimit = 50;

const Duration _syncCooldown = Duration(seconds: 45);
const Duration _persistedSyncCooldown = Duration(minutes: 5);

final Map<String, Future<void>> _syncInFlightByKey = <String, Future<void>>{};
final Map<String, DateTime> _lastSyncEndedAtByKey = <String, DateTime>{};
int _notificationSessionGeneration = 0;

/// Clears in-flight sync futures and cooldown timestamps for every account key.
void clearInAppNotificationSyncGateAll() {
  _notificationSessionGeneration++;
  _syncInFlightByKey.clear();
  _lastSyncEndedAtByKey.clear();
}

String _notificationAudienceTag() => app_state.prismUser.premium ? 'premium' : 'free';

String _notificationOwnerId() {
  final user = app_state.prismUser;
  final String userId = user.id.trim();
  return user.loggedIn && userId.isNotEmpty ? userId : 'guest';
}

/// Stable key for sync gating: same identity + premium tier as [_notificationModifiers] audience.
String _notificationSyncGateKey() {
  final u = app_state.prismUser;
  final String stableId = u.id.trim();
  if (!u.loggedIn || stableId.isEmpty) {
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
    ),
    (data, _) => data,
  );
}

bool _isNotificationFromBlockedCreator(InAppNotificationEntity e, BlockedCreators blocked) {
  final String uid = e.followerUid?.trim() ?? '';
  if (uid.isNotEmpty) return blocked.blocks(uid);
  final String route = (e.route ?? e.pageName).toLowerCase();
  final String copyKind = e.copyKind?.toLowerCase() ?? '';
  final bool followerNotification =
      e.kind == InAppNotificationKind.follower ||
      route == 'follower' ||
      route.endsWith('/follower') ||
      copyKind == 'follower';
  return followerNotification;
}

List<InAppNotificationEntity> _filterBlockedActors(
  List<InAppNotificationEntity> entities,
  KnownBlockedCreators blocked,
) {
  if (blocked.uids.isEmpty) {
    return entities;
  }
  return entities
      .where((InAppNotificationEntity e) => !_isNotificationFromBlockedCreator(e, blocked))
      .toList(growable: false);
}

/// Removes cached notifications from blocked creators. Returns false, and keeps the cache, while the block list is
/// unknown, because the cache may still hold their notifications.
Future<bool> pruneBlockedNotificationsCache({NotificationsLocalDataSource? notificationsLocal}) async {
  final NotificationsLocalDataSource local = notificationsLocal ?? getIt<NotificationsLocalDataSource>();
  final String owner = local.ownerId;
  final int generation = local.ownerGeneration;
  final BlockedCreators blocked = await getIt<UserBlockRepository>().loadBlockedCreators();
  if (blocked is! KnownBlockedCreators) return false;
  if (local.ownerId != owner || local.ownerGeneration != generation || blocked.uids.isEmpty) return true;
  await local.removeWhere((InAppNotificationEntity item) => _isNotificationFromBlockedCreator(item, blocked));
  return true;
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
  final Map<String, dynamic> data = toJsonMap(raw['data']);
  final Map<String, dynamic> notification = toJsonMap(raw['notification']);
  final Map<String, dynamic> message = toJsonMap(raw['message']);
  final DateTime createdAt = _createdAtFrom(raw['createdAt']).toUtc();
  final String title = notification['title']?.toString() ?? '';
  final String body = notification['body']?.toString() ?? '';
  final String pageName = data['pageName']?.toString() ?? '';
  final String url = data['url']?.toString() ?? '';
  final String imageUrl = data['imageUrl']?.toString().trim() ?? '';
  final Object? arguments = data['arguments'];
  final InAppNotificationKind? kind = switch (data['notification_kind']) {
    'follower' => InAppNotificationKind.follower,
    'wall_live' => InAppNotificationKind.wallLive,
    'wall_approved' => InAppNotificationKind.wallApproved,
    'wall_of_the_day' => InAppNotificationKind.wallOfTheDay,
    'generic' => InAppNotificationKind.generic,
    _ => null,
  };
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
    followerUid: data['follower_uid']?.toString(),
    kind: kind,
    copyKind: message['kind']?.toString() ?? data['notification_copy_kind']?.toString(),
    copyArgs: toJsonMap(message['args']).cast<String, Object?>(),
  );
}

Future<void> syncInAppNotificationsFromRemote({bool force = false}) async {
  if (!app_state.prismUser.loggedIn) {
    logger.d('Skipping in-app notification sync — user not signed in');
    return;
  }
  final String ownerId = _notificationOwnerId();
  getIt<NotificationsLocalDataSource>().setOwner(ownerId);
  getIt<NotificationTombstones>().setOwner(ownerId);
  final String gateKey = _notificationSyncGateKey();
  if (gateKey.isEmpty) {
    logger.d('Skipping in-app notification sync — missing user id');
    return;
  }
  final int sessionGeneration = _notificationSessionGeneration;
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
    final bool ok = await _syncInAppNotificationsFromRemoteBody(
      force: force,
      gateKey: gateKey,
      sessionGeneration: sessionGeneration,
    );
    if (ok && sessionGeneration == _notificationSessionGeneration && gateKey == _notificationSyncGateKey()) {
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
Future<bool> _syncInAppNotificationsFromRemoteBody({
  required bool force,
  required String gateKey,
  required int sessionGeneration,
}) async {
  logger.d('Fetching in-app notifications');
  try {
    final NotificationsLocalDataSource notificationsLocal = getIt<NotificationsLocalDataSource>();
    final String ownerId = _notificationOwnerId();
    notificationsLocal.setOwner(ownerId);
    final int ownerGeneration = notificationsLocal.ownerGeneration;
    final NotificationTombstones tombstones = getIt<NotificationTombstones>();
    tombstones.setOwner(ownerId);
    final int tombstoneGeneration = tombstones.ownerGeneration;
    bool isCurrentSession() =>
        sessionGeneration == _notificationSessionGeneration &&
        gateKey == _notificationSyncGateKey() &&
        ownerGeneration == notificationsLocal.ownerGeneration &&
        ownerId == notificationsLocal.ownerId &&
        tombstoneGeneration == tombstones.ownerGeneration &&
        ownerId == tombstones.ownerId;

    final DateTime nowUtc = DateTime.now().toUtc();
    final DateTime? lastFetchTime = await notificationsLocal.lastFetchAtUtc();
    final BlockedCreators blocked = await getIt<UserBlockRepository>().loadBlockedCreators();
    // An unknown list would drop every follower notification from the cache for good. Sync again later.
    if (!isCurrentSession() || blocked is! KnownBlockedCreators) return false;

    if (blocked.uids.isNotEmpty) {
      await notificationsLocal.removeWhere(
        (InAppNotificationEntity item) => _isNotificationFromBlockedCreator(item, blocked),
      );
    }
    if (!isCurrentSession()) return false;
    if (!force &&
        lastFetchTime != null &&
        !lastFetchTime.isAfter(nowUtc) &&
        nowUtc.difference(lastFetchTime) < _persistedSyncCooldown) {
      return true;
    }

    if (force || lastFetchTime == null || lastFetchTime.isAfter(nowUtc)) {
      final DateTime fetchFloor = await tombstones.fetchFloor(nowUtc.subtract(const Duration(days: 30)));
      if (!isCurrentSession()) return false;
      final List<Map<String, dynamic>> snap = await _fetchNotificationsSince(
        sinceUtc: fetchFloor,
        sourceTag: force ? 'notifications.force_backfill' : 'notifications.last_month',
      );
      if (!isCurrentSession()) return false;
      final entities = await tombstones.withoutRemoved(
        _filterBlockedActors(snap.map(toJsonMap).map(_toEntity).toList(growable: false), blocked),
      );
      if (!isCurrentSession()) return false;
      await notificationsLocal.replaceAllPreservingReadState(
        entities,
        filterRemoved: tombstones.withoutRemoved,
        isCurrentSession: isCurrentSession,
      );
      if (!isCurrentSession()) return false;
      await notificationsLocal.setLastFetchAtUtc(nowUtc);
      if (!isCurrentSession()) return false;
      return true;
    }

    final List<Map<String, dynamic>> snap = await _fetchNotificationsSince(
      sinceUtc: lastFetchTime,
      sourceTag: 'notifications.latest',
    );
    if (!isCurrentSession()) return false;
    final entities = await tombstones.withoutRemoved(
      _filterBlockedActors(snap.map(toJsonMap).map(_toEntity).toList(growable: false), blocked),
    );
    if (!isCurrentSession()) return false;
    if (entities.isNotEmpty) {
      await notificationsLocal.upsertAll(entities);
    }
    if (!isCurrentSession()) return false;
    await notificationsLocal.setLastFetchAtUtc(nowUtc);
    if (!isCurrentSession()) return false;
    return true;
  } on FirestoreError catch (e) {
    logger.w('syncInAppNotificationsFromRemote failed (code=${e.code}): ${e.message}');
    return false;
  } catch (e) {
    logger.w('syncInAppNotificationsFromRemote failed: $e');
    return false;
  }
}
