import 'dart:async';

import 'package:Prism/analytics/analytics_service.dart';
import 'package:Prism/core/analytics/events/events.dart';
import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/router/deep_link_parser.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
import 'package:Prism/features/deep_link/domain/repositories/deep_link_repository.dart';
import 'package:app_links/app_links.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DeepLinkRepository)
class DeepLinkRepositoryImpl implements DeepLinkRepository {
  DeepLinkRepositoryImpl(this._appLinks);

  final AppLinks _appLinks;
  final DeepLinkParser _parser = const DeepLinkParser();
  final StreamController<DeepLinkActionEntity> _controller = StreamController<DeepLinkActionEntity>.broadcast();
  StreamSubscription<Uri>? _appLinksSubscription;
  bool _isInitialized = false;

  TargetTypeValue _targetType(DeepLinkActionEntity action) {
    return switch (action) {
      ShareLinkIntent() => TargetTypeValue.share,
      UserLinkIntent() => TargetTypeValue.user,
      SetupLinkIntent() => TargetTypeValue.setup,
      ReferLinkIntent() => TargetTypeValue.refer,
      ShortCodeIntent() => TargetTypeValue.shortCode,
      UnknownIntent() => TargetTypeValue.unknown,
    };
  }

  void _trackParse(DeepLinkActionEntity action) {
    final TargetTypeValue targetType = _targetType(action);
    final bool success = action is! UnknownIntent;
    unawaited(
      analytics.track(
        DeepLinkReceivedEvent(source: DeepLinkSourceValue.appLinks, targetType: targetType, hasPayload: success),
      ),
    );
    unawaited(
      analytics.track(
        DeepLinkResolvedEvent(
          targetType: targetType,
          result: success ? EventResultValue.success : EventResultValue.failure,
          reason: success ? null : AnalyticsReasonValue.missingData,
        ),
      ),
    );
  }

  DeepLinkActionEntity _parseUri(Uri uri) {
    final DeepLinkActionEntity action = _parser.parse(uri);
    _trackParse(action);
    return action;
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
        unawaited(
          analytics.track(
            const DeepLinkResolvedEvent(
              targetType: TargetTypeValue.unknown,
              result: EventResultValue.failure,
              reason: AnalyticsReasonValue.error,
            ),
          ),
        );
        _controller.add(UnknownIntent(rawUri: error.toString()));
      },
    );
  }

  @override
  Future<Result<DeepLinkActionEntity?>> getInitialAction() async {
    try {
      _ensureWatcher();
      final Uri? uri = await _appLinks.getInitialLink();
      if (uri == null) {
        return Result.success(null);
      }
      return Result.success(_parseUri(uri));
    } catch (error) {
      unawaited(
        analytics.track(
          const DeepLinkResolvedEvent(
            targetType: TargetTypeValue.unknown,
            result: EventResultValue.failure,
            reason: AnalyticsReasonValue.error,
          ),
        ),
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
