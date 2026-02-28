import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
import 'package:Prism/features/deep_link/domain/repositories/deep_link_repository.dart';
import 'package:app_links/app_links.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DeepLinkRepository)
class DeepLinkRepositoryImpl implements DeepLinkRepository {
  DeepLinkRepositoryImpl(this._appLinks);

  final AppLinks _appLinks;
  final StreamController<DeepLinkActionEntity> _controller = StreamController<DeepLinkActionEntity>.broadcast();
  StreamSubscription<Uri>? _appLinksSubscription;
  bool _isInitialized = false;

  TargetTypeValue _targetTypeFromPath(String path) {
    switch (path) {
      case 'share':
        return TargetTypeValue.share;
      case 'user':
        return TargetTypeValue.user;
      case 'setup':
        return TargetTypeValue.setup;
      case 'refer':
        return TargetTypeValue.refer;
      case 'l':
        return TargetTypeValue.shortCode;
      default:
        return TargetTypeValue.unknown;
    }
  }

  void _trackReceived({required TargetTypeValue targetType, required bool hasPayload}) {
    unawaited(
      analytics.track(
        DeepLinkReceivedEvent(source: DeepLinkSourceValue.appLinks, targetType: targetType, hasPayload: hasPayload),
      ),
    );
  }

  void _trackResolved({
    required TargetTypeValue targetType,
    required EventResultValue result,
    AnalyticsReasonValue? reason,
  }) {
    unawaited(analytics.track(DeepLinkResolvedEvent(targetType: targetType, result: result, reason: reason)));
  }

  DeepLinkActionEntity _parseUri(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      _trackReceived(targetType: TargetTypeValue.unknown, hasPayload: uri.queryParameters.isNotEmpty);
      _trackResolved(
        targetType: TargetTypeValue.unknown,
        result: EventResultValue.failure,
        reason: AnalyticsReasonValue.missingData,
      );
      return DeepLinkActionEntity(
        type: DeepLinkActionType.unknown,
        route: '',
        arguments: const <dynamic>[],
        rawUri: uri.toString(),
      );
    }

    final path = uri.pathSegments.first;
    final TargetTypeValue targetType = _targetTypeFromPath(path);
    _trackReceived(targetType: targetType, hasPayload: uri.queryParameters.isNotEmpty || uri.pathSegments.length > 1);
    if (path == 'share') {
      final bool hasSharePayload =
          (uri.queryParameters['id'] ?? '').trim().isNotEmpty &&
          (uri.queryParameters['provider'] ?? '').trim().isNotEmpty;
      _trackResolved(
        targetType: TargetTypeValue.share,
        result: hasSharePayload ? EventResultValue.success : EventResultValue.failure,
        reason: hasSharePayload ? null : AnalyticsReasonValue.missingData,
      );
      return DeepLinkActionEntity(
        type: DeepLinkActionType.share,
        route: '/share',
        arguments: <dynamic>[
          uri.queryParameters['id'],
          uri.queryParameters['provider'],
          uri.queryParameters['url'],
          uri.queryParameters['thumb'],
        ],
        rawUri: uri.toString(),
      );
    }
    if (path == 'user') {
      final usernameOrEmail = uri.queryParameters['username'] ?? uri.queryParameters['email'];
      final bool hasUserPayload = (usernameOrEmail ?? '').trim().isNotEmpty;
      _trackResolved(
        targetType: TargetTypeValue.user,
        result: hasUserPayload ? EventResultValue.success : EventResultValue.failure,
        reason: hasUserPayload ? null : AnalyticsReasonValue.missingData,
      );
      return DeepLinkActionEntity(
        type: DeepLinkActionType.user,
        route: '/follower-profile',
        arguments: <dynamic>[usernameOrEmail],
        rawUri: uri.toString(),
      );
    }
    if (path == 'setup') {
      final bool hasSetupPayload =
          (uri.queryParameters['name'] ?? '').trim().isNotEmpty &&
          (uri.queryParameters['thumbUrl'] ?? '').trim().isNotEmpty;
      _trackResolved(
        targetType: TargetTypeValue.setup,
        result: hasSetupPayload ? EventResultValue.success : EventResultValue.failure,
        reason: hasSetupPayload ? null : AnalyticsReasonValue.missingData,
      );
      return DeepLinkActionEntity(
        type: DeepLinkActionType.setup,
        route: '/share-setup',
        arguments: <dynamic>[uri.queryParameters['name'], uri.queryParameters['thumbUrl']],
        rawUri: uri.toString(),
      );
    }
    if (path == 'refer') {
      final String? inviterId =
          uri.queryParameters['userID'] ??
          uri.queryParameters['userId'] ??
          uri.queryParameters['userid'] ??
          uri.queryParameters['id'];
      final bool hasReferralPayload = (inviterId ?? '').trim().isNotEmpty;
      _trackResolved(
        targetType: TargetTypeValue.refer,
        result: hasReferralPayload ? EventResultValue.success : EventResultValue.failure,
        reason: hasReferralPayload ? null : AnalyticsReasonValue.missingData,
      );
      return DeepLinkActionEntity(
        type: DeepLinkActionType.refer,
        route: '',
        arguments: <dynamic>[inviterId],
        rawUri: uri.toString(),
      );
    }
    if (path == 'l' && uri.pathSegments.length >= 2) {
      final bool hasShortCode = uri.pathSegments[1].trim().isNotEmpty;
      _trackResolved(
        targetType: TargetTypeValue.shortCode,
        result: hasShortCode ? EventResultValue.success : EventResultValue.failure,
        reason: hasShortCode ? null : AnalyticsReasonValue.missingData,
      );
      return DeepLinkActionEntity(
        type: DeepLinkActionType.shortCode,
        route: '/l',
        arguments: <dynamic>[uri.pathSegments[1]],
        rawUri: uri.toString(),
      );
    }

    _trackResolved(
      targetType: TargetTypeValue.unknown,
      result: EventResultValue.failure,
      reason: AnalyticsReasonValue.unknown,
    );
    return DeepLinkActionEntity(
      type: DeepLinkActionType.unknown,
      route: '',
      arguments: const <dynamic>[],
      rawUri: uri.toString(),
    );
  }

  void _ensureWatcher() {
    if (_isInitialized) {
      return;
    }
    _isInitialized = true;
    _appLinksSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        _controller.add(_parseUri(uri));
      },
      onError: (Object error) {
        _trackResolved(
          targetType: TargetTypeValue.unknown,
          result: EventResultValue.failure,
          reason: AnalyticsReasonValue.error,
        );
        _controller.add(
          DeepLinkActionEntity(
            type: DeepLinkActionType.unknown,
            route: '',
            arguments: <dynamic>[error.toString()],
            rawUri: '',
          ),
        );
      },
    );
  }

  @override
  Future<Result<DeepLinkActionEntity?>> getInitialAction() async {
    try {
      _ensureWatcher();
      final uri = await _appLinks.getInitialLink();
      if (uri == null) {
        return Result.success(null);
      }
      return Result.success(_parseUri(uri));
    } catch (error) {
      _trackResolved(
        targetType: TargetTypeValue.unknown,
        result: EventResultValue.failure,
        reason: AnalyticsReasonValue.error,
      );
      return Result.error(ServerFailure('Unable to get initial deep link: $error'));
    }
  }

  @override
  Stream<DeepLinkActionEntity> watchActions() {
    _ensureWatcher();
    return _controller.stream;
  }

  @override
  @disposeMethod
  Future<void> dispose() async {
    await _appLinksSubscription?.cancel();
    await _controller.close();
  }
}
