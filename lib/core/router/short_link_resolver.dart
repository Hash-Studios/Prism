import 'dart:convert';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/logger/logger.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart' as launcher;

sealed class ShortLinkResult {
  const ShortLinkResult();
}

final class ShortLinkResolved extends ShortLinkResult {
  const ShortLinkResolved(this.action);

  final DeepLinkActionEntity action;
}

final class ShortLinkFailed extends ShortLinkResult {
  const ShortLinkFailed(this.reason);

  final AnalyticsReasonValue reason;
}

class ShortLinkResolver {
  ShortLinkResolver({
    http.Client? client,
    DeepLinkParser parser = const DeepLinkParser(),
    Future<bool> Function(launcher.LaunchMode)? supportsLaunchMode,
    Future<bool> Function(Uri, {required launcher.LaunchMode mode})? launchUrl,
  }) : _client = client ?? http.Client(),
       _parser = parser,
       _supportsLaunchMode = supportsLaunchMode ?? launcher.supportsLaunchMode,
       _launchUrl = launchUrl ?? launcher.launchUrl;

  final http.Client _client;
  final DeepLinkParser _parser;
  final Future<bool> Function(launcher.LaunchMode) _supportsLaunchMode;
  final Future<bool> Function(Uri, {required launcher.LaunchMode mode}) _launchUrl;

  Future<bool> openFallback(String code) async {
    try {
      if (!await _supportsLaunchMode(launcher.LaunchMode.inAppBrowserView)) return false;
      return await _launchUrl(Uri.https('prismwalls.com', '/l/$code'), mode: launcher.LaunchMode.inAppBrowserView);
    } on PlatformException {
      return false;
    }
  }

  Future<ShortLinkResult> resolve(String code) async {
    try {
      final response = await _client
          .get(Uri.parse('$shortLinkApiUrl/$code'), headers: const <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        logger.w(
          'Short-link resolve returned non-success status.',
          fields: <String, Object?>{'status': response.statusCode, 'code': code, 'body': response.body},
        );
        return const ShortLinkFailed(AnalyticsReasonValue.error);
      }

      final decoded = jsonDecode(response.body);
      final canonical = decoded is Map<String, dynamic> ? decoded['canonical_url'] : null;
      final canonicalUri = canonical is String && canonical.isNotEmpty ? Uri.tryParse(canonical) : null;
      if (canonicalUri == null) return const ShortLinkFailed(AnalyticsReasonValue.missingData);

      final action = _parser.parse(canonicalUri);
      if (action is UnknownIntent || action is ShortCodeIntent) {
        return const ShortLinkFailed(AnalyticsReasonValue.missingData);
      }
      return ShortLinkResolved(action);
    } catch (error, stackTrace) {
      logger.w(
        'Failed to resolve short code.',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'code': code},
      );
      return const ShortLinkFailed(AnalyticsReasonValue.error);
    }
  }
}
