import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:Prism/features/creator_directory/domain/creator_directory_entities.dart';
import 'package:Prism/features/creator_directory/domain/creator_directory_repository.dart';
import 'package:injectable/injectable.dart';

/// Gives each signed-in viewer one "More like" offer per app session. Another account gets its own offer.
@lazySingleton
class SimilarCreatorsOfferSession {
  SimilarCreatorsOfferSession(this._repository);

  static const Duration _wait = Duration(seconds: 2);

  final CreatorDirectoryRepository _repository;
  String? _usedBy;

  /// The creators to offer after a follow of [uid]. Empty when the session already used its offer, for guests, and
  /// when [uid] has no similar creators the viewer does not follow. An empty result keeps the offer for later.
  Future<List<DirectoryCreator>> claim(String uid) async {
    final String viewer = app_state.prismUser.id;
    if (!app_state.prismUser.loggedIn || _usedBy == viewer || uid.isEmpty) return const <DirectoryCreator>[];
    _usedBy = viewer;
    List<DirectoryCreator> similar = const <DirectoryCreator>[];
    try {
      similar = await _repository.similarTo(uid).timeout(_wait);
    } catch (_) {}
    if (!app_state.prismUser.loggedIn || app_state.prismUser.id != viewer) return const <DirectoryCreator>[];
    if (similar.isEmpty) _usedBy = null;
    return similar;
  }

  /// A fresh list for the sheet. A slow or failed read keeps [offered].
  Future<List<DirectoryCreator>> refresh(String uid, List<DirectoryCreator> offered) async {
    try {
      return await _repository.similarTo(uid).timeout(_wait);
    } catch (_) {
      return offered;
    }
  }
}
