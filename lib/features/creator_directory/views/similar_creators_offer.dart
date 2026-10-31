import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/biz/similar_creators_offer_session.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/views/widgets/similar_creators_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/widgets.dart';

/// Shows the follow toast at once. Once per app session, when the creator has similar creators the viewer does not
/// follow yet, it then shows the toast again with a "More like `name`" action. An unfollow never calls this.
Future<void> showFollowToastWithSimilarOffer(
  BuildContext context, {
  required String uid,
  required String name,
  required String message,
}) async {
  final String viewer = app_state.prismUser.id;
  final String label = context.l10n.creatorsMoreLike(name);
  toasts.success(message, haptic: false);
  final SimilarCreatorsOfferSession session = getIt<SimilarCreatorsOfferSession>();
  final List<DirectoryCreator> offered = await session.claim(uid);
  if (offered.isEmpty) return;
  toasts.success(
    message,
    haptic: false,
    action: (
      label: label,
      onPressed: () async {
        if (!app_state.prismUser.loggedIn || app_state.prismUser.id != viewer) return;
        final List<DirectoryCreator> similar = await session.refresh(uid, offered);
        if (similar.isEmpty || !app_state.prismUser.loggedIn || app_state.prismUser.id != viewer) return;
        if (!context.mounted) return;
        analytics.track(SimilarCreatorsShownEvent(creatorId: uid, count: similar.length));
        await showSimilarCreatorsSheet(context, name: name, creators: similar);
      },
    ),
  );
}
