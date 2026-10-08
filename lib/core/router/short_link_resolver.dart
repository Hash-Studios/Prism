import 'dart:convert';

import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/constants/app_constants.dart';
import 'package:Prism/core/monitoring/sentry_before_send.dart';
import 'package:Prism/core/router/deep_link_action_entity.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/logger/logger.dart';
import 'package:http/http.dart' as http;

sealed class ShortLinkResult {
  const ShortLinkResult();
}

final class ShortLinkResolved extends ShortLinkResult {
  const ShortLinkResolved(this.action);

  final DeepLinkActionEntity action;
}

final class ShortLinkFailed extends ShortLinkResult {
  const ShortLinkFailed(this.reason, {this.isNetwork = false});

  final AnalyticsReasonValue reason;

  /// True when the request never reached a working server, so the link may still be valid.
  final bool isNetwork;
}

const Set<int> _serverUnavailableStatuses = <int>{502, 503, 504};

class ShortLinkResolver {
  ShortLinkResolver({http.Client? client, DeepLinkParser parser = const DeepLinkParser()})
    : _client = client ?? http.Client(),
      _parser = parser;

  final http.Client _client;
  final DeepLinkParser _parser;

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
        return ShortLinkFailed(
          AnalyticsReasonValue.error,
          isNetwork: _serverUnavailableStatuses.contains(response.statusCode),
        );
      }

      final decoded = jsonDecode(response.body);
      final canonical = decoded is Map<String, dynamic> ? decoded['canonical_url'] : null;
      final canonicalUri = canonical is String && canonical.isNotEmpty ? Uri.tryParse(canonical) : null;
      if (canonicalUri == null) return const ShortLinkFailed(AnalyticsReasonValue.missingData);

      final action = _parser.parse(canonicalUri);
      if (action is UnknownIntent) return const ShortLinkFailed(AnalyticsReasonValue.missingData);
      return ShortLinkResolved(action);
    } catch (error, stackTrace) {
      logger.w(
        'Failed to resolve short code.',
        error: error,
        stackTrace: stackTrace,
        fields: <String, Object?>{'code': code},
      );
      return ShortLinkFailed(AnalyticsReasonValue.error, isNetwork: isNetworkNoise(error));
    }
  }
}
