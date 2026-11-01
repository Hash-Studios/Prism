import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/share/share_card.dart';
import 'package:Prism/core/share/share_sheet.dart';
import 'package:Prism/data/share/create_dynamic_link.dart';
import 'package:Prism/features/folders/domain/entities/public_folder_entity.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/material.dart';

/// Shares a public folder: a short link whose preview shows the 4-wall image, in the share sheet.
/// [source] is where the user tapped Share, for analytics.
Future<void> shareFolder(
  BuildContext context,
  PublicFolderEntity folder, {
  required String ownerName,
  required String source,
}) async {
  final AppLocalizations l10n = context.l10n;
  final String description = '${l10n.foldersItemCount(folder.itemCount)} · ${l10n.foldersByOwner(ownerName)}';
  String link = 'https://prismwalls.com/folder/${folder.id}';
  try {
    link = await createFolderLink(
      folderId: folder.id,
      name: folder.name,
      description: description,
      shareImage: folder.shareImage,
      coverImage: folder.covers.isEmpty ? '' : folder.covers.first,
    ).timeout(const Duration(seconds: 6));
  } catch (error, stackTrace) {
    logger.w('Folder short link unavailable; sharing the canonical URL.', error: error, stackTrace: stackTrace);
  }
  if (!context.mounted) return;
  unawaited(analytics.track(FolderSharedEvent(source: source)));
  final String image = folder.shareImage.isNotEmpty
      ? folder.shareImage
      : (folder.covers.isEmpty ? '' : folder.covers.first);
  if (image.isEmpty) {
    await ShareService.shareText(text: '${folder.name}\n$link', context: context);
    return;
  }
  await showShareSheet(
    context,
    ShareCardContent(
      imageUrl: image,
      link: link,
      brandName: l10n.appTitle,
      contextLine: folder.name,
      creator: ownerName,
      creatorLine: l10n.foldersByOwner(ownerName),
    ),
    'folder',
  );
}
