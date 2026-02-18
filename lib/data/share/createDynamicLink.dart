import 'dart:convert';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/widgets/popup/copyrightPopUp.dart';
import 'package:Prism/logger/logger.dart';
import 'package:Prism/theme/toasts.dart' as toasts;
import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:share_plus/share_plus.dart';

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

  Uri user({required String email}) {
    return Uri.https(_shareDomain, '/user', <String, String>{'email': email});
  }

  Uri setup({required String index, required String name, required String thumbUrl}) {
    return Uri.https(_shareDomain, '/setup', <String, String>{
      'index': index,
      'name': name,
      'thumbUrl': thumbUrl,
    });
  }

  Uri refer({required String userId}) {
    return Uri.https(_shareDomain, '/refer', <String, String>{'userID': userId});
  }
}

class ShortLinkService {
  const ShortLinkService();

  Future<Uri> createShortLink({required String type, required Uri canonicalUri, Map<String, dynamic>? payload}) async {
    final Uri endpoint = Uri.parse(_shortLinkApiUrl);
    try {
      final response = await http
          .post(
            endpoint,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(<String, dynamic>{
              'type': type,
              'payload': payload ?? const <String, dynamic>{},
              'canonical_url': canonicalUri.toString(),
            }),
          )
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        logger.w('Short-link API non-success status', fields: <String, Object?>{
          'status': response.statusCode,
          'body': response.body,
          'canonical': canonicalUri.toString(),
        });
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

Future<String> _buildShareableLink(
    {required String type, required Uri canonicalUri, Map<String, dynamic>? payload}) async {
  final Uri resolved =
      await _shortLinkService.createShortLink(type: type, canonicalUri: canonicalUri, payload: payload);
  logger.d(resolved.toString());
  return resolved.toString();
}

Future<String> createDynamicLink(String id, String provider, String? url, String thumbUrl) async {
  final Uri canonical = _canonicalLinkBuilder.wallpaper(
    id: id,
    provider: provider,
    url: url,
    thumbUrl: thumbUrl,
  );
  final String link = await _buildShareableLink(
    type: 'share',
    canonicalUri: canonical,
    payload: <String, dynamic>{
      'id': id,
      'provider': provider,
      if (url != null) 'url': url,
      'thumb': thumbUrl,
    },
  );

  await Clipboard.setData(ClipboardData(text: 'Hey check this out ➜ $link'));
  analytics.logShare(contentType: 'focussedMenu', itemId: id, method: 'link');
  toasts.codeSend('Sharing link copied!');
  return link;
}

Future<void> createUserDynamicLink(String name, String username, String email, String bio, String userPhoto) async {
  final Uri canonical = _canonicalLinkBuilder.user(email: email);
  final String link = await _buildShareableLink(
    type: 'user',
    canonicalUri: canonical,
    payload: <String, dynamic>{'email': email, 'username': username},
  );

  await Clipboard.setData(ClipboardData(text: link));
  SharePlus.instance.share(
    ShareParams(
      text: 'Hey check out my profile on Prism ➜ $link',
      sharePositionOrigin: const Rect.fromLTWH(1, 1, 1, 1),
    ),
  );
  analytics.logShare(contentType: 'userShare', itemId: username, method: 'link');
}

Future<void> createSetupDynamicLink(String index, String name, String thumbUrl) async {
  final Uri canonical = _canonicalLinkBuilder.setup(index: index, name: name, thumbUrl: thumbUrl);
  final String link = await _buildShareableLink(
    type: 'setup',
    canonicalUri: canonical,
    payload: <String, dynamic>{'index': index, 'name': name, 'thumbUrl': thumbUrl},
  );

  await Clipboard.setData(ClipboardData(text: link));
  SharePlus.instance.share(
    ShareParams(
      text: 'Hey check this out ➜ $link',
      sharePositionOrigin: const Rect.fromLTWH(1, 1, 1, 1),
    ),
  );
  analytics.logShare(contentType: 'setupShare', itemId: name, method: 'link');
}

Future<String> createSharingPrismLink(String userID) async {
  final Uri canonical = _canonicalLinkBuilder.refer(userId: userID);
  final String link = await _buildShareableLink(
    type: 'refer',
    canonicalUri: canonical,
    payload: <String, dynamic>{'userID': userID},
  );

  analytics.logShare(contentType: 'prismShare', itemId: userID, method: 'link');
  return link;
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

  if (setup) {
    type = 'setup';
    canonical = _canonicalLinkBuilder.setup(index: index!, name: name!, thumbUrl: thumbUrl!);
    payload = <String, dynamic>{'index': index, 'name': name, 'thumbUrl': thumbUrl};
    analytics.logEvent(name: 'reportSetup');
  } else {
    type = 'share';
    canonical = _canonicalLinkBuilder.wallpaper(
      id: id!,
      provider: provider!,
      url: url,
      thumbUrl: thumbUrl!,
    );
    payload = <String, dynamic>{
      'id': id,
      'provider': provider,
      if (url != null) 'url': url,
      'thumb': thumbUrl,
    };
    analytics.logEvent(name: 'reportWall');
  }

  final String link = await _buildShareableLink(type: type, canonicalUri: canonical, payload: payload);
  if (!context.mounted) {
    return '';
  }
  showModal(
    context: context,
    builder: (BuildContext context) => CopyrightPopUp(
      setup: setup,
      shortlink: link,
    ),
  );
  return '';
}
