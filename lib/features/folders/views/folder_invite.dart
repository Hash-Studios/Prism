import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/di/injection.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/folders/domain/entities/folder_entity.dart';
import 'package:Prism/features/folders/domain/entities/folder_invite.dart';
import 'package:Prism/features/folders/domain/entities/folder_member.dart';
import 'package:Prism/features/folders/domain/repositories/shared_folders_repository.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:flutter/material.dart';

/// Makes an invite link for [folder] and shares it. The owner is checked by the server; this only stops early when
/// the editor list is full.
Future<void> inviteToFolder(BuildContext context, FolderEntity folder, {required String source}) async {
  final AppLocalizations l10n = context.l10n;
  if (folder.editors.length >= folderMaxEditors) {
    toasts.error(l10n.foldersInviteFull);
    return;
  }
  final Result<FolderInvite> result = await getIt<SharedFoldersRepository>().createInvite(folder.id);
  final Failure? failure = result.failure;
  if (failure != null) {
    final FolderJoinRefusal? refusal = failure is SharedFolderFailure ? failure.refusal : null;
    if (failure.code == 'resource-exhausted') {
      toasts.error(l10n.foldersInviteLimit);
    } else if (refusal == FolderJoinRefusal.full) {
      toasts.error(l10n.foldersInviteFull);
    } else {
      toasts.error(l10n.foldersInviteFailed);
    }
    return;
  }
  final FolderInvite invite = result.data!;
  String link = invite.canonicalLink.toString();
  try {
    link = await createFolderInviteLink(
      canonicalLink: invite.canonicalLink,
      title: l10n.foldersInvitePreviewTitle(folder.name),
      description: l10n.foldersInvitePreviewDescription,
      coverImage: folder.covers.isEmpty ? '' : folder.covers.first,
    ).timeout(const Duration(seconds: 6));
  } catch (error, stackTrace) {
    logger.w('Folder invite short link unavailable; sharing the canonical URL.', error: error, stackTrace: stackTrace);
  }
  if (!context.mounted) return;
  unawaited(analytics.track(FolderInviteCreatedEvent(source: source)));
  await ShareService.shareText(text: l10n.foldersInviteShareText(folder.name, link), context: context);
}
