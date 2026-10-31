import 'package:Prism/core/state/app_state.dart' as app_state;
import 'package:flutter/foundation.dart';

class CreatorFollowChanges extends ChangeNotifier {
  String _viewer = '';
  final Map<String, bool> _following = <String, bool>{};

  bool? following(String uid) => _viewer == app_state.prismUser.id ? _following[uid] : null;

  void record(String uid, bool following) {
    if (_viewer != app_state.prismUser.id) {
      _viewer = app_state.prismUser.id;
      _following.clear();
    }
    _following[uid] = following;
    notifyListeners();
  }
}

final CreatorFollowChanges creatorFollowChanges = CreatorFollowChanges();
