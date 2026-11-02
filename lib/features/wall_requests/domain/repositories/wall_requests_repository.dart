import 'package:Prism/features/wall_requests/domain/entities/wall_request.dart';

/// Wall requests live behind callables. Every method throws [WallRequestException] on a failure the app has copy for.
abstract class WallRequestsRepository {
  Future<List<WallRequest>> list(WallRequestTab tab);

  Future<CreateWallRequestResult> create({required String text, required List<String> tags, bool force = false});

  /// Sets the caller's vote. Returns the request's vote count after the change.
  Future<int> setVote(String requestId, {required bool vote});

  /// Admin only.
  Future<void> setHidden(String requestId, {required bool hidden});
}
