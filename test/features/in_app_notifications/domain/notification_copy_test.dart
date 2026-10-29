import 'package:Prism/features/in_app_notifications/domain/entities/in_app_notification_entity.dart';
import 'package:Prism/features/in_app_notifications/domain/notification_copy.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../in_app_notification_fixture.dart';

void main() {
  late AppLocalizations l10n;

  setUpAll(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  test('structured notification copy localizes known server message kinds', () {
    final InAppNotificationEntity item = notification(
      'follow',
      title: 'Legacy title',
      body: 'Legacy body',
    ).copyWith(copyKind: 'newFollower', copyArgs: const <String, Object?>{'followerName': 'Asha'});

    expect(localizedNotificationCopy(item, l10n), (
      title: 'You have a new follower! 🎉',
      body: 'Asha is now following you.',
    ));
  });

  test('unknown and historical notifications keep stored copy', () {
    final InAppNotificationEntity item = notification(
      'legacy',
      title: 'Old announcement',
      body: 'Written before structured copy was added.',
    );

    expect(localizedNotificationCopy(item, l10n), (
      title: 'Old announcement',
      body: 'Written before structured copy was added.',
    ));
  });

  test('report notification copy localizes known and unknown wire labels', () {
    expect(
      localizedNotificationCopyData(
        'reportNeedsReview',
        const <String, Object?>{'contentType': 'user', 'reason': 'spam'},
        fallbackTitle: '',
        fallbackBody: '',
        l10n: l10n,
      ),
      (
        title: l10n.notifPushReportReviewTitle,
        body: l10n.notifPushReportReviewBody(l10n.coreContentReportUser, l10n.coreReportReasonSpam),
      ),
    );
    expect(
      localizedNotificationCopyData(
        'reportNeedsReview',
        const <String, Object?>{'contentType': 'unrecognized', 'reason': 'unrecognized'},
        fallbackTitle: '',
        fallbackBody: '',
        l10n: l10n,
      ),
      (
        title: l10n.notifPushReportReviewTitle,
        body: l10n.notifPushReportReviewBody(l10n.notifReportUnknownContentType, l10n.coreReportReasonOther),
      ),
    );
    expect(
      localizedNotificationCopyData(
        'newContentReport',
        const <String, Object?>{'contentType': 'setup', 'reason': 'harassment', 'targetId': 'wall-17'},
        fallbackTitle: '',
        fallbackBody: '',
        l10n: l10n,
      ),
      (
        title: l10n.notifPushNewContentReportTitle,
        body: l10n.notifPushNewContentReportBody(
          l10n.coreContentReportWallpaper,
          l10n.coreReportReasonHarassment,
          'wall-17',
        ),
      ),
    );
    expect(
      localizedNotificationCopyData(
        'newContentReport',
        const <String, Object?>{'contentType': 'unknown', 'reason': 'unknown', 'targetId': 'user-8'},
        fallbackTitle: '',
        fallbackBody: '',
        l10n: l10n,
      ),
      (
        title: l10n.notifPushNewContentReportTitle,
        body: l10n.notifPushNewContentReportBody(
          l10n.notifReportUnknownContentType,
          l10n.coreReportReasonOther,
          'user-8',
        ),
      ),
    );
  });

  test('an empty or whitespace wall title uses the untitled approval copy', () {
    for (final String wallTitle in <String>['', '   ']) {
      expect(
        localizedNotificationCopyData(
          'wallApprovedForArtist',
          <String, Object?>{'wallTitle': wallTitle},
          fallbackTitle: '',
          fallbackBody: '',
          l10n: l10n,
        ),
        (title: l10n.notifPushWallApprovedArtistTitle, body: l10n.notifPushWallApprovedArtistBodyUntitled),
      );
    }
  });

  test('an empty or whitespace WOTD title uses the untitled audience copy', () {
    for (final String wallTitle in <String>['', '   ']) {
      expect(
        localizedNotificationCopyData(
          'wotdForAudience',
          <String, Object?>{'wallTitle': wallTitle},
          fallbackTitle: '',
          fallbackBody: '',
          l10n: l10n,
        ),
        (title: l10n.notifPushWotdAudienceTitle, body: l10n.notifPushWotdAudienceBodyUntitled),
      );
    }
  });

  test('a wall remix names the remixer and the wall', () {
    final InAppNotificationEntity item = notification(
      'wall_remixed',
      title: 'Legacy title',
      body: 'Legacy body',
    ).copyWith(copyKind: 'wallRemixed', copyArgs: const <String, Object?>{'remixerName': 'Asha', 'wallTitle': 'Koi'});

    expect(localizedNotificationCopy(item, l10n), (title: l10n.notifPushWallRemixedTitle, body: 'Asha remixed Koi.'));
  });

  test('a wall remix with an empty wall title uses the untitled copy', () {
    final InAppNotificationEntity item = notification(
      'wall_remixed',
      title: 'Legacy title',
      body: 'Legacy body',
    ).copyWith(copyKind: 'wallRemixed', copyArgs: const <String, Object?>{'remixerName': 'Asha', 'wallTitle': '  '});

    expect(localizedNotificationCopy(item, l10n), (
      title: l10n.notifPushWallRemixedTitle,
      body: 'Asha remixed your wallpaper.',
    ));
  });
}
