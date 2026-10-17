import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/session/domain/repositories/session_repository.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

void _trackBlockAction(String action, {required bool success}) {
  unawaited(analytics.track(UserBlockActionEvent(action: action, result: success ? 'success' : 'failure')));
}

bool _isPendingSync(Result<void> result) => result.failure?.message.startsWith('Pending sync:') ?? false;

void _showBlockResult(Result<void> result, {required String successMessage}) {
  if (_isPendingSync(result)) {
    toasts.info(result.failure!.message.substring('Pending sync:'.length).trim());
  } else if (result.isFailure) {
    toasts.error(result.failure?.message ?? 'Could not update blocked accounts');
  } else {
    toasts.success(successMessage);
  }
}

/// Unblocks a user and tells the viewer how it went. Returns whether it worked.
Future<bool> unblockUserWithFeedback(BuildContext context, String targetUserId) async {
  final Result<void> result = await getIt<UserBlockRepository>().unblockUser(targetUserId: targetUserId);
  if (!context.mounted) {
    return false;
  }
  _trackBlockAction('unblock', success: result.isSuccess || _isPendingSync(result));
  if (result.isFailure) {
    _showBlockResult(result, successMessage: 'Unblocked');
    return _isPendingSync(result);
  }
  _showBlockResult(result, successMessage: 'Unblocked');
  return true;
}

/// Confirms and blocks a user; updates session following, unsubscribes FCM artist topic.
Future<void> confirmAndBlockUser({
  required BuildContext context,
  required String targetUserId,
  required String targetEmail,
  String? displayName,
}) async {
  final String name = displayName == null || displayName.trim().isEmpty ? 'this user' : displayName.trim();
  final bool ok = await showPrismConfirm(
    context,
    title: 'Block $name?',
    message:
        'You will unfollow $name, stop seeing their wallpapers in feeds, '
        'and no longer get notifications about their new posts.',
    confirmLabel: 'Block',
    destructive: true,
  );
  if (!ok || !context.mounted) {
    return;
  }
  PrismHaptics.tap();

  final UserBlockRepository blocks = getIt<UserBlockRepository>();
  final Result<void> result = await blocks.blockUser(targetUserId: targetUserId, targetEmail: targetEmail);
  if (!context.mounted) {
    return;
  }
  _trackBlockAction('block', success: result.isSuccess || _isPendingSync(result));
  if (result.isFailure) {
    _showBlockResult(result, successMessage: 'Blocked $name');
    return;
  }

  unawaited(syncInAppNotificationsFromRemote(force: true));
  await setCreatorPostsTopics(
    FirebaseMessaging.instance,
    <String>[targetEmail],
    subscribed: false,
    sourceTag: 'user_block.unsubscribe_posts',
  );

  final SessionRepository session = getIt<SessionRepository>();
  final List<String> following = session.currentUser.following;
  final String targetNorm = targetEmail.trim().toLowerCase();
  final List<String> next = following.where((String e) => e.trim().toLowerCase() != targetNorm).toList(growable: false);
  if (next.length != following.length) {
    await session.updateFollowing(next);
  }

  _showBlockResult(result, successMessage: 'Blocked $name');
}
