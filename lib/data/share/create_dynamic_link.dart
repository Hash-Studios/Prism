import 'dart:async';
import 'dart:convert';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/router/app_router.dart';
import 'package:Prism/core/share/share_text.dart';
import 'package:Prism/core/wallpaper/wallpaper_core.dart';
import 'package:Prism/core/wallpaper/wallpaper_source.dart';
import 'package:Prism/data/offline/bundled_wallpapers.dart';
import 'package:Prism/features/public_profile/domain/creator_label.dart';
import 'package:Prism/l10n/l10n.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String _shareDomain = 'prismwalls.com';

String safeWallpaperShareThumbnail(String id, WallpaperSource source, String thumbUrl) {
  if (BundledWallpapers.isStarterIdentity(id, source)) return thumbUrl;
  if (source == WallpaperSource.wallhaven || source == WallpaperSource.pexels) return thumbUrl;
  if (source != WallpaperSource.prism) return '';
  if (!RegExp(r'^[A-Za-z0-9_-]{1,200}$').hasMatch(id)) return '';
  return 'https://asia-south1-prism-wallpapers.cloudfunctions.net/ownedThumbnail/$id';
}

class _CanonicalLinkBuilder {
  const _CanonicalLinkBuilder();

  Uri wallpaper({required String id, required WallpaperSource source, required String thumbUrl}) {
    return Uri.https(_shareDomain, '/share', <String, String>{
      'id': id,
      'source': source.wireValue,
      'provider': source.legacyProviderString,
      'thumb': thumbUrl,
    });
  }

  Uri user({required String identifier}) {
    return Uri.https(_shareDomain, '/user/${Uri.encodeComponent(identifier)}');
  }

  Uri refer({required String userId}) {
    return Uri.https(_shareDomain, '/refer/${Uri.encodeComponent(userId)}');
  }
}

class _ShortLinkService {
  const _ShortLinkService();

  Future<Uri> createShortLink({
    required String type,
    required Uri canonicalUri,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? preview,
  }) async {
    final Uri endpoint = Uri.parse(shortLinkApiUrl);
    try {
      final response = await http
          .post(
            endpoint,
            headers: const <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'},
            body: jsonEncode(<String, dynamic>{
              'type': type,
              'payload': payload ?? const <String, dynamic>{},
              'canonical_url': canonicalUri.toString(),
              'preview': preview ?? const <String, dynamic>{},
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        logger.w(
          'Short-link API non-success status',
          fields: <String, Object?>{
            'status': response.statusCode,
            'body': response.body,
            'canonical': canonicalUri.toString(),
          },
        );
        return canonicalUri;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        final dynamic shortUrl = decoded['short_url'];
        if (shortUrl is String && shortUrl.isNotEmpty) {
          final Uri? parsed = Uri.tryParse(shortUrl);
          if (parsed != null) {
            return parsed;
          }
        }
      }
    } catch (error, stackTrace) {
      logger.w(
        'Short-link API request failed; falling back to canonical URL.',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'canonical': canonicalUri.toString()},
      );
    }

    return canonicalUri;
  }
}

const _CanonicalLinkBuilder _canonicalLinkBuilder = _CanonicalLinkBuilder();
const _ShortLinkService _shortLinkService = _ShortLinkService();

String canonicalWallpaperLink({
  required String id,
  required WallpaperSource source,
  String? url,
  required String thumbUrl,
}) => BundledWallpapers.isStarterIdentity(id, source)
    ? Uri.https(_shareDomain, '/').toString()
    : _canonicalLinkBuilder
          .wallpaper(id: id, source: source, thumbUrl: safeWallpaperShareThumbnail(id, source, thumbUrl))
          .toString();

void _trackDynamicLinkCreateResult({
  required ShareTypeValue shareType,
  required EventResultValue result,
  AnalyticsReasonValue? reason,
}) {
  try {
    unawaited(analytics.track(DynamicLinkCreateResultEvent(shareType: shareType, result: result, reason: reason)));
  } catch (error, stackTrace) {
    logger.w('Dynamic link analytics failed', error: error, stackTrace: stackTrace);
  }
}

Future<String> _buildShareableLink({
  required String type,
  required Uri canonicalUri,
  Map<String, dynamic>? payload,
  Map<String, dynamic>? preview,
}) async {
  final Uri resolved = await _shortLinkService.createShortLink(
    type: type,
    canonicalUri: canonicalUri,
    payload: payload,
    preview: preview,
  );
  return resolved.toString();
}

/// Creator and size for the link preview card. The worker reads the view and download counts itself.
Map<String, String> _wallpaperCardPreview(WallpaperCore? core) {
  final String? creator = shareSafeText(core?.authorName);
  final String photo = core?.authorPhoto?.trim() ?? '';
  final String resolution = core?.resolution?.trim() ?? '';
  return <String, String>{
    if (creator != null) 'creator_name': creator,
    if (photo.isNotEmpty) 'creator_photo_url': photo,
    if (resolution.isNotEmpty) 'resolution': resolution,
  };
}

/// Builds a share link for a wallpaper. It has no side effects besides analytics.
/// Returns null when the link cannot be created, so callers choose how to tell the user.
Future<String?> createDynamicLink(
  String id,
  WallpaperSource source,
  String? url,
  String thumbUrl, {
  String? title,
  WallpaperCore? core,
  required AppLocalizations l10n,
}) async {
  try {
    thumbUrl = safeWallpaperShareThumbnail(id, source, thumbUrl);
    final Uri canonical = Uri.parse(canonicalWallpaperLink(id: id, source: source, url: url, thumbUrl: thumbUrl));
    if (BundledWallpapers.isStarterIdentity(id, source)) {
      _trackDynamicLinkCreateResult(shareType: ShareTypeValue.wallpaper, result: EventResultValue.success);
      return canonical.toString();
    }
    final String link = await _buildShareableLink(
      type: 'share',
      canonicalUri: canonical,
      payload: <String, dynamic>{
        'id': id,
        'source': source.wireValue,
        'provider': source.legacyProviderString,
        'thumb': thumbUrl,
      },
      preview: <String, dynamic>{
        'title': shareSafeText(title) ?? l10n.coreWallpaperPreviewTitle,
        'description': l10n.coreWallpaperPreviewDescription,
        'image_source_url': thumbUrl,
        'provider': source.legacyProviderString,
        'wall_id': id,
        ..._wallpaperCardPreview(core),
      },
    );
    _trackDynamicLinkCreateResult(shareType: ShareTypeValue.wallpaper, result: EventResultValue.success);
    return link;
  } catch (error, stackTrace) {
    logger.e('Failed to create wallpaper dynamic link.', error: error, stackTrace: stackTrace);
    _trackDynamicLinkCreateResult(
      shareType: ShareTypeValue.wallpaper,
      result: EventResultValue.failure,
      reason: AnalyticsReasonValue.error,
    );
    return null;
  }
}

/// Creates the wallpaper link, copies it to the clipboard and shows a toast. Never throws.
Future<bool> copyWallpaperLink(
  String id,
  WallpaperSource source,
  String? url,
  String thumbUrl, {
  String? title,
  WallpaperCore? core,
  required AppLocalizations l10n,
}) async {
  final String? link = await createDynamicLink(id, source, url, thumbUrl, title: title, core: core, l10n: l10n);
  if (link == null) {
    toasts.error(l10n.coreWallpaperLinkCreateFailed);
    return false;
  }
  try {
    await Clipboard.setData(ClipboardData(text: l10n.coreShareWallpaperClipboard(link)));
  } catch (error, stackTrace) {
    logger.w('Failed to copy the wallpaper link.', error: error, stackTrace: stackTrace);
    toasts.error(l10n.coreWallpaperLinkCopyFailed);
    return false;
  }
  toasts.success(l10n.coreShareLinkCopied);
  return true;
}

/// Shares a link to the profile. [email] is unused: a link never holds an email address. Without a username it
/// opens the edit panel instead. The counts and up to 4 [gallery] thumbnails go on the link preview card.
Future<void> createUserDynamicLink(
  String name,
  String username,
  String email,
  String bio,
  String userPhoto, {
  BuildContext? context,
  int? followerCount,
  int? wallpaperCount,
  List<String> gallery = const <String>[],
  required AppLocalizations l10n,
}) async {
  final String userIdentifier = username.trim();
  if (userIdentifier.isEmpty) {
    toasts.info(l10n.coreUsernameRequiredToShareProfile);
    if (context != null && context.mounted) unawaited(context.router.root.push(const EditProfilePanelRoute()));
    return;
  }
  try {
    final Uri canonical = _canonicalLinkBuilder.user(identifier: userIdentifier);
    final String label = creatorLabel(name: name, username: userIdentifier, fallback: l10n.accountCreatorFallback);
    final String link = await _buildShareableLink(
      type: 'user',
      canonicalUri: canonical,
      payload: <String, dynamic>{'username': userIdentifier},
      preview: <String, dynamic>{
        'title': '$label (@$userIdentifier)',
        'description': bio.isNotEmpty ? bio : l10n.coreCreatorPreviewDescription,
        'image_source_url': userPhoto,
        'username': userIdentifier,
        'creator_name': label,
        'follower_count': ?followerCount,
        'wallpaper_count': ?wallpaperCount,
        if (gallery.isNotEmpty) 'gallery': gallery.take(4).toList(),
      },
    );

    await Clipboard.setData(ClipboardData(text: link));
    if (context != null && !context.mounted) {
      return;
    }
    await ShareService.shareText(text: l10n.coreShareProfileClipboard(link), context: context);
    _trackDynamicLinkCreateResult(shareType: ShareTypeValue.user, result: EventResultValue.success);
  } catch (error, stackTrace) {
    logger.e('Failed to create user dynamic link.', error: error, stackTrace: stackTrace);
    _trackDynamicLinkCreateResult(
      shareType: ShareTypeValue.user,
      result: EventResultValue.failure,
      reason: AnalyticsReasonValue.error,
    );
    rethrow;
  }
}

/// Creates the invite link. The preview reads "Name invited you to Prism" and shows the inviter's photo.
Future<String> createSharingPrismLink(
  String userID, {
  String? inviterName,
  String? inviterPhoto,
  required AppLocalizations l10n,
}) async {
  final String? who = shareSafeText(inviterName);
  final String photo = inviterPhoto?.trim() ?? '';
  try {
    final Uri canonical = _canonicalLinkBuilder.refer(userId: userID);
    final String link = await _buildShareableLink(
      type: 'refer',
      canonicalUri: canonical,
      payload: <String, dynamic>{'userID': userID},
      preview: <String, dynamic>{
        'title': who == null ? l10n.coreJoinPrismPreviewTitle : l10n.coreInvitedToPrismTitle(who),
        'description': l10n.coreDownloadPrismPreviewDescription,
        'creator_name': ?who,
        if (who != null && photo.isNotEmpty) 'image_source_url': photo,
      },
    );

    _trackDynamicLinkCreateResult(shareType: ShareTypeValue.refer, result: EventResultValue.success);
    return link;
  } catch (error, stackTrace) {
    logger.e('Failed to create referral dynamic link.', error: error, stackTrace: stackTrace);
    _trackDynamicLinkCreateResult(
      shareType: ShareTypeValue.refer,
      result: EventResultValue.failure,
      reason: AnalyticsReasonValue.error,
    );
    rethrow;
  }
}
