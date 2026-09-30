import 'package:Prism/core/router/deep_link_action_entity.dart';

class PendingDeepLinkQueue {
  final List<DeepLinkActionEntity> _actions = <DeepLinkActionEntity>[];
  bool _draining = false;

  bool get isEmpty => _actions.isEmpty;

  void add(DeepLinkActionEntity action) => _actions.add(action);

  Future<void> drain(Future<void> Function(DeepLinkActionEntity action) handle, {required bool ready}) async {
    if (!ready || _draining) return;
    _draining = true;
    try {
      while (_actions.isNotEmpty) {
        await handle(_actions.removeAt(0));
      }
    } finally {
      _draining = false;
    }
  }
}
