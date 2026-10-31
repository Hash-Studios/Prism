import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/generated/analytics_events.g.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:Prism/features/creator_directory/views/widgets/similar_creators_sheet.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/widgets.dart';

/// The signed-in viewer who already got the offer in this app session. Another account gets its own offer.
String? _similarOfferUsedBy;

/// Shows the follow toast at once. Once per app session, when the creator has similar creators the viewer does not
/// follow yet, it then shows the toast again with a "More like `name`" action. An unfollow never calls this.
Future<void> showFollowToastWithSimilarOffer(
  BuildContext context, {
  required String uid,
  required String name,
  required String message,
}) async {
  final String viewer = app_state.prismUser.id;
  toasts.success(message, haptic: false);
  if (!app_state.prismUser.loggedIn || _similarOfferUsedBy == viewer || uid.isEmpty) return;
  _similarOfferUsedBy = viewer;
  final String label = context.l10n.creatorsMoreLike(name);
  List<DirectoryCreator> similar = const <DirectoryCreator>[];
  try {
    similar = await getIt<CreatorDirectoryRepository>().similarTo(uid).timeout(const Duration(seconds: 2));
  } catch (_) {}
  if (!app_state.prismUser.loggedIn || app_state.prismUser.id != viewer) return;
  if (similar.isEmpty) {
    _similarOfferUsedBy = null;
    return;
  }
  toasts.success(
    message,
    haptic: false,
    action: (
      label: label,
      onPressed: () async {
        if (!app_state.prismUser.loggedIn || app_state.prismUser.id != viewer) return;
        // A slow or failed refresh keeps the list the toast was offered with.
        try {
          similar = await getIt<CreatorDirectoryRepository>().similarTo(uid).timeout(const Duration(seconds: 2));
        } catch (_) {}
        if (similar.isEmpty || !app_state.prismUser.loggedIn || app_state.prismUser.id != viewer) return;
        if (!context.mounted) return;
        analytics.track(SimilarCreatorsShownEvent(creatorId: uid, count: similar.length));
        await showSimilarCreatorsSheet(context, name: name, creators: similar);
      },
    ),
  );
}
