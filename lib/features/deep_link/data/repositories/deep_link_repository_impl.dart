import 'dart:async';

import 'package:Prism/core/error/failure.dart';
import 'package:Prism/core/utils/result.dart';
import 'package:Prism/features/deep_link/domain/entities/deep_link_action_entity.dart';
import 'package:Prism/features/deep_link/domain/repositories/deep_link_repository.dart';
import 'package:Prism/core/router/route_names.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: DeepLinkRepository)
class DeepLinkRepositoryImpl implements DeepLinkRepository {
  DeepLinkRepositoryImpl(this._dynamicLinks);

  final FirebaseDynamicLinks _dynamicLinks;
  final StreamController<DeepLinkActionEntity> _controller = StreamController<DeepLinkActionEntity>.broadcast();
  bool _isInitialized = false;

  DeepLinkActionEntity _parseUri(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.unknown,
        route: '',
        arguments: const <dynamic>[],
        rawUri: uri.toString(),
      );
    }

    final path = uri.pathSegments.first;
    if (path == 'share') {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.share,
        route: shareRoute,
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
      return DeepLinkActionEntity(
        type: DeepLinkActionType.user,
        route: followerProfileRoute,
        arguments: <dynamic>[uri.queryParameters['email']],
        rawUri: uri.toString(),
      );
    }
    if (path == 'setup') {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.setup,
        route: shareSetupViewRoute,
        arguments: <dynamic>[
          uri.queryParameters['name'],
          uri.queryParameters['thumbUrl'],
        ],
        rawUri: uri.toString(),
      );
    }
    if (path == 'refer') {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.refer,
        route: '',
        arguments: const <dynamic>[],
        rawUri: uri.toString(),
      );
    }

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
    _dynamicLinks.onLink.listen(
      (dynamicLinkData) {
        final uri = dynamicLinkData.link;
        _controller.add(_parseUri(uri));
      },
      onError: (Object error) {
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
      final data = await _dynamicLinks.getInitialLink();
      final uri = data?.link;
      if (uri == null) {
        return Result.success(null);
      }
      return Result.success(_parseUri(uri));
    } catch (error) {
      return Result.error(ServerFailure('Unable to get initial deep link: $error'));
    }
  }

  @override
  Stream<DeepLinkActionEntity> watchActions() {
    _ensureWatcher();
    return _controller.stream;
  }
}
