import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/haptics/prism_haptics.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/core/widgets/prism_sheet.dart';
import 'package:Prism/data/notifications/notifications.dart';
import 'package:Prism/features/user_blocks/domain/repositories/user_block_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/notifications/topic_subscription.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

void _trackBlockAction(String action, {required bool success}) {
  unawaited(analytics.track(UserBlockActionEvent(action: action, result: success ? 'success' : 'failure')));
}

bool _isPendingSync(Result<void> result) => result.failure?.message.startsWith('Pending sync:') ?? false;

void _showBlockResult(BuildContext context, Result<void> result, {required String successMessage}) {
  if (_isPendingSync(result)) {
    toasts.info(context.l10n.accountBlockActionPendingSync);
  } else if (result.isFailure) {
    toasts.error(context.l10n.accountBlockActionFailed);
  } else {
    toasts.success(successMessage);
  }
}

/// Unblocks a user and tells the viewer how it went. Returns whether it worked.
Future<bool> unblockUserWithFeedback(BuildContext context, String targetUserId) async {
  final AppLocalizations l10n = context.l10n;
  final Result<void> result = await getIt<UserBlockRepository>().unblockUser(targetUserId: targetUserId);
  if (!context.mounted) {
    return false;
  }
  _trackBlockAction('unblock', success: result.isSuccess || _isPendingSync(result));
  if (result.isFailure) {
    _showBlockResult(context, result, successMessage: l10n.accountUserUnblocked);
    return _isPendingSync(result);
  }
  _showBlockResult(context, result, successMessage: l10n.accountUserUnblocked);
  return true;
}

/// Confirms and blocks a user; updates session following, unsubscribes FCM artist topic.
Future<void> confirmAndBlockUser({
  required BuildContext context,
  required String targetUserId,
  String? displayName,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String name = displayName == null || displayName.trim().isEmpty
      ? l10n.accountBlockConfirmationUserFallback
      : displayName.trim();
  final bool ok = await showPrismConfirm(
    context,
    title: l10n.accountBlockThisUserTitle(name),
    message: l10n.accountBlockUserMessage(name),
    confirmLabel: l10n.accountBlock,
    destructive: true,
  );
  if (!ok || !context.mounted) {
    return;
  }
  PrismHaptics.tap();

  final UserBlockRepository blocks = getIt<UserBlockRepository>();
  final Result<void> result = await blocks.blockUser(targetUserId: targetUserId);
  if (!context.mounted) {
    return;
  }
  _trackBlockAction('block', success: result.isSuccess || _isPendingSync(result));
  if (result.isFailure) {
    _showBlockResult(context, result, successMessage: l10n.accountUserBlocked(name));
    return;
  }

  unawaited(syncInAppNotificationsFromRemote(force: true));
  await setCreatorPostsTopicForUid(
    FirebaseMessaging.instance,
    targetUserId,
    subscribed: false,
    sourceTag: 'user_block.unsubscribe_posts',
  );

  if (!context.mounted) return;
  _showBlockResult(context, result, successMessage: l10n.accountUserBlocked(name));
}
