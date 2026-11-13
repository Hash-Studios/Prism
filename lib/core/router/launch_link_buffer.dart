import 'package:flutter/widgets.dart';

/// Keeps links that Android pushes before the app router exists.
///
/// When Prism's task is in Recents but its process was killed, a widget or tile tap recreates the old Activity from
/// its first intent and sends the new link with `onNewIntent`. Flutter pushes that link while `main` still starts up,
/// before any Router listens, so the binding drops it. Install this right after the binding, then [drain] it once the
/// deep link dispatcher exists.
class LaunchLinkBuffer with WidgetsBindingObserver {
  final List<Uri> _links = <Uri>[];
  bool _drained = false;
  bool _initialLinkHandled = false;

  void install() => WidgetsBinding.instance.addObserver(this);

  bool claimInitialLink(Uri link) {
    if (link.path == '/' && link.query.isEmpty) return false;
    if (_initialLinkHandled) return false;
    _initialLinkHandled = true;
    return true;
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    if (_drained) return false;
    _initialLinkHandled = true;
    _links.add(routeInformation.uri);
    return true;
  }

  /// Gives each kept link to [open] in arrival order. Later links go to the router.
  void drain(void Function(Uri link) open) {
    if (_drained) return;
    _drained = true;
    WidgetsBinding.instance.removeObserver(this);
    final List<Uri> links = List<Uri>.of(_links);
    _links.clear();
    links.forEach(open);
  }
}
