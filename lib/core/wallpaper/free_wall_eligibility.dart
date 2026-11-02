import 'package:Prism/core/state/app_state.dart' as app_state;

/// An approved wall a free user can open: protected original, not streak exclusive, not in a Drop, not in a premium collection.
bool isFreeListableWallDoc(Map<String, dynamic> data) {
  if (data['review'] != true ||
      data['originalProtected'] != true ||
      data['is_streak_exclusive'] == true ||
      data['dropReserved'] == true ||
      _isTruthy(data['dropWeek'])) {
    return false;
  }
  final Object? rawCollections = data['collections'];
  if (rawCollections is! List || rawCollections.any((value) => value is! String)) return false;
  final Set<String> premiumCollections = app_state.premiumCollections.toSet();
  return !rawCollections.cast<String>().any((collection) => premiumCollections.contains(collection.trim()));
}

bool _isTruthy(Object? value) => value != null && value != false && value != '' && value != 0;
