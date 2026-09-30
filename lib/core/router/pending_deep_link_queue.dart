import 'package:Prism/core/router/deep_link_action_entity.dart';

/// Deep links waiting for startup, handled one at a time in arrival order.
class PendingDeepLinkQueue {
  final List<DeepLinkActionEntity> _actions = <DeepLinkActionEntity>[];
  bool _draining = false;

  bool get isEmpty => _actions.isEmpty;

  void add(DeepLinkActionEntity action) => _actions.add(action);

  /// A link that throws goes to [onError]; the links after it still run.
  Future<void> drain(
    Future<void> Function(DeepLinkActionEntity action) handle, {
    required void Function(DeepLinkActionEntity action, Object error, StackTrace stackTrace) onError,
  }) async {
    if (_draining) return;
    _draining = true;
    try {
      // Re-check after each await: links can arrive while a short code resolves.
      while (_actions.isNotEmpty) {
        final DeepLinkActionEntity action = _actions.removeAt(0);
        try {
          await handle(action);
        } catch (error, stackTrace) {
          onError(action, error, stackTrace);
        }
      }
    } finally {
      _draining = false;
    }
  }
}
