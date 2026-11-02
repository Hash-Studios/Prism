import 'package:Prism/core/firestore/firestore_client.dart';
import 'package:Prism/core/firestore/firestore_collections.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

typedef ShowProBadgeState = ({bool loaded, bool shown});

/// The Settings switch for showing the Pro badge on the viewer's profile. A missing field means shown. A failed write
/// goes back and returns false.
class ShowProBadgeCubit extends Cubit<ShowProBadgeState> {
  ShowProBadgeCubit(this._firestore, this._viewerUid) : super((loaded: false, shown: true));

  final FirestoreClient _firestore;
  final String Function() _viewerUid;

  Future<void> load() async {
    bool shown = true;
    try {
      shown =
          await _firestore.getById<bool>(
            FirebaseCollections.usersV2,
            _viewerUid(),
            (data, _) => data['showProBadge'] != false,
            sourceTag: 'pro_badge.setting.read',
          ) ??
          true;
    } catch (_) {}
    if (!isClosed) emit((loaded: true, shown: shown));
  }

  Future<bool> setShown(bool shown) async {
    final bool previous = state.shown;
    emit((loaded: true, shown: shown));
    try {
      await _firestore.updateDoc(FirebaseCollections.usersV2, _viewerUid(), <String, dynamic>{
        'showProBadge': shown,
      }, sourceTag: 'pro_badge.setting.write');
      return true;
    } catch (_) {
      if (!isClosed) emit((loaded: true, shown: previous));
      return false;
    }
  }
}
