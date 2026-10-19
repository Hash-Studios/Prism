import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/l10n/l10n.dart';

String _stringArg(Map<String, Object?> args, String key) => switch (args[key]) {
  final String value => value,
  _ => '',
};

int _intArg(Map<String, Object?> args, String key) => switch (args[key]) {
  final int value => value,
  _ => 0,
};

String _reportContentTypeLabel(String wireValue, AppLocalizations l10n) => switch (wireValue) {
  'user' => l10n.coreContentReportUser,
  'wall' || 'setup' => l10n.coreContentReportWallpaper,
  _ => l10n.notifReportUnknownContentType,
};

String _reportReasonLabel(String wireValue, AppLocalizations l10n) => switch (wireValue) {
  'copyright' => l10n.coreReportReasonCopyright,
  'harassment' => l10n.coreReportReasonHarassment,
  'sexual' => l10n.coreReportReasonSexual,
  'spam' => l10n.coreReportReasonSpam,
  'other' => l10n.coreReportReasonOther,
  _ => l10n.coreReportReasonOther,
};

({String title, String body}) localizedNotificationCopy(InAppNotificationEntity notification, AppLocalizations l10n) =>
    localizedNotificationCopyData(
      notification.copyKind,
      notification.copyArgs,
      fallbackTitle: notification.title,
      fallbackBody: notification.body,
      l10n: l10n,
    );

({String title, String body}) localizedNotificationCopyData(
  String? copyKind,
  Map<String, Object?> args, {
  required String fallbackTitle,
  required String fallbackBody,
  required AppLocalizations l10n,
}) => switch (copyKind) {
  'wallApprovedForArtist' => (
    title: l10n.notifPushWallApprovedArtistTitle,
    body: _stringArg(args, 'wallTitle').trim().isEmpty
        ? l10n.notifPushWallApprovedArtistBodyUntitled
        : l10n.notifPushWallApprovedArtistBody(_stringArg(args, 'wallTitle')),
  ),
  'wallLiveForFollowers' => (
    title: l10n.notifPushWallLiveFollowersTitle(_stringArg(args, 'artistName')),
    body: l10n.notifPushWallLiveFollowersBody(_stringArg(args, 'wallTitle')),
  ),
  'wallApprovedForAdmin' => (
    title: l10n.notifPushWallApprovedAdminTitle,
    body: l10n.notifPushWallApprovedAdminBody(_stringArg(args, 'wallTitle'), _stringArg(args, 'artistName')),
  ),
  'newFollower' => (
    title: l10n.notifPushNewFollowerTitle,
    body: l10n.notifPushNewFollowerBody(_stringArg(args, 'followerName')),
  ),
  'streakReminder' => (title: l10n.notifPushStreakReminderTitle, body: l10n.notifPushStreakReminderBody),
  'wotdForCreator' => (title: l10n.notifPushWotdCreatorTitle, body: l10n.notifPushWotdCreatorBody),
  'wotdForAudience' => (
    title: l10n.notifPushWotdAudienceTitle,
    body: _stringArg(args, 'wallTitle').trim().isEmpty
        ? l10n.notifPushWotdAudienceBodyUntitled
        : l10n.notifPushWotdAudienceBody(_stringArg(args, 'wallTitle')),
  ),
  'winBack7' => (title: l10n.notifPushWinBack7Title, body: l10n.notifPushWinBack7Body),
  'winBack14' => (title: l10n.notifPushWinBack14Title, body: l10n.notifPushWinBack14Body),
  'winBack30' => (title: l10n.notifPushWinBack30Title, body: l10n.notifPushWinBack30Body),
  'winBack60' => (title: l10n.notifPushWinBack60Title, body: l10n.notifPushWinBack60Body),
  'dropLive' => (title: l10n.notifPushDropLiveTitle, body: l10n.notifPushDropLiveBody(_intArg(args, 'wallCount'))),
  'dropLastCall' => (
    title: l10n.notifPushDropLastCallTitle,
    body: l10n.notifPushDropLastCallBody(_stringArg(args, 'dropTitle'), _intArg(args, 'hoursLeft')),
  ),
  'drawWinner' => (title: l10n.notifPushDrawWinnerTitle, body: l10n.notifPushDrawWinnerBody),
  'giftReceived' => (
    title: l10n.notifPushGiftReceivedTitle(_stringArg(args, 'senderName')),
    body: l10n.notifPushGiftReceivedBody,
  ),
  'reportNeedsReview' => (
    title: l10n.notifPushReportReviewTitle,
    body: l10n.notifPushReportReviewBody(
      _reportContentTypeLabel(_stringArg(args, 'contentType'), l10n),
      _reportReasonLabel(_stringArg(args, 'reason'), l10n),
    ),
  ),
  'newContentReport' => (
    title: l10n.notifPushNewContentReportTitle,
    body: l10n.notifPushNewContentReportBody(
      _reportContentTypeLabel(_stringArg(args, 'contentType'), l10n),
      _reportReasonLabel(_stringArg(args, 'reason'), l10n),
      _stringArg(args, 'targetId'),
    ),
  ),
  'wallSubmittedForReview' => (
    title: l10n.notifPushWallSubmittedTitle,
    body: l10n.notifPushWallSubmittedBody(_stringArg(args, 'artistName'), _stringArg(args, 'artistEmail')),
  ),
  _ => (title: fallbackTitle, body: fallbackBody),
};
