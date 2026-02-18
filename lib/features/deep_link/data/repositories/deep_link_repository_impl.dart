import 'dart:async';

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
      return DeepLinkActionEntity(
        type: DeepLinkActionType.user,
        route: '/follower-profile',
        arguments: <dynamic>[usernameOrEmail],
        rawUri: uri.toString(),
      );
    }
    if (path == 'setup') {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.setup,
        route: '/share-setup',
        arguments: <dynamic>[uri.queryParameters['name'], uri.queryParameters['thumbUrl']],
        rawUri: uri.toString(),
      );
    }
    if (path == 'refer') {
      final String? inviterId = uri.queryParameters['userID'] ??
          uri.queryParameters['userId'] ??
          uri.queryParameters['userid'] ??
          uri.queryParameters['id'];
      return DeepLinkActionEntity(
        type: DeepLinkActionType.refer,
        route: '',
        arguments: <dynamic>[inviterId],
        rawUri: uri.toString(),
      );
    }
    if (path == 'l' && uri.pathSegments.length >= 2) {
      return DeepLinkActionEntity(
        type: DeepLinkActionType.shortCode,
        route: '/l',
        arguments: <dynamic>[uri.pathSegments[1]],
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
    _appLinksSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
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
      final uri = await _appLinks.getInitialLink();
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

  @disposeMethod
  Future<void> dispose() async {
    await _appLinksSubscription?.cancel();
    await _controller.close();
  }
}
