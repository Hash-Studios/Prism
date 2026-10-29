import 'package:Prism/core/constants/app_functions.dart';
import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';
import 'package:Prism/features/wall_requests/domain/repositories/wall_requests_repository.dart';
import 'package:cloud_functions/cloud_functions.dart' as cf;
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

@LazySingleton(as: WallRequestsRepository)
class WallRequestsRepositoryImpl implements WallRequestsRepository {
  WallRequestsRepositoryImpl() : _call = _callable;

  @visibleForTesting
  WallRequestsRepositoryImpl.withCaller(this._call);

  final Future<Object?> Function(String name, Map<String, Object?> data) _call;

  static Future<Object?> _callable(String name, Map<String, Object?> data) async {
    final cf.HttpsCallableResult<Object?> result = await appFunctions
        .httpsCallable(name, options: cf.HttpsCallableOptions(timeout: const Duration(seconds: 15)))
        .call<Object?>(data);
    return result.data;
  }

  @override
  Future<List<WallRequest>> list(WallRequestTab tab) async {
    final Map<String, Object?> body = _asMap(await _invoke('listWallRequests', <String, Object?>{'tab': tab.wire}));
    final Object? requests = body['requests'];
    if (requests is! List<Object?>) throw const WallRequestException(WallRequestError.unknown);
    return requests.map((Object? item) => WallRequest.fromMap(_asMap(item))).toList(growable: false);
  }

  @override
  Future<CreateWallRequestResult> create({required String text, required List<String> tags, bool force = false}) async {
    final Map<String, Object?> body = _asMap(
      await _invoke('createWallRequest', <String, Object?>{'text': text, 'tags': tags, 'force': force}),
    );
    final WallRequest request = WallRequest.fromMap(_asMap(body['request']));
    return switch (body['status']) {
      'created' => WallRequestCreated(request),
      'duplicate' => WallRequestDuplicate(request, exact: body['exact'] == true),
      _ => throw const WallRequestException(WallRequestError.unknown),
    };
  }

  @override
  Future<int> setVote(String requestId, {required bool vote}) async {
    final Map<String, Object?> body = _asMap(
      await _invoke('setWallRequestVote', <String, Object?>{'requestId': requestId, 'vote': vote}),
    );
    final Object? count = body['voteCount'];
    if (count is! num) throw const WallRequestException(WallRequestError.unknown);
    return count.toInt();
  }

  @override
  Future<void> setHidden(String requestId, {required bool hidden}) async {
    await _invoke('setWallRequestHidden', <String, Object?>{'requestId': requestId, 'hidden': hidden});
  }

  Future<Object?> _invoke(String name, Map<String, Object?> data) async {
    try {
      return await _call(name, data);
    } on cf.FirebaseFunctionsException catch (e) {
      throw WallRequestException(_errorFor(e));
    } on WallRequestException {
      rethrow;
    } catch (_) {
      throw const WallRequestException(WallRequestError.unknown);
    }
  }

  WallRequestError _errorFor(cf.FirebaseFunctionsException e) => switch (e.code) {
    'unauthenticated' => WallRequestError.signedOut,
    'invalid-argument' => WallRequestError.textRejected,
    'resource-exhausted' => WallRequestError.dailyLimit,
    'failed-precondition' when e.message == 'own-request' => WallRequestError.ownRequest,
    'failed-precondition' when e.message == 'request-closed' => WallRequestError.closed,
    'not-found' => WallRequestError.missing,
    _ => WallRequestError.unknown,
  };

  /// A response that is not a map is a malformed reply, so it maps to unknown. Nested maps and lists are converted too.
  Map<String, Object?> _asMap(Object? value) {
    if (value is! Map<Object?, Object?>) throw const WallRequestException(WallRequestError.unknown);
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> entry in value.entries)
        if (entry.key case final String key) key: _plain(entry.value),
    };
  }

  Object? _plain(Object? value) => switch (value) {
    Map<Object?, Object?>() => _asMap(value),
    List<Object?>() => value.map(_plain).toList(growable: false),
    _ => value,
  };
}
