import 'dart:convert';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/platform/share_service.dart';
import 'package:Prism/core/widgets/popup/copyrightPopUp.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

const String _shareDomain = 'prismwalls.com';
const String _shortLinkApiUrl = 'https://prismwalls.com/api/links';

class CanonicalLinkBuilder {
  const CanonicalLinkBuilder();

  Uri wallpaper({required String id, required String provider, String? url, required String thumbUrl}) {
    return Uri.https(_shareDomain, '/share', <String, String>{
      'id': id,
      'provider': provider,
      'thumb': thumbUrl,
      if (url != null) 'url': url,
    });
  }

  Uri user({required String username}) {
    return Uri.https(_shareDomain, '/user', <String, String>{'username': username});
  }

  Uri setup({required String index, required String name, required String thumbUrl}) {
    return Uri.https(_shareDomain, '/setup', <String, String>{'index': index, 'name': name, 'thumbUrl': thumbUrl});
  }

  Uri refer({required String userId}) {
    return Uri.https(_shareDomain, '/refer', <String, String>{'userID': userId});
  }
}

class ShortLinkService {
  const ShortLinkService();

  Future<Uri> createShortLink({
    required String type,
    required Uri canonicalUri,
    Map<String, dynamic>? payload,
    Map<String, dynamic>? preview,
  }) async {
    final Uri endpoint = Uri.parse(_shortLinkApiUrl);
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

const CanonicalLinkBuilder _canonicalLinkBuilder = CanonicalLinkBuilder();
const ShortLinkService _shortLinkService = ShortLinkService();

void _trackDynamicLinkCreateResult({
  required ShareTypeValue shareType,
  required EventResultValue result,
  AnalyticsReasonValue? reason,
}) {
  analytics.track(DynamicLinkCreateResultEvent(shareType: shareType, result: result, reason: reason));
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
  logger.d(resolved.toString());
  return resolved.toString();
}

Future<String> createDynamicLink(String id, String provider, String? url, String thumbUrl) async {
  try {
    final Uri canonical = _canonicalLinkBuilder.wallpaper(id: id, provider: provider, url: url, thumbUrl: thumbUrl);
    final String link = await _buildShareableLink(
      type: 'share',
      canonicalUri: canonical,
      payload: <String, dynamic>{'id': id, 'provider': provider, if (url != null) 'url': url, 'thumb': thumbUrl},
      preview: <String, dynamic>{
        'title': '$id - Prism',
        'description': 'Check out this amazing wallpaper from Prism.',
        'image_source_url': thumbUrl,
        'provider': provider,
        'wall_id': id,
      },
    );

    await Clipboard.setData(ClipboardData(text: 'Hey check this out ➜ $link'));
    _trackDynamicLinkCreateResult(shareType: ShareTypeValue.wallpaper, result: EventResultValue.success);
    toasts.codeSend('Sharing link copied!');
    return link;
  } catch (error, stackTrace) {
    logger.e('Failed to create wallpaper dynamic link.', error: error, stackTrace: stackTrace);
    _trackDynamicLinkCreateResult(
      shareType: ShareTypeValue.wallpaper,
      result: EventResultValue.failure,
      reason: AnalyticsReasonValue.error,
    );
    rethrow;
  }
}

Future<void> createUserDynamicLink(
  String name,
  String username,
  String email,
  String bio,
  String userPhoto, {
  BuildContext? context,
}) async {
  final String userIdentifier = username.isNotEmpty ? username : email;
  try {
    final Uri canonical = _canonicalLinkBuilder.user(username: userIdentifier);
    final String link = await _buildShareableLink(
      type: 'user',
      canonicalUri: canonical,
      payload: <String, dynamic>{'username': userIdentifier},
      preview: <String, dynamic>{
        'title': '$name (@$userIdentifier)',
        'description': bio.isNotEmpty ? bio : 'Check out this creator profile on Prism.',
        'image_source_url': userPhoto,
        'username': userIdentifier,
      },
    );

    await Clipboard.setData(ClipboardData(text: link));
    if (context != null && !context.mounted) {
      return;
    }
    await ShareService.shareText(text: 'Hey check out my profile on Prism ➜ $link', context: context);
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

Future<void> createSetupDynamicLink(String index, String name, String thumbUrl, {BuildContext? context}) async {
  try {
    final Uri canonical = _canonicalLinkBuilder.setup(index: index, name: name, thumbUrl: thumbUrl);
    final String link = await _buildShareableLink(
      type: 'setup',
      canonicalUri: canonical,
      payload: <String, dynamic>{'index': index, 'name': name, 'thumbUrl': thumbUrl},
      preview: <String, dynamic>{
        'title': '$name - Prism',
        'description': 'Check out this setup shared from Prism.',
        'image_source_url': thumbUrl,
        'setup_name': name,
      },
    );

    await Clipboard.setData(ClipboardData(text: link));
    if (context != null && !context.mounted) {
      return;
    }
    await ShareService.shareText(text: 'Hey check this out ➜ $link', context: context);
    _trackDynamicLinkCreateResult(shareType: ShareTypeValue.setup, result: EventResultValue.success);
  } catch (error, stackTrace) {
    logger.e('Failed to create setup dynamic link.', error: error, stackTrace: stackTrace);
    _trackDynamicLinkCreateResult(
      shareType: ShareTypeValue.setup,
      result: EventResultValue.failure,
      reason: AnalyticsReasonValue.error,
    );
    rethrow;
  }
}

Future<String> createSharingPrismLink(String userID) async {
  try {
    final Uri canonical = _canonicalLinkBuilder.refer(userId: userID);
    final String link = await _buildShareableLink(
      type: 'refer',
      canonicalUri: canonical,
      payload: <String, dynamic>{'userID': userID},
      preview: <String, dynamic>{
        'title': 'Join Prism',
        'description': 'Download Prism to discover beautiful wallpapers and setups.',
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

Future<String> createCopyrightLink(
  bool setup,
  BuildContext context, {
  String? id,
  String? provider,
  String? url,
  String? thumbUrl,
  String? name,
  String? index,
}) async {
  late final Uri canonical;
  late final String type;
  late final Map<String, dynamic> payload;
  late final Map<String, dynamic> preview;

  if (setup) {
    type = 'setup';
    canonical = _canonicalLinkBuilder.setup(index: index!, name: name!, thumbUrl: thumbUrl!);
    payload = <String, dynamic>{'index': index, 'name': name, 'thumbUrl': thumbUrl};
    preview = <String, dynamic>{
      'title': '$name - Prism',
      'description': 'Check out this setup shared from Prism.',
      'image_source_url': thumbUrl,
      'setup_name': name,
    };
    analytics.track(const ReportSetupEvent());
  } else {
    type = 'share';
    canonical = _canonicalLinkBuilder.wallpaper(id: id!, provider: provider!, url: url, thumbUrl: thumbUrl!);
    payload = <String, dynamic>{'id': id, 'provider': provider, if (url != null) 'url': url, 'thumb': thumbUrl};
    preview = <String, dynamic>{
      'title': '$id - Prism',
      'description': 'Check out this amazing wallpaper from Prism.',
      'image_source_url': thumbUrl,
      'provider': provider,
      'wall_id': id,
    };
    analytics.track(const ReportWallEvent());
  }

  try {
    final String link = await _buildShareableLink(
      type: type,
      canonicalUri: canonical,
      payload: payload,
      preview: preview,
    );
    _trackDynamicLinkCreateResult(
      shareType: setup ? ShareTypeValue.setup : ShareTypeValue.wallpaper,
      result: EventResultValue.success,
    );
    if (!context.mounted) {
      return '';
    }
    showModal(
      context: context,
      builder: (BuildContext context) => CopyrightPopUp(setup: setup, shortlink: link),
    );
  } catch (error, stackTrace) {
    logger.e('Failed to create copyright link.', error: error, stackTrace: stackTrace);
    _trackDynamicLinkCreateResult(
      shareType: setup ? ShareTypeValue.setup : ShareTypeValue.wallpaper,
      result: EventResultValue.failure,
      reason: AnalyticsReasonValue.error,
    );
    rethrow;
  }
  return '';
}
