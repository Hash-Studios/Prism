import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/foundation.dart';

class CreatorFollowChanges extends ChangeNotifier {
  String _viewer = '';
  final Map<String, bool> _following = <String, bool>{};

  bool? following(String uid) =>
      app_state.prismUser.loggedIn && _viewer == app_state.prismUser.id ? _following[uid] : null;

  /// Session scopes rebuild their buttons after this reset, so no build-time notification is needed.
  void resetForViewer(String viewer) {
    if (_viewer == viewer) return;
    _viewer = viewer;
    _following.clear();
  }

  void record(String uid, bool following) {
    if (!app_state.prismUser.loggedIn) return;
    resetForViewer(app_state.prismUser.id);
    _following[uid] = following;
    notifyListeners();
  }
}

final CreatorFollowChanges creatorFollowChanges = CreatorFollowChanges();
